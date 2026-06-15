import '../auth_service.dart';
import '../../services/auth_service.dart' as native;

/// Production implementation of [IAuthService] that delegates to an
/// instance of the existing [native.AuthService].
class FirebaseAuthService implements IAuthService {
  final native.AuthService _delegate;

  FirebaseAuthService() : _delegate = native.AuthService();
  FirebaseAuthService._withDelegate(this._delegate);

  @override
  Future<Map<String, dynamic>?> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _delegate.registerOwner(
        email: email,
        password: password,
        fullName: fullName,
      );

  @override
  Future<Map<String, dynamic>?> registerOwnerWithGoogle() =>
      _delegate.registerOwnerWithGoogle();

  @override
  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  }) =>
      _delegate.completeOwnerSetup(
        userId: userId,
        organizationId: organizationId,
        workspaceName: workspaceName,
      );

  @override
  List<String> generateWorkspaceSuggestions(String fullName) =>
      _delegate.generateWorkspaceSuggestions(fullName);

  @override
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) =>
      _delegate.loginWithEmail(email: email, password: password);

  @override
  Future<Map<String, dynamic>?> loginStudent({
    required String studentCode,
    required String password,
  }) =>
      _delegate.loginStudent(studentCode: studentCode, password: password);

  @override
  Future<Map<String, dynamic>?> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) =>
      _delegate.registerTeacherWithInvite(
        email: email,
        password: password,
        fullName: fullName,
        inviteCode: inviteCode,
      );

  @override
  Future<Map<String, dynamic>?> registerTeacherWithGoogle({
    required String inviteCode,
  }) =>
      _delegate.registerTeacherWithGoogle(inviteCode: inviteCode);

  @override
  Future<Map<String, dynamic>?> registerParent({
    required String email,
    required String password,
    required String fullName,
  }) =>
      _delegate.registerParent(
        email: email,
        password: password,
        fullName: fullName,
      );

  @override
  Future<Map<String, dynamic>?> registerParentWithGoogle() =>
      _delegate.registerParentWithGoogle();

  @override
  Future<Map<String, dynamic>?> loginWithGoogle({String? expectedRole}) =>
      _delegate.loginWithGoogle(expectedRole: expectedRole);

  @override
  Future<void> syncEmailVerification(String userId, bool isVerified) =>
      _delegate.syncEmailVerification(userId, isVerified);

  @override
  Future<void> signOut() => _delegate.logout();

  @override
  bool get isLoggedIn => _delegate.isLoggedIn;

  @override
  Future<void> sendPasswordReset(String email) =>
      _delegate.sendPasswordReset(email);

  @override
  Future<bool> needsSetup() => _delegate.needsSetup();
}
