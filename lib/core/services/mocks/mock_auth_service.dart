import '../interfaces/i_auth_service.dart';

/// Mock implementation of [IAuthService] that stores data in memory.
///
/// Provides [seedUser], [setLoginFailure], and [reset] helpers so
/// tests can control state and make assertions.
class MockAuthService implements IAuthService {
  final Map<String, Map<String, dynamic>> _users = {};
  Map<String, dynamic>? _currentUser;
  bool _shouldFailLogin = false;
  String? _failLoginMessage;

  // ─── Test Helpers ──────────────────────────────────────────────────────

  /// Force the next login attempt to throw.
  void setLoginFailure({required bool shouldFail, String? message}) {
    _shouldFailLogin = shouldFail;
    _failLoginMessage = message;
  }

  /// Pre-populate a user record for login lookups.
  void seedUser({
    required String uid,
    required String email,
    required String role,
    String? orgId,
  }) {
    _users[uid] = {
      'uid': uid,
      'email': email,
      'role': role,
      'organizationId': orgId,
    };
  }

  /// Clear all in-memory state.
  void reset() {
    _users.clear();
    _currentUser = null;
    _shouldFailLogin = false;
    _failLoginMessage = null;
  }

  // ─── IAuthService Implementation ───────────────────────────────────────

  @override
  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uid = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final userData = {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': 'owner',
      'authProvider': 'password',
    };
    _users[uid] = userData;
    _currentUser = userData;
    return userData;
  }

  @override
  Future<Map<String, dynamic>> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    final uid = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final userData = {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': 'teacher',
      'authProvider': 'password',
    };
    _users[uid] = userData;
    _currentUser = userData;
    return userData;
  }

  @override
  Future<Map<String, dynamic>> registerStudent({
    required String code,
    required String password,
  }) async {
    final uid = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final userData = {
      'uid': uid,
      'code': code,
      'role': 'student',
      'authProvider': 'student_code',
    };
    _users[uid] = userData;
    _currentUser = userData;
    return userData;
  }

  @override
  Future<Map<String, dynamic>> registerParent({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uid = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    final userData = {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'role': 'parent',
      'authProvider': 'password',
    };
    _users[uid] = userData;
    _currentUser = userData;
    return userData;
  }

  @override
  Future<Map<String, dynamic>> loginOwner({
    required String email,
    required String password,
  }) async {
    if (_shouldFailLogin) {
      throw Exception(_failLoginMessage ?? 'Login failed');
    }
    final user = _users.values.firstWhere(
      (u) => u['email'] == email && u['role'] == 'owner',
      orElse: () => {'uid': 'mock_login', 'email': email, 'role': 'owner'},
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>> loginTeacher({
    required String email,
    required String password,
  }) async {
    if (_shouldFailLogin) {
      throw Exception(_failLoginMessage ?? 'Login failed');
    }
    final user = _users.values.firstWhere(
      (u) => u['email'] == email && u['role'] == 'teacher',
      orElse: () => {'uid': 'mock_login', 'email': email, 'role': 'teacher'},
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>> loginStudent({
    required String code,
    required String password,
  }) async {
    if (_shouldFailLogin) {
      throw Exception(_failLoginMessage ?? 'Login failed');
    }
    final user = _users.values.firstWhere(
      (u) => u['code'] == code && u['role'] == 'student',
      orElse: () => {'uid': 'mock_login', 'code': code, 'role': 'student'},
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>> loginParent({
    required String email,
    required String password,
  }) async {
    if (_shouldFailLogin) {
      throw Exception(_failLoginMessage ?? 'Login failed');
    }
    final user = _users.values.firstWhere(
      (u) => u['email'] == email && u['role'] == 'parent',
      orElse: () => {'uid': 'mock_login', 'email': email, 'role': 'parent'},
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>> loginWithGoogle() async {
    if (_shouldFailLogin) {
      throw Exception(_failLoginMessage ?? 'Google sign-in failed');
    }
    final uid = 'mock_google_${DateTime.now().millisecondsSinceEpoch}';
    final userData = {
      'uid': uid,
      'email': 'mock@gmail.com',
      'role': 'teacher',
      'authProvider': 'google',
    };
    _users[uid] = userData;
    _currentUser = userData;
    return userData;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  bool isEmailVerified() => true;
}
