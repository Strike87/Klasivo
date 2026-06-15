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
exports.sentryTestEvent = void 0;
const https_1 = require("firebase-functions/v2/https");
const Sentry = __importStar(require("@sentry/node"));
const sentry_1 = require("../config/sentry");
/**
 * sentryTestEvent — Diagnostic callable for verifying Sentry integration.
 *
 * Sends a test message and a test exception to Sentry so the operator can
 * confirm events arrive in the Sentry dashboard. Intended for staging/dev
 * verification only; harmless in production but not critical-path.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sentryTestEvent').call({
 *     message: 'hello from Klasivo',
 *   });
 */
exports.sentryTestEvent = (0, https_1.onCall)({ secrets: ['SENTRY_DSN'], region: 'us-central1', memory: '256MiB', timeoutSeconds: 15, minInstances: 0, maxInstances: 3, concurrency: 10 }, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('function', 'sentryTestEvent');
        scope.setTag('diagnostic', 'true');
        const message = request.data?.message ?? 'default test message';
        const authUid = request.auth?.uid ?? 'anonymous';
        // Send a test breadcrumb
        Sentry.addBreadcrumb({
            category: 'diagnostic',
            message: 'sentryTestEvent_invoked',
            data: { message, authUid, timestamp: new Date().toISOString() },
            level: 'info',
        });
        // Send a test captureMessage
        Sentry.captureMessage(`Sentry test event from Klasivo Cloud Functions: "${message}"`, {
            level: 'info',
            tags: { diagnostic: 'sentry_test', authUid },
        });
        // Send a test exception (non-fatal)
        try {
            throw new Error(`Sentry test exception — this is intentional (authUid=${authUid})`);
        }
        catch (err) {
            Sentry.captureException(err, { tags: { diagnostic: 'sentry_test', authUid } });
        }
        return {
            success: true,
            message: 'Sentry test events sent. Check your Sentry dashboard for: 1 message + 1 exception',
            authUid,
            environment: process.env.GOOGLE_CLOUD_PROJECT ?? 'unknown',
        };
    });
});
//# sourceMappingURL=sentryTestEvent.js.map