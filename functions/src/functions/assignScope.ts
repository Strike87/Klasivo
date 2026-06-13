import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

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

const ALLOWED_ROLES = ['super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager'];

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

    if (!ALLOWED_ROLES.includes(callerRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions to assign scope.');
    }

    const { targetUserId, scope, organizationId } = data;
    if (!targetUserId || !scope || !organizationId) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUserId, scope, and organizationId are required.');
    }

    // Caller must be in same org (unless super_admin)
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (callerOrgId !== organizationId && callerRole !== 'super_admin') {
      throw new functions.https.HttpsError('permission-denied', 'Cannot assign scope in a different organization.');
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', `User ${targetUserId} not found.`);
    }

    const oldScope = {
      campusIds: userDoc.data()?.campusIds || [],
      stageIds: userDoc.data()?.stageIds || [],
      classIds: userDoc.data()?.classIds || [],
      subjectIds: userDoc.data()?.subjectIds || [],
      academicYearIds: userDoc.data()?.academicYearIds || [],
      studentIds: userDoc.data()?.studentIds || [],
    };

    // Build update map — only include non-empty arrays
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

    // Audit log
    await db.collection('audit_logs').add({
      organizationId: organizationId,
      userId: callerUid,
      action: 'assign_scope',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        oldScope: oldScope,
        newScope: scope,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, targetUserId, scope };
  });
