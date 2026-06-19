/**
 * hashPassword + verifyPassword — Server-side bcrypt hashing (C-02/C-18 fix)
 *
 * Replaces 4 client-side SHA-256 hashPassword implementations.
 * Uses bcrypt (salted, slow KDF) via the 'bcryptjs' package.
 *
 * Install: cd functions && npm install bcryptjs
 *
 * Why server-side:
 *   - Dart doesn't have bcrypt without native deps
 *   - Hashing should never happen client-side (exposes algorithm + salt to attacker)
 *   - Firebase Auth already uses bcrypt server-side — this is a bridge until
 *     all passwordHash fields are deleted from Firestore (Day 5 migration)
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as bcrypt from 'bcryptjs';
import { initSentry, withIsolatedScope } from '../config/sentry';

const BCRYPT_ROUNDS = 12;  // ~250ms per hash — secure without being slow

export const hashPassword = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'hashPassword');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const { password } = request.data as { password: string };

      if (!password || typeof password !== 'string') {
        throw new HttpsError('invalid-argument', 'password is required.');
      }

      if (password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }

      if (password.length > 128) {
        throw new HttpsError('invalid-argument', 'Password must be at most 128 characters.');
      }

      // Hash with bcrypt (salted, slow)
      const salt = await bcrypt.genSalt(BCRYPT_ROUNDS);
      const hash = await bcrypt.hash(password, salt);

      return { hash };
    });
  },
);

export const verifyPassword = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'verifyPassword');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const { password, hash } = request.data as { password: string; hash: string };

      if (!password || !hash) {
        throw new HttpsError('invalid-argument', 'password and hash are required.');
      }

      const valid = await bcrypt.compare(password, hash);

      return { valid };
    });
  },
);
