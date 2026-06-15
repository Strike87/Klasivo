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
export declare const sentryTestEvent: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    success: boolean;
    message: string;
    authUid: string;
    environment: string;
}>, unknown>;
