import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import type { QueueStatus } from '../types/queue';
import type { EmailResult } from '../types/email';
import { SENDER } from '../types/email';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { sendEmail } from '../services/emailService';
import { buildWelcomeHtml } from '../templates/welcomeEmail';
import { buildTeacherInvitationHtml } from '../templates/teacherInvitation';
import { buildSchoolAnnouncementHtml } from '../templates/schoolAnnouncement';

const db = admin.firestore();

async function processQueueItem(type: string, to: string | string[], payload: Record<string, unknown>, queueId: string): Promise<EmailResult> {
  switch (type) {
    case 'welcome': {
      const name = payload['name']; const role = payload['role'];
      if (typeof name !== 'string' || name === '') return { success: false, error: 'Missing name in welcome payload' };
      const html = buildWelcomeHtml(name, typeof role === 'string' ? role : 'teacher');
      return sendEmail({ to: to as string, subject: 'Welcome to Klasivo — Your Smart School Platform', html, category: 'welcome', queueId });
    }
    case 'teacher_invitation': {
      const teacherName = payload['teacherName']; const schoolName = payload['schoolName']; const inviterName = payload['inviterName']; const inviteCode = payload['inviteCode']; const orgId = payload['orgId'];
      if (typeof teacherName !== 'string' || teacherName === '' || typeof schoolName !== 'string' || schoolName === '' || typeof inviterName !== 'string' || inviterName === '' || typeof inviteCode !== 'string' || inviteCode === '' || typeof orgId !== 'string' || orgId === '')
        return { success: false, error: 'Missing required fields in teacher_invitation payload' };
      const html = buildTeacherInvitationHtml({ teacherName, schoolName, inviterName, inviteCode, orgId });
      return sendEmail({ to: to as string, subject: `You're Invited to Join ${schoolName} on Klasivo`, html, category: 'teacher_invitation', queueId });
    }
    case 'school_announcement': {
      const schoolName = payload['schoolName']; const title = payload['title']; const message = payload['message']; const senderName = payload['senderName']; const senderRole = payload['senderRole']; const priority = payload['priority'];
      if (typeof schoolName !== 'string' || schoolName === '' || typeof title !== 'string' || title === '' || typeof message !== 'string' || message === '' || typeof senderName !== 'string' || senderName === '' || typeof senderRole !== 'string' || senderRole === '')
        return { success: false, error: 'Missing required fields in school_announcement payload' };
      const html = buildSchoolAnnouncementHtml({ schoolName, title, message, senderName, senderRole, priority: typeof priority === 'string' ? priority : 'normal' });
      const prefix = priority === 'urgent' ? '\uD83D\uDD34 ' : priority === 'important' ? '\uD83D\uDFE1 ' : '';
      return sendEmail({ to, subject: `${prefix}${title} — ${schoolName}`, html, from: SENDER.noreply, category: 'school_announcement', queueId });
    }
    default: return { success: false, error: `Unknown queue type: ${type}` };
  }
}

async function handleFailure(docRef: admin.firestore.DocumentReference, currentAttempts: number, maxAttempts: number, errorMessage: string): Promise<void> {
  const newAttempts = currentAttempts + 1;
  if (newAttempts < maxAttempts) {
    // P2-2: Exponential backoff — delay = 2^attempts seconds (2s, 4s, 8s, 16s, 32s)
    const delaySeconds = Math.pow(2, newAttempts);
    const retryAfter = new Date(Date.now() + delaySeconds * 1000);
    await docRef.update({
      status: 'retrying' as QueueStatus,
      attempts: newAttempts,
      lastError: errorMessage,
      retryAfter: admin.firestore.Timestamp.fromDate(retryAfter),
    });
    console.log(`Queue item ${docRef.id} retrying — attempt ${newAttempts}/${maxAttempts}: ${errorMessage}`);
    Sentry.addBreadcrumb({ category: 'email', message: 'Retry scheduled', level: 'warning', data: { queueId: docRef.id, attempts: newAttempts, maxAttempts, error: errorMessage } });
  } else {
    await docRef.update({ status: 'failed' as QueueStatus, attempts: newAttempts, lastError: errorMessage });
    console.error(`Queue item ${docRef.id} FAILED permanently after ${newAttempts} attempts: ${errorMessage}`);
  }
}

