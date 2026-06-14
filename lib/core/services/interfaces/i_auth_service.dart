/// Abstract interface for authentication operations.
///
/// Implementations may delegate to Firebase Auth or use an in-memory
/// store for testing.
abstract class IAuthService {
  /// Register a new organization owner.
  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
  });

  /// Register a teacher using an invite code.
  Future<Map<String, dynamic>> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  });

  /// Register a student using a student code.
  Future<Map<String, dynamic>> registerStudent({
    required String code,
    required String password,
  });

  /// Register a parent account.
  Future<Map<String, dynamic>> registerParent({
    required String email,
    required String password,
    required String fullName,
  });

  /// Log in as an owner.
  Future<Map<String, dynamic>> loginOwner({
    required String email,
    required String password,
  });

  /// Log in as a teacher.
  Future<Map<String, dynamic>> loginTeacher({
    required String email,
    required String password,
  });

  /// Log in as a student.
  Future<Map<String, dynamic>> loginStudent({
    required String code,
    required String password,
  });

  /// Log in as a parent.
  Future<Map<String, dynamic>> loginParent({
    required String email,
    required String password,
  });

  /// Sign in with Google.
  Future<Map<String, dynamic>> loginWithGoogle();

  /// Sign out the current user.
  Future<void> logout();

  /// Send a password-reset email.
  Future<void> sendPasswordResetEmail({required String email});

  /// Whether the current user's email is verified.
  bool isEmailVerified();
}
