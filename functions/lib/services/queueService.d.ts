/**
 * Klasivo — Queue Service
 *
 * Writes email jobs to the emailQueue Firestore collection.
 * The emailWorker picks them up and sends them via Resend.
 *
 * Why a queue?
 *   - Retries automatically on Resend failures
 *   - Survives Resend outages
 *   - Handles bulk announcements safely
 *   - Callable functions return immediately
 *
 * Direct-send emails (welcome, contact form) do NOT go through the queue.
 */
import * as admin from 'firebase-admin';
import type { EmailType } from './emailService';
export interface QueueEmailParams {
    /** Which email type to send */
    type: EmailType;
    /** Recipient email(s) */
    to: string | string[];
    /** Type-specific data passed to the email template */
    payload: Record<string, unknown>;
}
export type QueueStatus = 'pending' | 'processing' | 'sent' | 'failed';
export interface EmailQueueEntry {
    type: EmailType;
    to: string[];
    payload: Record<string, unknown>;
    status: QueueStatus;
    attempts: number;
    createdAt: admin.firestore.FieldValue;
    scheduledAt?: admin.firestore.FieldValue;
    sentAt?: admin.firestore.FieldValue;
    error?: string;
}
/**
 * Queue an email for async delivery.
 *
 * Returns immediately with the queue document ID.
 * The emailWorker will process it and update the status.
 *
 * @returns The Firestore document ID of the queue entry
 */
export declare function queueEmail(params: QueueEmailParams): Promise<string>;
//# sourceMappingURL=queueService.d.ts.map