/**
 * Klasivo — Password Hashing Utility (C-02 PATCH)
 *
 * Replaces the previous SHA-256 password hashing with scrypt, which is:
 *   - Memory-hard (resistant to GPU/ASIC brute force)
 *   - Salted (resistant to rainbow tables)
 *   - Configurable (N/r/p parameters can be tuned as hardware improves)
 *
 * Storage format (PHC-ish, `$`-separated):
 *   scrypt$N=16384$r=8$p=1$<saltHex>$<hashHex>
 *
 * Legacy SHA-256 hashes (64 hex chars, no `$`) are still accepted by
 * verifyPassword() for backward compatibility. On successful verification
 * of a legacy hash, the caller should re-hash with hashPassword() and
 * update the user doc — see needsRehash().
 *
 * References:
 *   - https://nodejs.org/api/crypto.html#cryptoscryptsyncpassword-salt-keylen-options
 *   - https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
 */

import * as crypto from 'crypto';

// Scrypt parameters (OWASP-recommended as of 2024).
// N=16384 (2^14), r=8, p=1 → ~50ms on a 2024-era CPU. Tunable.
const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEY_LEN = 64;       // 512-bit hash
const SALT_LEN = 16;      // 128-bit salt

const SCRYPT_PREFIX = 'scrypt';
const LEGACY_SHA256_LENGTH = 64;  // hex chars in a SHA-256 digest

/**
 * Hash a plaintext password using scrypt.
 * Returns: "scrypt$N=...$r=...$p=...$<saltHex>$<hashHex>"
 */
export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(SALT_LEN);
  const hash = crypto.scryptSync(password, salt, KEY_LEN, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
    maxmem: 128 * SCRYPT_N * SCRYPT_R * 2,  // scrypt requires ~128*N*r bytes
  });
  return (
    `${SCRYPT_PREFIX}$N=${SCRYPT_N}$r=${SCRYPT_R}$p=${SCRYPT_P}` +
    `$${salt.toString('hex')}$${hash.toString('hex')}`
  );
}

/**
 * Verify a plaintext password against a stored hash.
 * Accepts:
 *   - scrypt format: "scrypt$N=...$r=...$p=...$<saltHex>$<hashHex>"
 *   - legacy SHA-256: 64-char hex string (no $ separators)
 *
 * Returns true if the password matches.
 */
export function verifyPassword(password: string, storedHash: string): boolean {
  if (!storedHash || typeof storedHash !== 'string') return false;

  // Legacy SHA-256 path (no $ in the string, 64 hex chars)
  if (!storedHash.includes('$') && storedHash.length === LEGACY_SHA256_LENGTH) {
    const inputHash = crypto.createHash('sha256').update(password).digest('hex');
    // Constant-time compare to prevent timing attacks
    return crypto.timingSafeEqual(Buffer.from(inputHash, 'hex'), Buffer.from(storedHash, 'hex'));
  }

  // scrypt path
  if (storedHash.startsWith(`${SCRYPT_PREFIX}$`)) {
    const parts = storedHash.split('$');
    // Expected: ["scrypt", "N=...", "r=...", "p=...", "<saltHex>", "<hashHex>"]
    if (parts.length !== 6) return false;
    const params: Record<string, number> = {};
    for (const part of parts.slice(1, 4)) {
      const [k, v] = part.split('=');
      params[k] = parseInt(v, 10);
      if (isNaN(params[k])) return false;
    }
    const salt = Buffer.from(parts[4], 'hex');
    const expectedHash = Buffer.from(parts[5], 'hex');
    if (salt.length === 0 || expectedHash.length === 0) return false;

    try {
      const actualHash = crypto.scryptSync(password, salt, expectedHash.length, {
        N: params['N'] || SCRYPT_N,
        r: params['r'] || SCRYPT_R,
        p: params['p'] || SCRYPT_P,
        maxmem: 128 * (params['N'] || SCRYPT_N) * (params['r'] || SCRYPT_R) * 2,
      });
      return crypto.timingSafeEqual(actualHash, expectedHash);
    } catch {
      return false;
    }
  }

  return false;
}

/**
 * Returns true if the stored hash is in legacy SHA-256 format and should
 * be re-hashed with scrypt on the next successful authentication.
 */
export function needsRehash(storedHash: string): boolean {
  if (!storedHash || typeof storedHash !== 'string') return false;
  return !storedHash.startsWith(`${SCRYPT_PREFIX}$`);
}
