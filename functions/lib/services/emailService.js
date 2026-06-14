"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.DIRECT_TYPES = exports.QUEUED_TYPES = void 0;
exports.logEmail = logEmail;
exports.sendEmail = sendEmail;
exports.sendWelcomeEmail = sendWelcomeEmail;
exports.sendContactFormNotification = sendContactFormNotification;
exports.sendTeacherInvitation = sendTeacherInvitation;
exports.sendSchoolAnnouncement = sendSchoolAnnouncement;
const resend_1 = require("resend");
const admin = __importStar(require("firebase-admin"));
const emailLayout_1 = require("../templates/emailLayout");
const welcomeEmail_1 = require("../templates/welcomeEmail");
const contactForm_1 = require("../templates/contactForm");
const teacherInvitation_1 = require("../templates/teacherInvitation");
const schoolAnnouncement_1 = require("../templates/schoolAnnouncement");
/** Types that go through the queue. Used by queueService and emailWorker. */
exports.QUEUED_TYPES = [
    'teacher_invitation',
    'school_announcement',
];
/** Types that send directly (no queue). */
exports.DIRECT_TYPES = [
    'welcome',
    'contact_form',
];
// ─── Email logging ─────────────────────────────────────────────
const db = admin.firestore();
const EMAIL_LOGS_COLLECTION = 'emailLogs';
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
async function logEmail(entry) {
    try {
        await db.collection(EMAIL_LOGS_COLLECTION).add(entry);
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.warn(`Failed to log email ${entry.resendId}: ${msg}`);
    }
}
// ─── Singleton Resend client ──────────────────────────────────
let _client = null;
/**
 * Lazily initialise the Resend client so we don't crash on cold-start
 * if the secret is absent (e.g. during local emulator without secrets).
 */
function getClient() {
    if (!_client) {
        const apiKey = process.env.RESEND_API_KEY;
        if (!apiKey) {
            throw new Error('RESEND_API_KEY is not set. Run: firebase functions:secrets:set RESEND_API_KEY');
        }
        _client = new resend_1.Resend(apiKey);
    }
    return _client;
}
/**
 * Send a single email via Resend.
 *
 * This is the ONLY function that talks to the Resend API.
 * All other functions in this file call this one.
 *
 * Does NOT log to Firestore — the caller is responsible for logging.
 */
async function sendEmail({ to, subject, html, from, replyTo, headers, }) {
    try {
        const client = getClient();
        const payload = {
            from: from ?? emailLayout_1.SENDER.noreply,
            to: Array.isArray(to) ? to : [to],
            subject,
            html,
        };
        if (replyTo)
            payload.replyTo = replyTo;
        if (headers)
            payload.headers = headers;
        const { data, error } = await client.emails.send(payload);
        if (error) {
            console.error('Resend API error:', error);
            return { success: false, error: error.message || String(error) };
        }
        console.log(`Email sent successfully — id: ${data.id}, to: ${to}`);
        return { success: true, id: data.id ?? undefined };
    }
    catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error('Email send failed:', message);
        return { success: false, error: message };
    }
}
// ─── High-level email functions ───────────────────────────────
// These build HTML + call sendEmail(). No logging — caller handles it.
/**
 * Send a welcome email to a newly registered user. (Direct send)
 */
async function sendWelcomeEmail(email, name, role = 'teacher') {
    const html = (0, welcomeEmail_1.buildWelcomeEmail)(name, role);
    const subject = 'Welcome to Klasivo — Your Smart School Platform';
    return sendEmail({ to: email, subject, html });
}
/**
 * Send a contact-form notification to the Klasivo support team. (Direct send)
 *
 * Uses support@klasivo.app as sender and sets Reply-To to the
 * submitter so the team can respond directly.
 */
async function sendContactFormNotification(payload) {
    const html = (0, contactForm_1.buildContactNotification)(payload);
    const subject = `New Contact Form: ${payload.subject}`;
    return sendEmail({
        to: 'support@klasivo.app',
        from: emailLayout_1.SENDER.support,
        subject,
        html,
        replyTo: payload.email,
    });
}
/**
 * Send a teacher invitation email. (Queued — called by emailWorker)
 */
async function sendTeacherInvitation(payload) {
    const { email, ...templateData } = payload;
    const html = (0, teacherInvitation_1.buildTeacherInvitation)(templateData);
    const subject = `You're Invited to Join ${payload.schoolName} on Klasivo`;
    return sendEmail({ to: email, subject, html });
}
/**
 * Send a school announcement email to one or more recipients. (Queued — called by emailWorker)
 */
async function sendSchoolAnnouncement(payload) {
    const { to, ...templateData } = payload;
    const html = (0, schoolAnnouncement_1.buildAnnouncement)(templateData);
    const prefix = templateData.priority === 'urgent'
        ? '\uD83D\uDD34 '
        : templateData.priority === 'important'
            ? '\uD83D\uDFE1 '
            : '';
    const subject = `${prefix}${templateData.title} — ${templateData.schoolName}`;
    return sendEmail({ to, subject, html });
}
//# sourceMappingURL=emailService.js.map