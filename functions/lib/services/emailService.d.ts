/**
 * Klasivo — Email Service
 *
 * Single source of truth for all email dispatch.
 * Every email goes through this file.
 *
 * Nothing sends directly to Resend except this file.
 *
 * Architecture:
 *   Templates → build HTML (no Resend logic)
 *   emailService → send via Resend (no HTML logic)
 *   Functions / Worker → validate + sanitise → call emailService
 *
 * Logging:
 *   Direct sends (welcome, contact form) → logEmail() called by the callable function
 *   Queued sends (invitations, announcements) → logEmail() called by emailWorker
 */
import * as admin from 'firebase-admin';
import type { ContactFormPayload } from '../templates/contactForm';
import type { TeacherInvitationPayload } from '../templates/teacherInvitation';
import type { AnnouncementPayload } from '../templates/schoolAnnouncement';
import type { UserRole } from '../utils/validators';
export interface EmailResult {
    success: boolean;
    id?: string;
    error?: string;
}
export type EmailType = 'welcome' | 'contact_form' | 'teacher_invitation' | 'school_announcement';
/** Types that go through the queue. Used by queueService and emailWorker. */
export declare const QUEUED_TYPES: readonly EmailType[];
/** Types that send directly (no queue). */
export declare const DIRECT_TYPES: readonly EmailType[];
export interface EmailLogEntry {
    queueId?: string;
    resendId: string;
    type: EmailType;
    to: string[];
    from: string;
    subject: string;
    replyTo?: string;
    templateVersion: string;
    status: 'sent' | 'failed';
    sentAt: admin.firestore.FieldValue;
}
/**
 * Log a sent email to Firestore.
 *
 * Called by:
 *   - Direct-send callables (welcome, contact form)
 *   - emailWorker (for queued sends)
 *
 * Fire-and-forget — if this fails we only log a warning.
 * The email was already sent; the log is for auditing, not delivery.
 */
export declare function logEmail(entry: EmailLogEntry): Promise<void>;
interface SendEmailParams {
    /** Recipient email (or array of emails) */
    to: string | string[];
    /** Email subject line */
    subject: string;
    /** HTML body */
    html: string;
    /** Sender address (defaults to Klasivo noreply) */
    from?: string;
    /** Reply-To address */
    replyTo?: string;
    /** Custom headers */
    headers?: Record<string, string>;
}
/**
 * Send a single email via Resend.
 *
 * This is the ONLY function that talks to the Resend API.
 * All other functions in this file call this one.
 *
 * Does NOT log to Firestore — the caller is responsible for logging.
 */
export declare function sendEmail({ to, subject, html, from, replyTo, headers, }: SendEmailParams): Promise<EmailResult>;
/**
 * Send a welcome email to a newly registered user. (Direct send)
 */
export declare function sendWelcomeEmail(email: string, name: string, role?: UserRole): Promise<EmailResult>;
/**
 * Send a contact-form notification to the Klasivo support team. (Direct send)
 *
 * Uses support@klasivo.app as sender and sets Reply-To to the
 * submitter so the team can respond directly.
 */
export declare function sendContactFormNotification(payload: ContactFormPayload): Promise<EmailResult>;
/**
 * Send a teacher invitation email. (Queued — called by emailWorker)
 */
export declare function sendTeacherInvitation(payload: TeacherInvitationPayload & {
    email: string;
}): Promise<EmailResult>;
/**
 * Send a school announcement email to one or more recipients. (Queued — called by emailWorker)
 */
export declare function sendSchoolAnnouncement(payload: AnnouncementPayload & {
    to: string | string[];
}): Promise<EmailResult>;
export {};
//# sourceMappingURL=emailService.d.ts.map