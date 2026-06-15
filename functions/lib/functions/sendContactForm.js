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
exports.sendContactForm = void 0;
const https_1 = require("firebase-functions/v2/https");
const Sentry = __importStar(require("@sentry/node"));
const emailService_1 = require("../services/emailService");
const contactForm_1 = require("../templates/contactForm");
const email_1 = require("../types/email");
const validators_1 = require("../utils/validators");
const sanitizer_1 = require("../utils/sanitizer");
const sentry_1 = require("../config/sentry");
exports.sendContactForm = (0, https_1.onCall)({ secrets: ['RESEND_API_KEY', 'SENTRY_DSN'], enforceAppCheck: true, region: 'us-central1', memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 }, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'email');
        scope.setTag('function', 'sendContactForm');
        const data = request.data;
        const missing = (0, validators_1.missingField)(data ?? {}, ['name', 'email', 'subject', 'message']);
        if (missing)
            throw new Error(`Missing required field: ${missing}`);
        const record = data;
        const name = record['name'] ?? '';
        const email = record['email'] ?? '';
        const subject = record['subject'] ?? '';
        const message = record['message'] ?? '';
        if (!(0, validators_1.isValidEmail)(email))
            throw new Error('Invalid email address.');
        if (message.length > 5000)
            throw new Error('Message must be under 5,000 characters.');
        const cleanName = (0, sanitizer_1.sanitizeText)(name, 100);
        const cleanEmail = (0, sanitizer_1.sanitizeEmail)(email);
        const cleanSubject = (0, sanitizer_1.sanitizeText)(subject, 200);
        const cleanMessage = (0, sanitizer_1.sanitizeText)(message, 5000);
        const html = (0, contactForm_1.buildContactFormHtml)({ name: cleanName, email: cleanEmail, subject: cleanSubject, message: cleanMessage });
        const result = await (0, emailService_1.sendEmail)({ to: 'support@klasivo.app', subject: `New Contact Form: ${cleanSubject}`, html, from: email_1.SENDER.noreply, replyTo: cleanEmail, category: 'contact' });
        if (!result.success) {
            const error = new Error(result.error ?? 'Unknown error');
            Sentry.captureException(error, { tags: { step: 'send_contact_email' } });
            throw error;
        }
        return { success: true, id: result.id };
    }); // withIsolatedScope
});
//# sourceMappingURL=sendContactForm.js.map