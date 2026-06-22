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
 *   1. Accepts an invite code + new-user profile (unauthenticated).
 *   2. Looks up the code in invite_codes (Admin SDK bypasses rules).
 *   3. Validates: code exists, type in ['teacher','student'], isUsed=false,
 *      not expired, useCount < maxUses.
 *   4. Creates the Firebase Auth account (email/password).
 *   5. Creates the users/{uid} doc with role derived from invite type +
 *      organizationId from the invite.
 *   6. Sets custom claims (role, organizationId, scopeAccessLevel).
 *   7. Atomically flips the invite: isUsed, useCount++, usedBy, usedAt.
 *
 * Schema (CANONICAL — matches invite_code_service.dart creation):
 *   type: 'teacher' | 'student'
 *   isUsed: bool
 *   useCount: int
 *   maxUses: int
 *   expiresAt: timestamp | null
 *   organizationId: string
 *   createdBy: string
 *
 * Atomicity:
 *   If any step after Auth account creation fails, the Auth account AND the
 *   user doc are DELETED and the invite is left in its original state.
 *   This closes A9 (orphaned Auth accounts + orphaned user docs).
 *
 * Security:
 *   - Caller is unauthenticated (by design — onboarding flow).
 *   - App Check is enforced (this is an authenticated-alternative path;
 *     legitimate callers have an App Check token from their device even
 *     though they don't have a Firebase Auth session yet).
 *   - Role is derived from invite.type (never from caller input).
 *   - organizationId is taken from the invite.
 *   - Invite-minted roles cannot include super_admin or owner.
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
    enforceAppCheck: true,
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
        throw new HttpsError('not-found', 'Invite code not found.');
      }
      const inviteData = inviteDoc.data();
      const inviteId = inviteDoc.id;

      // ─── Validate invite state (CANONICAL schema) ──────────────────────
      // Schema matches lib/core/services/invite_code_service.dart:
      //   type: 'teacher' | 'student'
      //   isUsed: bool
      //   useCount: int
      //   maxUses: int
      //   expiresAt: timestamp | null
      //   organizationId: string
      const inviteType = inviteData['type'] as string;
      if (inviteType !== 'teacher' && inviteType !== 'student') {
        throw new HttpsError(
          'failed-precondition',
          `This invite code is for '${inviteType || 'unknown'}', not a redeemable type.`,
        );
      }

      // Derive role from invite type (canonical: type → role mapping).
      const role: string = inviteType; // 'teacher' or 'student' at creation time

      if (!VALID_ROLES.includes(role as KlasivoRole)) {
        throw new HttpsError(
          'failed-precondition',
          `Invite code has invalid type '${role}'. Contact the administrator who issued this invite.`,
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

      // Canonical field: isUsed (bool)
      if (inviteData['isUsed'] === true) {
        throw new HttpsError(
          'failed-precondition',
          'This invite code has already been used.',
        );
      }

      // Canonical field: expiresAt
      const expiresAt = inviteData['expiresAt'];
      if (expiresAt && (expiresAt as { toMillis: () => number }).toMillis() < Date.now()) {
        throw new HttpsError('failed-precondition', 'Invite code has expired.');
      }

      // Canonical fields: useCount / maxUses
      const useCount = (inviteData['useCount'] as number) ?? 0;
      const maxUses = (inviteData['maxUses'] as number) ?? 1;
      if (useCount >= maxUses) {
        throw new HttpsError('failed-precondition', 'Invite code has reached its usage limit.');
      }

      const organizationId = inviteData['organizationId'] as string;
      if (!organizationId || typeof organizationId !== 'string' || organizationId.length === 0) {
        throw new HttpsError(
          'failed-precondition',
          'Invite code has no organizationId. Contact the administrator who issued this invite.',
        );
      }

      // ─── Abuse control: prevent duplicate emails ──────────────────────
      try {
        await admin.auth().getUserByEmail(email.trim().toLowerCase());
        throw new HttpsError('already-exists', 'An account with this email already exists.');
      } catch (e: unknown) {
        if (e instanceof HttpsError && e.code === 'already-exists') throw e;
      }

      // ─── Create Auth account + Firestore doc + claims ─────────────────
      let createdUid: string | null = null;
      try {
        const userRecord = await admin.auth().createUser({
          email: email.trim().toLowerCase(),
          password,
          displayName: fullName.trim(),
          phoneNumber: phone || undefined,
        });
        createdUid = userRecord.uid;
        scope.setUser({ id: createdUid });

        // ─── Create users/{uid} Firestore doc ──────────────────────────
        const userData: Record<string, unknown> = {
          email: email.trim().toLowerCase(),
          fullName: fullName.trim(),
          role,
          organizationId,
          tenantId: organizationId,
          authProvider: 'password',
          isActive: true,
          createdBy: 'redeemInviteCode',
          invitedBy: inviteData['createdBy'] ?? null,
          inviteCodeId: inviteId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          roleVersion: 1,
        };
        if (phone) userData['phone'] = phone;

        await db.collection('users').doc(createdUid).set(userData);

        // ─── Set custom claims ─────────────────────────────────────────
        const customClaims = buildCustomClaims(role, organizationId);
        await admin.auth().setCustomUserClaims(createdUid, customClaims);

        // ─── Atomically flip invite (CANONICAL fields) ──────────────────
        // Use Firestore transaction to prevent race conditions where two
        // users redeem the same single-use code simultaneously.
        // Mirrors registerTeacher.ts:224-256.
        await db.runTransaction(async (tx) => {
          const freshInviteRef = db.collection('invite_codes').doc(inviteId);
          const freshSnap = await tx.get(freshInviteRef);
          if (!freshSnap.exists) {
            throw new HttpsError('not-found', 'Invite code disappeared during redemption.');
          }
          const freshData = freshSnap.data()!;
          if (freshData['isUsed'] === true) {
            throw new HttpsError(
              'failed-precondition',
              'Invite code was just used by someone else. Please try again.',
            );
          }
          const freshUseCount = (freshData['useCount'] as number) ?? 0;
          const freshMaxUses = (freshData['maxUses'] as number) ?? 1;
          if (freshUseCount >= freshMaxUses) {
            throw new HttpsError(
              'failed-precondition',
              'Invite code has reached its usage limit during redemption.',
            );
          }

          const newUseCount = freshUseCount + 1;
          tx.update(freshInviteRef, {
            isUsed: newUseCount >= freshMaxUses,
            useCount: newUseCount,
            usedBy: admin.firestore.FieldValue.arrayUnion(createdUid),
            usedAt: admin.firestore.FieldValue.arrayUnion(admin.firestore.FieldValue.serverTimestamp()),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        // ─── Audit log ─────────────────────────────────────────────────
        try {
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
              email: email.trim().toLowerCase(),
              inviteCodeId: inviteId,
              invitedBy: inviteData['createdBy'] ?? null,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            serverVerified: true,
          });
        } catch (auditErr) {
          // Non-critical: audit failure must not undo a successful redemption.
          const m = auditErr instanceof Error ? auditErr.message : String(auditErr);
          console.warn(`[redeemInviteCode] Audit log failed (non-critical): ${m}`);
        }

        return {
          success: true,
          uid: createdUid,
          role,
          organizationId,
        };
      } catch (err) {
        // ─── A9 PATCH: Rollback orphaned Auth account + user doc ───────
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
          // Also delete the Firestore user doc to prevent orphans.
          try {
            await db.collection('users').doc(createdUid).delete();
          } catch (docDeleteErr) {
            const m = docDeleteErr instanceof Error ? docDeleteErr.message : String(docDeleteErr);
            console.error(`[redeemInviteCode] Failed to roll back user doc ${createdUid}: ${m}`);
          }
        }

        // Transaction self-reverts on abort — invite state is unchanged.
        // Re-throw HttpsError as-is; wrap everything else.
        if (err instanceof HttpsError) throw err;
        Sentry.captureException(err, { tags: { step: 'redeem_invite_code' } });
        throw new HttpsError('internal', 'Invite redemption failed. Please try again.');
      }
    }); // withIsolatedScope
  },
);
