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
exports.initSentry = initSentry;
exports.withIsolatedScope = withIsolatedScope;
exports.withTransaction = withTransaction;
exports.sanitizePayload = sanitizePayload;
const Sentry = __importStar(require("@sentry/node"));
let _initialised = false;
/**
 * Initialize Sentry for Cloud Functions.
 *
 * IMPORTANT: This must be called once per cold start (module load).
 * After initialization, every function invocation MUST use
 * `Sentry.withScope()` or `Sentry.withIsolationScope()` to prevent
 * tag/user context from leaking between concurrent requests in
 * Cloud Functions v2 (which handles multiple requests per instance).
 *
 * Usage in a function:
 *   initSentry();
 *   Sentry.withScope(async (scope) => {
 *     scope.setTag('function', 'generateLiveKitToken');
 *     scope.setUser({ id: callerUid });
 *     // ... business logic ...
 *   });
 */
function initSentry() {
    if (_initialised)
        return;
    const dsn = process.env.SENTRY_DSN;
    if (!dsn) {
        console.warn('SENTRY_DSN is not set. Run: firebase functions:secrets:set SENTRY_DSN');
        return;
    }
    const env = process.env.FUNCTION_TARGET
        ?? process.env.GOOGLE_CLOUD_PROJECT ?? 'production';
    Sentry.init({
        dsn,
        environment: env,
        tracesSampleRate: env === 'production' ? 0.2 : 1.0,
        // Before-send callback: strip sensitive data from all events
        beforeSend(event) {
            // Sanitize breadcrumbs
            if (event.breadcrumbs) {
                for (let i = 0; i < event.breadcrumbs.length; i++) {
                    const crumb = event.breadcrumbs[i];
                    if (crumb.data) {
                        crumb.data = sanitizeMap(crumb.data);
                    }
                }
            }
            // Sanitize extra fields
            if (event.extra) {
                event.extra = sanitizeMap(event.extra);
            }
            // Sanitize request headers
            if (event.request?.headers) {
                const sanitized = {};
                for (const [key, value] of Object.entries(event.request.headers)) {
                    const lower = key.toLowerCase();
                    if (lower.includes('authorization') || lower.includes('cookie') || lower.includes('token')) {
                        sanitized[key] = '[REDACTED]';
                    }
                    else {
                        sanitized[key] = value;
                    }
                }
                event.request.headers = sanitized;
            }
            return event;
        },
    });
    _initialised = true;
    console.log(`Sentry initialised for Cloud Functions (env=${env})`);
}
// ─── Scope Isolation Helpers ──────────────────────────────────────────────
/**
 * Run a function inside an isolated Sentry scope.
 * Tags and user context set inside [fn] do NOT leak to subsequent
 * invocations handled by the same Cloud Functions instance.
 *
 * This is MANDATORY for all callable/onRequest functions in v2.
 */
async function withIsolatedScope(fn) {
    return Sentry.withIsolationScope(async (scope) => {
        // Clear any leftover tags from previous invocations
        scope.clear();
        return fn(scope);
    });
}
/**
 * Run a function inside a Sentry span for performance tracing.
 *
 * Note: @sentry/node v8+ replaced startTransaction with Sentry.startSpan().
 * The returned span is a Transaction-like object that supports setStatus/finish.
 */
async function withTransaction(name, op, fn) {
    return Sentry.startSpan({ name, op }, async (span) => {
        try {
            const result = await fn(span);
            span.setStatus({ code: 1 }); // OK
            return result;
        }
        catch (e) {
            span.setStatus({ code: 2 }); // ERROR
            throw e;
        }
    });
}
// ─── Sensitive Field Sanitization ─────────────────────────────────────────
const SENSITIVE_KEYS = [
    'password', 'passwordhash', 'confirmpassword', 'newpassword',
    'accesstoken', 'refreshtoken', 'idtoken', 'otp', 'otpcode',
    'invitecode', 'secret', 'apikey', 'authemail', 'studentcode',
];
function isSensitiveKey(key) {
    const lower = key.toLowerCase();
    return SENSITIVE_KEYS.some(s => lower.includes(s));
}
function sanitizeMap(data) {
    const result = {};
    for (const [key, value] of Object.entries(data)) {
        if (isSensitiveKey(key)) {
            result[key] = '[REDACTED]';
        }
        else if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
            result[key] = sanitizeMap(value);
        }
        else {
            result[key] = value;
        }
    }
    return result;
}
/**
 * Sanitize a request payload for Sentry reporting.
 * Removes passwords, tokens, OTP codes, and invite codes.
 */
function sanitizePayload(payload) {
    return sanitizeMap(payload);
}
//# sourceMappingURL=sentry.js.map