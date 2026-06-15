// ─── Auth Domain Models ──────────────────────────────────────────────────────
// Extracted from auth_service.dart and auth_provider.dart

/// Tracks which authentication method a user registered with.
class AuthProviders {
  static const String password = 'password';
  static const String google = 'google';
  static const String studentCode = 'student_code';
}

/// Represents the current authentication state of the app.
class AuthState {
  final bool isLoggedIn;
  final String userRole;
  final String? userName;
  final String? userId;
  final String? authMethod;
  final String? organizationId;
  final bool hasCompletedSetup;
  final String? studentClassId;
  final String? studentTeacherId;
  final String? studentCode;
  final String? studentClassName;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.userRole = '',
    this.userName,
    this.userId,
    this.authMethod,
    this.organizationId,
    this.hasCompletedSetup = true,
    this.studentClassId,
    this.studentTeacherId,
    this.studentCode,
    this.studentClassName,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? userRole,
    String? userName,
    String? userId,
    String? authMethod,
    String? organizationId,
    bool? hasCompletedSetup,
    String? studentClassId,
    String? studentTeacherId,
    String? studentCode,
    String? studentClassName,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userRole: userRole ?? this.userRole,
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      authMethod: authMethod ?? this.authMethod,
      organizationId: organizationId ?? this.organizationId,
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
      studentClassId: studentClassId ?? this.studentClassId,
      studentTeacherId: studentTeacherId ?? this.studentTeacherId,
      studentCode: studentCode ?? this.studentCode,
      studentClassName: studentClassName ?? this.studentClassName,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Convenience getters for role checks
  bool get isOwner => userRole == 'owner';
  bool get isTeacher => userRole == 'teacher';
  bool get isStudent => userRole == 'student';
  bool get isParent => userRole == 'parent';
}
