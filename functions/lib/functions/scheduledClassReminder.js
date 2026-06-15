"use strict";
/**
 * Klasivo — Scheduled Class Reminders
 *
 * Pub/Sub-triggered function that runs every 5 minutes and sends
 * push notifications for scheduled classes starting in the next
 * 10 minutes. Prevents duplicate notifications via a `reminderSent` flag.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.scheduledClassReminder = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const sentry_1 = require("../config/sentry");
const db = admin.firestore();
exports.scheduledClassReminder = (0, scheduler_1.onSchedule)({
    schedule: 'every 5 minutes',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    timeZone: 'UTC',
    memory: '256MiB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 1, // Only one instance needed for scheduled job
}, async () => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
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
                const orgId = data['organizationId'];
                const title = data['title'];
                const teacherName = data['teacherName'] ?? 'Your teacher';
                // Find students in the organization
                const studentsSnapshot = await db
                    .collection('users')
                    .where('organizationId', '==', orgId)
                    .where('role', '==', 'student')
                    .where('isActive', '==', true)
                    .get();
                const tokens = [];
                for (const studentDoc of studentsSnapshot.docs) {
                    const fcmToken = studentDoc.data()?.['fcmToken'];
                    if (fcmToken)
                        tokens.push(fcmToken);
                }
                if (tokens.length > 0) {
                    try {
                        const message = {
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
                    }
                    catch (err) {
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
        }
        catch (error) {
            const msg = error instanceof Error ? error.message : String(error);
            console.error(`Scheduled class reminder failed: ${msg}`);
            Sentry.captureException(error);
        }
    }); // withIsolatedScope
});
//# sourceMappingURL=scheduledClassReminder.js.map