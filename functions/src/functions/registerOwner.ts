/**
 * registerOwner — P0-1: Owner registration via Cloud Function
 *
 * Previous: client wrote role:'owner' → Firestore rules rejected it
 * (rules only allow student/parent/teacher on self-create).
 * No CF existed → owner registration was impossible.
 *
 * This CF:
 * 1. Creates Firebase Auth account
 * 2. Creates organization doc
 * 3. Creates user doc with role:'owner' + real organizationId
 * 4. Sets custom claims (role, organizationId, roleVersion)
 * 5. Writes audit log
 * 6. Returns the new user's UID + org ID
 *
 * Rollback: deletes Auth account + org doc on any failure.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface RegisterOwnerData {
  email: string;
  password: string;
  fullName: string;
  organizationName: string;
  phone?: string;
}

export const registerOwner = onCall(
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
      scope.setTag('function', 'registerOwner');

      const data = request.data as RegisterOwnerData;

      // Validate inputs
      if (!data.email || !data.password || !data.fullName || !data.organizationName) {
        throw new HttpsError('invalid-argument', 'email, password, fullName, organizationName are required.');
      }
      if (data.password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }
      if (data.organizationName.trim().length < 3) {
        throw new HttpsError('invalid-argument', 'Organization name must be at least 3 characters.');
      }

      const auth = getAuth();
      const db = getFirestore();

      // P2-2: Abuse controls — prevent duplicate emails.
      // (Run AFTER const auth = getAuth() so auth is in scope.)
      try {
        await auth.getUserByEmail(data.email.trim().toLowerCase());
        throw new HttpsError('already-exists', 'An account with this email already exists.');
      } catch (e: any) {
        if (e.code === 'already-exists') throw e;
      }

      let authUser;
      let orgId: string | undefined;

      try {
        // 1. Create Auth account
        authUser = await auth.createUser({
          email: data.email.trim().toLowerCase(),
          password: data.password,
          displayName: data.fullName.trim(),
        });

        // 2. Create organization
        const orgRef = await db.collection('organizations').add({
          name: data.organizationName.trim(),
          ownerId: authUser.uid,
          slug: data.organizationName.trim().toLowerCase().replace(/[^a-z0-9]/g, '-'),
          plan: 'free',
          isActive: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        orgId = orgRef.id;

        // 3. Create user doc with role:owner + real orgId
        await db.collection('users').doc(authUser.uid).set({
          email: data.email.trim().toLowerCase(),
          fullName: data.fullName.trim(),
          phone: data.phone || null,
          role: 'owner',
          organizationId: orgId,
          tenantId: orgId,  // P1-5: org-specific tenant (was 'default' — shared across orgs)
          isActive: true,
          hasCompletedSetup: false,
          authProvider: 'email',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          roleVersion: 1,
        });

        // 4. Set custom claims
        await auth.setCustomUserClaims(authUser.uid, {
          role: 'owner',
          organizationId: orgId,
          tenantId: orgId,  // P1-5: org-specific tenant (was 'default' — shared across orgs)
          roleVersion: 1,
        });

        // 5. Audit log
        await db.collection('audit_logs').add({
          organizationId: orgId,
          performedBy: authUser.uid,
          performedByRole: 'owner',
          performedByOrgId: orgId,
          action: 'register_owner',
          targetType: 'user',
          targetId: authUser.uid,
          metadata: { email: data.email, organizationName: data.organizationName },
          timestamp: FieldValue.serverTimestamp(),
          serverVerified: true,
        });

        return {
          success: true,
          uid: authUser.uid,
          organizationId: orgId,
        };
      } catch (error: unknown) {
        // Rollback: delete Auth account if created
        if (authUser) {
          try { await auth.deleteUser(authUser.uid); } catch {}
        }
        // Rollback: delete org if created
        if (orgId) {
          try { await db.collection('organizations').doc(orgId).delete(); } catch {}
        }
        const msg = error instanceof Error ? error.message : String(error);
        console.error('registerOwner failed:', msg);
        throw new HttpsError('internal', `Registration failed: ${msg}`);
      }
    });
  },
);
