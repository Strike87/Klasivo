/**
 * KLASIVO — deleteStudent (v2 callable)
 *
 * Phase 2 PATCH — A6: Build deleteStudent callable.
 *
 * Background:
 *   lib/core/services/student_service.dart:214-250 calls
 *   SentryFirestoreHelper.docDelete → CLIENT-SIDE Firestore delete.
 *   firestore.rules:109 `allow delete: if false` correctly blocks.
 *   No callable existed → student deletion was structurally impossible.
 *
 * What this function does:
 *   1. Caller must be authenticated staff in the same org as the student.
 *   2. Caller must be strictly higher rank than the target (D6 alignment).
 *   3. Disables (not deletes) the Firebase Auth account — preserves audit trail.
 *   4. Soft-deletes the Firestore user doc (isArchived=true, archivedAt, archivedBy).
 *   5. Removes the student from class studentCount.
 *   6. Writes audit log.
 *
 * Why soft-delete instead of hard-delete:
 *   - Preserves referential integrity (submissions, answers, exam_instances
 *     all reference studentId).
 *   - Audit trail for grade/attendance disputes.
 *   - Reversible if deletion was accidental.
 *   - Aligns with the universal soft-delete pattern (isArchived) used across
 *     the rest of the codebase.
 *
 * Hard-delete (Auth account deletion) is reserved for onUserDeleted trigger
 * which cascades cleanup of all related collections.
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import {
  STAFF_ROLES,
  verifyOrgBoundary,
  isHigherRole,
  type KlasivoRole,
} from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface DeleteStudentData {
  targetUserId: string;
  organizationId: string;
  reason?: string;
  hardDelete?: boolean;
}

export const deleteStudent = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,  // C-01 PATCH: App Check now enforced
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 20,
  },
  async (request: CallableRequest<DeleteStudentData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'student');
      scope.setTag('function', 'deleteStudent');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      scope.setUser({ id: callerUid });
      const callerRole = (request.auth.token.role as string) || '';

      if (!STAFF_ROLES.includes(callerRole as KlasivoRole)) {
        throw new HttpsError('permission-denied', 'Only staff can delete students.');
      }

      const { targetUserId, organizationId, reason, hardDelete } = request.data ?? {};

      if (!targetUserId || !organizationId) {
        throw new HttpsError('invalid-argument', 'targetUserId and organizationId are required.');
      }

      // ─── D6 alignment: caller cannot delete themselves ─────────────────
      if (callerUid === targetUserId) {
        throw new HttpsError('permission-denied', 'Cannot delete your own account via this function.');
      }

      const db = admin.firestore();

      // ─── Fetch target user ─────────────────────────────────────────────
      const userDoc = await db.collection('users').doc(targetUserId).get();
      if (!userDoc.exists) {
        throw new HttpsError('not-found', `User ${targetUserId} not found.`);
      }

      const userData = userDoc.data()!;
      const targetRole = userData.role || 'student';
      const targetOrgId = userData.organizationId || '';

      // ─── Org boundary (D8 strict — fail-closed on empty orgs) ──────────
      const callerOrgId = (request.auth.token.organizationId as string) || '';
      if (!verifyOrgBoundary(callerOrgId, targetOrgId, callerRole)) {
        throw new HttpsError(
          'permission-denied',
          'Cannot delete a student in a different organization.',
        );
      }

      // ─── Verify caller-supplied org matches target's actual org ────────
      if (organizationId !== targetOrgId) {
        throw new HttpsError(
          'permission-denied',
          `organizationId mismatch: caller passed ${organizationId} but target user is in ${targetOrgId}.`,
        );
      }

      // ─── Hierarchy check: caller must be strictly higher than target ───
      if (callerRole !== 'super_admin' && !isHigherRole(callerRole, targetRole)) {
        throw new HttpsError(
          'permission-denied',
          `Cannot delete a user with equal or higher role (caller=${callerRole}, target=${targetRole}).`,
        );
      }

      // ─── Soft-delete: mark user doc as archived ────────────────────────
      // Soft-delete preserves referential integrity for submissions, answers,
      // exam_instances, attendance, gradebook, etc. Hard-delete is reserved
      // for the onUserDeleted trigger which cascades cleanup.
      await db.collection('users').doc(targetUserId).update({
        isArchived: true,
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        archivedBy: callerUid,
        archivedReason: reason || 'deleted_by_admin',
        isActive: false,
        status: 'archived',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ─── Disable Auth account (revoke tokens, prevent login) ───────────
      // We DISABLE rather than DELETE so the audit trail (uid) is preserved.
      // True Auth deletion happens via onUserDeleted when an owner is removed.
      try {
        await admin.auth().updateUser(targetUserId, { disabled: true });
      } catch (authError: unknown) {
        // Non-critical: if the Auth account doesn't exist or is already disabled,
        // log and continue. The Firestore soft-delete is the source of truth.
        const msg = authError instanceof Error ? authError.message : String(authError);
        console.warn(`[deleteStudent] Auth disable failed (non-critical): ${msg}`);
        Sentry.captureException(authError, {
          tags: { function: 'deleteStudent', step: 'auth_disable' },
        });
      }

      // ─── Revoke refresh tokens (force re-auth on any active session) ───
      try {
        await admin.auth().revokeRefreshTokens(targetUserId);
      } catch (revokeError: unknown) {
        const msg = revokeError instanceof Error ? revokeError.message : String(revokeError);
        console.warn(`[deleteStudent] Token revoke failed (non-critical): ${msg}`);
      }

      // ─── Update class studentCount (if student was in a class) ─────────
      const classId = userData.classId;
      if (classId) {
        try {
          const countSnapshot = await db
            .collection('users')
            .where('classId', '==', classId)
            .where('role', '==', 'student')
            .where('isArchived', '==', false)
            .count()
            .get();
          await db.collection('classes').doc(classId).update({
            studentCount: countSnapshot.data().count ?? 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (countError: unknown) {
          const msg = countError instanceof Error ? countError.message : String(countError);
          console.warn(`[deleteStudent] Class count update failed (non-critical): ${msg}`);
        }
      }

      // ─── Hard-delete path (owner-only, deferrable) ─────────────────────
      // If hardDelete=true AND caller is owner/super_admin, also delete the
      // Auth account entirely. This triggers onUserDeleted which cascades
      // cleanup of all related collections. Use with caution — irreversible.
      if (hardDelete === true && isHigherRole(callerRole, 'admin')) {
        try {
          await admin.auth().deleteUser(targetUserId);
          console.log(`[deleteStudent] Hard-deleted Auth account ${targetUserId} (cascades via onUserDeleted).`);
        } catch (hardDeleteError: unknown) {
          const msg = hardDeleteError instanceof Error ? hardDeleteError.message : String(hardDeleteError);
          console.error(`[deleteStudent] Hard-delete failed (soft-delete succeeded): ${msg}`);
          Sentry.captureException(hardDeleteError, {
            tags: { function: 'deleteStudent', step: 'hard_delete' },
          });
          // Don't throw — soft-delete succeeded, hard-delete is best-effort.
        }
      }

      // ─── Audit log ─────────────────────────────────────────────────────
      await db.collection('audit_logs').add({
        organizationId: targetOrgId,
        performedBy: callerUid,
        performedByRole: callerRole,
        performedByOrgId: callerOrgId || targetOrgId,
        userId: callerUid,
        action: hardDelete ? 'hard_delete_student' : 'archive_student',
        targetType: 'user',
        targetId: targetUserId,
        metadata: {
          targetRole,
          targetClassId: classId || null,
          reason: reason || null,
          hardDelete: hardDelete === true,
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        targetUserId,
        action: hardDelete ? 'hard_deleted' : 'archived',
      };
    }); // withIsolatedScope
  },
);
