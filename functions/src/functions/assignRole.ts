import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

const VALID_ROLES = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
  'academic_supervisor', 'teacher', 'assistant_teacher', 'observer',
  'student', 'parent',
];

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

    // Only super_admin, owner, admin can assign roles
    const callerRole = (callerClaims.role as string) || '';
    if (!['super_admin', 'owner', 'admin'].includes(callerRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Only admins can assign roles.');
    }

    // ─── Input Validation ───────────────────────────────────────────────
    const { targetUserId, newRole, organizationId } = data;
    if (!targetUserId || !newRole || !organizationId) {
      throw new functions.https.HttpsError('invalid-argument', 'targetUserId, newRole, and organizationId are required.');
    }
    if (!VALID_ROLES.includes(newRole)) {
      throw new functions.https.HttpsError('invalid-argument', `Invalid role: ${newRole}. Valid roles: ${VALID_ROLES.join(', ')}`);
    }

    // Admin cannot assign super_admin or owner
    if (callerRole === 'admin' && ['super_admin', 'owner'].includes(newRole)) {
      throw new functions.https.HttpsError('permission-denied', 'Admins cannot assign super_admin or owner roles.');
    }

    // Caller must be in the same organization
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (callerOrgId !== organizationId && callerRole !== 'super_admin') {
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
    // An owner cannot remove their own owner role. This prevents accidental
    // lockout where the last owner demotes themselves, leaving the
    // organization without any owner.
    if (callerUid === targetUserId && oldRole === 'owner' && newRole !== 'owner') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'You cannot remove your own owner role. Assign another owner first.',
      );
    }

    // ─── Last-Owner Protection ─────────────────────────────────────────
    // If demoting an owner (not self — that was caught above), ensure the
    // organization will still have at least one remaining owner.
    if (oldRole === 'owner' && newRole !== 'owner' && callerRole !== 'super_admin') {
      const ownersSnapshot = await db.collection('users')
        .where('organizationId', '==', organizationId)
        .where('role', '==', 'owner')
        .get();

      const ownerCount = ownersSnapshot.size;
      if (ownerCount <= 1) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Cannot demote the last owner. Assign another owner first.',
        );
      }
    }

    // ─── Set Custom Claims ──────────────────────────────────────────────
    const scopeAccessLevel = SCOPE_ACCESS_LEVELS[newRole] || 'self';
    await admin.auth().setCustomUserClaims(targetUserId, {
      role: newRole,
      organizationId: organizationId,
      scopeAccessLevel: scopeAccessLevel,
    });

    // ─── Update User Document ───────────────────────────────────────────
    // Use atomic increment for roleVersion — avoids race conditions under
    // concurrent calls. roleVersion is a refresh trigger, not business data,
    // so the exact value in the response is informational only.
    await db.collection('users').doc(targetUserId).update({
      role: newRole,
      roleVersion: admin.firestore.FieldValue.increment(1),
      scopeAccessLevel: scopeAccessLevel,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ─── Audit Log ──────────────────────────────────────────────────────
    await db.collection('audit_logs').add({
      organizationId: organizationId,
      userId: callerUid,
      action: 'assign_role',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        oldRole: oldRole,
        newRole: newRole,
        scopeAccessLevel: scopeAccessLevel,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      targetUserId,
      oldRole,
      newRole,
      scopeAccessLevel,
    };
  });
