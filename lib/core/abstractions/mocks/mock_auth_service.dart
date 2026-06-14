import '../auth_service.dart';

/// Mock implementation of [IAuthService] for testing.
///
/// Stores users in an in-memory map. Provides helpers to seed test
/// users and inspect state for assertions.
class MockAuthService implements IAuthService {
  /// In-memory user store keyed by user ID.
  final Map<String, Map<String, dynamic>> _users = {};

  /// The currently "signed-in" user data, or `null`.
  Map<String, dynamic>? _currentUser;

  /// Whether [signOut] was called since the last reset.
  bool signOutCalled = false;

  // ─── Pre-seeded Test Users ──────────────────────────────────────────────

  /// Seed a test owner.
  void seedOwner({
    required String uid,
    required String email,
    required String fullName,
    String organizationId = 'org-1',
  }) {
    _users[uid] = {
      'id': uid,
      'email': email,
      'fullName': fullName,
      'role': 'owner',
      'authProvider': 'password',
      'organizationId': organizationId,
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': true,
    };
  }

  /// Seed a test teacher.
  void seedTeacher({
    required String uid,
    required String email,
    required String fullName,
    String organizationId = 'org-1',
  }) {
    _users[uid] = {
      'id': uid,
      'email': email,
      'fullName': fullName,
      'role': 'teacher',
      'authProvider': 'password',
      'organizationId': organizationId,
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': true,
    };
  }

  /// Seed a test student.
  void seedStudent({
    required String uid,
    required String studentCode,
    required String fullName,
    required String passwordHash,
    String organizationId = 'org-1',
    String classId = 'class-1',
    String? authEmail,
  }) {
    _users[uid] = {
      'id': uid,
      'studentCode': studentCode,
      'fullName': fullName,
      'role': 'student',
      'authProvider': 'student_code',
      'organizationId': organizationId,
      'classId': classId,
      'isActive': true,
      'passwordHash': passwordHash,
      'authEmail': authEmail ?? 'student_$studentCode@klasivo.internal',
    };
  }

  /// Seed a test parent.
  void seedParent({
    required String uid,
    required String email,
    required String fullName,
    String? organizationId,
  }) {
    _users[uid] = {
      'id': uid,
      'email': email,
      'fullName': fullName,
      'role': 'parent',
      'authProvider': 'password',
      'organizationId': organizationId,
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': organizationId != null,
    };
  }

  // ─── IAuthService ───────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uid = 'owner_${_users.length}';
    final user = {
      'id': uid,
      'email': email,
      'fullName': fullName,
      'role': 'owner',
      'authProvider': 'password',
      'organizationId': 'org-$_uid',
      'isActive': true,
      'isEmailVerified': false,
      'hasCompletedSetup': false,
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>?> registerOwnerWithGoogle() async {
    final uid = 'owner_g_${_users.length}';
    final user = {
      'id': uid,
      'email': 'owner@example.com',
      'fullName': 'Google Owner',
      'role': 'owner',
      'authProvider': 'google',
      'organizationId': 'org-g-$uid',
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': false,
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  }) async {
    // No-op in mock — state is not persisted to a real org doc.
  }

  @override
  List<String> generateWorkspaceSuggestions(String fullName) {
    final firstName = fullName.split(' ').first;
    return [
      '$firstName Academy',
      "$firstName's Classroom",
      '$firstName Learning Center',
      '$firstName Education',
      '$firstName Institute',
    ];
  }

  @override
  Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    // Find a user whose email matches.
    try {
      final user = _users.values.firstWhere(
        (u) => u['email'] == email && u['role'] != 'student',
      );
      if (user['isActive'] == false) {
        throw Exception('Your account has been deactivated.');
      }
      _currentUser = user;
      return Map<String, dynamic>.from(user);
    } on StateError {
      throw Exception('User not found or invalid credentials.');
    }
  }

