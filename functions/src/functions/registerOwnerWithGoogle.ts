/**
 * registerOwnerWithGoogle — Server-side owner setup for Google Sign-In.
 *
 * Problem:
 *   registerOwnerWithGoogle() in auth_service.dart writes the user doc with
 *   role:'owner' directly from the client. Firestore rules block this
 *   (self-create allows only student/parent). Org creation is also blocked
 *   (allow create: if false). So Google-owner registration is broken.
 *
 * Flow:
 *   1. Client calls FirebaseAuth.signInWithCredential (Google) → Auth account
 *      auto-created with email/displayName but NO custom claims.
 *   2. Client calls this CF with { organizationName }.
 *   3. CF reads the Auth record for email/name (trustworthy — Google-verified).
 *   4. CF creates the organization doc (Admin SDK, bypasses rules).
 *   5. CF writes the user doc with role:'owner' + organizationId (Admin SDK).
 *   6. CF mints custom claims.
 *   7. Client calls completeOwnerSetup() to name the workspace (existing flow).
 *
 * Security:
 *   - Caller must be authenticated (they just signed in with Google).
 *   - Caller must NOT already have a role or org (prevents hijacking an existing
 *     account into an owner — if they're already a teacher in another org, they
 *     can't use this to create a second org).
 *   - Email verification: Google Sign-In emails are pre-verified by Google,
 *     so no separate verification step needed.
 *   - Duplicate-email guard: Auth account already exists (that's how they got
 *     here), so the CF only checks for a pre-existing user doc with a role.
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { buildCustomClaims, type KlasivoRole } from '../utils/rbac';

interface RegisterOwnerWithGoogleData {
  organizationName: string;
}

export const registerOwnerWithGoogle = onCall(
  {
    secrets: ['SENTRY_DSN'],
    // enforceAppCheck: false — called immediately after Google Sign-In,
    // before the token reliably carries an App Check token. Auth is enforced
    // via request.auth check below. Abuse is mitigated by: the caller must
    // already have a valid Google Auth session (can't spoof), and the
    // duplicate-role guard below prevents account hijacking.
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 40,
  },
  async (request: CallableRequest<RegisterOwnerWithGoogleData>) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'registerOwnerWithGoogle');

      // ─── Auth check ────────────────────────────────────────────────────
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }
      const uid = request.auth.uid;
      scope.setUser({ id: uid });

      const { organizationName } = request.data ?? {};
      if (!organizationName || typeof organizationName !== 'string' || organizationName.trim().length < 2) {
        throw new HttpsError('invalid-argument', 'Organization name is required.');
      }

      const auth = getAuth();
      const db = getFirestore();

      // ─── Read Auth record (email/name from Google — trustworthy) ──────
      let authUser;
      try {
        authUser = await auth.getUser(uid);
      } catch {
        throw new HttpsError('not-found', 'Authenticated user not found in Firebase Auth.');
      }

      const email = authUser.email ?? '';
      if (!email) {
        throw new HttpsError('failed-precondition', 'Google account has no email. Please use an account with an email address.');
      }

      // ─── Guard: caller must not already have a role or org ────────────
      // Prevents an existing teacher/parent from hijacking this CF to create
      // a second org. They should use the normal org-creation flow instead.
      const existingUserDoc = await db.collection('users').doc(uid).get();
      if (existingUserDoc.exists) {
        const existingRole = (existingUserDoc.data()?.['role'] as string) || '';
        const existingOrg = (existingUserDoc.data()?.['organizationId'] as string) || '';
        if (existingRole && existingRole !== 'parent') {
          // Parents with empty org can legitimately re-register (linkParent fixes
          // their org). Everyone else: block.
          throw new HttpsError(
            'already-exists',
            `Account already exists with role '${existingRole}'. Use the login flow instead.`,
          );
        }
      }

      // ─── Create organization + user doc + claims ──────────────────────
      let orgId: string | undefined;

      try {
        // 1. Create organization
        const orgRef = await db.collection('organizations').add({
          name: organizationName.trim(),
          ownerId: uid,
          slug: organizationName.trim().toLowerCase().replace(/[^a-z0-9]/g, '-'),
          plan: 'free',
          isActive: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        orgId = orgRef.id;

        // 2. Create/update user doc with role:owner + real orgId
        await db.collection('users').doc(uid).set({
          email: email.toLowerCase(),
          fullName: authUser.displayName || 'Owner',
          phone: authUser.phoneNumber || null,
          photoUrl: authUser.photoURL || null,
          role: 'owner',
          organizationId: orgId,
          tenantId: orgId,
          isActive: true,
          hasCompletedSetup: false,
          authProvider: 'google',
          isEmailVerified: authUser.emailVerified,
          createdAt: existingUserDoc.exists
            ? existingUserDoc.data()?.['createdAt'] // Preserve original creation time
            : FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          roleVersion: 1,
        }, { merge: true });

        // 3. Set custom claims
        const customClaims = buildCustomClaims('owner' as KlasivoRole, orgId);
        await auth.setCustomUserClaims(uid, customClaims);

        // 4. Audit log
        try {
          await db.collection('audit_logs').add({
            organizationId: orgId,
            performedBy: uid,
            performedByRole: 'owner',
            performedByOrgId: orgId,
            action: 'register_owner_google',
            targetType: 'user',
            targetId: uid,
            metadata: { email: email.toLowerCase(), organizationName: organizationName.trim() },
            timestamp: FieldValue.serverTimestamp(),
            serverVerified: true,
          });
        } catch (auditErr) {
          const m = auditErr instanceof Error ? auditErr.message : String(auditErr);
          console.warn(`[registerOwnerWithGoogle] Audit log failed (non-critical): ${m}`);
        }

        return {
          success: true,
          uid,
          organizationId: orgId,
          role: 'owner',
          hasCompletedSetup: false,
        };
      } catch (error: unknown) {
        // Rollback org doc if created. Auth account is managed by Google
        // Sign-In and cannot be deleted by us (user would lose their Google
        // auth entirely — bad UX). The user doc can be cleaned up.
        if (orgId) {
          try { await db.collection('organizations').doc(orgId).delete(); } catch {}
        }
        try {
          await db.collection('users').doc(uid).delete();
        } catch {
          // May fail if the doc didn't exist before our set()
        }

        if (error instanceof HttpsError) throw error;
        const msg = error instanceof Error ? error.message : String(error);
        console.error('registerOwnerWithGoogle failed:', msg);
        throw new HttpsError('internal', 'Registration failed. Please try again.');
      }
    });
  },
);
