/**
 * Klasivo — Scheduled Class Reminders
 *
 * Pub/Sub-triggered function that runs every 5 minutes and sends
 * push notifications for scheduled classes starting in the next
 * 10 minutes. Prevents duplicate notifications via a `reminderSent` flag.
 */
export declare const scheduledClassReminder: import("firebase-functions/v2/scheduler").ScheduleFunction;
