import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import * as Sentry from '@sentry/node';

import { verifyOrgBoundary, PASSWORD_RESET_ROLES } from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface ChangePasswordData {
  currentPassword?: string;
  newPassword: string;
  targetUserId?: string;  // Only for admin resetting another user's password
}

function hashPassword(password: string): string {
  return crypto.createHash('sha256').update(password).digest('hex');
}

export const changeUserPassword = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,      // Infrequent operation
    concurrency: 80,
  },
  async (request: CallableRequest<ChangePasswordData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'rbac');
    scope.setTag('function', 'changeUserPassword');

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = request.auth.uid;
    scope.setUser({ id: callerUid });
    const { newPassword, targetUserId } = request.data;

    if (!newPassword || newPassword.length < 6) {
      throw new HttpsError('invalid-argument', 'New password must be at least 6 characters.');
    }

    const effectiveTargetId = targetUserId || callerUid;
    const isAdminReset = effectiveTargetId !== callerUid;

    // ── Load target user document ──────────────────────────────
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(effectiveTargetId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', `User ${effectiveTargetId} not found.`);
    }

    const userData = userDoc.data()!;
    const authProvider = userData.authProvider || 'password';

    // If admin resetting someone else's password, check permissions and org boundary
    if (isAdminReset) {
      const callerRole = (request.auth.token.role as string) || '';
      if (!PASSWORD_RESET_ROLES.includes(callerRole as any)) {
        throw new HttpsError('permission-denied', 'Insufficient permissions to reset passwords.');
      }

      // Org boundary: fail-closed — deny if either org ID is missing
      const targetOrgId = userData.organizationId || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';
      if (!targetOrgId || !callerOrgId) {
        throw new HttpsError(
          'permission-denied',
          'Organization information is required for cross-user password resets.',
        );
      }
      if (!verifyOrgBoundary(callerOrgId, targetOrgId, callerRole)) {
        throw new HttpsError(
          'permission-denied',
          'You can only reset passwords for users in your organization.',
        );
      }
    }

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
        console.warn('Could not update Firebase Auth password for student:', e);
        Sentry.captureException(e);
      }

      // Update passwordHash in Firestore
      await db.collection('users').doc(effectiveTargetId).update({
        passwordHash: passwordHash,
        mustChangePassword: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Audit log
      const callerRole = (request.auth.token.role as string) || 'unknown';
      const callerOrgId = (request.auth.token.organizationId as string) || userData.organizationId || '';
      await db.collection('audit_logs').add({
        organizationId: userData.organizationId || '',
        performedBy: callerUid,
        performedByRole: callerRole,
        performedByOrgId: callerOrgId,
        userId: callerUid,
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
        await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
        await db.collection('users').doc(effectiveTargetId).update({
          mustChangePassword: true,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
        await db.collection('users').doc(effectiveTargetId).update({
          mustChangePassword: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Audit log
      const callerRole = (request.auth.token.role as string) || 'unknown';
      const callerOrgId = (request.auth.token.organizationId as string) || userData.organizationId || '';
      await db.collection('audit_logs').add({
        organizationId: userData.organizationId || '',
        performedBy: callerUid,
        performedByRole: callerRole,
        performedByOrgId: callerOrgId,
        userId: callerUid,
        action: isAdminReset ? 'reset_password' : 'change_password',
        targetType: 'user',
        targetId: effectiveTargetId,
        metadata: { authProvider: 'password', isAdminReset: isAdminReset },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, targetUserId: effectiveTargetId };
    }

    // Google auth users shouldn't have passwords
    throw new HttpsError('failed-precondition', 'Cannot change password for this auth provider.');
    }); // withIsolatedScope
  });
