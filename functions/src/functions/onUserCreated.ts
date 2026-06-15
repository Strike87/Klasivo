import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import { queueEmail } from '../services/queueService';
import { initSentry, withIsolatedScope } from '../config/sentry';

const db = admin.firestore();

export const onUserCreated = functions
  .runWith({ secrets: ['SENTRY_DSN'], memory: '256MB', timeoutSeconds: 60 })
  .auth.user()
  .onCreate(async (user) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'email');
    scope.setTag('function', 'onUserCreated');

    const uid = user.uid;
    const email = user.email;

    scope.setUser({ id: uid });

    if (!email) {
      console.warn(`User ${uid} created without email — skipping welcome queue`);
      return null;
    }

    // ─── Skip synthetic student emails ───────────────────────────────────
    // Students get internal Auth emails (student_XXXXXX@students.klasivo.app)
    // that have no real mailboxes. Welcome emails for students with real
    // addresses are sent by the createStudent callable AFTER the Firestore
    // doc is confirmed — not here.
    const SYNTHETIC_EMAIL_SUFFIX = '@students.klasivo.app';
    if (email.toLowerCase().endsWith(SYNTHETIC_EMAIL_SUFFIX)) {
      console.log(`Skipping welcome email for synthetic student email: ${uid} (${email})`);
      return null;
    }

    const displayName = user.displayName || email.split('@')[0];
    console.log(`New user created: ${uid} (${email})`);

    try {
      const userDoc = await db.collection('users').doc(uid).get();

      // Verification breadcrumb: log whether the user doc exists.
      // If it doesn't exist, the Auth trigger fired before the client's
      // Firestore .set() completed (or it was blocked by rules).
      Sentry.addBreadcrumb({
        category: 'firestore',
        message: 'onUserCreated_user_doc_readback',
        data: {
          uid,
          userDocExists: userDoc.exists,
          userDocRole: userDoc.exists ? (userDoc.data()?.['role'] ?? 'null') : 'N/A',
          userDocOrgId: userDoc.exists ? (userDoc.data()?.['organizationId'] ?? 'N/A') : 'N/A',
        },
        level: 'info',
      });

      if (!userDoc.exists) {
        // Log at warning level — this may indicate a race condition
        // where the auth trigger fires before the client writes the user doc,
        // OR it may indicate the client's .set() was blocked by security rules.
        Sentry.captureMessage(
          `onUserCreated: users/${uid} does NOT exist in Firestore — auth account may be orphaned`,
          { level: 'warning' },
        );
      }

      const role = userDoc.exists
        ? (userDoc.data()?.['role'] as string | undefined) ?? 'teacher'
        : 'teacher';

      const result = await queueEmail({
        type: 'welcome',
        category: 'welcome',
        to: email,
        payload: { name: displayName, role },
        idempotencyKey: `welcome_${uid}`,
      });

      if (result.queued) {
        console.log(`Welcome email queued for ${email} (role: ${role}, queueId: ${result.queueId})`);
      } else {
        console.log(`Welcome email already queued for ${email} (reason: ${result.reason})`);
      }
      return null;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.warn(`Welcome email queue error for ${email}: ${msg}`);
      Sentry.captureException(err);
      return null;
    }
    }); // withIsolatedScope
  });