  @override
  Future<Map<String, dynamic>?> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    try {
      final user = _users.values.firstWhere(
        (u) => u['studentCode'] == studentCode && u['role'] == 'student',
      );
      if (user['isActive'] == false) {
        throw Exception('Your account has been deactivated.');
      }
      _currentUser = user;
      return Map<String, dynamic>.from(user);
    } on StateError {
      throw Exception('Student not found. Please check your student code.');
    }
  }

  @override
  Future<Map<String, dynamic>?> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    if (inviteCode.isEmpty) {
      throw Exception('Invalid or expired invite code.');
    }
    final uid = 'teacher_${_users.length}';
    final user = {
      'id': uid,
      'email': email,
      'fullName': fullName,
      'role': 'teacher',
      'authProvider': 'password',
      'organizationId': 'org-invite',
      'isActive': true,
      'isEmailVerified': false,
      'hasCompletedSetup': true,
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>?> registerTeacherWithGoogle({
    required String inviteCode,
  }) async {
    if (inviteCode.isEmpty) {
      throw Exception('Invalid or expired invite code.');
    }
    final uid = 'teacher_g_${_users.length}';
    final user = {
      'id': uid,
      'email': 'teacher@example.com',
      'fullName': 'Google Teacher',
      'role': 'teacher',
      'authProvider': 'google',
      'organizationId': 'org-invite',
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': true,
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>?> registerParent({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uid = 'parent_${_users.length}';
    final user = {
      'id': uid,
      'email': email,
      'fullName': fullName,
      'role': 'parent',
      'authProvider': 'password',
      'organizationId': null,
      'isActive': true,
      'isEmailVerified': false,
      'hasCompletedSetup': false,
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>?> registerParentWithGoogle() async {
    final uid = 'parent_g_${_users.length}';
    final user = {
      'id': uid,
      'email': 'parent@example.com',
      'fullName': 'Google Parent',
      'role': 'parent',
      'authProvider': 'google',
      'organizationId': null,
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': false,
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<Map<String, dynamic>?> loginWithGoogle({String? expectedRole}) async {
    final role = expectedRole ?? 'owner';
    final uid = 'google_${_users.length}';
    final user = {
      'id': uid,
      'email': 'user@example.com',
      'fullName': 'Google User',
      'role': role,
      'authProvider': 'google',
      'organizationId': role == 'owner' ? 'org-g-$uid' : null,
      'isActive': true,
      'isEmailVerified': true,
      'hasCompletedSetup': role == 'teacher',
    };
    _users[uid] = user;
    _currentUser = user;
    return user;
  }

  @override
  Future<void> syncEmailVerification(String userId, bool isVerified) async {
    final user = _users[userId];
    if (user != null) {
      user['isEmailVerified'] = isVerified;
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    signOutCalled = true;
  }

  @override
  bool get isLoggedIn => _currentUser != null;

  @override
  Future<void> sendPasswordReset(String email) async {
    // No-op in mock.
  }

  @override
  Future<bool> needsSetup() async {
    if (_currentUser == null) return false;
    final role = _currentUser!['role'] as String?;
    final hasCompletedSetup =
        _currentUser!['hasCompletedSetup'] as bool? ?? true;
    if ((role == 'owner' || role == 'parent') && !hasCompletedSetup) {
      return true;
    }
    return false;
  }

  // ─── Test Helpers ───────────────────────────────────────────────────────

  /// The current signed-in user data (for assertions).
  Map<String, dynamic>? get currentUserData => _currentUser;

  /// All seeded / registered users.
  Map<String, Map<String, dynamic>> get allUsers =>
      Map<String, Map<String, dynamic>>.unmodifiable(_users);

  /// Reset all state. Call in `setUp` or between tests.
  void reset() {
    _users.clear();
    _currentUser = null;
    signOutCalled = false;
  }
}

final String _uid = DateTime.now().millisecondsSinceEpoch.toString();
