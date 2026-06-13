import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const SCOPE_ACCESS_LEVELS: Record<string, string> = {
  super_admin: 'all',
  owner: 'all',
  admin: 'all',
  campus_manager: 'campus',
  stage_manager: 'stage',
  academic_supervisor: 'stage',
  teacher: 'class',
  assistant_teacher: 'class',
  observer: 'all',
  student: 'self',
  parent: 'linked',
};

interface SyncClaimsData {
  targetUserId?: string;
}

export const syncClaims = functions
  .runWith({
    secrets: [],
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onCall(async (data: SyncClaimsData, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = context.auth.uid;
    const callerRole = (context.auth.token.role as string) || '';
    const targetUserId = data.targetUserId || callerUid;

    // Users can sync their own claims; admins can sync anyone in their org
    if (targetUserId !== callerUid && !['super_admin', 'owner', 'admin'].includes(callerRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Can only sync your own claims.');
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', `User ${targetUserId} not found.`);
    }

    const userData = userDoc.data()!;
    const role = userData.role || 'student';
    const organizationId = userData.organizationId || '';
    const scopeAccessLevel = SCOPE_ACCESS_LEVELS[role] || 'self';

    // If admin syncing another user, verify same org
    if (targetUserId !== callerUid && callerRole !== 'super_admin') {
      const callerOrgId = (context.auth.token.organizationId as string) || '';
      if (callerOrgId !== organizationId) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot sync claims for users in a different organization.');
      }
    }

    // Set custom claims
    await admin.auth().setCustomUserClaims(targetUserId, {
      role: role,
      organizationId: organizationId,
      scopeAccessLevel: scopeAccessLevel,
    });

    // Audit log
    await db.collection('audit_logs').add({
      organizationId: organizationId,
      userId: callerUid,
      action: 'sync_claims',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        role: role,
        scopeAccessLevel: scopeAccessLevel,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      targetUserId,
      role,
      organizationId,
      scopeAccessLevel,
    };
  });
