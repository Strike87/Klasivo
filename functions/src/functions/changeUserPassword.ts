import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';

interface ChangePasswordData {
  currentPassword?: string;
  newPassword: string;
  targetUserId?: string;  // Only for admin resetting another user's password
}

function hashPassword(password: string): string {
  return crypto.createHash('sha256').update(password).digest('hex');
}

export const changeUserPassword = functions
  .runWith({
    secrets: [],
    timeoutSeconds: 60,
    memory: '256MB',
  })
  .https.onCall(async (data: ChangePasswordData, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = context.auth.uid;
    const { newPassword, targetUserId } = data;

    if (!newPassword || newPassword.length < 6) {
      throw new functions.https.HttpsError('invalid-argument', 'New password must be at least 6 characters.');
    }

    const effectiveTargetId = targetUserId || callerUid;
    const isAdminReset = effectiveTargetId !== callerUid;

    // If admin resetting someone else's password, check permissions
    if (isAdminReset) {
      const callerRole = (context.auth.token.role as string) || '';
      if (!['super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager'].includes(callerRole)) {
        throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions to reset passwords.');
      }
    }

    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(effectiveTargetId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', `User ${effectiveTargetId} not found.`);
    }

    const userData = userDoc.data()!;
    const authProvider = userData.authProvider || 'password';

    // ─── Student (student_code auth) ────────────────────────────────────
    if (authProvider === 'student_code') {
      const passwordHash = hashPassword(newPassword);

      // Update Firebase Auth password if student has an auth account
      try {
        const authEmail = userData.authEmail || userData.email;
        if (authEmail) {
          await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
        }
      } catch (e) {
        // Student may not have a Firebase Auth account (bulk import without auth)
        console.warn('Could not update Firebase Auth password for student:', e);
      }

      // Update passwordHash in Firestore
      await db.collection('users').doc(effectiveTargetId).update({
        passwordHash: passwordHash,
        mustChangePassword: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Audit log
      const callerRole = (context.auth.token.role as string) || 'unknown';
      const callerOrgId = (context.auth.token.organizationId as string) || userData.organizationId || '';
      await db.collection('audit_logs').add({
        organizationId: userData.organizationId || '',
        performedBy: callerUid,                       // canonical actor field
        performedByRole: callerRole,                  // Phase 1: add
        performedByOrgId: callerOrgId,                // Phase 1: add
        userId: callerUid,                            // legacy — remove in Phase 3
        action: 'change_password',
        targetType: 'user',
        targetId: effectiveTargetId,
        metadata: { authProvider: 'student_code', isAdminReset: isAdminReset },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, targetUserId: effectiveTargetId };
    }

    // ─── Email/Password User ────────────────────────────────────────────
    if (authProvider === 'password') {
      if (isAdminReset) {
        // Admin resetting someone's password
        await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
        await db.collection('users').doc(effectiveTargetId).update({
          mustChangePassword: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // Self-service password change
        // Verify current password by trying to re-authenticate
        // (Client should verify current password before calling this)
        await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
        await db.collection('users').doc(effectiveTargetId).update({
          mustChangePassword: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Audit log
      const callerRole = (context.auth.token.role as string) || 'unknown';
      const callerOrgId = (context.auth.token.organizationId as string) || userData.organizationId || '';
      await db.collection('audit_logs').add({
        organizationId: userData.organizationId || '',
        performedBy: callerUid,                       // canonical actor field
        performedByRole: callerRole,                  // Phase 1: add
        performedByOrgId: callerOrgId,                // Phase 1: add
        userId: callerUid,                            // legacy — remove in Phase 3
        action: isAdminReset ? 'reset_password' : 'change_password',
        targetType: 'user',
        targetId: effectiveTargetId,
        metadata: { authProvider: 'password', isAdminReset: isAdminReset },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, targetUserId: effectiveTargetId };
    }

    // Google auth users shouldn't have passwords
    throw new functions.https.HttpsError('failed-precondition', 'Cannot change password for this auth provider.');
  });
