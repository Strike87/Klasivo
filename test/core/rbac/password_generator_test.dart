import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/rbac/rbac.dart';

void main() {
  group('PasswordGenerator', () {
    test('generates password of correct length', () {
      final password = PasswordGenerator.generateTempPassword(length: 10);
      expect(password.length, 10);
    });

    test('generates password with default length 10', () {
      final password = PasswordGenerator.generateTempPassword();
      expect(password.length, 10);
    });

    test('generates password with minimum length 8', () {
      final password = PasswordGenerator.generateTempPassword(length: 5);
      expect(password.length, 8); // Clamped to 8
    });

    test('generates password with maximum length 32', () {
      final password = PasswordGenerator.generateTempPassword(length: 50);
      expect(password.length, 32); // Clamped to 32
    });

    test('contains at least one uppercase letter', () {
      for (int i = 0; i < 100; i++) {
        final password = PasswordGenerator.generateTempPassword();
        expect(password.contains(RegExp(r'[A-Z]')), true, reason: 'Password "$password" has no uppercase');
      }
    });

    test('contains at least one lowercase letter', () {
      for (int i = 0; i < 100; i++) {
        final password = PasswordGenerator.generateTempPassword();
        expect(password.contains(RegExp(r'[a-z]')), true, reason: 'Password "$password" has no lowercase');
      }
    });

    test('contains at least one digit', () {
      for (int i = 0; i < 100; i++) {
        final password = PasswordGenerator.generateTempPassword();
        expect(password.contains(RegExp(r'[0-9]')), true, reason: 'Password "$password" has no digit');
      }
    });

    test('only contains alphanumeric characters', () {
      for (int i = 0; i < 100; i++) {
        final password = PasswordGenerator.generateTempPassword();
        expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(password), true, reason: 'Password "$password" has non-alphanumeric chars');
      }
    });

    test('generates unique passwords', () {
      final passwords = <String>{};
      for (int i = 0; i < 50; i++) {
        passwords.add(PasswordGenerator.generateTempPassword());
      }
      // At least 48 out of 50 should be unique (very high probability)
      expect(passwords.length, greaterThan(45));
    });

    test('generateBulkPasswords returns correct count', () {
      final passwords = PasswordGenerator.generateBulkPasswords(count: 20);
      expect(passwords.length, 20);
    });

    test('generateBulkPasswords returns unique passwords', () {
      final passwords = PasswordGenerator.generateBulkPasswords(count: 30);
      final uniqueSet = passwords.toSet();
      expect(uniqueSet.length, 30);
    });

    test('is not 123456', () {
      for (int i = 0; i < 100; i++) {
        final password = PasswordGenerator.generateTempPassword();
        expect(password, isNot(equals('123456')));
        expect(password, isNot(equals('Klasivo2024!')));
      }
    });
  });
}
