import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

import {
  VALID_ROLES,
  ROLE_ASSIGNMENT_ROLES,
  buildCustomClaims,
  verifyOrgBoundary,
  type KlasivoRole,
} from '../utils/rbac';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — assignRole
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

export const assignRole = functions
  .runWith({
    secrets: [],
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onCall(async (data: AssignRoleData, context) => {
    // ─── Auth Check ─────────────────────────────────────────────────────
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = context.auth.uid;
    const callerClaims = context.auth.token;
    const callerRole = (callerClaims.role as string) || '';

    if (!ROLE_ASSIGNMENT_ROLES.includes(callerRole as KlasivoRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can assign roles.');
    }

    // ─── Input Validation ───────────────────────────────────────────────
    const { targetUserId, newRole, organizationId } = data;
    if (!targetUserId || !newRole || !organizationId) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUserId, newRole, and organizationId are required.');
    }
    if (!VALID_ROLES.includes(newRole as KlasivoRole)) {
      throw new functions.https.HttpsError('invalid-argument', `Invalid role: ${newRole}. Valid roles: ${VALID_ROLES.join(', ')}`);
    }

    // Admin cannot assign super_admin or owner
    if (callerRole === 'admin' && ['super_admin', 'owner'].includes(newRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Admins cannot assign super_admin or owner roles.');
    }

    // Caller must be in the same organization
    if (!verifyOrgBoundary(
      (callerClaims.organizationId as string) || '',
      organizationId,
      callerRole,
    )) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot assign roles in a different organization.');
    }

    // ─── Get Target User ────────────────────────────────────────────────
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', `User ${targetUserId} not found.`);
    }
    const oldRole = userDoc.data()?.role || 'unknown';

    // ─── Owner Self-Demotion Protection ────────────────────────────────
    if (callerUid === targetUserId && oldRole === 'owner' && newRole !== 'owner') {
      throw new functions.https.HttpsError(
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
        throw new functions.https.HttpsError(
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
      performedBy: callerUid,                                            // canonical actor field
      performedByRole: callerRole,                                       // Phase 1: add
      performedByOrgId: (callerClaims.organizationId as string) || organizationId,  // Phase 1: add
      userId: callerUid,                                                 // legacy — remove in Phase 3
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
  });
