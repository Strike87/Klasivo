// ─── Auth Providers — Code Generation (Disabled) ──────────────────────────
//
// This file previously used @riverpod code generation with a `part` directive
// for `auth_generated_providers.g.dart`, which was never generated.
//
// The working manual providers live in `auth_providers.dart` in this same
// directory. That file provides:
//   - authServiceProvider     → IAuthService (with DI)
//   - authRepositoryProvider  → AuthRepository
//   - currentUserProvider     → StreamProvider<UserModel?> (FirebaseAuth + Firestore + Hive)
//   - isLoggedInProvider      → bool
//   - currentUserRoleProvider → String
//   - currentOrgIdProvider    → String?
//
// To re-enable code generation in the future:
//   1. Add `riverpod_generator: ^2.4.0` to dev_dependencies (already done)
//   2. Run: dart run build_runner build --delete-conflicting-outputs
//   3. Move @riverpod annotations here with proper `part` directive
//
// For now, all auth providers are in auth_providers.dart.
// ──────────────────────────────────────────────────────────────────────────

export 'auth_providers.dart';
