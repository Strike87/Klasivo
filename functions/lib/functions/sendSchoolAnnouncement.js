"use strict";
/**
 * Klasivo — sendSchoolAnnouncement Callable Function
 *
 * Broadcast an announcement to one or more recipients.
 * Supports three priority levels: urgent, important, normal.
 *
 * Flow:
 *   Flutter → Callable → emailQueue → emailWorker → emailService → Resend
 *
 * The function returns immediately with the queue ID.
 * The email will be sent asynchronously by the worker.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendSchoolAnnouncement').call({
 *     to: ['parent1@email.com', 'parent2@email.com'],  // or single string
 *     schoolName: 'Al-Noor School',
 *     title: 'Midterm Exam Schedule',
 *     message: 'Dear parents, ...',
 *     senderName: 'Principal Mohamed',
 *     senderRole: 'Principal',
 *     priority: 'important',  // 'urgent' | 'important' | 'normal'
 *   });
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
exports.sendSchoolAnnouncementFn = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const queueService_1 = require("../services/queueService");
const validators_1 = require("../utils/validators");
const sanitizer_1 = require("../utils/sanitizer");
exports.sendSchoolAnnouncementFn = functions
    .https.onCall(async (data, context) => {
    // ── Auth check ──────────────────────────────────────────
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    // ── Input validation ────────────────────────────────────
    const required = ['to', 'schoolName', 'title', 'message', 'senderName', 'senderRole'];
    const missing = (0, validators_1.missingField)(data ?? {}, required);
    if (missing) {
        throw new functions.https.HttpsError('invalid-argument', `Missing required field: ${missing}`);
    }
    const { to, schoolName, title, message, senderName, senderRole, priority } = data;
    // Validate recipients
    const recipients = (Array.isArray(to) ? to : [to]);
    const recipientCheck = (0, validators_1.isValidRecipientList)(recipients);
    if (!recipientCheck.valid) {
        throw new functions.https.HttpsError('invalid-argument', recipientCheck.reason ?? 'Invalid recipients');
    }
    // Validate priority
    const safePriority = (0, validators_1.isValidPriority)(priority) ? priority : 'normal';
    // Validate message length
    if (message.length > 10000) {
        throw new functions.https.HttpsError('invalid-argument', 'Message must be under 10,000 characters.');
    }
    // ── Sanitise & queue ────────────────────────────────────
    const queueId = await (0, queueService_1.queueEmail)({
        type: 'school_announcement',
        to: recipients.map(sanitizer_1.sanitizeEmail),
        payload: {
            schoolName: (0, sanitizer_1.sanitizeText)(schoolName, 150),
            title: (0, sanitizer_1.sanitizeText)(title, 200),
            message: (0, sanitizer_1.sanitizeText)(message, 10000),
            senderName: (0, sanitizer_1.sanitizeText)(senderName, 100),
            senderRole: (0, sanitizer_1.sanitizeText)(senderRole, 50),
            priority: safePriority,
        },
    });
    return { queued: true, queueId };
});
//# sourceMappingURL=sendSchoolAnnouncement.js.map