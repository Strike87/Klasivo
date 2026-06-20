import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import {
  VALID_ROLES,
  ROLE_ASSIGNMENT_ROLES,
  buildCustomClaims,
  verifyOrgBoundary,
  roleRank,
  type KlasivoRole,
} from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — assignRole (v2 callable)
//
// Assigns a role to a user. Updates both custom claims and Firestore.
//
// Security:
//   - Only super_admin, owner, admin can assign roles
//   - Admin cannot assign super_admin or owner
//   - Caller must be in the same org (unless super_admin)
//   - Last-owner protection: cannot demote the last owner
//   - Self-demotion protection: owner cannot remove own owner role
// ═══════════════════════════════════════════════════════════════════════════════

interface AssignRoleData {
  targetUserId: string;
  newRole: string;
  organizationId: string;
}

export const assignRole = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,  // C-01 PATCH: App Check now enforced
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,      // Admin-only — low concurrency need
    concurrency: 80,
  },
  async (request: CallableRequest<AssignRoleData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'rbac');
    scope.setTag('function', 'assignRole');

    // ─── Auth Check ─────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = request.auth.uid;
    const callerClaims = request.auth.token;
    const callerRole = (callerClaims.role as string) || '';

    scope.setUser({ id: callerUid });

    if (!ROLE_ASSIGNMENT_ROLES.includes(callerRole as KlasivoRole)) {
      throw new HttpsError('permission-denied', 'Only admins can assign roles.');
    }

    // ─── Input Validation ───────────────────────────────────────────────
    const { targetUserId, newRole, organizationId } = request.data;
    if (!targetUserId || !newRole || !organizationId) {
      throw new HttpsError('invalid-argument', 'targetUserId, newRole, and organizationId are required.');
    }
    if (!VALID_ROLES.includes(newRole as KlasivoRole)) {
      throw new HttpsError('invalid-argument', `Invalid role: ${newRole}. Valid roles: ${VALID_ROLES.join(', ')}`);
    }

    // ─── D3 PATCH: super_admin assignment restrictions ──────────────────
    // Only super_admin can assign super_admin. Owner and admin are blocked.
    // Previous rule only blocked admin → owner could self-promote a peer to
    // super_admin → GLOBAL cross-org control.
    if (newRole === 'super_admin' && callerRole !== 'super_admin') {
      throw new HttpsError(
        'permission-denied',
        'Only super_admin can assign the super_admin role.',
      );
    }

    // Admin cannot assign owner or super_admin
    if (callerRole === 'admin' && ['super_admin', 'owner'].includes(newRole)) {
      throw new HttpsError('permission-denied', 'Admins cannot assign super_admin or owner roles.');
    }

    // ─── D3 PATCH: Self-targeting block ─────────────────────────────────
    // Callers cannot change their own role via assignRole. Self-role-changes
    // are structurally suspect (self-promotion, self-demotion edge cases).
    // Owner self-demotion is explicitly blocked at line 97 below; this block
    // extends the prohibition to ALL self-targeted calls.
    // Exception: super_admin may re-assign super_admin to themselves (no-op
    // but allowed for admin tooling).
    if (callerUid === targetUserId && callerRole !== 'super_admin') {
      throw new HttpsError(
        'permission-denied',
        'Cannot change your own role via assignRole. Use a separate owner-approved flow.',
      );
    }

    // ─── D3 PATCH: Hierarchy enforcement ────────────────────────────────
    // Caller cannot assign a role HIGHER than their own. Prevents admin from
    // making someone an owner, campus_manager from making someone an admin, etc.
    if (roleRank(newRole) > roleRank(callerRole)) {
      throw new HttpsError(
        'permission-denied',
        `Cannot assign a role higher than your own (${callerRole} → ${newRole}).`,
      );
    }

    // Caller must be in the same organization
    if (!verifyOrgBoundary(
      (callerClaims.organizationId as string) || '',
      organizationId,
      callerRole,
    )) {
      throw new HttpsError('permission-denied', 'Cannot assign roles in a different organization.');
    }

    // ─── Get Target User ────────────────────────────────────────────────
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', `User ${targetUserId} not found.`);
    }
    const oldRole = userDoc.data()?.role || 'unknown';

    // P1-1 PATCH: Verify target user belongs to the same org as caller.
    // Previous code checked caller's org but never verified target's org.
    const targetOrgId = userDoc.data()?.organizationId || '';
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (targetOrgId !== callerOrgId) {
      throw new HttpsError(
        'permission-denied',
        `Target user is in a different organization (${targetOrgId} vs ${callerOrgId}).`,
      );
    }

    // P1-1 (rbac) PATCH: Caller must also be strictly higher than the target's
    // CURRENT role. The D3 check above only prevents promoting someone above
    // your own rank; this prevents demoting someone who is at or above your
    // rank (e.g. an admin (70) demoting an owner (80) — privilege escalation).
    // Applies to non-super_admin only.
    if (callerRole !== 'super_admin' && roleRank(callerRole) <= roleRank(oldRole)) {
      throw new HttpsError(
        'permission-denied',
        `Cannot modify a user with equal or higher role (caller=${callerRole}, target=${oldRole}).`,
      );
    }

    // ─── Owner Self-Demotion Protection ────────────────────────────────
    if (callerUid === targetUserId && oldRole === 'owner' && newRole !== 'owner') {
      throw new HttpsError(
        'failed-precondition',
        'You cannot remove your own owner role. Assign another owner first.',
      );
    }

    // ─── Last-Owner Protection ─────────────────────────────────────────
    if (oldRole === 'owner' && newRole !== 'owner' && callerRole !== 'super_admin') {
      const ownersSnapshot = await db.collection('users')
        .where('organizationId', '==', organizationId)
        .where('role', '==', 'owner')
        .get();

      if (ownersSnapshot.size <= 1) {
        throw new HttpsError(
          'failed-precondition',
          'Cannot demote the last owner. Assign another owner first.',
        );
      }
    }

    // ─── Set Custom Claims ──────────────────────────────────────────────
    const customClaims = buildCustomClaims(newRole, organizationId);
    await admin.auth().setCustomUserClaims(targetUserId, customClaims);

    // ─── Update User Document ───────────────────────────────────────────
    await db.collection('users').doc(targetUserId).update({
      role: newRole,
      roleVersion: admin.firestore.FieldValue.increment(1),
      scopeAccessLevel: customClaims.scopeAccessLevel,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ─── Audit Log ──────────────────────────────────────────────────────
    await db.collection('audit_logs').add({
      organizationId: organizationId,
      performedBy: callerUid,
      performedByRole: callerRole,
      performedByOrgId: (callerClaims.organizationId as string) || organizationId,
      userId: callerUid,
      action: 'assign_role',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        oldRole: oldRole,
        newRole: newRole,
        scopeAccessLevel: customClaims.scopeAccessLevel,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      targetUserId,
      oldRole,
      newRole,
      scopeAccessLevel: customClaims.scopeAccessLevel,
    };
    }); // withIsolatedScope
  });
