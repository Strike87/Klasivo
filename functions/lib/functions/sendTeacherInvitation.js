"use strict";
/**
 * Klasivo — sendTeacherInvitation Callable Function
 *
 * School owner invites a teacher to join their organisation.
 *
 * Flow:
 *   Flutter → Callable → emailQueue → emailWorker → emailService → Resend
 *
 * The function returns immediately with the queue ID.
 * The email will be sent asynchronously by the worker.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendTeacherInvitation').call({
 *     email: 'teacher@school.com',
 *     teacherName: 'Dr. Ahmed',
 *     schoolName: 'Al-Noor School',
 *     inviterName: 'Mohamed (Admin)',
 *     inviteCode: 'ABC-XYZ',
 *     orgId: 'org123',
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
exports.sendTeacherInvitationFn = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const queueService_1 = require("../services/queueService");
const validators_1 = require("../utils/validators");
const sanitizer_1 = require("../utils/sanitizer");
exports.sendTeacherInvitationFn = functions
    .https.onCall(async (data, context) => {
    // ── Auth check ──────────────────────────────────────────
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }
    // ── Input validation ────────────────────────────────────
    const required = ['email', 'teacherName', 'schoolName', 'inviterName', 'inviteCode', 'orgId'];
    const missing = (0, validators_1.missingField)(data ?? {}, required);
    if (missing) {
        throw new functions.https.HttpsError('invalid-argument', `Missing required field: ${missing}`);
    }
    const { email, teacherName, schoolName, inviterName, inviteCode, orgId } = data;
    if (!(0, validators_1.isValidEmail)(email)) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid email address.');
    }
    // ── Sanitise & queue ────────────────────────────────────
    const queueId = await (0, queueService_1.queueEmail)({
        type: 'teacher_invitation',
        to: (0, sanitizer_1.sanitizeEmail)(email),
        payload: {
            teacherName: (0, sanitizer_1.sanitizeText)(teacherName, 100),
            schoolName: (0, sanitizer_1.sanitizeText)(schoolName, 150),
            inviterName: (0, sanitizer_1.sanitizeText)(inviterName, 100),
            inviteCode: (0, sanitizer_1.sanitizeText)(inviteCode, 20),
            orgId: (0, sanitizer_1.sanitizeText)(orgId, 50),
        },
    });
    return { queued: true, queueId };
});
//# sourceMappingURL=sendTeacherInvitation.js.map