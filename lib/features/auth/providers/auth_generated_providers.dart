// ─── Riverpod Generator Example: Auth Feature ──────────────────────────────
//
// This file demonstrates the new @riverpod code-generation pattern.
// Compare with the manual providers in the same directory.
//
// To generate code, run:
//   dart run build_runner build --delete-conflicting-outputs
//
// After generation, a `auth_generated_providers.g.dart` file will appear
// containing the boilerplate that Riverpod Generator creates automatically.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/interfaces/i_auth_service.dart';

part 'auth_generated_providers.g.dart';

/// Production auth service provider.
///
/// Using @riverpod, the provider is auto-disposed and type-safe.
/// Compare: manual version would be `final authServiceProvider = Provider<IAuthService>((ref) => AuthService());`
@riverpod
IAuthService authService(Ref ref) {
  return AuthService();
}

/// Auth repository provider — depends on [authServiceProvider].
@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(authServiceProvider));
}

/// Current user provider — auto-disposed when no longer watched.
///
/// This is a placeholder that would normally read from FirebaseAuth + Hive.
/// In a full migration, this would listen to `FirebaseAuth.instance.authStateChanges()`
/// and map the result to a [UserModel].
@riverpod
UserModel? currentUser(Ref ref) {
  // TODO: Wire to FirebaseAuth.authStateChanges() + Hive box
  return null;
}

/// Whether the user is logged in — derived from [currentUserProvider].
@riverpod
bool isLoggedIn(Ref ref) {
  return ref.watch(currentUserProvider) != null;
}

/// Current user's role — derived from [currentUserProvider].
@riverpod
String currentUserRole(Ref ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role ?? 'unknown';
}
