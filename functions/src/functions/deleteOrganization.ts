/**
 * Klasivo — Delete Organization (C-08 PATCH)
 *
 * Performs a transactional, audited, owner-only org shutdown.
 *
 * Flow:
 *   1. Caller MUST be the org owner (or super_admin).
 *   2. Org MUST have `shutdownRequested == true` AND
 *      `shutdownRequestedAt` >= 24h ago (cooldown prevents impulse-deletes
 *      from a compromised account).
 *   3. Cascade-archive (soft delete): classes, students, staff, invites.
 *   4. Mark org as `archived: true, archivedAt: now, archivedBy: callerUid`.
 *   5. Audit log entry.
 *
 * Data is NEVER hard-deleted. The org can be restored by setting
 * `archived: false` in Firestore (Admin SDK).
 *
 * Why a Cloud Function:
 *   - Client rules deny `delete: if false;` on organizations.
 *   - Admin SDK bypasses rules, so the CF can perform the cascade.
 *   - The 24h cooldown + role check + audit log are enforced server-side,
 *     not client-side (which would be trivially bypassable).
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import { initSentry, withIsolatedScope } from '../config/sentry';

interface DeleteOrgData {
  organizationId: string;
  confirmName?: string;  // Optional: require typing the org name to confirm
}

const SHUTDOWN_COOLDOWN_MS = 24 * 60 * 60 * 1000;  // 24 hours

export const deleteOrganization = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,  // C-01 PATCH
    region: 'us-central1',
    memory: '512MiB',       // Cascade needs more memory
    timeoutSeconds: 300,    // 5 min — large orgs take time
    minInstances: 0,
    maxInstances: 5,        // Very infrequent operation
    concurrency: 4,
  },
  async (request: CallableRequest<DeleteOrgData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'organizations');
      scope.setTag('function', 'deleteOrganization');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';
      const { organizationId, confirmName } = request.data;

      scope.setUser({ id: callerUid });

      // ─── Input validation ──────────────────────────────────────────────
      if (!organizationId || typeof organizationId !== 'string') {
        throw new HttpsError('invalid-argument', 'organizationId is required.');
      }

      // ─── Role check: only owner or super_admin ─────────────────────────
      if (callerRole !== 'owner' && callerRole !== 'super_admin') {
        throw new HttpsError(
          'permission-denied',
          'Only the organization owner can delete the organization.',
        );
      }

      // ─── Org boundary check ────────────────────────────────────────────
      if (callerRole !== 'super_admin' && callerOrgId !== organizationId) {
        throw new HttpsError(
          'permission-denied',
          'You can only delete your own organization.',
        );
      }

      const db = admin.firestore();

      // ─── Load the org doc ──────────────────────────────────────────────
      const orgDoc = await db.collection('organizations').doc(organizationId).get();
      if (!orgDoc.exists) {
        throw new HttpsError('not-found', `Organization ${organizationId} not found.`);
      }
      const orgData = orgDoc.data()!;

      // ─── Verify caller is the org owner ────────────────────────────────
      if (orgData.ownerId !== callerUid && callerRole !== 'super_admin') {
        throw new HttpsError(
          'permission-denied',
          'Only the organization owner can delete the organization.',
        );
      }

      // ─── Optional: confirm org name matches ────────────────────────────
      if (confirmName !== undefined && confirmName !== orgData.name) {
        throw new HttpsError(
          'invalid-argument',
          `Confirmation name does not match. Expected: "${orgData.name}"`,
        );
      }

      // ─── Already archived? ─────────────────────────────────────────────
      if (orgData.archived === true) {
        throw new HttpsError(
          'failed-precondition',
          'Organization is already archived.',
        );
      }

      // ─── Cooldown check: shutdownRequested must be true AND >= 24h old ─
      if (!orgData.shutdownRequested) {
        throw new HttpsError(
          'failed-precondition',
          'Shutdown must be requested first. Set `shutdownRequested: true` ' +
          'on the org doc, then wait 24 hours before calling deleteOrganization.',
        );
      }
      const requestedAt = orgData.shutdownRequestedAt?.toMillis?.()
        || (orgData.shutdownRequestedAt ? new Date(orgData.shutdownRequestedAt).getTime() : 0);
      if (!requestedAt) {
        throw new HttpsError(
          'failed-precondition',
          'shutdownRequestedAt timestamp is missing. Re-request shutdown.',
        );
      }
      const elapsed = Date.now() - requestedAt;
      if (elapsed < SHUTDOWN_COOLDOWN_MS) {
        const remainingMs = SHUTDOWN_COOLDOWN_MS - elapsed;
        const remainingHours = Math.ceil(remainingMs / (60 * 60 * 1000));
        throw new HttpsError(
          'failed-precondition',
          `Shutdown cooldown not yet elapsed. ${remainingHours} hour(s) remaining. ` +
          `This 24h cooldown protects against impulse-deletes from a compromised account.`,
        );
      }

      // ─── Cascade archive (soft delete) ─────────────────────────────────
      // Archive (don't hard-delete): classes, students, staff, invites.
      // Use batched writes for efficiency.
      const batch = db.batch();
      const now = admin.firestore.FieldValue.serverTimestamp();

      // Archive all classes in the org
      const classesSnap = await db.collection('classes')
        .where('organizationId', '==', organizationId)
        .get();
      classesSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          isArchived: true,
          archivedAt: now,
          archivedBy: callerUid,
          archivedReason: 'org_shutdown',
        });
      });

      // Archive all users in the org (students, teachers, staff — NOT the
      // owner, who remains so they can re-activate or be audited)
      const usersSnap = await db.collection('users')
        .where('organizationId', '==', organizationId)
        .where('role', '!=', 'owner')
        .get();
      usersSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          isArchived: true,
          archivedAt: now,
          archivedBy: callerUid,
          archivedReason: 'org_shutdown',
        });
      });

      // Revoke all pending invites
      const invitesSnap = await db.collection('invite_codes')
        .where('organizationId', '==', organizationId)
        .where('isUsed', '==', false)
        .get();
      invitesSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          isRevoked: true,
          revokedAt: now,
          revokedBy: callerUid,
          revokedReason: 'org_shutdown',
        });
      });

      // Archive the org itself
      batch.update(orgDoc.ref, {
        archived: true,
        archivedAt: now,
        archivedBy: callerUid,
        archivedReason: 'owner_requested_shutdown',
      });

      await batch.commit();

      // ─── Audit log ─────────────────────────────────────────────────────
      await db.collection('audit_logs').add({
        organizationId,
        performedBy: callerUid,
        performedByRole: callerRole,
        action: 'delete_organization',
        targetType: 'organization',
        targetId: organizationId,
        metadata: {
          orgName: orgData.name || '',
          classesArchived: classesSnap.size,
          usersArchived: usersSnap.size,
          invitesRevoked: invitesSnap.size,
          shutdownRequestedAt: orgData.shutdownRequestedAt || null,
        },
        timestamp: now,
      });

      Sentry.captureMessage(
        `Organization archived: ${organizationId} by ${callerUid} ` +
        `(${classesSnap.size} classes, ${usersSnap.size} users, ${invitesSnap.size} invites)`,
        'info',
      );

      return {
        success: true,
        organizationId,
        archived: {
          classes: classesSnap.size,
          users: usersSnap.size,
          invites: invitesSnap.size,
        },
      };
    });  // withIsolatedScope
  });
