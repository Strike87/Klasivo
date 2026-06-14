import * as Sentry from '@sentry/node';

let _initialised = false;

export function initSentry(): void {
  if (_initialised) return;
  const dsn = process.env.SENTRY_DSN;
  if (!dsn) {
    console.warn('SENTRY_DSN is not set. Run: firebase functions:secrets:set SENTRY_DSN');
    return;
  }
  Sentry.init({
    dsn,
    environment: process.env.FUNCTION_TARGET ?? 'production',
    tracesSampleRate: 1.0,
  });
  _initialised = true;
  console.log('Sentry initialised for Cloud Functions');
}
