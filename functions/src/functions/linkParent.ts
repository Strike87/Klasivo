/**
 * linkParent — Parent-child linking via 8-character code (server-side).
 *
 * Closes the parent deadlock (N1/N3). After registration, a parent has
 * organizationId:'' and empty-org claims. The client flow (parent_link_service
 * → /auth/parent-link) collects an 8-char linking code, but the client cannot
 * complete the link because:
 *   - firestore.rules parent_links create requires isStaff() (parent isn't staff)
 *   - the parent cannot update status/approvedBy/approvedAt on its own link
 *   - the parent cannot write its own organizationId (privilege field, D1)
 *   - only Admin SDK can mint custom claims
 *
 * This CF does everything server-side using the Admin SDK, mirroring
 * registerTeacher / createStudent:
 *   1. Resolve caller = parent (role check)
 *    2. Look up the pending parent_links doc by `code`
 *   3. Validate: status='pending', not expired
 *   4. Transaction: flip the link to 'approved' + set parentId/linkedAt
 *   5. Write parent's organizationId + tenantId (the deadlock fix)
 *   6. Re-mint parent claims with the real org + bump roleVersion
 *   7. Write the deterministic parent_links/{parentId}_{studentId} doc that
 *      parentHasAccessToStudent() (firestore.rules:153) requires
 *   8. Stamp parentId on the student doc
 *   9. Audit log
 *  10. Return { studentId, studentName, organizationId }
 *
 * Rollback: if the post-transaction steps (claims/orgId write) fail, the link
 * doc is reverted to 'pending' so the parent can retry.
 *
 * Security:
 *   - Caller must be authenticated AND role=='parent'.
 *   - organizationId is taken from the link doc (staff-created, server-validated).
 *   - The code is an opaque 8-char token looked up by equality — no org scoping
 *     needed because the code is generated server-side by a staff member.
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import { buildCustomClaims, type KlasivoRole } from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface LinkParentData {
  code: string;
}

export const linkParent = onCall(
  {
    secrets: ['SENTRY_DSN'],
    // enforceAppCheck: false (default). Called immediately after registration,
    // before the parent's token may reliably carry an App Check token. Auth is
    // enforced via the request.auth check below.
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 40,
  },
  async (request: CallableRequest<LinkParentData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'parent_link');
      scope.setTag('function', 'linkParent');

      // ─── Auth check ────────────────────────────────────────────────────
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }
      const parentId = request.auth.uid;
      scope.setUser({ id: parentId });

      const code = request.data?.code;
      if (!code || typeof code !== 'string' || code.trim().length < 4) {
        throw new HttpsError('invalid-argument', 'A valid linking code is required.');
      }

      const db = admin.firestore();

      // ─── Resolve caller role (claim → Firestore fallback) ──────────────
      const callerRoleClaim = (request.auth.token?.role as string) || '';
      let callerRole = callerRoleClaim;
      if (!callerRole) {
        const callerDoc = await db.collection('users').doc(parentId).get();
        callerRole = (callerDoc.data()?.['role'] as string) || '';
      }
      scope.setTag('caller_role', callerRole);

      if (callerRole !== 'parent') {
        throw new HttpsError(
          'permission-denied',
          'Only parent accounts can link a child.',
        );
      }

      // ─── Look up the pending link by code ──────────────────────────────
      const linkSnapshot = await db
        .collection('parent_links')
        .where('code', '==', code.trim())
        .where('status', '==', 'pending')
        .limit(1)
        .get();

      if (linkSnapshot.empty) {
        throw new HttpsError('not-found', 'Invalid or already used linking code.');
      }

      const linkDoc = linkSnapshot.docs[0];
      if (!linkDoc) {
        throw new HttpsError('not-found', 'Invalid or already used linking code.');
      }
      const linkData = linkDoc.data();
      const linkRef = linkDoc.ref;

      // ─── Validate expiry ───────────────────────────────────────────────
      const expiresAt = linkData['expiresAt'] as
        | { toDate: () => Date }
        | null
        | undefined;
      if (expiresAt && expiresAt.toDate().getTime() < Date.now()) {
        throw new HttpsError('failed-precondition', 'This linking code has expired.');
      }

      const studentId = linkData['studentId'] as string;
      const organizationId = linkData['organizationId'] as string;
      if (!studentId || !organizationId) {
        throw new HttpsError(
          'failed-precondition',
          'Linking code is missing required data. Ask the teacher to regenerate it.',
        );
      }

      // ─── Transaction: atomically flip the link to approved ─────────────
      // Prevents two parents redeeming the same code concurrently.
      await db.runTransaction(async (tx) => {
        const freshSnap = await tx.get(linkRef);
        if (!freshSnap.exists) {
          throw new HttpsError('not-found', 'Linking code disappeared during redemption.');
        }
        const freshData = freshSnap.data()!;
        if (freshData['status'] !== 'pending') {
          throw new HttpsError(
            'failed-precondition',
            'This linking code has already been used.',
          );
        }
        // Re-check expiry inside the transaction (someone could have let it lapse).
        const freshExpires = freshData['expiresAt'] as
          | { toDate: () => Date }
          | null
          | undefined;
        if (freshExpires && freshExpires.toDate().getTime() < Date.now()) {
          throw new HttpsError('failed-precondition', 'This linking code has expired.');
        }

        tx.update(linkRef, {
          status: 'approved',
          parentId,
          linkedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      // ─── Post-transaction steps: org write + claims + deterministic doc ─
      // If any of these fail, revert the link to 'pending' so the parent can retry.
      try {
        // Verify the student exists in the expected org.
        const studentDoc = await db.collection('users').doc(studentId).get();
        if (!studentDoc.exists) {
          throw new HttpsError('not-found', 'Linked student not found.');
        }
        const studentOrgId = (studentDoc.data()?.['organizationId'] as string) || '';
        if (studentOrgId !== organizationId) {
          throw new HttpsError(
            'failed-precondition',
            'Linking code organization mismatch. Ask the teacher to regenerate it.',
          );
        }

        // THE DEADLOCK FIX — write the parent's real org + tenantId.
        await db.collection('users').doc(parentId).update({
          organizationId,
          tenantId: organizationId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Re-mint claims with the real org. scopeAccessLevel for parent = 'linked'.
        const customClaims = buildCustomClaims('parent' as KlasivoRole, organizationId);
        await admin.auth().setCustomUserClaims(parentId, customClaims);

        // Bump roleVersion so the client refreshes its token immediately.
        await db.collection('users').doc(parentId).set(
          { roleVersion: admin.firestore.FieldValue.increment(1) },
          { merge: true },
        );

        // Write the deterministic parent_links/{parentId}_{studentId} doc that
        // parentHasAccessToStudent() looks up by ID.
        await db
          .collection('parent_links')
          .doc(`${parentId}_${studentId}`)
          .set({
            code: linkData['code'] ?? null,
            organizationId,
            studentId,
            generatedBy: linkData['generatedBy'] ?? null,
            parentId,
            status: 'approved',
            expiresAt: linkData['expiresAt'] ?? null,
            linkedAt: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        // Stamp parentId on the student doc (mirrors legacy client behavior).
        await db.collection('users').doc(studentId).update({
          parentId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const studentName = (studentDoc.data()?.['fullName'] as string) || '';

        // ─── Audit log ──────────────────────────────────────────────────
        try {
          await db.collection('audit_logs').add({
            organizationId,
            performedBy: parentId,
            performedByRole: 'parent',
            performedByOrgId: organizationId,
            userId: parentId,
            action: 'parent_link_child',
            targetType: 'user',
            targetId: studentId,
            metadata: { studentId, linkCodeDocId: linkDoc.id },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            serverVerified: true,
          });
        } catch (auditErr) {
          // Non-critical: audit failure must not undo a successful link.
          const m = auditErr instanceof Error ? auditErr.message : String(auditErr);
          console.warn(`[linkParent] Audit log failed (non-critical): ${m}`);
        }

        return {
          success: true,
          studentId,
          studentName,
          organizationId,
        };
      } catch (postTxError) {
        // Revert the link doc to pending so the parent can retry.
        try {
          await linkRef.update({
            status: 'pending',
            parentId: admin.firestore.FieldValue.delete(),
            linkedAt: admin.firestore.FieldValue.delete(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (revertErr) {
          // Log loudly — the link is now in an inconsistent state and needs
          // manual cleanup, but don't mask the original error.
          const m = revertErr instanceof Error ? revertErr.message : String(revertErr);
          console.error(
            `[linkParent] CRITICAL: failed to revert link ${linkDoc.id} to pending: ${m}`,
          );
          Sentry.captureMessage(
            `linkParent: link ${linkDoc.id} stuck in approved state after post-tx failure for parent ${parentId}`,
            'fatal',
          );
        }

        if (postTxError instanceof HttpsError) throw postTxError;
        const m = postTxError instanceof Error ? postTxError.message : String(postTxError);
        console.error(`[linkParent] post-transaction failure: ${m}`);
        Sentry.captureException(postTxError, {
          tags: { function: 'linkParent', step: 'post_transaction' },
        });
        throw new HttpsError('internal', 'Linking failed. Please try again.');
      }
    });
  },
);
