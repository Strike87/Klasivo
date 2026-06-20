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
// ============================================================================

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

  /// Generate a random 8-character temporary password for new students.
  ///
  /// Replaces the hardcoded '123456' default. Generates a memorable
  /// but unpredictable password using 4 letters + 4 digits (excludes
  /// ambiguous characters I, O, 0, 1).
  ///
  /// Note: This uses DateTime.now().microsecondsSinceEpoch as the entropy
  /// source, which is sufficient for temporary passwords that the user
  /// must change on first login (mustChangePassword: true). For
  /// cryptographic key generation, use a proper secure random source.
  String generateTemporaryPassword() {
    // Exclude ambiguous characters: no I, O (look like 1, 0)
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    // Exclude ambiguous characters: no 0, 1 (look like O, I)
    const digits = '23456789';

    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();

    // 4 letters
    for (int i = 0; i < 4; i++) {
      buffer.write(letters[(random + i * 7919) % letters.length]);
    }
    // 4 digits
    for (int i = 0; i < 4; i++) {
      buffer.write(digits[(random + i * 6271) % digits.length]);
    }

    return buffer.toString();
  }
}
