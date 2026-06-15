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
exports.assignScope = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const rbac_1 = require("../utils/rbac");
const sentry_1 = require("../config/sentry");
exports.assignScope = (0, https_1.onCall)({
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
    return (0, sentry_1.withIsolatedScope)(async (sentryScope) => {
        sentryScope.setTag('service', 'rbac');
        sentryScope.setTag('function', 'assignScope');
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'Must be authenticated.');
        }
        const callerUid = request.auth.uid;
        sentryScope.setUser({ id: callerUid });
        const callerClaims = request.auth.token;
        const callerRole = callerClaims.role || '';
        if (!rbac_1.SCOPE_ASSIGNMENT_ROLES.includes(callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Insufficient permissions to assign scope.');
        }
        const { targetUserId, scope, organizationId } = request.data;
        if (!targetUserId || !scope || !organizationId) {
            throw new https_1.HttpsError('invalid-argument', 'targetUserId, scope, and organizationId are required.');
        }
        // ─── Org Boundary ───────────────────────────────────────────────────
        const callerOrgId = callerClaims.organizationId || '';
        if (!(0, rbac_1.verifyOrgBoundary)(callerOrgId, organizationId, callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Cannot assign scope in a different organization.');
        }
        try {
            // ─── Get Target User ────────────────────────────────────────────────
            const db = admin.firestore();
            const userDoc = await db.collection('users').doc(targetUserId).get();
            if (!userDoc.exists) {
                throw new https_1.HttpsError('not-found', `User ${targetUserId} not found.`);
            }
            const userData = userDoc.data();
            const targetRole = userData.role || 'student';
            const oldScope = {
                campusIds: userData.campusIds || [],
                stageIds: userData.stageIds || [],
                classIds: userData.classIds || [],
                subjectIds: userData.subjectIds || [],
                academicYearIds: userData.academicYearIds || [],
                studentIds: userData.studentIds || [],
            };
            // ─── Update Firestore ───────────────────────────────────────────────
            const updateData = {
                roleVersion: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };
            if (scope.campusIds !== undefined)
                updateData['campusIds'] = scope.campusIds;
            if (scope.stageIds !== undefined)
                updateData['stageIds'] = scope.stageIds;
            if (scope.classIds !== undefined)
                updateData['classIds'] = scope.classIds;
            if (scope.subjectIds !== undefined)
                updateData['subjectIds'] = scope.subjectIds;
            if (scope.academicYearIds !== undefined)
                updateData['academicYearIds'] = scope.academicYearIds;
            if (scope.studentIds !== undefined)
                updateData['studentIds'] = scope.studentIds;
            await db.collection('users').doc(targetUserId).update(updateData);
            // ─── Refresh Custom Claims ──────────────────────────────────────────
            // Immediately update custom claims so the client doesn't have to wait
            // for the roleVersion listener → syncClaims round-trip. This eliminates
            // the window where claims are stale after a scope change.
            const customClaims = (0, rbac_1.buildCustomClaims)(targetRole, organizationId);
            await admin.auth().setCustomUserClaims(targetUserId, customClaims);
            // ─── Audit Log ──────────────────────────────────────────────────────
            await db.collection('audit_logs').add({
                organizationId: organizationId,
                performedBy: callerUid,
                performedByRole: callerRole,
                performedByOrgId: callerClaims.organizationId || organizationId,
                userId: callerUid,
                action: 'assign_scope',
                targetType: 'user',
                targetId: targetUserId,
                metadata: {
                    targetRole: targetRole,
                    oldScope: oldScope,
                    newScope: scope,
                },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: true, targetUserId, scope };
        }
        catch (err) {
            Sentry.captureException(err);
            throw err;
        }
    }); // withIsolatedScope
});
//# sourceMappingURL=assignScope.js.map