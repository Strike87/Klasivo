import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/services/auth_service.dart';

void main() {
  // P0-12 PATCH: AuthService.hashPassword() and its tests removed. The
  // method was dead code with no production caller (its doc comment pointed
  // at lib/features/auth/data/auth_service.dart, which no longer exists).
  // Password verification now happens via Firebase Auth directly
  // (AuthService.loginStudent uses signInWithEmailAndPassword), and password
  // hashing for storage happens server-side via scrypt
  // (functions/src/utils/passwordHash.ts).

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
