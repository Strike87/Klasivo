// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Secure Password Generator
//
// Generates random temporary passwords for bulk-imported students.
// Uses Random.secure() for cryptographic randomness.
// Output: alphanumeric (uppercase + lowercase + digits), 10-12 chars.
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:math';

class PasswordGenerator {
  PasswordGenerator._();

  static const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const _digits = '0123456789';
  static const _allChars = _lowercase + _uppercase + _digits;

  static final _random = Random.secure();

  /// Generate a secure temporary password.
  ///
  /// [length] must be between 8 and 32. Default: 10.
  /// Guarantees at least 1 uppercase, 1 lowercase, and 1 digit.
  static String generateTempPassword({int length = 10}) {
    if (length < 8) length = 8;
    if (length > 32) length = 32;

    // Ensure at least one of each character type
    final buffer = StringBuffer();
    buffer.write(_uppercase[_random.nextInt(_uppercase.length)]);
    buffer.write(_lowercase[_random.nextInt(_lowercase.length)]);
    buffer.write(_digits[_random.nextInt(_digits.length)]);

    // Fill the rest with random characters
    for (int i = 3; i < length; i++) {
      buffer.write(_allChars[_random.nextInt(_allChars.length)]);
    }

    // Shuffle the characters to avoid predictable positions
    final chars = buffer.toString().split('')..shuffle(_random);
    return chars.join();
  }

  /// Generate multiple unique passwords.
  static List<String> generateBulkPasswords({int count = 30, int length = 10}) {
    final passwords = <String>{};
    while (passwords.length < count) {
      passwords.add(generateTempPassword(length: length));
    }
    return passwords.toList();
  }
}
