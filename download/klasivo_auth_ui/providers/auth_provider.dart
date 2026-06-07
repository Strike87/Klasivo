import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/auth_service.dart';

/// Firebase Auth instance provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// AuthService instance provider
final authServiceInstanceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth state provider — exposes the current Firebase user
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Whether the current user needs org setup (hasn't named their workspace yet)
final needsSetupProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return false;
      final authService = ref.read(authServiceInstanceProvider);
      return authService.needsSetup(user.uid);
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Auth Notifier for state mutations (login, register, etc.)
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.read(authServiceInstanceProvider));
});

/// Auth Notifier — manages auth state mutations
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  /// Login with email and password
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.loginWithEmail(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Login with Google
  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authService.loginWithGoogle();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Register a new owner (teacher)
  Future<void> registerOwner({
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.registerOwner(
        fullName: fullName,
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Complete owner setup by naming their organization
  Future<void> completeOwnerSetup({
    required String organizationName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.completeOwnerSetup(
        organizationName: organizationName,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Generate workspace name suggestions
  Future<List<String>> generateWorkspaceSuggestions() async {
    return _authService.generateWorkspaceSuggestions();
  }

  /// Login as a student (studentCode + password backed by Firebase Auth)
  Future<void> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.loginStudent(
        studentCode: studentCode,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
