import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import {
  SCOPE_ASSIGNMENT_ROLES,
  buildCustomClaims,
  verifyOrgBoundary,
  type KlasivoRole,
} from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — assignScope (v2 callable)
//
// Assigns scope (campus/stage/class/subject/academicYear/student IDs)
// to a user. Updates Firestore user doc AND refreshes custom claims.
//
// Security:
//   - Only super_admin, owner, admin, campus_manager, stage_manager
//   - Caller must be in the same org (unless super_admin)
//   - Updates custom claims immediately (no longer relies solely on
//     roleVersion listener → syncClaims flow)
// ═══════════════════════════════════════════════════════════════════════════════

interface ScopeData {
  campusIds?: string[];
  stageIds?: string[];
  classIds?: string[];
  subjectIds?: string[];
  academicYearIds?: string[];
  studentIds?: string[];
}

interface AssignScopeData {
  targetUserId: string;
  scope: ScopeData;
  organizationId: string;
}

export const assignScope = onCall(
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
  async (request: CallableRequest<AssignScopeData>) => {
    initSentry();
    return withIsolatedScope(async (sentryScope) => {
    sentryScope.setTag('service', 'rbac');
    sentryScope.setTag('function', 'assignScope');

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = request.auth.uid;
    sentryScope.setUser({ id: callerUid });
    const callerClaims = request.auth.token;
    const callerRole = (callerClaims.role as string) || '';

    if (!SCOPE_ASSIGNMENT_ROLES.includes(callerRole as KlasivoRole)) {
      throw new HttpsError('permission-denied', 'Insufficient permissions to assign scope.');
    }

    const { targetUserId, scope, organizationId } = request.data;
    if (!targetUserId || !scope || !organizationId) {
      throw new HttpsError('invalid-argument', 'targetUserId, scope, and organizationId are required.');
    }

    // ─── D4 PATCH: Validate scope arrays ──────────────────────────────
    // Previous rule did no validation on scope arrays → caller could inject
    // arbitrary strings, non-array values, or huge arrays.
    const MAX_SCOPE_ARRAY_LENGTH = 500;
    const scopeKeys = ['campusIds', 'stageIds', 'classIds', 'subjectIds', 'academicYearIds', 'studentIds'] as const;
    for (const key of scopeKeys) {
      if (key in scope) {
        const value = (scope as Record<string, unknown>)[key];
        if (!Array.isArray(value)) {
          throw new HttpsError('invalid-argument', `scope.${key} must be an array.`);
        }
        if (value.length > MAX_SCOPE_ARRAY_LENGTH) {
          throw new HttpsError('invalid-argument', `scope.${key} exceeds max length of ${MAX_SCOPE_ARRAY_LENGTH}.`);
        }
        for (const item of value) {
          if (typeof item !== 'string' || item.length === 0) {
            throw new HttpsError('invalid-argument', `scope.${key} must contain only non-empty strings.`);
          }
        }
      }
    }

    // ─── D4 PATCH: Self-targeting block ─────────────────────────────────
    // Callers cannot assign scope to themselves via this function. Self-scope
    // is a privilege escalation primitive (a campus_manager could grant
    // themselves all campuses). Scope assignment must come from a HIGHER-
    // privileged caller. Exception: super_admin/owner/admin can self-assign
    // because they already have all-access scope (the call is effectively a no-op).
    if (callerUid === targetUserId &&
        !['super_admin', 'owner', 'admin'].includes(callerRole)) {
      throw new HttpsError(
        'permission-denied',
        'Cannot assign scope to yourself. Ask a higher-privileged admin.',
      );
    }

    // ─── Org Boundary ───────────────────────────────────────────────────
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (!verifyOrgBoundary(callerOrgId, organizationId, callerRole)) {
      throw new HttpsError('permission-denied', 'Cannot assign scope in a different organization.');
    }

    try {
    // ─── Get Target User ────────────────────────────────────────────────
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', `User ${targetUserId} not found.`);
    }

    const userData = userDoc.data()!;
    const targetRole = userData.role || 'student';

    // ─── D4 PATCH: Use TARGET user's actual org, not caller-supplied org ──
    // Previous rule used request.data.organizationId (caller-supplied) for the
    // org boundary check AND for building custom claims. A caller could pass
    // a different org's ID and the function would happily mint claims for
    // that org. Now we read the target's actual org from Firestore and use
    // THAT for both the boundary check and claim minting.
    const targetOrgId = userData.organizationId || '';
    if (!targetOrgId) {
      throw new HttpsError(
        'failed-precondition',
        `Target user ${targetUserId} has no organizationId. Cannot assign scope.`,
      );
    }
    // Verify caller-supplied organizationId matches target's actual org.
    // This catches the case where a caller passes a mismatched orgId either
    // maliciously or by mistake.
    if (organizationId !== targetOrgId) {
      throw new HttpsError(
        'permission-denied',
        `organizationId mismatch: caller passed ${organizationId} but target user is in ${targetOrgId}.`,
      );
    }

    const oldScope = {
      campusIds: userData.campusIds || [],
      stageIds: userData.stageIds || [],
      classIds: userData.classIds || [],
      subjectIds: userData.subjectIds || [],
      academicYearIds: userData.academicYearIds || [],
      studentIds: userData.studentIds || [],
    };

    // ─── Update Firestore ───────────────────────────────────────────────
    const updateData: Record<string, unknown> = {
      roleVersion: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (scope.campusIds !== undefined) updateData['campusIds'] = scope.campusIds;
    if (scope.stageIds !== undefined) updateData['stageIds'] = scope.stageIds;
    if (scope.classIds !== undefined) updateData['classIds'] = scope.classIds;
    if (scope.subjectIds !== undefined) updateData['subjectIds'] = scope.subjectIds;
    if (scope.academicYearIds !== undefined) updateData['academicYearIds'] = scope.academicYearIds;
    if (scope.studentIds !== undefined) updateData['studentIds'] = scope.studentIds;

    await db.collection('users').doc(targetUserId).update(updateData);

    // ─── Refresh Custom Claims ──────────────────────────────────────────
    // Immediately update custom claims so the client doesn't have to wait
    // for the roleVersion listener → syncClaims round-trip. This eliminates
    // the window where claims are stale after a scope change.
    // D4 PATCH: use targetOrgId (from Firestore), not caller-supplied organizationId.
    const customClaims = buildCustomClaims(targetRole, targetOrgId);
    await admin.auth().setCustomUserClaims(targetUserId, customClaims);

    // ─── Audit Log ──────────────────────────────────────────────────────
    // D4 PATCH: use targetOrgId (from Firestore), not caller-supplied organizationId.
    await db.collection('audit_logs').add({
      organizationId: targetOrgId,
      performedBy: callerUid,
      performedByRole: callerRole,
      performedByOrgId: (callerClaims.organizationId as string) || targetOrgId,
      userId: callerUid,
      action: 'assign_scope',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        targetRole: targetRole,
        oldScope: oldScope,
        newScope: scope,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, targetUserId, scope };
    } catch (err) {
      Sentry.captureException(err);
      throw err;
    }
    }); // withIsolatedScope
  });
