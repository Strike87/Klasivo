import { onCall } from 'firebase-functions/v2/https';
import * as Sentry from '@sentry/node';

import { queueEmail } from '../services/queueService';
import { isValidEmail, missingField } from '../utils/validators';
import { sanitizeText, sanitizeEmail } from '../utils/sanitizer';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { verifyOrgBoundary, INVITATION_ROLES } from '../utils/rbac';

export const sendTeacherInvitation = onCall(
  { secrets: ['SENTRY_DSN'], enforceAppCheck: true,  // C-01 PATCH: App Check now enforced
    region: 'us-central1', memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'email');
    scope.setTag('function', 'sendTeacherInvitation');

    if (!request.auth) throw new Error('User must be authenticated.');

    // ── Role check: owner/admin only ────────────────────────────
    const callerRole = (request.auth.token.role as string) || '';
    if (!INVITATION_ROLES.includes(callerRole as any)) {
      throw new Error('Only owners and administrators can send teacher invitations.');
    }

    const data = request.data;
    const required = ['email', 'teacherName', 'schoolName', 'inviterName', 'inviteCode', 'orgId'];
    const missing = missingField(data ?? {}, required);
    if (missing) throw new Error(`Missing required field: ${missing}`);

    const fields = data as Record<string, string>;
    if (!isValidEmail(fields['email'] ?? '')) throw new Error('Invalid email address.');

    const cleanEmail = sanitizeEmail(fields['email'] ?? '');
    const cleanTeacherName = sanitizeText(fields['teacherName'] ?? '', 100);
    const cleanSchoolName = sanitizeText(fields['schoolName'] ?? '', 150);
    const cleanInviterName = sanitizeText(fields['inviterName'] ?? '', 100);
    const cleanInviteCode = sanitizeText(fields['inviteCode'] ?? '', 20);
    const cleanOrgId = sanitizeText(fields['orgId'] ?? '', 50);

    // ── Org boundary check ──────────────────────────────────────
    const callerOrgId = (request.auth.token.organizationId as string) || '';
    if (!verifyOrgBoundary(callerOrgId, cleanOrgId, callerRole)) {
      throw new Error('You can only send invitations for your own organization.');
    }

    try {
      const result = await queueEmail({
        type: 'teacher_invitation', category: 'teacher_invitation', to: cleanEmail,
        payload: { teacherName: cleanTeacherName, schoolName: cleanSchoolName, inviterName: cleanInviterName, inviteCode: cleanInviteCode, orgId: cleanOrgId },
        idempotencyKey: `invite_${cleanOrgId}_${cleanEmail}`,
      });
      if (!result.queued && result.reason === 'duplicate') return { success: true, id: result.queueId, message: 'Invitation already queued or sent' };
      return { success: true, id: result.queueId };
    } catch (err: unknown) {
      Sentry.captureException(err);
      throw new Error('Failed to queue teacher invitation');
    }
    }); // withIsolatedScope
  });
