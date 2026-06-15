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
exports.setPermissionOverrides = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const rbac_1 = require("../utils/rbac");
const sentry_1 = require("../config/sentry");
// Basic validation: permission strings must match "category:action" pattern
const PERMISSION_RE = /^[a-z_]+:[a-z_]+$/;
const WILDCARD = '*';
function isValidPermissionKey(key) {
    if (key === WILDCARD)
        return true;
    return PERMISSION_RE.test(key);
}
exports.setPermissionOverrides = (0, https_1.onCall)({
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10, // Admin-only — very infrequent
    concurrency: 80,
}, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'rbac');
        scope.setTag('function', 'setPermissionOverrides');
        // ─── Auth Check ─────────────────────────────────────────────────────
        if (!request.auth) {
            throw new https_1.HttpsError('unauthenticated', 'Must be authenticated.');
        }
        const callerUid = request.auth.uid;
        scope.setUser({ id: callerUid });
        const callerClaims = request.auth.token;
        const callerRole = callerClaims.role || '';
        if (!rbac_1.OVERRIDE_ASSIGNMENT_ROLES.includes(callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Only super_admin, owner, or admin can set permission overrides.');
        }
        // ─── Input Validation ───────────────────────────────────────────────
        const { targetUserId, organizationId, overrides, replace = false } = request.data;
        if (!targetUserId || !organizationId || overrides === undefined) {
            throw new https_1.HttpsError('invalid-argument', 'targetUserId, organizationId, and overrides are required.');
        }
        // Validate override keys
        const overrideEntries = Object.entries(overrides);
        for (const [key, value] of overrideEntries) {
            if (typeof value !== 'boolean') {
                throw new https_1.HttpsError('invalid-argument', `Override value for "${key}" must be a boolean, got ${typeof value}.`);
            }
            if (!isValidPermissionKey(key)) {
                throw new https_1.HttpsError('invalid-argument', `Invalid permission key: "${key}". Must match "category:action" pattern or be "*".`);
            }
        }
        // ─── Org Boundary ───────────────────────────────────────────────────
        const callerOrgId = callerClaims.organizationId || '';
        if (!(0, rbac_1.verifyOrgBoundary)(callerOrgId, organizationId, callerRole)) {
            throw new https_1.HttpsError('permission-denied', 'Cannot set overrides for users in a different organization.');
        }
        try {
            // ─── Get Target User ────────────────────────────────────────────────
            const db = admin.firestore();
            const userDoc = await db.collection('users').doc(targetUserId).get();
            if (!userDoc.exists) {
                throw new https_1.HttpsError('not-found', `User ${targetUserId} not found.`);
            }
            const userData = userDoc.data();
            const targetRole = userData.role || 'unknown';
            // Admin cannot set overrides for super_admin or owner
            if (callerRole === 'admin' && ['super_admin', 'owner'].includes(targetRole)) {
                throw new https_1.HttpsError('permission-denied', 'Admins cannot set permission overrides for super_admin or owner.');
            }
            // ─── Build Override Map ─────────────────────────────────────────────
            let finalOverrides;
            if (replace) {
                finalOverrides = { ...overrides };
            }
            else {
                const existingOverrides = (userData.permissionOverrides || {});
                finalOverrides = { ...existingOverrides, ...overrides };
            }
            // ─── Update Firestore ───────────────────────────────────────────────
            await db.collection('users').doc(targetUserId).update({
                permissionOverrides: finalOverrides,
                roleVersion: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // ─── Audit Log ──────────────────────────────────────────────────────
            await db.collection('audit_logs').add({
                organizationId: organizationId,
                performedBy: callerUid,
                performedByRole: callerRole,
                performedByOrgId: callerClaims.organizationId || organizationId,
                userId: callerUid,
                action: 'set_permission_overrides',
                targetType: 'user',
                targetId: targetUserId,
                metadata: {
                    targetRole: targetRole,
                    overrides: finalOverrides,
                    replace: replace,
                    overrideCount: Object.keys(finalOverrides).length,
                },
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });
            return {
                success: true,
                targetUserId,
                overrides: finalOverrides,
                overrideCount: Object.keys(finalOverrides).length,
            };
        }
        catch (err) {
            Sentry.captureException(err);
            throw err;
        }
    }); // withIsolatedScope
});
//# sourceMappingURL=setPermissionOverrides.js.map