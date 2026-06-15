import { onCall } from 'firebase-functions/v2/https';
import * as Sentry from '@sentry/node';

import { sendEmail } from '../services/emailService';
import { buildContactFormHtml } from '../templates/contactForm';
import { SENDER } from '../types/email';
import { isValidEmail, missingField } from '../utils/validators';
import { sanitizeText, sanitizeEmail } from '../utils/sanitizer';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const sendContactForm = onCall(
  { secrets: ['RESEND_API_KEY', 'SENTRY_DSN'], /* enforceAppCheck: true — DISABLED: no client AppCheck init */ region: 'us-central1', memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'email');
    scope.setTag('function', 'sendContactForm');

    const data = request.data;
    const missing = missingField(data ?? {}, ['name', 'email', 'subject', 'message']);
    if (missing) throw new Error(`Missing required field: ${missing}`);

    const record = data as Record<string, string>;
    const name = record['name'] ?? '';
    const email = record['email'] ?? '';
    const subject = record['subject'] ?? '';
    const message = record['message'] ?? '';

    if (!isValidEmail(email)) throw new Error('Invalid email address.');
    if (message.length > 5000) throw new Error('Message must be under 5,000 characters.');

    const cleanName = sanitizeText(name, 100);
    const cleanEmail = sanitizeEmail(email);
    const cleanSubject = sanitizeText(subject, 200);
    const cleanMessage = sanitizeText(message, 5000);

    const html = buildContactFormHtml({ name: cleanName, email: cleanEmail, subject: cleanSubject, message: cleanMessage });
    const result = await sendEmail({ to: 'support@klasivo.app', subject: `New Contact Form: ${cleanSubject}`, html, from: SENDER.noreply, replyTo: cleanEmail, category: 'contact' });

    if (!result.success) {
      const error = new Error(result.error ?? 'Unknown error');
      Sentry.captureException(error, { tags: { step: 'send_contact_email' } });
      throw error;
    }
    return { success: true, id: result.id };
    }); // withIsolatedScope
  });
