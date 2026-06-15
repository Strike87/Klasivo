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
exports.assignRole = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const rbac_1 = require("../utils/rbac");
const sentry_1 = require("../config/sentry");
exports.assignRole = (0, https_1.onCall)({
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10, // Admin-only — low concurrency need
    concurrency: 80,
}, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'rbac');
        scope.setTag('function', 'assignRole');
        // ─── Auth Check ─────────────────────────────────────────────────────
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'Must be authenticated.');
        }
        const callerUid = request.auth.uid;
        const callerClaims = request.auth.token;
        const callerRole = callerClaims.role || '';
        scope.setUser({ id: callerUid });
        if (!rbac_1.ROLE_ASSIGNMENT_ROLES.includes(callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Only admins can assign roles.');
        }
        // ─── Input Validation ───────────────────────────────────────────────
        const { targetUserId, newRole, organizationId } = request.data;
        if (!targetUserId || !newRole || !organizationId) {
            throw new https_1.HttpsError('invalid-argument', 'targetUserId, newRole, and organizationId are required.');
        }
        if (!rbac_1.VALID_ROLES.includes(newRole)) {
            throw new https_1.HttpsError('invalid-argument', `Invalid role: ${newRole}. Valid roles: ${rbac_1.VALID_ROLES.join(', ')}`);
        }
        // Admin cannot assign super_admin or owner
        if (callerRole === 'admin' && ['super_admin', 'owner'].includes(newRole)) {
            throw new https_1.HttpsError('permission-denied', 'Admins cannot assign super_admin or owner roles.');
        }
        // Caller must be in the same organization
        if (!(0, rbac_1.verifyOrgBoundary)(callerClaims.organizationId || '', organizationId, callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Cannot assign roles in a different organization.');
        }
        // ─── Get Target User ────────────────────────────────────────────────
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(targetUserId).get();
        if (!userDoc.exists) {
            throw new https_1.HttpsError('not-found', `User ${targetUserId} not found.`);
        }
        const oldRole = userDoc.data()?.role || 'unknown';
        // ─── Owner Self-Demotion Protection ────────────────────────────────
        if (callerUid === targetUserId && oldRole === 'owner' && newRole !== 'owner') {
            throw new https_1.HttpsError('failed-precondition', 'You cannot remove your own owner role. Assign another owner first.');
        }
        // ─── Last-Owner Protection ─────────────────────────────────────────
        if (oldRole === 'owner' && newRole !== 'owner' && callerRole !== 'super_admin') {
            const ownersSnapshot = await db.collection('users')
                .where('organizationId', '==', organizationId)
                .where('role', '==', 'owner')
                .get();
            if (ownersSnapshot.size <= 1) {
                throw new https_1.HttpsError('failed-precondition', 'Cannot demote the last owner. Assign another owner first.');
            }
        }
        // ─── Set Custom Claims ──────────────────────────────────────────────
        const customClaims = (0, rbac_1.buildCustomClaims)(newRole, organizationId);
        await admin.auth().setCustomUserClaims(targetUserId, customClaims);
        // ─── Update User Document ───────────────────────────────────────────
        await db.collection('users').doc(targetUserId).update({
            role: newRole,
            roleVersion: admin.firestore.FieldValue.increment(1),
            scopeAccessLevel: customClaims.scopeAccessLevel,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // ─── Audit Log ──────────────────────────────────────────────────────
        await db.collection('audit_logs').add({
            organizationId: organizationId,
            performedBy: callerUid,
            performedByRole: callerRole,
            performedByOrgId: callerClaims.organizationId || organizationId,
            userId: callerUid,
            action: 'assign_role',
            targetType: 'user',
            targetId: targetUserId,
            metadata: {
                oldRole: oldRole,
                newRole: newRole,
                scopeAccessLevel: customClaims.scopeAccessLevel,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {
            success: true,
            targetUserId,
            oldRole,
            newRole,
            scopeAccessLevel: customClaims.scopeAccessLevel,
        };
    }); // withIsolatedScope
});
//# sourceMappingURL=assignRole.js.map