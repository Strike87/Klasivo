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
exports.sendTeacherInvitation = void 0;
const https_1 = require("firebase-functions/v2/https");
const Sentry = __importStar(require("@sentry/node"));
const queueService_1 = require("../services/queueService");
const validators_1 = require("../utils/validators");
const sanitizer_1 = require("../utils/sanitizer");
const sentry_1 = require("../config/sentry");
const rbac_1 = require("../utils/rbac");
exports.sendTeacherInvitation = (0, https_1.onCall)({ secrets: ['SENTRY_DSN'], enforceAppCheck: true, region: 'us-central1', memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 }, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'email');
        scope.setTag('function', 'sendTeacherInvitation');
        if (!request.auth)
            throw new Error('User must be authenticated.');
        // ── Role check: owner/admin only ────────────────────────────
        const callerRole = request.auth.token.role || '';
        if (!rbac_1.INVITATION_ROLES.includes(callerRole)) {
            throw new Error('Only owners and administrators can send teacher invitations.');
        }
        const data = request.data;
        const required = ['email', 'teacherName', 'schoolName', 'inviterName', 'inviteCode', 'orgId'];
        const missing = (0, validators_1.missingField)(data ?? {}, required);
        if (missing)
            throw new Error(`Missing required field: ${missing}`);
        const fields = data;
        if (!(0, validators_1.isValidEmail)(fields['email'] ?? ''))
            throw new Error('Invalid email address.');
        const cleanEmail = (0, sanitizer_1.sanitizeEmail)(fields['email'] ?? '');
        const cleanTeacherName = (0, sanitizer_1.sanitizeText)(fields['teacherName'] ?? '', 100);
        const cleanSchoolName = (0, sanitizer_1.sanitizeText)(fields['schoolName'] ?? '', 150);
        const cleanInviterName = (0, sanitizer_1.sanitizeText)(fields['inviterName'] ?? '', 100);
        const cleanInviteCode = (0, sanitizer_1.sanitizeText)(fields['inviteCode'] ?? '', 20);
        const cleanOrgId = (0, sanitizer_1.sanitizeText)(fields['orgId'] ?? '', 50);
        // ── Org boundary check ──────────────────────────────────────
        const callerOrgId = request.auth.token.organizationId || '';
        if (!(0, rbac_1.verifyOrgBoundary)(callerOrgId, cleanOrgId, callerRole)) {
            throw new Error('You can only send invitations for your own organization.');
        }
        try {
            const result = await (0, queueService_1.queueEmail)({
                type: 'teacher_invitation', category: 'teacher_invitation', to: cleanEmail,
                payload: { teacherName: cleanTeacherName, schoolName: cleanSchoolName, inviterName: cleanInviterName, inviteCode: cleanInviteCode, orgId: cleanOrgId },
                idempotencyKey: `invite_${cleanOrgId}_${cleanEmail}`,
            });
            if (!result.queued && result.reason === 'duplicate')
                return { success: true, id: result.queueId, message: 'Invitation already queued or sent' };
            return { success: true, id: result.queueId };
        }
        catch (err) {
            Sentry.captureException(err);
            throw new Error('Failed to queue teacher invitation');
        }
    }); // withIsolatedScope
});
//# sourceMappingURL=sendTeacherInvitation.js.map