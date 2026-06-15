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
exports.onUserCreated = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const queueService_1 = require("../services/queueService");
const sentry_1 = require("../config/sentry");
const db = admin.firestore();
exports.onUserCreated = functions
    .runWith({ secrets: ['SENTRY_DSN'], memory: '256MB', timeoutSeconds: 60 })
    .auth.user()
    .onCreate(async (user) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'email');
        scope.setTag('function', 'onUserCreated');
        const uid = user.uid;
        const email = user.email;
        scope.setUser({ id: uid });
        if (!email) {
            console.warn(`User ${uid} created without email — skipping welcome queue`);
            return null;
        }
        const displayName = user.displayName || email.split('@')[0];
        console.log(`New user created: ${uid} (${email})`);
        try {
            const userDoc = await db.collection('users').doc(uid).get();
            // Verification breadcrumb: log whether the user doc exists.
            // If it doesn't exist, the Auth trigger fired before the client's
            // Firestore .set() completed (or it was blocked by rules).
            Sentry.addBreadcrumb({
                category: 'firestore',
                message: 'onUserCreated_user_doc_readback',
                data: {
                    uid,
                    userDocExists: userDoc.exists,
                    userDocRole: userDoc.exists ? (userDoc.data()?.['role'] ?? 'null') : 'N/A',
                    userDocOrgId: userDoc.exists ? (userDoc.data()?.['organizationId'] ?? 'N/A') : 'N/A',
                },
                level: 'info',
            });
            if (!userDoc.exists) {
                // Log at warning level — this may indicate a race condition
                // where the auth trigger fires before the client writes the user doc,
                // OR it may indicate the client's .set() was blocked by security rules.
                Sentry.captureMessage(`onUserCreated: users/${uid} does NOT exist in Firestore — auth account may be orphaned`, { level: 'warning' });
            }
            const role = userDoc.exists
                ? userDoc.data()?.['role'] ?? 'teacher'
                : 'teacher';
            const result = await (0, queueService_1.queueEmail)({
                type: 'welcome',
                category: 'welcome',
                to: email,
                payload: { name: displayName, role },
                idempotencyKey: `welcome_${uid}`,
            });
            if (result.queued) {
                console.log(`Welcome email queued for ${email} (role: ${role}, queueId: ${result.queueId})`);
            }
            else {
                console.log(`Welcome email already queued for ${email} (reason: ${result.reason})`);
            }
            return null;
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            console.warn(`Welcome email queue error for ${email}: ${msg}`);
            Sentry.captureException(err);
            return null;
        }
    }); // withIsolatedScope
});
//# sourceMappingURL=onUserCreated.js.map