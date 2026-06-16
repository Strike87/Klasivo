/**
 * Klasivo Email Service — Resend Integration
 *
 * Centralised wrapper around the Resend SDK for sending transactional emails.
 * All email dispatch goes through this module so that:
 *   1. The API key is loaded from Firebase Secrets (never hard-coded).
 *   2. Errors are caught, logged, and returned in a consistent shape.
 *   3. Switching providers later requires changing only this file.
 */

const { Resend } = require('resend');

// ─── Singleton client ────────────────────────────────────────
// The RESEND_API_KEY secret is injected by Firebase Functions
// when the function declares `secrets: ['RESEND_API_KEY']`.
let _client = null;

/**
 * Lazily initialise the Resend client so we don't crash on cold-start
 * if the secret is absent (e.g. during local emulator without secrets).
 */
function getClient() {
  if (!_client) {
    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      throw new Error(
        'RESEND_API_KEY is not set. Run: firebase functions:secrets:set RESEND_API_KEY'
      );
    }
    _client = new Resend(apiKey);
  }
  return _client;
}

// ─── Sender configuration ────────────────────────────────────
const DEFAULT_FROM = 'Klasivo <noreply@klasivo.app>';

// ─── Public API ──────────────────────────────────────────────

/**
 * Send a single email.
 *
 * @param {Object} params
 * @param {string} params.to       — Recipient email (or array of emails)
 * @param {string} params.subject  — Email subject line
 * @param {string} params.html     — HTML body
 * @param {string} [params.from]   — Sender address (defaults to Klasivo)
 * @param {string} [params.replyTo]— Reply-To address
 * @param {Object} [params.headers]— Custom headers
 * @returns {Promise<{success: boolean, id?: string, error?: string}>}
 */
async function sendEmail({ to, subject, html, from, replyTo, headers }) {
  try {
    const client = getClient();

    const payload = {
      from: from || DEFAULT_FROM,
      to: Array.isArray(to) ? to : [to],
      subject,
      html,
    };

    if (replyTo) payload.replyTo = replyTo;
    if (headers) payload.headers = headers;

    const { data, error } = await client.emails.send(payload);

    if (error) {
      console.error('Resend API error:', error);
      return { success: false, error: error.message || String(error) };
    }

    console.log(`Email sent successfully — id: ${data.id}, to: ${to}`);
    return { success: true, id: data.id };
  } catch (err) {
    console.error('Email send failed:', err.message);
    return { success: false, error: err.message };
  }
}

/**
 * Send a welcome email to a newly registered user.
 *
 * @param {string} email — User's email address
 * @param {string} name  — User's display name
 * @param {string} [role] — 'teacher' | 'student' | 'parent' (customises CTA)
 * @returns {Promise<{success: boolean, id?: string, error?: string}>}
 */
async function sendWelcomeEmail(email, name, role = 'teacher') {
  const { buildWelcomeHtml } = require('./emailTemplates');
  const html = buildWelcomeHtml(name, role);
  const subject = 'Welcome to Klasivo — Your Smart School Platform';

  return sendEmail({ to: email, subject, html });
}

/**
 * Send a contact-form notification to the Klasivo team.
 *
 * @param {Object} params
 * @param {string} params.name    — Submitter's name
 * @param {string} params.email   — Submitter's email
 * @param {string} params.subject — Message subject
 * @param {string} params.message — Message body
 * @returns {Promise<{success: boolean, id?: string, error?: string}>}
 */
async function sendContactFormNotification({ name, email, subject, message }) {
  const { buildContactFormHtml } = require('./emailTemplates');
  const html = buildContactFormHtml({ name, email, subject, message });
  const emailSubject = `New Contact Form: ${subject}`;

  // Reply-To the submitter so the team can respond directly
  return sendEmail({
    to: 'support@klasivo.app',
    subject: emailSubject,
    html,
    replyTo: email,
  });
}

/**
 * Send a teacher invitation email.
 *
 * @param {Object} params
 * @param {string} params.email       — Teacher's email address
 * @param {string} params.teacherName — Teacher's display name
 * @param {string} params.schoolName  — Organisation / school name
 * @param {string} params.inviterName — Name of the person who sent the invite
 * @param {string} params.inviteCode  — Invite code (e.g. 'ABC-XYZ')
 * @param {string} params.orgId       — Organisation ID (for deep-link)
 * @returns {Promise<{success: boolean, id?: string, error?: string}>}
 */
async function sendTeacherInvitation({ email, teacherName, schoolName, inviterName, inviteCode, orgId }) {
  const { buildTeacherInvitationHtml } = require('./emailTemplates');
  const html = buildTeacherInvitationHtml({ teacherName, schoolName, inviterName, inviteCode, orgId });
  const subject = `You're Invited to Join ${schoolName} on Klasivo`;

  return sendEmail({ to: email, subject, html });
}

/**
 * Send a school announcement email to one or more recipients.
 *
 * @param {Object} params
 * @param {string|string[]} params.to         — Recipient email(s)
 * @param {string} params.schoolName          — Organisation / school name
 * @param {string} params.title               — Announcement title
 * @param {string} params.message             — Announcement body
 * @param {string} params.senderName          — Who sent the announcement
 * @param {string} params.senderRole          — Sender's role (e.g. 'Principal', 'Admin')
 * @param {string} [params.priority='normal'] — 'urgent' | 'important' | 'normal'
 * @returns {Promise<{success: boolean, id?: string, error?: string}>}
 */
async function sendSchoolAnnouncement({ to, schoolName, title, message, senderName, senderRole, priority = 'normal' }) {
  const { buildSchoolAnnouncementHtml } = require('./emailTemplates');
  const html = buildSchoolAnnouncementHtml({ schoolName, title, message, senderName, senderRole, priority });

  const prefix = priority === 'urgent' ? '🔴 ' : priority === 'important' ? '🟡 ' : '';
  const subject = `${prefix}${title} — ${schoolName}`;

  return sendEmail({ to, subject, html });
}

// ─── Exports ─────────────────────────────────────────────────
module.exports = {
  sendEmail,
  sendWelcomeEmail,
  sendContactFormNotification,
  sendTeacherInvitation,
  sendSchoolAnnouncement,
  DEFAULT_FROM,
};
