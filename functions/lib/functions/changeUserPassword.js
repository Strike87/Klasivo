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
exports.changeUserPassword = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
const Sentry = __importStar(require("@sentry/node"));
const rbac_1 = require("../utils/rbac");
const sentry_1 = require("../config/sentry");
function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}
exports.changeUserPassword = (0, https_1.onCall)({
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10, // Infrequent operation
    concurrency: 80,
}, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'rbac');
        scope.setTag('function', 'changeUserPassword');
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'Must be authenticated.');
        }
        const callerUid = request.auth.uid;
        scope.setUser({ id: callerUid });
        const { newPassword, targetUserId } = request.data;
        if (!newPassword || newPassword.length < 6) {
            throw new https_1.HttpsError('invalid-argument', 'New password must be at least 6 characters.');
        }
        const effectiveTargetId = targetUserId || callerUid;
        const isAdminReset = effectiveTargetId !== callerUid;
        // ── Load target user document ──────────────────────────────
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(effectiveTargetId).get();
        if (!userDoc.exists) {
            throw new https_1.HttpsError('not-found', `User ${effectiveTargetId} not found.`);
        }
        const userData = userDoc.data();
        const authProvider = userData.authProvider || 'password';
        // If admin resetting someone else's password, check permissions and org boundary
        if (isAdminReset) {
            const callerRole = request.auth.token.role || '';
            if (!rbac_1.PASSWORD_RESET_ROLES.includes(callerRole)) {
                throw new https_1.HttpsError('permission-denied', 'Insufficient permissions to reset passwords.');
            }
            // Org boundary: fail-closed — deny if either org ID is missing
            const targetOrgId = userData.organizationId || '';
            const callerOrgId = request.auth.token.organizationId || '';
            if (!targetOrgId || !callerOrgId) {
                throw new https_1.HttpsError('permission-denied', 'Organization information is required for cross-user password resets.');
            }
            if (!(0, rbac_1.verifyOrgBoundary)(callerOrgId, targetOrgId, callerRole)) {
                throw new https_1.HttpsError('permission-denied', 'You can only reset passwords for users in your organization.');
            }
        }
        // ─── Student (student_code auth) ────────────────────────────────────
        if (authProvider === 'student_code') {
            const passwordHash = hashPassword(newPassword);
            // Update Firebase Auth password if student has an auth account
            try {
                const authEmail = userData.authEmail || userData.email;
                if (authEmail) {
                    await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
                }
            }
            catch (e) {
                console.warn('Could not update Firebase Auth password for student:', e);
                Sentry.captureException(e);
            }
            // Update passwordHash in Firestore
            await db.collection('users').doc(effectiveTargetId).update({
                passwordHash: passwordHash,
                mustChangePassword: false,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Audit log
            const callerRole = request.auth.token.role || 'unknown';
            const callerOrgId = request.auth.token.organizationId || userData.organizationId || '';
            await db.collection('audit_logs').add({
                organizationId: userData.organizationId || '',
                performedBy: callerUid,
                performedByRole: callerRole,
                performedByOrgId: callerOrgId,
                userId: callerUid,
                action: 'change_password',
                targetType: 'user',
                targetId: effectiveTargetId,
                metadata: { authProvider: 'student_code', isAdminReset: isAdminReset },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: true, targetUserId: effectiveTargetId };
        }
        // ─── Email/Password User ────────────────────────────────────────────
        if (authProvider === 'password') {
            if (isAdminReset) {
                await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
                await db.collection('users').doc(effectiveTargetId).update({
                    mustChangePassword: true,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            else {
                await admin.auth().updateUser(effectiveTargetId, { password: newPassword });
                await db.collection('users').doc(effectiveTargetId).update({
                    mustChangePassword: false,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            // Audit log
            const callerRole = request.auth.token.role || 'unknown';
            const callerOrgId = request.auth.token.organizationId || userData.organizationId || '';
            await db.collection('audit_logs').add({
                organizationId: userData.organizationId || '',
                performedBy: callerUid,
                performedByRole: callerRole,
                performedByOrgId: callerOrgId,
                userId: callerUid,
                action: isAdminReset ? 'reset_password' : 'change_password',
                targetType: 'user',
                targetId: effectiveTargetId,
                metadata: { authProvider: 'password', isAdminReset: isAdminReset },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: true, targetUserId: effectiveTargetId };
        }
        // Google auth users shouldn't have passwords
        throw new https_1.HttpsError('failed-precondition', 'Cannot change password for this auth provider.');
    }); // withIsolatedScope
});
//# sourceMappingURL=changeUserPassword.js.map