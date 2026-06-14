import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import { queueEmail } from '../services/queueService';
import { initSentry } from '../config/sentry';

const db = admin.firestore();

export const onUserCreated = functions
  .runWith({ secrets: ['SENTRY_DSN'], memory: '256MB', timeoutSeconds: 60 })
  .auth.user()
  .onCreate(async (user) => {
    initSentry();
    Sentry.setTag('service', 'email');
    Sentry.setTag('function', 'onUserCreated');

    const uid = user.uid;
    const email = user.email;

    if (!email) {
      console.warn(`User ${uid} created without email — skipping welcome queue`);
      return null;
    }

    const displayName = user.displayName || email.split('@')[0];
    console.log(`New user created: ${uid} (${email})`);

    try {
      const userDoc = await db.collection('users').doc(uid).get();
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
  });
