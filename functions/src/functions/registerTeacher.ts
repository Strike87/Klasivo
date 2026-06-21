/**
 * registerTeacher — P0-3: Teacher registration via Cloud Function
 *
 * Previous: registerTeacherWithInvite in auth_service.dart did everything
 * client-side (create Auth, create user doc, flip invite_codes.isUsed).
 * The invite_codes update required `safeStaffUpdate()` which requires
 * `isStaffInSameOrg()` — but the newly-created teacher's custom claims
 * hadn't been synced yet, so the rules engine couldn't verify org
 * membership reliably → permission-denied.
 *
 * This CF mirrors registerOwner/registerParent: does everything server-side
 * using Admin SDK (bypasses Firestore rules), then signs the user in on
 * the client.
 *
 * Flow:
 *   1. Look up invite code by `code` field (Admin SDK bypasses rules)
 *   2. Validate: type='teacher', isUsed=false, not expired, useCount < maxUses
 *   3. Create Firebase Auth account
 *   4. Create users/{uid} doc with role='teacher' + organizationId from invite
 *   5. Set custom claims (role, organizationId, roleVersion)
 *   6. Atomically flip invite: isUsed=true, usedBy, usedAt, useCount++
 *   7. Write audit log
 *   8. Return { uid, organizationId, role, fullName, email }
 *
 * Rollback: deletes Auth account on any failure (closes A9 orphaned-Account
 * risk for the teacher-invite path).
 *
 * Security:
 *   - Caller is unauthenticated (by design — registration flow).
 *   - Role is forced to 'teacher' regardless of invite.type (defensive).
 *   - OrganizationId comes from the invite (server-validated).
 *   - enforceAppCheck: false (default) — registration is a pre-auth public
 *     endpoint. App Check tokens cannot be reliably minted before sign-in.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface RegisterTeacherData {
  email: string;
  password: string;
  fullName: string;
  inviteCode: string;
  phone?: string;
}

export const registerTeacher = onCall(
  {
    secrets: ['SENTRY_DSN'],
    // enforceAppCheck: false (default) — registration is a pre-auth public endpoint.
    // App Check tokens cannot be reliably minted before Firebase Auth sign-in,
    // so enforceAppCheck:true returns UNAUTHENTICATED to legitimate sign-ups.
    // Abuse is mitigated by: input validation, Firebase Auth rate limits on
    // createUser, and the email-duplicate guard below.
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'registerTeacher');

      const data = request.data as RegisterTeacherData;

      // ─── Input validation ──────────────────────────────────────────────
      if (!data.email || !data.password || !data.fullName || !data.inviteCode) {
        throw new HttpsError(
          'invalid-argument',
          'email, password, fullName, and inviteCode are required.',
        );
      }
      if (data.password.length < 6) {
        throw new HttpsError(
          'invalid-argument',
          'Password must be at least 6 characters.',
        );
      }
      if (data.fullName.trim().length < 2) {
        throw new HttpsError(
          'invalid-argument',
          'Full name must be at least 2 characters.',
        );
      }
      if (data.inviteCode.trim().length < 4) {
        throw new HttpsError(
          'invalid-argument',
          'A valid invite code is required.',
        );
      }

      const auth = getAuth();
      const db = getFirestore();

      // ─── Look up invite code (Admin SDK bypasses rules) ────────────────
      const inviteSnapshot = await db
        .collection('invite_codes')
        .where('code', '==', data.inviteCode.trim())
        .limit(1)
        .get();

      if (inviteSnapshot.empty) {
        throw new HttpsError(
          'not-found',
          'Invalid or expired invite code.',
        );
      }

      const inviteDoc = inviteSnapshot.docs[0];
      if (!inviteDoc) {
        throw new HttpsError(
          'not-found',
          'Invalid or expired invite code.',
        );
      }
      const inviteData = inviteDoc.data();
      const inviteId = inviteDoc.id;
      const inviteRef = inviteDoc.ref;

      // ─── Validate invite state ─────────────────────────────────────────
      // Schema (matches lib/core/services/invite_code_service.dart):
      //   type: 'teacher' | 'student'
      //   isUsed: bool
      //   useCount: int
      //   maxUses: int
      //   expiresAt: timestamp | null
      //   organizationId: string
      if (inviteData['type'] !== 'teacher') {
        throw new HttpsError(
          'failed-precondition',
          'This invite code is not for teachers.',
        );
      }
      if (inviteData['isUsed'] === true) {
        throw new HttpsError(
          'failed-precondition',
          'This invite code has already been used.',
        );
      }

      const expiresAt = inviteData['expiresAt'];
      if (expiresAt && (expiresAt as { toMillis: () => number }).toMillis() < Date.now()) {
        throw new HttpsError(
          'failed-precondition',
          'This invite code has expired.',
        );
      }

      const useCount = (inviteData['useCount'] as number) ?? 0;
      const maxUses = (inviteData['maxUses'] as number) ?? 1;
      if (useCount >= maxUses) {
        throw new HttpsError(
          'failed-precondition',
          'This invite code has reached its usage limit.',
        );
      }

      const organizationId = inviteData['organizationId'] as string;
      if (!organizationId || typeof organizationId !== 'string' || organizationId.length === 0) {
        throw new HttpsError(
          'failed-precondition',
          'Invite code has no organization. Contact the administrator who issued this invite.',
        );
      }

      // ─── Abuse control: prevent duplicate emails ──────────────────────
      try {
        await auth.getUserByEmail(data.email.trim().toLowerCase());
        throw new HttpsError(
          'already-exists',
          'An account with this email already exists.',
        );
      } catch (e: unknown) {
        if (e instanceof HttpsError && e.code === 'already-exists') throw e;
      }

      // ─── Create Auth account + Firestore doc + claims ─────────────────
      let authUser: { uid: string } | null = null;

      try {
        // 1. Create Auth account
        authUser = await auth.createUser({
          email: data.email.trim().toLowerCase(),
          password: data.password,
          displayName: data.fullName.trim(),
        });
        scope.setUser({ id: authUser.uid });

        // 2. Create users/{uid} doc
        await db.collection('users').doc(authUser.uid).set({
          email: data.email.trim().toLowerCase(),
          fullName: data.fullName.trim(),
          phone: data.phone || null,
          role: 'teacher',
          organizationId,
          tenantId: organizationId,  // P1-5: org-specific tenant
          isActive: true,
          hasCompletedSetup: true,
          authProvider: 'password',
          isEmailVerified: false,
          photoUrl: null,
          invitedBy: inviteData['createdBy'] ?? null,
          inviteCodeId: inviteId,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          roleVersion: 1,
        });

        // 3. Set custom claims (role + organizationId + roleVersion)
        await auth.setCustomUserClaims(authUser.uid, {
          role: 'teacher',
          organizationId,
          tenantId: organizationId,
          roleVersion: 1,
        });

        // 4. Atomically flip invite code (transaction prevents race conditions)
        await db.runTransaction(async (tx) => {
          const freshSnap = await tx.get(inviteRef);
          if (!freshSnap.exists) {
            throw new HttpsError(
              'not-found',
              'Invite code disappeared during redemption.',
            );
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
              'Invite code has reached its usage limit.',
            );
          }

          const newUseCount = freshUseCount + 1;
          tx.update(inviteRef, {
            isUsed: newUseCount >= freshMaxUses,
            useCount: newUseCount,
            usedBy: authUser!.uid,
            usedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        });

        // 5. Audit log
        await db.collection('audit_logs').add({
          organizationId,
          performedBy: authUser.uid,
          performedByRole: 'teacher',
          performedByOrgId: organizationId,
          userId: authUser.uid,
          action: 'register_teacher_via_invite',
          targetType: 'invite_code',
          targetId: inviteId,
          metadata: {
            email: data.email,
            inviteCodeId: inviteId,
            invitedBy: inviteData['createdBy'] ?? null,
          },
          timestamp: FieldValue.serverTimestamp(),
          serverVerified: true,
        });

        return {
          success: true,
          uid: authUser.uid,
          organizationId,
          role: 'teacher',
          fullName: data.fullName.trim(),
          email: data.email.trim().toLowerCase(),
        };
      } catch (error: unknown) {
        // A9 PATCH: Rollback orphaned Auth account on any failure.
        if (authUser) {
          try {
            await auth.deleteUser(authUser.uid);
            console.log(
              `Rolled back orphaned Auth account ${authUser.uid} after teacher registration failure.`,
            );
          } catch (deleteErr) {
            console.error(
              `CRITICAL: Failed to roll back orphaned Auth account ${authUser.uid}. ` +
                `Manual cleanup required in Firebase Console → Authentication → Users.`,
              deleteErr,
            );
          }
        }

        const msg = error instanceof Error ? error.message : String(error);
        console.error('registerTeacher failed:', msg);

        // Re-throw HttpsError as-is; wrap everything else.
        if (error instanceof HttpsError) throw error;
        throw new HttpsError('internal', `Registration failed: ${msg}`);
      }
    });
  },
);
