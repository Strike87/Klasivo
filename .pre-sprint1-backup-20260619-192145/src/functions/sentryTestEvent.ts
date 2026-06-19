import { onCall } from 'firebase-functions/v2/https';
import * as Sentry from '@sentry/node';

import { initSentry, withIsolatedScope } from '../config/sentry';

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
export const sentryTestEvent = onCall(
  { secrets: ['SENTRY_DSN'], enforceAppCheck: true, region: 'us-central1', memory: '256MiB', timeoutSeconds: 15, minInstances: 0, maxInstances: 3, concurrency: 10 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('function', 'sentryTestEvent');
      scope.setTag('diagnostic', 'true');

      const message = (request.data as Record<string, string>)?.message ?? 'default test message';
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
      } catch (err) {
        Sentry.captureException(err, { tags: { diagnostic: 'sentry_test', authUid } });
      }

      return {
        success: true,
        message: 'Sentry test events sent. Check your Sentry dashboard for: 1 message + 1 exception',
        authUid,
        environment: process.env.GOOGLE_CLOUD_PROJECT ?? 'unknown',
      };
    });
  },
);
