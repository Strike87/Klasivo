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
exports.syncClaims = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const rbac_1 = require("../utils/rbac");
const sentry_1 = require("../config/sentry");
exports.syncClaims = (0, https_1.onCall)({
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 20, // Can burst on app open — allow moderate scaling
    concurrency: 80,
}, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'rbac');
        scope.setTag('function', 'syncClaims');
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'Must be authenticated.');
        }
        const callerUid = request.auth.uid;
        scope.setUser({ id: callerUid });
        const callerRole = request.auth.token.role || '';
        const targetUserId = request.data.targetUserId || callerUid;
        // Users can sync their own claims; admins can sync anyone in their org
        if (targetUserId !== callerUid &&
            !rbac_1.ROLE_ASSIGNMENT_ROLES.includes(callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Can only sync your own claims.');
        }
        const db = admin.firestore();
        const userDoc = await db.collection('users').doc(targetUserId).get();
        if (!userDoc.exists) {
            throw new https_1.HttpsError('not-found', `User ${targetUserId} not found.`);
        }
        const userData = userDoc.data();
        const role = userData.role || 'student';
        const organizationId = userData.organizationId || '';
        // ─── Org Boundary ───────────────────────────────────────────────────
        if (targetUserId !== callerUid && callerRole !== 'super_admin') {
            const callerOrgId = request.auth.token.organizationId || '';
            if (!(0, rbac_1.verifyOrgBoundary)(callerOrgId, organizationId, callerRole)) {
                throw new https_1.HttpsError('permission-denied', 'Cannot sync claims for users in a different organization.');
            }
        }
        try {
            // ─── Set Custom Claims ──────────────────────────────────────────────
            const customClaims = (0, rbac_1.buildCustomClaims)(role, organizationId);
            await admin.auth().setCustomUserClaims(targetUserId, customClaims);
            // ─── Audit Log ──────────────────────────────────────────────────────
            await db.collection('audit_logs').add({
                organizationId: organizationId,
                performedBy: callerUid,
                performedByRole: callerRole,
                performedByOrgId: request.auth.token.organizationId || organizationId,
                userId: callerUid,
                action: 'sync_claims',
                targetType: 'user',
                targetId: targetUserId,
                metadata: {
                    role: role,
                    scopeAccessLevel: customClaims.scopeAccessLevel,
                },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
            return {
                success: true,
                targetUserId,
                role,
                organizationId,
                scopeAccessLevel: customClaims.scopeAccessLevel,
            };
        }
        catch (err) {
            Sentry.captureException(err);
            throw err;
        }
    }); // withIsolatedScope
});
//# sourceMappingURL=syncClaims.js.map