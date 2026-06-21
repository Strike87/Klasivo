/**
 * registerParent — P0-2: Parent registration via Cloud Function
 *
 * Previous: client wrote organizationId:null → rules rejected (is string fails on null)
 *
 * This CF:
 * 1. Creates Firebase Auth account
 * 2. Creates user doc with role:'parent' + organizationId:'' (empty string, not null)
 * 3. Sets custom claims
 * 4. If studentCode provided: links parent to student + updates orgId to match student
 * 5. Returns the new user's UID
 *
 * Rollback: deletes Auth account on any failure.
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
  studentCode?: string;  // Optional: link to student immediately
}

export const registerParent = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
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

      let authUser;

      try {
        authUser = await auth.createUser({
          email: data.email.trim().toLowerCase(),
          password: data.password,
          displayName: data.fullName.trim(),
        });

        // Create user doc — organizationId will be set when parent links to a student
        await db.collection('users').doc(authUser.uid).set({
          email: data.email.trim().toLowerCase(),
          fullName: data.fullName.trim(),
          phone: data.phone || null,
          role: 'parent',
          organizationId: '',  // Empty string (not null) — passes 'is string' rule
          tenantId: '',  // P1-5: will be set when parent links to student's org
          isActive: true,
          authProvider: 'email',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          roleVersion: 1,
        });

        // Set custom claims
        await auth.setCustomUserClaims(authUser.uid, {
          role: 'parent',
          organizationId: '',
          tenantId: '',  // P1-5: will be set when parent links to student's org
          roleVersion: 1,
        });

        // If studentCode provided, create parent_link + update parent's org to match student's org
        if (data.studentCode) {
          const studentSnapshot = await db.collection('users')
            .where('studentCode', '==', data.studentCode)
            .limit(1)
            .get();

          if (!studentSnapshot.empty) {
            const studentDoc = studentSnapshot.docs[0];
            if (studentDoc) {
              const studentOrgId = studentDoc.data()['organizationId'] as string;

              // Update parent's org to match student's org
              await db.collection('users').doc(authUser.uid).update({
                organizationId: studentOrgId,
              });

              await auth.setCustomUserClaims(authUser.uid, {
                role: 'parent',
                organizationId: studentOrgId,
                tenantId: '',  // P1-5: will be set when parent links to student's org
                roleVersion: 2,
              });

              // Create parent_link
              await db.collection('parent_links').doc(`${authUser.uid}_${studentDoc.id}`).set({
                parentId: authUser.uid,
                studentId: studentDoc.id,
                organizationId: studentOrgId,
                status: 'pending',
                createdAt: FieldValue.serverTimestamp(),
              });
            }
          }
        }

        return { success: true, uid: authUser.uid };
      } catch (error: unknown) {
        if (authUser) {
          try { await auth.deleteUser(authUser.uid); } catch {}
        }
        const msg = error instanceof Error ? error.message : String(error);
        console.error('registerParent failed:', msg);
        throw new HttpsError('internal', `Parent registration failed: ${msg}`);
      }
    });
  },
);
