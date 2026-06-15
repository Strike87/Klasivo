import { Resend } from 'resend';
import * as admin from 'firebase-admin';

import type { SendEmailParams, EmailResult } from '../types/email';
import { SENDER } from '../types/email';
import { logEmail } from './emailLogService';

const db = admin.firestore();

// ─── Lazy-initialized Resend client ────────────────────────────
// Firebase secrets (RESEND_API_KEY) are only available at runtime
// inside function invocations, NOT during the deploy analysis phase.
// Creating `new Resend()` at module top-level would crash deployment
// because the key is empty during source analysis.

let _resend: Resend | null = null;

function getResendClient(): Resend {
  if (_resend === null) {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      throw new Error('RESEND_API_KEY secret is not configured. Set it with: firebase functions:secrets:set RESEND_API_KEY');
    }
    _resend = new Resend(apiKey);
  }
  return _resend;
}

export async function sendEmail(params: SendEmailParams): Promise<EmailResult> {
  const { to, subject, html, category, queueId, from, replyTo } = params;
  const sender = from ?? SENDER.noreply;
  const resend = getResendClient();

  try {
    const { data, error } = await resend.emails.send({
      from: sender,
      to: to as string | string[],
      subject,
      html,
      replyTo: replyTo ?? undefined,
    });

    if (error) {
      console.error(`Resend API error for ${category}: ${error.message}`);
      return { success: false, error: error.message };
    }

    const resendId = data?.id;
    console.log(`Email sent: ${category} → ${String(to)} (resendId: ${resendId ?? 'unknown'})`);

    // Write audit log
    await logEmail({
      resendId: resendId ?? 'unknown',
      type: category,
      to,
      from: sender,
      subject,
      replyTo,
      queueId,
    });

    return { success: true, id: resendId };
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`sendEmail failed for ${category}: ${msg}`);
    return { success: false, error: msg };
  }
}
