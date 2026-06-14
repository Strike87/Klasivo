import '../domain/user_model.dart';
import '../../../core/services/interfaces/i_auth_service.dart';

/// Repository layer that wraps IAuthService and returns domain models.
///
/// This is the data layer for the auth feature. It converts raw
/// service responses into [UserModel] domain objects.
class AuthRepository {
  final IAuthService _authService;

  AuthRepository(this._authService);

  Future<UserModel> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _authService.registerOwner(
      email: email,
      password: password,
      fullName: fullName,
    );
    return _mapToUser(data);
  }

  Future<UserModel> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    final data = await _authService.registerTeacher(
      email: email,
      password: password,
      fullName: fullName,
      inviteCode: inviteCode,
    );
    return _mapToUser(data);
  }

  Future<UserModel> registerStudent({
    required String code,
    required String password,
  }) async {
    final data = await _authService.registerStudent(
      code: code,
      password: password,
    );
    return _mapToUser(data);
  }

  Future<UserModel> registerParent({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final data = await _authService.registerParent(
      email: email,
      password: password,
      fullName: fullName,
    );
    return _mapToUser(data);
  }

  Future<UserModel> loginOwner({
    required String email,
    required String password,
  }) async {
    final data = await _authService.loginOwner(email: email, password: password);
    return _mapToUser(data);
  }

  Future<UserModel> loginTeacher({
    required String email,
    required String password,
  }) async {
    final data = await _authService.loginTeacher(email: email, password: password);
    return _mapToUser(data);
  }

  Future<UserModel> loginStudent({
    required String code,
    required String password,
  }) async {
    final data = await _authService.loginStudent(code: code, password: password);
    return _mapToUser(data);
  }

  Future<UserModel> loginParent({
    required String email,
    required String password,
  }) async {
    final data = await _authService.loginParent(email: email, password: password);
    return _mapToUser(data);
  }

  Future<UserModel> loginWithGoogle() async {
    final data = await _authService.loginWithGoogle();
    return _mapToUser(data);
  }

  Future<void> logout() => _authService.logout();

  Future<void> sendPasswordResetEmail({required String email}) =>
      _authService.sendPasswordResetEmail(email: email);

  bool isEmailVerified() => _authService.isEmailVerified();

  UserModel _mapToUser(Map<String, dynamic> data) {
    return UserModel.fromFirestore(data, data['uid'] as String? ?? '');
  }
}
