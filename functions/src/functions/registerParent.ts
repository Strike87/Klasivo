/**
 * registerParent — P0-2: Parent registration via Cloud Function
 *
 * Previous: client wrote organizationId:null → rules rejected (is string fails on null)
 *
 * This CF:
 * 1. Creates Firebase Auth account
 * 2. Creates user doc with role:'parent' + organizationId:'' (empty string, not null)
 * 3. Sets custom claims (organizationId:'' — filled in by linkParent when the
 *    parent later links a child)
 * 4. Returns the new user's UID
 *
 * The parent's real organizationId + claims are written server-side by the
 * linkParent Cloud Function when they redeem an 8-character linking code at
 * /auth/parent-link. The client cannot write its own organizationId (D1) or
 * mint claims (Admin SDK only).
 *
 * Rollback: deletes Auth account + user doc on any failure.
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface RegisterParentData {
  email: string;
  password: string;
  fullName: string;
  phone?: string;
}

export const registerParent = onCall(
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
      scope.setTag('function', 'registerParent');

      const data = request.data as RegisterParentData;

      if (!data.email || !data.password || !data.fullName) {
        throw new HttpsError('invalid-argument', 'email, password, fullName are required.');
      }
      if (data.password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }

      const auth = getAuth();
      const db = getFirestore();

      // P2-2: Abuse control — prevent duplicate emails (matches registerOwner).
      try {
        await auth.getUserByEmail(data.email.trim().toLowerCase());
        throw new HttpsError('already-exists', 'An account with this email already exists.');
      } catch (e: any) {
        if (e.code === 'already-exists') throw e;
      }

      let authUser;

      try {
        authUser = await auth.createUser({
          email: data.email.trim().toLowerCase(),
          password: data.password,
          displayName: data.fullName.trim(),
        });

        // Create user doc. organizationId stays empty until the parent links a
        // child via linkParent (which writes the real org + re-mints claims).
        await db.collection('users').doc(authUser.uid).set({
          email: data.email.trim().toLowerCase(),
          fullName: data.fullName.trim(),
          phone: data.phone || null,
          role: 'parent',
          organizationId: '',  // Empty string (not null) — passes 'is string' rule
          tenantId: '',  // Filled in by linkParent when the parent links a child
          isActive: true,
          authProvider: 'email',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          roleVersion: 1,
        });

        // Set custom claims (organizationId empty until linkParent fills it).
        await auth.setCustomUserClaims(authUser.uid, {
          role: 'parent',
          organizationId: '',
          tenantId: '',
          roleVersion: 1,
        });

        return {
          success: true,
          uid: authUser.uid,
          // organizationId is intentionally empty here — the client routes the
          // parent to /auth/parent-link, and linkParent populates it + re-mints
          // claims. Returning '' (not null) keeps Hive/GoRouter type checks happy.
          organizationId: '',
          role: 'parent',
        };
      } catch (error: unknown) {
        // Rollback Auth + user doc to prevent orphans.
        if (authUser) {
          try { await auth.deleteUser(authUser.uid); } catch {}
          try { await db.collection('users').doc(authUser.uid).delete(); } catch {}
        }
        const msg = error instanceof Error ? error.message : String(error);
        console.error('registerParent failed:', msg);
        throw new HttpsError('internal', 'Parent registration failed. Please try again.');
      }
    });
  },
);
