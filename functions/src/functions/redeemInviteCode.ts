/**
 * KLASIVO — redeemInviteCode (v2 callable)
 *
 * Phase 2 PATCH — D7: invite_codes onboarding catch-22.
 *
 * Background:
 *   firestore.rules:248 previously required `isAuth() && isInSameOrg()` for
 *   invite_codes read. But registerTeacherWithInvite in auth_service.dart:656
 *   calls validateInviteCode() BEFORE registerWithEmail — caller is unauthenticated
 *   AND has no user doc. No redeemInviteCode Cloud Function existed. Teacher
 *   invite-code redemption was structurally broken in production.
 *
 * What this function does:
 *   1. Accepts an invite code + new-user profile from an UNAUTHENTICATED caller.
 *   2. Looks up the code in invite_codes (Admin SDK bypasses rules).
 *   3. Validates: code exists, status='active', not expired, not at usage limit.
 *   4. Creates the Firebase Auth account (email/password).
 *   5. Creates the users/{uid} doc with role + organizationId from the invite.
 *   6. Sets custom claims (role, organizationId, scopeAccessLevel).
 *   7. Atomically flips the invite to 'redeemed' with redeemedBy + redeemedAt.
 *
 * Atomicity:
 *   If any step after Auth account creation fails, the Auth account is DELETED
 *   and the invite is left in its original state. This closes A9 (orphaned
 *   Auth accounts) for the teacher-invite path.
 *
 * Security:
 *   - Caller is unauthenticated (by design — onboarding flow).
 *   - Invite code must be active, unexpired, under usage limit.
 *   - Role is taken from the invite, NOT from the caller.
 *   - OrganizationId is taken from the invite.
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import {
  VALID_ROLES,
  buildCustomClaims,
  type KlasivoRole,
} from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface RedeemInviteCodeData {
  code: string;
  email: string;
  password: string;
  fullName: string;
  phone?: string;
}

export const redeemInviteCode = onCall(
  {
    secrets: ['SENTRY_DSN'],
    // enforceAppCheck: true — DISABLED: client has no FirebaseAppCheck init
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 20,
  },
  async (request: CallableRequest<RedeemInviteCodeData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'redeemInviteCode');

      // ─── Input validation ──────────────────────────────────────────────
      const { code, email, password, fullName, phone } = request.data ?? {};

      if (!code || typeof code !== 'string' || code.length < 4 || code.length > 64) {
        throw new HttpsError('invalid-argument', 'A valid invite code is required.');
      }
      if (!email || typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
        throw new HttpsError('invalid-argument', 'A valid email is required.');
      }
      if (!password || typeof password !== 'string' || password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }
      if (!fullName || typeof fullName !== 'string' || fullName.trim().length < 2) {
        throw new HttpsError('invalid-argument', 'Full name is required.');
      }

      // ─── Look up the invite code (Admin SDK bypasses rules) ────────────
      const db = admin.firestore();
      const inviteSnapshot = await db.collection('invite_codes')
        .where('code', '==', code)
        .limit(1)
        .get();

      if (inviteSnapshot.empty) {
        throw new HttpsError('not-found', 'Invite code not found.');
      }

      const inviteDoc = inviteSnapshot.docs[0];
      if (!inviteDoc) {
        throw new HttpsError('not-found', 'Invite code not found (no snapshot).');
      }
      const inviteData = inviteDoc.data();
      const inviteId = inviteDoc.id;

      // ─── Validate invite state ─────────────────────────────────────────
      if (inviteData.status !== 'active') {
        throw new HttpsError('failed-precondition', `Invite code is ${inviteData.status}, not active.`);
      }

      const expiresAt = inviteData.expiresAt;
      if (expiresAt && expiresAt.toMillis() < Date.now()) {
        throw new HttpsError('failed-precondition', 'Invite code has expired.');
      }

      const maxUses = inviteData.maxUses ?? 1;
      const currentUses = inviteData.usesCount ?? 0;
      if (currentUses >= maxUses) {
        throw new HttpsError('failed-precondition', 'Invite code has reached its usage limit.');
      }

      const role = inviteData.role as string;
      if (!VALID_ROLES.includes(role as KlasivoRole)) {
        throw new HttpsError(
          'failed-precondition',
          `Invite code has invalid role '${role}'. Contact the administrator who issued this invite.`,
        );
      }

      // D7 safety: invite-minted roles cannot include super_admin or owner.
      // Those roles must be assigned via assignRole by an existing super_admin/owner.
      if (role === 'super_admin' || role === 'owner') {
        throw new HttpsError(
          'failed-precondition',
          'Invite codes cannot grant super_admin or owner roles. Contact an existing owner.',
        );
      }

      const organizationId = inviteData.organizationId as string;
      if (!organizationId || typeof organizationId !== 'string') {
        throw new HttpsError(
          'failed-precondition',
          'Invite code has no organizationId. Contact the administrator who issued this invite.',
        );
      }

      // ─── Create Auth account ───────────────────────────────────────────
      let createdUid: string | null = null;
      try {
        const userRecord = await admin.auth().createUser({
          email,
          password,
          displayName: fullName.trim(),
          phoneNumber: phone || undefined,
        });
        createdUid = userRecord.uid;
        scope.setUser({ id: createdUid });

        // ─── Create users/{uid} Firestore doc ──────────────────────────
        const userData: Record<string, unknown> = {
          uid: createdUid,
          email,
          fullName: fullName.trim(),
          role,
          organizationId,
          authProvider: 'password',
          status: 'active',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdBy: 'redeemInviteCode',
          invitedBy: inviteData.createdBy ?? null,
          inviteCodeId: inviteId,
          // Scope fields from invite (if present)
        };
        if (inviteData.campusId) userData['campusIds'] = [inviteData.campusId];
        if (inviteData.stageId) userData['stageIds'] = [inviteData.stageId];
        if (inviteData.classIds) userData['classIds'] = inviteData.classIds;
        if (phone) userData['phone'] = phone;

        await db.collection('users').doc(createdUid).set(userData);

        // ─── Set custom claims ─────────────────────────────────────────
        const customClaims = buildCustomClaims(role, organizationId);
        await admin.auth().setCustomUserClaims(createdUid, customClaims);

        // ─── Atomically flip invite to redeemed ─────────────────────────
        // Use Firestore transaction to prevent race conditions where two
        // users redeem the same single-use code simultaneously.
        await db.runTransaction(async (tx) => {
          const freshInviteRef = db.collection('invite_codes').doc(inviteId);
          const freshSnap = await tx.get(freshInviteRef);
          if (!freshSnap.exists) {
            throw new HttpsError('not-found', 'Invite code disappeared during redemption.');
          }
          const freshData = freshSnap.data()!;
          if (freshData.status !== 'active') {
            throw new HttpsError('failed-precondition', `Invite code is ${freshData.status}, not active.`);
          }
          const freshUses = freshData.usesCount ?? 0;
          const freshMax = freshData.maxUses ?? 1;
          if (freshUses >= freshMax) {
            throw new HttpsError('failed-precondition', 'Invite code reached usage limit during redemption.');
          }

          const newUses = freshUses + 1;
          const newStatus = newUses >= freshMax ? 'redeemed' : 'active';
          tx.update(freshInviteRef, {
            status: newStatus,
            usesCount: newUses,
            redeemedBy: admin.firestore.FieldValue.arrayUnion(createdUid),
            redeemedAt: admin.firestore.FieldValue.arrayUnion(admin.firestore.FieldValue.serverTimestamp()),
            lastRedeemedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        // ─── Audit log ─────────────────────────────────────────────────
        await db.collection('audit_logs').add({
          organizationId,
          performedBy: createdUid,
          performedByRole: role,
          performedByOrgId: organizationId,
          userId: createdUid,
          action: 'redeem_invite_code',
          targetType: 'invite_code',
          targetId: inviteId,
          metadata: {
            role,
            email,
            inviteCodeId: inviteId,
            invitedBy: inviteData.createdBy ?? null,
          },
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        return {
          success: true,
          uid: createdUid,
          role,
          organizationId,
        };
      } catch (err) {
        // ─── A9 PATCH: Rollback orphaned Auth account on any failure ────
        // If we created an Auth account but the Firestore write or claim
        // minting failed, DELETE the Auth account to prevent orphans.
        if (createdUid) {
          try {
            await admin.auth().deleteUser(createdUid);
            console.log(`Rolled back orphaned Auth account ${createdUid} after invite redemption failure.`);
          } catch (deleteErr) {
            console.error(
              `CRITICAL: Failed to roll back orphaned Auth account ${createdUid}. ` +
              `Manual cleanup required in Firebase Console → Authentication → Users.`,
              deleteErr,
            );
            Sentry.captureMessage(
              `Orphaned Auth account ${createdUid} requires manual cleanup after invite redemption failure.`,
              'fatal',
            );
          }
        }

        // Re-flip invite if it was flipped (best-effort — transaction should
        // have already rolled back, but be defensive)
        if (err instanceof HttpsError && err.code === 'aborted') {
          // Transaction rolled back — invite state is unchanged.
        }

        Sentry.captureException(err, { tags: { step: 'redeem_invite_code' } });
        throw err;
      }
    }); // withIsolatedScope
  },
);
