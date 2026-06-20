/**
 * Klasivo — Firestore-counter Rate Limiter (C-05 PATCH)
 *
 * A lightweight, dependency-free rate limiter backed by Firestore.
 * Designed for low-traffic callables (e.g. sendContactForm: 5 req/hour/IP).
 * For high-traffic use cases, consider Redis or a dedicated WAF rule.
 *
 * Storage: `rate_limits/{key}` documents with shape:
 *   {
 *     count: number,           // current request count in this window
 *     firstRequestAt: Timestamp,  // start of current window
 *     lastRequestAt: Timestamp,   // last seen
 *     updatedAt: Timestamp
 *   }
 *
 * Algorithm:
 *   1. Read rate_limits/{key} (or treat as new)
 *   2. If doc is missing OR (now - firstRequestAt > windowMs): reset to count=1
 *   3. Else: atomic increment count via FieldValue.increment(1)
 *   4. If count > limit: throw HttpsError('resource-exhausted', ...)
 *
 * Race condition note: read-then-write has a small race window, but for
 * rate limiting an approximate count is acceptable. A few extra requests
 * slipping through under heavy concurrency is fine.
 *
 * Cleanup: rate_limits docs accumulate over time. To avoid unbounded
 * growth, set up a scheduled Cloud Function to delete docs where
 * `firstRequestAt < now - 7d`. (Out of scope for this patch.)
 */

import * as admin from 'firebase-admin';
import { HttpsError } from 'firebase-functions/v2/https';

const db = admin.firestore();
const COLLECTION = 'rate_limits';

export interface RateLimitOptions {
  /** Bucket key, e.g. "contact_form:ip:1.2.3.4". Caller is responsible for composition. */
  key: string;
  /** Max requests allowed in the window. */
  limit: number;
  /** Window length in milliseconds. */
  windowMs: number;
  /** Human-readable label for the error message, e.g. "contact form submissions". */
  label?: string;
}

/**
 * Check and increment the rate limit counter for the given key.
 * Throws HttpsError('resource-exhausted') if the limit is exceeded.
 */
export async function checkRateLimit(opts: RateLimitOptions): Promise<void> {
  const { key, limit, windowMs, label = 'requests' } = opts;
  const docRef = db.collection(COLLECTION).doc(key);
  const now = Date.now();

  const snap = await docRef.get();
  const data = snap.data();

  let newCount: number;
  let firstRequestAt: number = now;  // TS fix: initialized to avoid 'used before assigned'

  if (!data || !data.firstRequestAt) {
    // New window
    newCount = 1;
    firstRequestAt = now;
    await docRef.set({
      count: newCount,
      firstRequestAt: now,
      lastRequestAt: now,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    const firstMs = typeof data.firstRequestAt === 'number'
      ? data.firstRequestAt
      : (data.firstRequestAt.toMillis ? data.firstRequestAt.toMillis() : now);
    const elapsed = now - firstMs;

    if (elapsed > windowMs) {
      // Window expired — reset
      newCount = 1;
      firstRequestAt = now;
      await docRef.set({
        count: newCount,
        firstRequestAt: now,
        lastRequestAt: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Within window — increment atomically
      newCount = (data.count || 0) + 1;
      firstRequestAt = firstMs;  // TS fix: assign before use at line 101
      await docRef.update({
        count: admin.firestore.FieldValue.increment(1),
        lastRequestAt: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  if (newCount > limit) {
    const resetMs = firstRequestAt + windowMs - now;
    const resetMinutes = Math.ceil(resetMs / 60000);
    throw new HttpsError(
      'resource-exhausted',
      `Rate limit exceeded for ${label}. ` +
      `Max ${limit} ${label} per ${Math.round(windowMs / 60000)} minutes. ` +
      `Try again in ${resetMinutes} minute(s).`,
    );
  }
}

/**
 * Compose a rate-limit key from a function name + identifier (typically IP).
 * Example: rateLimitKey('contact_form', '1.2.3.4') -> 'contact_form:ip:1.2.3.4'
 */
export function rateLimitKey(fn: string, ip: string): string {
  // Sanitize: keep only safe chars
  const safeFn = fn.replace(/[^a-zA-Z0-9_]/g, '_');
  const safeIp = (ip || 'unknown').replace(/[^a-zA-Z0-9._:]/g, '_');
  return `${safeFn}:ip:${safeIp}`;
}
