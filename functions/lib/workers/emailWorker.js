"use strict";
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
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const email_1 = require("../types/email");
const sentry_1 = require("../config/sentry");
const emailService_1 = require("../services/emailService");
const welcomeEmail_1 = require("../templates/welcomeEmail");
const teacherInvitation_1 = require("../templates/teacherInvitation");
const schoolAnnouncement_1 = require("../templates/schoolAnnouncement");
const db = admin.firestore();
async function processQueueItem(type, to, payload, queueId) {
    switch (type) {
        case 'welcome': {
            const name = payload['name'];
            const role = payload['role'];
            if (typeof name !== 'string' || name === '')
                return { success: false, error: 'Missing name in welcome payload' };
            const html = (0, welcomeEmail_1.buildWelcomeHtml)(name, typeof role === 'string' ? role : 'teacher');
            return (0, emailService_1.sendEmail)({ to: to, subject: 'Welcome to Klasivo — Your Smart School Platform', html, category: 'welcome', queueId });
        }
        case 'teacher_invitation': {
            const teacherName = payload['teacherName'];
            const schoolName = payload['schoolName'];
            const inviterName = payload['inviterName'];
            const inviteCode = payload['inviteCode'];
            const orgId = payload['orgId'];
            if (typeof teacherName !== 'string' || teacherName === '' || typeof schoolName !== 'string' || schoolName === '' || typeof inviterName !== 'string' || inviterName === '' || typeof inviteCode !== 'string' || inviteCode === '' || typeof orgId !== 'string' || orgId === '')
                return { success: false, error: 'Missing required fields in teacher_invitation payload' };
            const html = (0, teacherInvitation_1.buildTeacherInvitationHtml)({ teacherName, schoolName, inviterName, inviteCode, orgId });
            return (0, emailService_1.sendEmail)({ to: to, subject: `You're Invited to Join ${schoolName} on Klasivo`, html, category: 'teacher_invitation', queueId });
        }
        case 'school_announcement': {
            const schoolName = payload['schoolName'];
            const title = payload['title'];
            const message = payload['message'];
            const senderName = payload['senderName'];
            const senderRole = payload['senderRole'];
            const priority = payload['priority'];
            if (typeof schoolName !== 'string' || schoolName === '' || typeof title !== 'string' || title === '' || typeof message !== 'string' || message === '' || typeof senderName !== 'string' || senderName === '' || typeof senderRole !== 'string' || senderRole === '')
                return { success: false, error: 'Missing required fields in school_announcement payload' };
            const html = (0, schoolAnnouncement_1.buildSchoolAnnouncementHtml)({ schoolName, title, message, senderName, senderRole, priority: typeof priority === 'string' ? priority : 'normal' });
            const prefix = priority === 'urgent' ? '\uD83D\uDD34 ' : priority === 'important' ? '\uD83D\uDFE1 ' : '';
            return (0, emailService_1.sendEmail)({ to, subject: `${prefix}${title} — ${schoolName}`, html, from: email_1.SENDER.noreply, category: 'school_announcement', queueId });
        }
        default: return { success: false, error: `Unknown queue type: ${type}` };
    }
}
async function handleFailure(docRef, currentAttempts, maxAttempts, errorMessage) {
    const newAttempts = currentAttempts + 1;
    if (newAttempts < maxAttempts) {
        await docRef.update({ status: 'retrying', attempts: newAttempts, lastError: errorMessage });
        console.log(`Queue item ${docRef.id} retrying — attempt ${newAttempts}/${maxAttempts}: ${errorMessage}`);
        Sentry.addBreadcrumb({ category: 'email', message: 'Retry scheduled', level: 'warning', data: { queueId: docRef.id, attempts: newAttempts, maxAttempts, error: errorMessage } });
    }
    else {
        await docRef.update({ status: 'failed', attempts: newAttempts, lastError: errorMessage });
        console.error(`Queue item ${docRef.id} FAILED permanently after ${newAttempts} attempts: ${errorMessage}`);
    }
}
exports.emailWorker = (0, firestore_1.onDocumentWritten)({ document: 'emailQueue/{queueId}', secrets: ['RESEND_API_KEY', 'SENTRY_DSN'] }, async (event) => {
    (0, sentry_1.initSentry)();
    Sentry.setTag('service', 'email');
    Sentry.setTag('function', 'emailWorker');
    const change = event.data;
    if (!change)
        return;
    if (!change.after.exists)
        return;
    const afterData = change.after.data();
    if (!afterData)
        return;
    const status = afterData['status'];
    if (status !== 'pending' && status !== 'retrying')
        return;
    const queueId = change.after.id;
    const docRef = change.after.ref;
    const type = afterData['type'];
    const to = afterData['to'];
    const attempts = afterData['attempts'];
    const maxAttempts = afterData['maxAttempts'];
    Sentry.setContext('emailQueue', { queueId, type: type ?? 'unknown', recipientCount: Array.isArray(to) ? to.length : to ? 1 : 0, attempts: attempts ?? 0, maxAttempts: maxAttempts ?? 5 });
    let claimed = false;
    try {
        await db.runTransaction(async (transaction) => {
            const freshDoc = await transaction.get(docRef);
            if (!freshDoc.exists)
                return;
            const freshData = freshDoc.data();
            if (!freshData)
                return;
            const freshStatus = freshData['status'];
            if (freshStatus !== 'pending' && freshStatus !== 'retrying')
                return;
            transaction.update(docRef, { status: 'processing', processedAt: admin.firestore.FieldValue.serverTimestamp() });
            claimed = true;
        });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Failed to claim queue document ${queueId}: ${msg}`);
        Sentry.captureException(err);
        return;
    }
    if (!claimed)
        return;
    const payload = afterData['payload'];
    if (!type || !to || !payload) {
        await docRef.update({ status: 'failed', lastError: 'Missing required fields: type, to, or payload' });
        return;
    }
    try {
        const result = await processQueueItem(type, to, payload, queueId);
        if (result.success) {
            const updateData = { status: 'sent', sentAt: admin.firestore.FieldValue.serverTimestamp() };
            if (result.id)
                updateData['resendId'] = result.id;
            await docRef.update(updateData);
            console.log(`Queue item ${queueId} sent successfully (resendId: ${result.id ?? 'unknown'})`);
            Sentry.addBreadcrumb({ category: 'email', message: 'Email sent successfully', level: 'info', data: { queueId, resendId: result.id ?? 'unknown', type: type ?? 'unknown' } });
        }
        else {
            await handleFailure(docRef, attempts ?? 0, maxAttempts ?? 5, result.error ?? 'Unknown error');
        }
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        Sentry.captureException(err);
        await handleFailure(docRef, attempts ?? 0, maxAttempts ?? 5, msg);
    }
});
//# sourceMappingURL=emailWorker.js.map