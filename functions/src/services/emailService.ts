import { Resend } from 'resend';
import * as admin from 'firebase-admin';

import type { SendEmailParams, EmailResult } from '../types/email';
import { SENDER } from '../types/email';
import { logEmail } from './emailLogService';

const resend = new Resend(process.env.RESEND_API_KEY);
const db = admin.firestore();

export async function sendEmail(params: SendEmailParams): Promise<EmailResult> {
  const { to, subject, html, category, queueId, from, replyTo } = params;
  const sender = from ?? SENDER.noreply;

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
