/**
 * Klasivo — Firebase Cloud Functions
 *
 * All functions are exported from this single entry point
 * so Firebase can discover and deploy them.
 *
 * ─── Email Functions ──────────────────────────────────────────
 *   onUserCreated          — Auth trigger: send welcome email (direct)
 *   sendContactForm        — Public: forward contact form to support (direct)
 *   sendTeacherInvitation  — Auth: queue teacher invitation
 *   sendSchoolAnnouncement — Auth: queue announcement
 *
 * ─── Email Worker ─────────────────────────────────────────────
 *   emailWorker            — Processes emailQueue, retries on failure
 *
 * ─── Auth Triggers ────────────────────────────────────────────
 *   onUserDelete           — Cascade-delete org data when owner removed
 *
 * ─── Firestore Triggers ──────────────────────────────────────
 *   onNewMessageNotification — Push notification on new notification doc
 *   onNewMessage             — Push notification on new message doc
 *
 * ─── Firebase Auth ────────────────────────────────────────────
 *   Email Verification  → user.sendEmailVerification()  (native)
 *   Password Reset      → FirebaseAuth.instance.sendPasswordResetEmail()  (native)
 *   No custom Resend functions needed for these.
 */
import * as functions from 'firebase-functions/v1';
export { onUserCreated } from './functions/onUserCreated';
export { sendContactForm } from './functions/sendContactForm';
export { sendTeacherInvitationFn as sendTeacherInvitation } from './functions/sendTeacherInvitation';
export { sendSchoolAnnouncementFn as sendSchoolAnnouncement } from './functions/sendSchoolAnnouncement';
export { emailWorker } from './workers/emailWorker';
/**
 * Cascade delete all organization data when a Firebase Auth user (owner) is deleted.
 * Also handles cleanup when any user is deleted.
 */
export declare const onUserDelete: functions.CloudFunction<import("firebase-admin/auth").UserRecord>;
/**
 * Firestore trigger: When a new notification document is created with
 * relatedType === 'conversation', send an FCM push notification.
 */
export declare const onNewMessageNotification: functions.CloudFunction<functions.firestore.QueryDocumentSnapshot>;
/**
 * Firestore trigger: When a new message is created directly, also send
 * push notifications to all conversation participants (except sender).
 */
export declare const onNewMessage: functions.CloudFunction<functions.firestore.QueryDocumentSnapshot>;
//# sourceMappingURL=index.d.ts.map