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
exports.sendSchoolAnnouncement = void 0;
const https_1 = require("firebase-functions/v2/https");
const Sentry = __importStar(require("@sentry/node"));
const queueService_1 = require("../services/queueService");
const validators_1 = require("../utils/validators");
const sanitizer_1 = require("../utils/sanitizer");
const sentry_1 = require("../config/sentry");
exports.sendSchoolAnnouncement = (0, https_1.onCall)({ secrets: ['SENTRY_DSN'], enforceAppCheck: true }, async (request) => {
    (0, sentry_1.initSentry)();
    Sentry.setTag('service', 'email');
    Sentry.setTag('function', 'sendSchoolAnnouncement');
    if (!request.auth)
        throw new Error('User must be authenticated.');
    const data = request.data;
    const required = ['to', 'schoolId', 'schoolName', 'title', 'message', 'senderName', 'senderRole'];
    const missing = (0, validators_1.missingField)(data ?? {}, required);
    if (missing)
        throw new Error(`Missing required field: ${missing}`);
    const fields = data;
    const { to, schoolId, schoolName, title, message, senderName, senderRole, priority } = fields;
    const recipients = Array.isArray(to) ? to : typeof to === 'string' ? [to] : [];
    if (!(0, validators_1.isValidRecipientList)(recipients))
        throw new Error('Recipients must be between 1 and 50 valid email addresses.');
    for (const email of recipients) {
        if (typeof email !== 'string' || !(0, validators_1.isValidEmail)(email))
            throw new Error(`Invalid email address: ${String(email)}`);
    }
    const safePriority = typeof priority === 'string' && (0, validators_1.isValidPriority)(priority) ? priority : 'normal';
    if (typeof message === 'string' && message.length > 10000)
        throw new Error('Message must be under 10,000 characters.');
    const cleanRecipients = recipients.map((e) => (0, sanitizer_1.sanitizeEmail)(e));
    const cleanSchoolId = (0, sanitizer_1.sanitizeText)(String(schoolId ?? ''), 50);
    const cleanSchoolName = (0, sanitizer_1.sanitizeText)(String(schoolName ?? ''), 150);
    const cleanTitle = (0, sanitizer_1.sanitizeText)(String(title ?? ''), 200);
    const cleanMessage = (0, sanitizer_1.sanitizeText)(String(message ?? ''), 10000);
    const cleanSenderName = (0, sanitizer_1.sanitizeText)(String(senderName ?? ''), 100);
    const cleanSenderRole = (0, sanitizer_1.sanitizeText)(String(senderRole ?? ''), 50);
    const rawAnnouncementId = fields['announcementId'];
    const cleanAnnouncementId = typeof rawAnnouncementId === 'string' && rawAnnouncementId !== ''
        ? (0, sanitizer_1.sanitizeText)(rawAnnouncementId, 50)
        : `${cleanSchoolId}_${cleanTitle.slice(0, 30)}`;
    try {
        const result = await (0, queueService_1.queueEmail)({
            type: 'school_announcement', category: 'school_announcement', to: cleanRecipients,
            payload: { schoolId: cleanSchoolId, schoolName: cleanSchoolName, title: cleanTitle, message: cleanMessage, senderName: cleanSenderName, senderRole: cleanSenderRole, priority: safePriority },
            idempotencyKey: `announce_${cleanSchoolId}_${cleanAnnouncementId}`,
        });
        return { success: true, id: result.queueId };
    }
    catch (err) {
        Sentry.captureException(err);
        throw new Error('Failed to queue school announcement');
    }
});
//# sourceMappingURL=sendSchoolAnnouncement.js.map