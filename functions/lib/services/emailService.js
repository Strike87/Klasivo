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
exports.sendEmail = sendEmail;
const resend_1 = require("resend");
const admin = __importStar(require("firebase-admin"));
const email_1 = require("../types/email");
const emailLogService_1 = require("./emailLogService");
const resend = new resend_1.Resend(process.env.RESEND_API_KEY);
const db = admin.firestore();
async function sendEmail(params) {
    const { to, subject, html, category, queueId, from, replyTo } = params;
    const sender = from ?? email_1.SENDER.noreply;
    try {
        const { data, error } = await resend.emails.send({
            from: sender,
            to: to,
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
        await (0, emailLogService_1.logEmail)({
            resendId: resendId ?? 'unknown',
            type: category,
            to,
            from: sender,
            subject,
            replyTo,
            queueId,
        });
        return { success: true, id: resendId };
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`sendEmail failed for ${category}: ${msg}`);
        return { success: false, error: msg };
    }
}
//# sourceMappingURL=emailService.js.map