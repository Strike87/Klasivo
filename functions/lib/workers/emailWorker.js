"use strict";
/**
 * Klasivo — Email Worker
 *
 * Firestore trigger that processes emails from the emailQueue collection.
 *
 * Flow:
 *   emailQueue doc created (status: pending)
 *     ↓
 *   Worker picks it up → status: processing
 *     ↓
 *   Dispatches to the right emailService function
 *     ↓
 *   Success → status: sent, log to emailLogs
 *   Failure → retry (up to 5 attempts), then status: failed
 *
 * Retry strategy:
 *   - Simple in-function retry with backoff (1s, 2s, 3s, 4s)
 *   - Max 5 attempts per queue entry
 *   - After 5 failures, mark as 'failed' and stop
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
exports.emailWorker = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const emailService_1 = require("../services/emailService");
const emailLayout_1 = require("../templates/emailLayout");
const db = admin.firestore();
const MAX_ATTEMPTS = 5;
// ─── Worker ───────────────────────────────────────────────────
exports.emailWorker = functions
    .runWith({ secrets: ['RESEND_API_KEY'], timeoutSeconds: 120 })
    .firestore.document('emailQueue/{id}')
    .onCreate(async (snap, context) => {
    const queueId = context.params.id;
    const data = snap.data();
    // Only process pending emails
    if (data.status !== 'pending')
        return null;
    // Mark as processing
    await snap.ref.update({ status: 'processing' });
    let lastResult = { success: false, error: 'No attempts made' };
    // ── Retry loop ──────────────────────────────────────────
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        await snap.ref.update({ attempts: attempt });
        console.log(`Processing queue ${queueId} — attempt ${attempt}/${MAX_ATTEMPTS} (type: ${data.type})`);
        lastResult = await dispatchEmail(data.type, data.to, data.payload);
        if (lastResult.success)
            break;
        // Simple backoff before next retry (1s, 2s, 3s, 4s)
        if (attempt < MAX_ATTEMPTS) {
            const delayMs = attempt * 1000;
            console.warn(`Attempt ${attempt} failed for queue ${queueId}: ${lastResult.error}. Retrying in ${delayMs}ms...`);
            await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
    }
    // ── Handle result ───────────────────────────────────────
    if (lastResult.success) {
        await snap.ref.update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log to emailLogs
        if (lastResult.id) {
            await (0, emailService_1.logEmail)({
                queueId,
                resendId: lastResult.id,
                type: data.type,
                to: data.to,
                from: getSenderForType(data.type),
                subject: getSubjectForType(data.type, data.payload),
                templateVersion: emailLayout_1.EMAIL_TEMPLATE_VERSION,
                status: 'sent',
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        console.log(`Queue ${queueId} processed successfully — resendId: ${lastResult.id}`);
    }
    else {
        await snap.ref.update({
            status: 'failed',
            error: lastResult.error ?? 'Unknown error',
        });
        // Log failure
        await (0, emailService_1.logEmail)({
            queueId,
            resendId: 'none',
            type: data.type,
            to: data.to,
            from: getSenderForType(data.type),
            subject: getSubjectForType(data.type, data.payload),
            templateVersion: emailLayout_1.EMAIL_TEMPLATE_VERSION,
            status: 'failed',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.error(`Queue ${queueId} failed after ${MAX_ATTEMPTS} attempts: ${lastResult.error}`);
    }
    return null;
});
// ─── Dispatcher ───────────────────────────────────────────────
/**
 * Route a queue entry to the correct emailService function.
 */
async function dispatchEmail(type, to, payload) {
    switch (type) {
        case 'teacher_invitation':
            return (0, emailService_1.sendTeacherInvitation)({
                email: to[0] ?? '',
                teacherName: String(payload.teacherName ?? ''),
                schoolName: String(payload.schoolName ?? ''),
                inviterName: String(payload.inviterName ?? ''),
                inviteCode: String(payload.inviteCode ?? ''),
                orgId: String(payload.orgId ?? ''),
            });
        case 'school_announcement':
            return (0, emailService_1.sendSchoolAnnouncement)({
                to,
                schoolName: String(payload.schoolName ?? ''),
                title: String(payload.title ?? ''),
                message: String(payload.message ?? ''),
                senderName: String(payload.senderName ?? ''),
                senderRole: String(payload.senderRole ?? ''),
                priority: payload.priority ?? 'normal',
            });
        default:
            return { success: false, error: `Unknown email type: ${type}` };
    }
}
// ─── Helpers ──────────────────────────────────────────────────
function getSenderForType(type) {
    // All queued emails use noreply — support@ is reserved for human conversations
    return emailLayout_1.SENDER.noreply;
}
function getSubjectForType(type, payload) {
    switch (type) {
        case 'teacher_invitation':
            return `You're Invited to Join ${payload.schoolName ?? 'a school'} on Klasivo`;
        case 'school_announcement': {
            const prefix = payload.priority === 'urgent'
                ? '\uD83D\uDD34 '
                : payload.priority === 'important'
                    ? '\uD83D\uDFE1 '
                    : '';
            return `${prefix}${payload.title ?? 'Announcement'} — ${payload.schoolName ?? 'School'}`;
        }
        default:
            return 'Klasivo Notification';
    }
}
//# sourceMappingURL=emailWorker.js.map