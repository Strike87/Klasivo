import * as Sentry from '@sentry/node';

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
export function initSentry(): void {
  if (_initialised) return;
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
        const sanitized: Record<string, string> = {};
        for (const [key, value] of Object.entries(event.request.headers)) {
          const lower = key.toLowerCase();
          if (lower.includes('authorization') || lower.includes('cookie') || lower.includes('token')) {
            sanitized[key] = '[REDACTED]';
          } else {
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
export async function withIsolatedScope<T>(
  fn: (scope: Sentry.Scope) => Promise<T>,
): Promise<T> {
  return Sentry.withIsolationScope(async (scope) => {
    // Clear any leftover tags from previous invocations
    scope.clear();
    return fn(scope);
  });
}

/**
 * Run a function with a Sentry transaction for performance tracing.
 */
export async function withTransaction<T>(
  name: string,
  op: string,
  fn: (transaction: Sentry.Transaction) => Promise<T>,
): Promise<T> {
  const transaction = Sentry.startTransaction({ name, op });
  try {
    const result = await fn(transaction);
    transaction.setStatus('ok');
    return result;
  } catch (e) {
    transaction.setStatus('internal_error');
    throw e;
  } finally {
    transaction.finish();
  }
}

// ─── Sensitive Field Sanitization ─────────────────────────────────────────

const SENSITIVE_KEYS = [
  'password', 'passwordhash', 'confirmpassword', 'newpassword',
  'accesstoken', 'refreshtoken', 'idtoken', 'otp', 'otpcode',
  'invitecode', 'secret', 'apikey', 'authemail', 'studentcode',
];

function isSensitiveKey(key: string): boolean {
  const lower = key.toLowerCase();
  return SENSITIVE_KEYS.some(s => lower.includes(s));
}

function sanitizeMap(data: Record<string, any>): Record<string, any> {
  const result: Record<string, any> = {};
  for (const [key, value] of Object.entries(data)) {
    if (isSensitiveKey(key)) {
      result[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      result[key] = sanitizeMap(value);
    } else {
      result[key] = value;
    }
  }
  return result;
}

/**
 * Sanitize a request payload for Sentry reporting.
 * Removes passwords, tokens, OTP codes, and invite codes.
 */
export function sanitizePayload(payload: Record<string, any>): Record<string, any> {
  return sanitizeMap(payload);
}
