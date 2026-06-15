import * as Sentry from '@sentry/node';
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
export declare function initSentry(): void;
/**
 * Run a function inside an isolated Sentry scope.
 * Tags and user context set inside [fn] do NOT leak to subsequent
 * invocations handled by the same Cloud Functions instance.
 *
 * This is MANDATORY for all callable/onRequest functions in v2.
 */
export declare function withIsolatedScope<T>(fn: (scope: Sentry.Scope) => Promise<T>): Promise<T>;
/**
 * Run a function inside a Sentry span for performance tracing.
 *
 * Note: @sentry/node v8+ replaced startTransaction with Sentry.startSpan().
 * The returned span is a Transaction-like object that supports setStatus/finish.
 */
export declare function withTransaction<T>(name: string, op: string, fn: (span: Sentry.Span) => Promise<T>): Promise<T>;
/**
 * Sanitize a request payload for Sentry reporting.
 * Removes passwords, tokens, OTP codes, and invite codes.
 */
export declare function sanitizePayload(payload: Record<string, any>): Record<string, any>;
