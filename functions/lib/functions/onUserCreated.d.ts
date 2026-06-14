/**
 * Klasivo — onUserCreated Auth Trigger
 *
 * Automatically sends a welcome email when a new Firebase Auth
 * user is created. (Direct send — no queue)
 *
 * Flow:
 *   New account → emailService → Resend
 *
 * This is fire-and-forget — if Resend is not configured the
 * function logs a warning but does NOT throw (user creation
 * must never fail because of an email issue).
 */
import * as functions from 'firebase-functions/v1';
export declare const onUserCreated: functions.CloudFunction<import("firebase-admin/auth").UserRecord>;
//# sourceMappingURL=onUserCreated.d.ts.map