export const emailWorker = onDocumentWritten(
  { document: 'emailQueue/{queueId}', secrets: ['RESEND_API_KEY', 'SENTRY_DSN'], region: 'us-central1', memory: '256MiB', timeoutSeconds: 60, minInstances: 0 },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'email');
    scope.setTag('function', 'emailWorker');

    const change = event.data;
    if (!change) return;
    if (!change.after.exists) return;

    const afterData = change.after.data();
    if (!afterData) return;

    const status = afterData['status'] as QueueStatus | undefined;
    if (status !== 'pending' && status !== 'retrying') return;

    const queueId = change.after.id;
    const docRef = change.after.ref;

  // P2-2: Check exponential backoff — don't process if retryAfter is in the future
  const retryAfter = afterData['retryAfter'];
  if (status === 'retrying' && retryAfter) {
    const retryAfterDate = retryAfter.toDate ? retryAfter.toDate() : new Date(retryAfter);
    if (retryAfterDate > new Date()) {
      console.log(`Queue item ${queueId} waiting for backoff (retry after ${retryAfterDate.toISOString()})`);
      return;
    }
  }

    const type = afterData['type'] as string | undefined;
    const to = afterData['to'] as string | string[] | undefined;
    const attempts = afterData['attempts'] as number | undefined;
    const maxAttempts = afterData['maxAttempts'] as number | undefined;

    scope.setContext('emailQueue', { queueId, type: type ?? 'unknown', recipientCount: Array.isArray(to) ? to.length : to ? 1 : 0, attempts: attempts ?? 0, maxAttempts: maxAttempts ?? 5 });

    let claimed = false;
    try {
      await db.runTransaction(async (transaction) => {
        const freshDoc = await transaction.get(docRef);
        if (!freshDoc.exists) return;
        const freshData = freshDoc.data();
        if (!freshData) return;
        const freshStatus = freshData['status'] as QueueStatus | undefined;
        if (freshStatus !== 'pending' && freshStatus !== 'retrying') return;
        transaction.update(docRef, { status: 'processing' as QueueStatus, processedAt: admin.firestore.FieldValue.serverTimestamp() });
        claimed = true;
      });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`Failed to claim queue document ${queueId}: ${msg}`);
      Sentry.captureException(err);
      return;
    }

    if (!claimed) return;

    const payload = afterData['payload'] as Record<string, unknown> | undefined;
    if (!type || !to || !payload) {
      await docRef.update({ status: 'failed' as QueueStatus, lastError: 'Missing required fields: type, to, or payload' });
      return;
    }

    try {
      const result = await processQueueItem(type, to, payload, queueId);
      if (result.success) {
        const updateData: Record<string, unknown> = { status: 'sent' as QueueStatus, sentAt: admin.firestore.FieldValue.serverTimestamp() };
        if (result.id) updateData['resendId'] = result.id;
        await docRef.update(updateData);
        console.log(`Queue item ${queueId} sent successfully (resendId: ${result.id ?? 'unknown'})`);
        Sentry.addBreadcrumb({ category: 'email', message: 'Email sent successfully', level: 'info', data: { queueId, resendId: result.id ?? 'unknown', type: type ?? 'unknown' } });
      } else {
        await handleFailure(docRef, attempts ?? 0, maxAttempts ?? 5, result.error ?? 'Unknown error');
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      Sentry.captureException(err);
      await handleFailure(docRef, attempts ?? 0, maxAttempts ?? 5, msg);
    }
    }); // withIsolatedScope
  });
