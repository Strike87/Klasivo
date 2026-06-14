/**
 * Klasivo — sendContactForm Callable Function
 *
 * Forwards a contact-form submission to the Klasivo support team.
 *
 * Flow (DIRECT — no queue, users expect instant confirmation):
 *   Visitor → Callable → emailService → Resend
 *
 * No authentication required — this is a public contact form.
 * Rate limiting is handled by Firebase Functions quotas.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendContactForm').call({
 *     name: 'Ahmed',
 *     email: 'ahmed@example.com',
 *     subject: 'Question about pricing',
 *     message: 'Hello, ...',
 *   });
 */
import * as functions from 'firebase-functions/v1';
export declare const sendContactForm: functions.HttpsFunction & functions.Runnable<any>;
//# sourceMappingURL=sendContactForm.d.ts.map