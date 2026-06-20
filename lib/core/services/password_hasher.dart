// ============================================================================
// Klasivo — Password Hasher Service (Sprint 1 minimal version)
// ============================================================================
// This service is the SINGLE SOURCE OF TRUTH for client-side password
// generation. The actual password HASHING happens server-side via the
// scrypt util (functions/src/utils/passwordHash.ts) — clients must NEVER
// hash passwords themselves.
//
// WHY THIS EXISTS:
//   - To replace the hardcoded '123456' default student password with
//     a random, per-student temporary password.
//   - To provide a single point of change when we later add client-side
//     password validation (length, complexity) before sending to server.
//
// WHAT THIS DOES NOT DO:
//   - hash() and verify() are intentionally NOT implemented here. The
//     server-side scrypt util handles hashing. Clients send plaintext
//     over HTTPS (enforced by Firebase Auth + App Check).
//
// MIGRATION HISTORY:
//   - Days 1-5 patches (commits 3504aef..b4f3e6c) added scrypt server-side.
//   - This Sprint 1 cleanup adds the client-side random password generator.
//   - A later sprint will remove the 5 client-side SHA-256 hashPassword()
//     copies and migrate callers to send plaintext to the server.
//   - P0-8 PATCH: generateTemporaryPassword() switched from a
//     DateTime-seeded generator to dart:math Random.secure(). The previous
//     version derived all 8 characters from a single microsecond timestamp
//     via fixed-offset modular arithmetic, which is deterministic and
//     guessable — two students created in the same microsecond tick (e.g.
//     back-to-back iterations of the Excel bulk-import loop) could receive
//     identical or trivially related passwords. Random.secure() uses the
//     platform CSPRNG and draws fresh entropy per character.
//   - A later sprint will remove the remaining client-side SHA-256
//     hashPassword() copies (auth_service.dart, student_service.dart,
//     excel_import_service.dart) and migrate callers to send plaintext to
//     the server (see changeUserPassword / createStudent callables).
// ============================================================================

import 'dart:math';

/// Singleton password hashing service.
///
/// Usage:
///   final tempPwd = PasswordHasher.instance.generateTemporaryPassword();
///
/// DO NOT use SHA-256 directly. Always go through this service or send
/// plaintext to a server callable.
class PasswordHasher {
  PasswordHasher._();
  static final PasswordHasher instance = PasswordHasher._();

  /// Cryptographically secure RNG. Created once and reused — Random.secure()
  /// reads from the OS entropy pool, so there's no benefit to recreating it
  /// per call, and doing so per-character would be wasteful.
  static final Random _secureRandom = Random.secure();

  /// Generate a random 8-character temporary password for new students.
  ///
  /// Replaces the hardcoded '123456' default. Generates a memorable
  /// but unpredictable password using 4 letters + 4 digits (excludes
  /// ambiguous characters I, O, 0, 1).
  ///
  /// Each character is drawn independently from Random.secure() (the
  /// platform CSPRNG), so passwords generated in rapid succession — e.g.
  /// during bulk Excel import — are not correlated with each other.
  ///
  /// This is a temporary password the student is forced to change on first
  /// login (mustChangePassword: true), not a long-term credential — but it
  /// still must not be predictable, since it's the only thing standing
  /// between account creation and first password change.
  String generateTemporaryPassword() {
    // Exclude ambiguous characters: no I, O (look like 1, 0)
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    // Exclude ambiguous characters: no 0, 1 (look like O, I)
    const digits = '23456789';

    final buffer = StringBuffer();

    // 4 letters
    for (int i = 0; i < 4; i++) {
      buffer.write(letters[_secureRandom.nextInt(letters.length)]);
    }
    // 4 digits
    for (int i = 0; i < 4; i++) {
      buffer.write(digits[_secureRandom.nextInt(digits.length)]);
    }

    return buffer.toString();
  }
}
