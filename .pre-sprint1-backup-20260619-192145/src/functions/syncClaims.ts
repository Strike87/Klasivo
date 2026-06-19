import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import {
  ROLE_ASSIGNMENT_ROLES,
  VALID_ROLES,
  buildCustomClaims,
  verifyOrgBoundary,
  isHigherRole,
  type KlasivoRole,
} from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — syncClaims (v2 callable)
//
// Re-syncs custom claims from the Firestore user doc.
//
// Called when:
//   - Client detects roleVersion mismatch (via ClaimsService listener)
//   - Admin manually triggers a claims refresh for a user
//
// Security:
//   - Users can sync their own claims
//   - super_admin, owner, admin can sync anyone in their org
//   - Cross-org sync requires super_admin
// ═══════════════════════════════════════════════════════════════════════════════

interface SyncClaimsData {
  targetUserId?: string;
}

export const syncClaims = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,  // C-01 PATCH: App Check now enforced
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20,      // Can burst on app open — allow moderate scaling
    concurrency: 80,
  },
  async (request: CallableRequest<SyncClaimsData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'rbac');
    scope.setTag('function', 'syncClaims');

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = request.auth.uid;
    scope.setUser({ id: callerUid });
    const callerRole = (request.auth.token.role as string) || '';
    const targetUserId = request.data.targetUserId || callerUid;

    // Users can sync their own claims; admins can sync anyone in their org
    if (targetUserId !== callerUid &&
        !ROLE_ASSIGNMENT_ROLES.includes(callerRole as KlasivoRole)) {
      throw new HttpsError('permission-denied', 'Can only sync your own claims.');
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', `User ${targetUserId} not found.`);
    }

    const userData = userDoc.data()!;
    const role = userData.role || 'student';
    const organizationId = userData.organizationId || '';

    // ─── D2 PATCH: Sanity checks on role + org ──────────────────────────
    // syncClaims is the escalation primitive in the org-takeover chain.
    // Even with D1 (Firestore rules) blocking self-mutation of role, we add
    // defense-in-depth checks here:
    //   1. role must be a valid Klasivo role (blocks garbage data → claims)
    //   2. organizationId must be a non-empty string (D8 strict — blocks
    //      empty-string org from being minted into claims)
    //   3. Caller (if admin-syncing another user) cannot be LOWER rank than
    //      the target — prevents admin from syncing super_admin claims for
    //      a peer (defense in depth against D3 bypass via Firestore manipulation).
    if (!VALID_ROLES.includes(role as KlasivoRole)) {
      throw new HttpsError(
        'failed-precondition',
        `User ${targetUserId} has invalid role '${role}'. Refusing to sync claims.`,
      );
    }
    if (!organizationId || typeof organizationId !== 'string') {
      throw new HttpsError(
        'failed-precondition',
        `User ${targetUserId} has missing or invalid organizationId. Refusing to sync claims.`,
      );
    }
    if (targetUserId !== callerUid &&
        !isHigherRole(callerRole, role)) {
      throw new HttpsError(
        'permission-denied',
        `Caller (${callerRole}) cannot sync claims for a user with equal or higher role (${role}).`,
      );
    }

    // ─── Org Boundary ───────────────────────────────────────────────────
    if (targetUserId !== callerUid && callerRole !== 'super_admin') {
      const callerOrgId = (request.auth.token.organizationId as string) || '';
      if (!verifyOrgBoundary(callerOrgId, organizationId, callerRole)) {
        throw new HttpsError(
          'permission-denied',
          'Cannot sync claims for users in a different organization.',
        );
      }
    }

    try {
    // ─── Set Custom Claims ──────────────────────────────────────────────
    const customClaims = buildCustomClaims(role, organizationId);
    await admin.auth().setCustomUserClaims(targetUserId, customClaims);

    // ─── Audit Log ──────────────────────────────────────────────────────
    await db.collection('audit_logs').add({
      organizationId: organizationId,
      performedBy: callerUid,
      performedByRole: callerRole,
      performedByOrgId: (request.auth.token.organizationId as string) || organizationId,
      userId: callerUid,
      action: 'sync_claims',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        role: role,
        scopeAccessLevel: customClaims.scopeAccessLevel,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      targetUserId,
      role,
      organizationId,
      scopeAccessLevel: customClaims.scopeAccessLevel,
    };
    } catch (err) {
      Sentry.captureException(err);
      throw err;
    }
    }); // withIsolatedScope
  });
