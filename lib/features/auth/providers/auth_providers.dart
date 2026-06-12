import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/interfaces/i_auth_service.dart';

/// Production [IAuthService] implementation
final authServiceProvider = Provider<IAuthService>((ref) => AuthService());

/// [AuthRepository] provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(authServiceProvider));
});

/// Current user provider — reads from Hive auth box
final currentUserProvider = Provider<UserModel?>((ref) {
  // This is a placeholder — the real implementation reads from Hive
  // and updates on auth state changes. For now it returns null.
  return null;
});
