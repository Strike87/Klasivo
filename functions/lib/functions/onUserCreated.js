"use strict";
/**
 * Klasivo — onUserCreated Auth Trigger
 *
 * Automatically sends a welcome email when a new Firebase Auth
 * user is created. (Direct send — no queue)
 *
 * Flow:
 *   New account → emailService → Resend
 *
 * This is fire-and-forget — if Resend is not configured the
 * function logs a warning but does NOT throw (user creation
 * must never fail because of an email issue).
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
exports.onUserCreated = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const emailService_1 = require("../services/emailService");
const emailLayout_1 = require("../templates/emailLayout");
const db = admin.firestore();
exports.onUserCreated = functions
    .runWith({ secrets: ['RESEND_API_KEY'] })
    .auth.user()
    .onCreate(async (user) => {
    const uid = user.uid;
    const email = user.email ?? '';
    const displayName = user.displayName || email.split('@')[0] || 'User';
    console.log(`New user created: ${uid} (${email})`);
    try {
        // Look up the user's role from Firestore (may not exist yet if the
        // Flutter app hasn't written the profile). Default to 'teacher'.
        const userDoc = await db.collection('users').doc(uid).get();
        const rawRole = userDoc.exists ? String(userDoc.data()?.role ?? 'teacher') : 'teacher';
        const role = rawRole === 'student' || rawRole === 'parent' ? rawRole : 'teacher';
        if (!email) {
            console.warn('No email for new user, skipping welcome email');
            return;
        }
        const result = await (0, emailService_1.sendWelcomeEmail)(email, displayName, role);
        if (result.success && result.id) {
            console.log(`Welcome email sent to ${email} (role: ${role})`);
            // Log to emailLogs
            await (0, emailService_1.logEmail)({
                resendId: result.id,
                type: 'welcome',
                to: [email],
                from: emailLayout_1.SENDER.noreply,
                subject: 'Welcome to Klasivo — Your Smart School Platform',
                templateVersion: emailLayout_1.EMAIL_TEMPLATE_VERSION,
                status: 'sent',
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            console.warn(`Welcome email failed for ${email}: ${result.error}`);
            // Log failure
            await (0, emailService_1.logEmail)({
                resendId: 'none',
                type: 'welcome',
                to: [email],
                from: emailLayout_1.SENDER.noreply,
                subject: 'Welcome to Klasivo — Your Smart School Platform',
                templateVersion: emailLayout_1.EMAIL_TEMPLATE_VERSION,
                status: 'failed',
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    }
    catch (err) {
        // Non-critical — do NOT re-throw; user creation must succeed
        const message = err instanceof Error ? err.message : String(err);
        console.warn(`Welcome email error for ${email}: ${message}`);
    }
});
//# sourceMappingURL=onUserCreated.js.map