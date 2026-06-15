/**
 * Klasivo — Scheduled Class Reminders
 *
 * Pub/Sub-triggered function that runs every 5 minutes and sends
 * push notifications for scheduled classes starting in the next
 * 10 minutes. Prevents duplicate notifications via a `reminderSent` flag.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import { initSentry, withIsolatedScope } from '../config/sentry';

const db = admin.firestore();

export const scheduledClassReminder = onSchedule(
  {
    schedule: 'every 5 minutes',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    timeZone: 'UTC',
    memory: '256MiB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 1,       // Only one instance needed for scheduled job
  },
  async () => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'livekit');
    scope.setTag('function', 'scheduledClassReminder');

    const now = new Date();
    const tenMinutesFromNow = new Date(now.getTime() + 10 * 60 * 1000);

    try {
      // Find scheduled classes starting within the next 10 minutes
      // that haven't had a reminder sent yet
      const snapshot = await db
        .collection('scheduled_classes')
        .where('startsAt', '>=', now.toISOString())
        .where('startsAt', '<=', tenMinutesFromNow.toISOString())
        .where('reminderSent', '==', false)
        .get();

      if (snapshot.empty) {
        return; // No upcoming classes need reminders
      }

      console.log(`Found ${snapshot.size} scheduled classes needing reminders`);

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const classId = doc.id;
        const orgId = data['organizationId'] as string;
        const title = data['title'] as string;
        const teacherName = data['teacherName'] as string ?? 'Your teacher';

        // Find students in the organization
        const studentsSnapshot = await db
          .collection('users')
          .where('organizationId', '==', orgId)
          .where('role', '==', 'student')
          .where('isActive', '==', true)
          .get();

        const tokens: string[] = [];
        for (const studentDoc of studentsSnapshot.docs) {
          const fcmToken = studentDoc.data()?.['fcmToken'] as string | undefined;
          if (fcmToken) tokens.push(fcmToken);
        }

        if (tokens.length > 0) {
          try {
            const message: admin.messaging.MulticastMessage = {
              notification: {
                title: `Class Starting Soon: ${title}`,
                body: `${teacherName} will start "${title}" in less than 10 minutes. Get ready!`,
              },
              data: {
                type: 'scheduled_class_reminder',
                classId,
                orgId,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              },
              tokens,
              android: {
                priority: 'high',
                notification: {
                  channelId: 'live_classes',
                  icon: 'ic_notification',
                  sound: 'default',
                },
              },
              apns: {
                payload: {
                  aps: { sound: 'default', badge: 1 },
                },
              },
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`Reminder sent for "${title}": ${response.successCount}/${tokens.length}`);
          } catch (err: unknown) {
            const msg = err instanceof Error ? err.message : String(err);
            console.error(`Failed to send reminder for class ${classId}: ${msg}`);
            Sentry.captureException(err, {
              tags: {
                function: 'scheduledClassReminder',
                step: 'send_reminder',
                classId,
              },
            });
          }
        }

        // Mark reminder as sent to prevent duplicates
        await doc.ref.update({ reminderSent: true });
      }
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error(`Scheduled class reminder failed: ${msg}`);
      Sentry.captureException(error);
    }
    }); // withIsolatedScope
  },
);
