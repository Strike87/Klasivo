import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

import {
  SCOPE_ASSIGNMENT_ROLES,
  buildCustomClaims,
  verifyOrgBoundary,
  type KlasivoRole,
} from '../utils/rbac';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — assignScope
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

export const assignScope = functions
  .runWith({
    secrets: [],
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onCall(async (data: AssignScopeData, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = context.auth.uid;
    const callerClaims = context.auth.token;
    const callerRole = (callerClaims.role as string) || '';

    if (!SCOPE_ASSIGNMENT_ROLES.includes(callerRole as KlasivoRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions to assign scope.');
    }

    const { targetUserId, scope, organizationId } = data;
    if (!targetUserId || !scope || !organizationId) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUserId, scope, and organizationId are required.');
    }

    // ─── Org Boundary ───────────────────────────────────────────────────
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (!verifyOrgBoundary(callerOrgId, organizationId, callerRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Cannot assign scope in a different organization.');
    }

    // ─── Get Target User ────────────────────────────────────────────────
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', `User ${targetUserId} not found.`);
    }

    const userData = userDoc.data()!;
    const targetRole = userData.role || 'student';

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
    const customClaims = buildCustomClaims(targetRole, organizationId);
    await admin.auth().setCustomUserClaims(targetUserId, customClaims);

    // ─── Audit Log ──────────────────────────────────────────────────────
    await db.collection('audit_logs').add({
      organizationId: organizationId,
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
  });
