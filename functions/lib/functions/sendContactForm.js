"use strict";
/**
 * Klasivo — sendContactForm Callable Function
 *
 * Forwards a contact-form submission to the Klasivo support team.
 *
 * Flow (DIRECT — no queue, users expect instant confirmation):
 *   Visitor → Callable → emailService → Resend
 *
 * No authentication required — this is a public contact form.
 * Rate limiting is handled by Firebase Functions quotas.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendContactForm').call({
 *     name: 'Ahmed',
 *     email: 'ahmed@example.com',
 *     subject: 'Question about pricing',
 *     message: 'Hello, ...',
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
exports.sendContactForm = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const emailService_1 = require("../services/emailService");
const emailLayout_1 = require("../templates/emailLayout");
const validators_1 = require("../utils/validators");
const sanitizer_1 = require("../utils/sanitizer");
exports.sendContactForm = functions
    .runWith({ secrets: ['RESEND_API_KEY'] })
    .https.onCall(async (data) => {
    // ── Input validation ────────────────────────────────────
    const missing = (0, validators_1.missingField)(data ?? {}, ['name', 'email', 'subject', 'message']);
    if (missing) {
        throw new functions.https.HttpsError('invalid-argument', `Missing required field: ${missing}`);
    }
    const { name, email, subject, message } = data;
    if (!(0, validators_1.isValidEmail)(email)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid email address.');
    }
    if (message.length > 5000) {
        throw new functions.https.HttpsError('invalid-argument', 'Message must be under 5,000 characters.');
    }
    // ── Sanitise ────────────────────────────────────────────
    const sanitised = {
        name: (0, sanitizer_1.sanitizeText)(name, 100),
        email: (0, sanitizer_1.sanitizeEmail)(email),
        subject: (0, sanitizer_1.sanitizeText)(subject, 200),
        message: (0, sanitizer_1.sanitizeText)(message, 5000),
    };
    // ── Send directly (no queue) ────────────────────────────
    const result = await (0, emailService_1.sendContactFormNotification)(sanitised);
    if (!result.success) {
        throw new functions.https.HttpsError('internal', result.error ?? 'Unknown error');
    }
    // ── Log ─────────────────────────────────────────────────
    if (result.id) {
        await (0, emailService_1.logEmail)({
            resendId: result.id,
            type: 'contact_form',
            to: ['support@klasivo.app'],
            from: emailLayout_1.SENDER.support,
            subject: `New Contact Form: ${sanitised.subject}`,
            replyTo: sanitised.email,
            templateVersion: emailLayout_1.EMAIL_TEMPLATE_VERSION,
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    return { success: true, id: result.id ?? undefined };
});
//# sourceMappingURL=sendContactForm.js.map