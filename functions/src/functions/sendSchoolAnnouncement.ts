import { onCall } from 'firebase-functions/v2/https';
import * as Sentry from '@sentry/node';

import { queueEmail } from '../services/queueService';
import { isValidEmail, isValidPriority, isValidRecipientList, missingField } from '../utils/validators';
import { sanitizeText, sanitizeEmail } from '../utils/sanitizer';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { verifyOrgBoundary, ANNOUNCEMENT_ROLES } from '../utils/rbac';

export const sendSchoolAnnouncement = onCall(
  { secrets: ['SENTRY_DSN'], /* enforceAppCheck: true — DISABLED: no client AppCheck init */ region: 'us-central1', memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'email');
    scope.setTag('function', 'sendSchoolAnnouncement');

    if (!request.auth) throw new Error('User must be authenticated.');

    // ── Role check: administrative roles only (no teacher/assistant_teacher) ───
    const callerRole = (request.auth.token.role as string) || '';
    if (!ANNOUNCEMENT_ROLES.includes(callerRole as any)) {
      throw new Error('Only administrators can send school-wide announcements.');
    }

    const data = request.data;
    const required = ['to', 'schoolId', 'schoolName', 'title', 'message', 'senderName', 'senderRole'];
    const missing = missingField(data ?? {}, required);
    if (missing) throw new Error(`Missing required field: ${missing}`);

    const fields = data as Record<string, unknown>;
    const { to, schoolId, schoolName, title, message, senderName, senderRole, priority } = fields;

    const recipients = Array.isArray(to) ? to : typeof to === 'string' ? [to] : [];
    if (!isValidRecipientList(recipients as string[])) throw new Error('Recipients must be between 1 and 50 valid email addresses.');
    for (const email of recipients) {
      if (typeof email !== 'string' || !isValidEmail(email)) throw new Error(`Invalid email address: ${String(email)}`);
    }

    const safePriority = typeof priority === 'string' && isValidPriority(priority) ? priority : 'normal';
    if (typeof message === 'string' && message.length > 10000) throw new Error('Message must be under 10,000 characters.');

    const cleanRecipients = (recipients as string[]).map((e) => sanitizeEmail(e));
    const cleanSchoolId = sanitizeText(String(schoolId ?? ''), 50);
    const cleanSchoolName = sanitizeText(String(schoolName ?? ''), 150);
    const cleanTitle = sanitizeText(String(title ?? ''), 200);
    const cleanMessage = sanitizeText(String(message ?? ''), 10000);
    const cleanSenderName = sanitizeText(String(senderName ?? ''), 100);
    const cleanSenderRole = sanitizeText(String(senderRole ?? ''), 50);

    // ── Org boundary check ──────────────────────────────────────
    const callerOrgId = (request.auth.token.organizationId as string) || '';
    if (!verifyOrgBoundary(callerOrgId, cleanSchoolId, callerRole)) {
      throw new Error('You can only send announcements for your own organization.');
    }

    const rawAnnouncementId = fields['announcementId'];
    const cleanAnnouncementId = typeof rawAnnouncementId === 'string' && rawAnnouncementId !== ''
      ? sanitizeText(rawAnnouncementId, 50)
      : `${cleanSchoolId}_${cleanTitle.slice(0, 30)}`;

    try {
      const result = await queueEmail({
        type: 'school_announcement', category: 'school_announcement', to: cleanRecipients,
        payload: { schoolId: cleanSchoolId, schoolName: cleanSchoolName, title: cleanTitle, message: cleanMessage, senderName: cleanSenderName, senderRole: cleanSenderRole, priority: safePriority },
        idempotencyKey: `announce_${cleanSchoolId}_${cleanAnnouncementId}`,
      });
      return { success: true, id: result.queueId };
    } catch (err: unknown) {
      Sentry.captureException(err);
      throw new Error('Failed to queue school announcement');
    }
    }); // withIsolatedScope
  });
