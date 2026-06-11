import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/services/auth_service.dart';

void main() {
  // ─── hashPassword ──────────────────────────────────────────────────────────

  group('AuthService.hashPassword', () {
    test('produces consistent SHA-256 hash for same input', () {
      final hash1 = AuthService.hashPassword('mypassword123');
      final hash2 = AuthService.hashPassword('mypassword123');

      expect(hash1, equals(hash2));
    });

    test('produces different hashes for different inputs', () {
      final hash1 = AuthService.hashPassword('password1');
      final hash2 = AuthService.hashPassword('password2');

      expect(hash1, isNot(equals(hash2)));
    });

    test('returns a 64-character hex string (SHA-256)', () {
      final hash = AuthService.hashPassword('test');

      // SHA-256 produces 32 bytes = 64 hex characters
      expect(hash.length, 64);
      expect(hash, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('handles empty password', () {
      final hash = AuthService.hashPassword('');

      // SHA-256 of empty string is a well-known value
      expect(hash.length, 64);
      expect(hash, equals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'));
    });

    test('handles special characters in password', () {
      final hash = AuthService.hashPassword('p@ssw0rd!#\$%');

      expect(hash.length, 64);
      expect(hash, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('handles Arabic characters in password', () {
      final hash = AuthService.hashPassword('كلمةمرور');

      expect(hash.length, 64);
      expect(hash, matches(RegExp(r'^[a-f0-9]{64}$')));
    });

    test('handles very long password', () {
      final longPassword = 'a' * 1000;
      final hash = AuthService.hashPassword(longPassword);

      expect(hash.length, 64);
    });

    test('default student password produces expected hash', () {
      // From AppConstants: defaultStudentPassword = '123456'
      final hash = AuthService.hashPassword('123456');

      // Verify it's deterministic
      expect(hash, equals(AuthService.hashPassword('123456')));
      expect(hash.length, 64);
    });
  });

  // ─── AuthProviders ─────────────────────────────────────────────────────────

  group('AuthProviders', () {
    test('has correct provider constants', () {
      expect(AuthProviders.password, equals('password'));
      expect(AuthProviders.google, equals('google'));
      expect(AuthProviders.studentCode, equals('student_code'));
    });

    test('provider constants are distinct', () {
      final providers = {
        AuthProviders.password,
        AuthProviders.google,
        AuthProviders.studentCode,
      };
      expect(providers.length, 3, reason: 'All provider constants should be unique');
    });
  });

  // ─── generateWorkspaceSuggestions ───────────────────────────────────────────

  group('generateWorkspaceSuggestions', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('generates 5 suggestions from full name', () {
      final suggestions = authService.generateWorkspaceSuggestions('Ahmed Mohamed');

      expect(suggestions.length, 5);
    });

    test('uses first name in suggestions', () {
      final suggestions = authService.generateWorkspaceSuggestions('Ahmed Mohamed');

      expect(suggestions.every((s) => s.contains('Ahmed')), isTrue);
    });

    test('includes expected suggestion patterns', () {
      final suggestions = authService.generateWorkspaceSuggestions('Sara');

      expect(suggestions, contains('Sara Academy'));
      expect(suggestions, contains("Sara's Classroom"));
      expect(suggestions, contains('Sara Learning Center'));
      expect(suggestions, contains('Sara Education'));
      expect(suggestions, contains('Sara Institute'));
    });

    test('handles single word name', () {
      final suggestions = authService.generateWorkspaceSuggestions('Teacher');

      expect(suggestions.length, 5);
      expect(suggestions.every((s) => s.contains('Teacher')), isTrue);
    });

    test('handles name with multiple spaces', () {
      final suggestions = authService.generateWorkspaceSuggestions('Mohamed Ahmed Ali');

      // Should use first word only
      expect(suggestions.every((s) => s.contains('Mohamed')), isTrue);
      expect(suggestions.every((s) => !s.contains('Ahmed')), isTrue);
    });
  });
}
