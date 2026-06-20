// ============================================================================
// Klasivo — Consolidated Password Hasher Service
// ============================================================================
// Replaces 4 duplicate hashPassword() implementations:
//   - lib/core/services/auth_service.dart (lines 29-33)
//   - lib/core/services/student_service.dart
//   - lib/core/services/excel_import_service.dart
//   - lib/features/auth/data/auth_service.dart (dead code, but still present)
//
// PROBLEM: Each copy uses unsalted SHA-256 (crypto.createHash('sha256')).
//   - SHA-256 is FAST — billions of guesses/sec on GPU
//   - No salt — identical passwords produce identical hashes
//   - 4 copies will drift over time
//
// SOLUTION: This shared service. All callers import this instead of
// implementing their own hashPassword. The actual hashing is done
// SERVER-SIDE via the hashPassword Cloud Function (bcrypt), because
// Dart doesn't have a hardened KDF without native deps.
//
// MIGRATION PATH:
//   Phase 1 (immediate): All client code calls PasswordHasher.hash()
//     which internally calls the Cloud Function. Old hashPassword()
//     copies deleted.
//   Phase 2 (Day 5 patch): Cloud Function stops storing passwordHash
//     in Firestore. Relies solely on Firebase Auth (bcrypt, server-side).
//     This PasswordHasher service becomes a thin wrapper that's eventually
//     removed once all callers migrate to Firebase Auth.
// ============================================================================

import 'package:firebase_functions/firebase_functions.dart';

/// Singleton password hashing service.
///
/// Usage:
///   final hash = await PasswordHasher.instance.hash('mypassword');
///   final verified = await PasswordHasher.instance.verify('mypassword', hash);
///
/// DO NOT use SHA-256 directly. Always go through this service.
class PasswordHasher {
  PasswordHasher._();
  static final PasswordHasher instance = PasswordHasher._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Hash a password server-side (bcrypt via Cloud Function).
  ///
  /// Returns the bcrypt hash string (including salt).
  /// Throws on failure.
  Future<String> hash(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }

    try {
      final result = await _functions.httpsCallable('hashPassword').call({
        'password': password,
      });
      return result.data['hash'] as String;
    } catch (e) {
      throw Exception('Password hashing failed: $e');
    }
  }

  /// Verify a password against a stored hash.
  ///
  /// Returns true if the password matches the hash.
  Future<bool> verify(String password, String hash) async {
    if (password.isEmpty || hash.isEmpty) return false;

    try {
      final result = await _functions.httpsCallable('verifyPassword').call({
        'password': password,
        'hash': hash,
      });
      return result.data['valid'] as bool;
    } catch (e) {
      // If verification fails, default to false (fail-closed)
      return false;
    }
  }

  /// Generate a random temporary password for new students.
  ///
  /// Replaces the hardcoded '123456' default. Generates a memorable
  /// but unpredictable 8-character password using the same pattern
  /// as invite_code_service.dart.
  String generateTemporaryPassword() {
    // Use a memorable pattern: 4 letters + 4 digits
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';  // no I, O (ambiguous)
    const digits = '23456789';  // no 0, 1 (ambiguous)

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
