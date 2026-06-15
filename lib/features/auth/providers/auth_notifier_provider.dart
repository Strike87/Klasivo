// ─── Auth Notifier Provider — Riverpod Generator ──────────────────────────────
//
// Migrated from lib/providers/auth_provider.dart (and the feature-first copy
// at lib/features/auth/providers/auth_provider.dart).
//
// This is the NEW Riverpod Generator–based reference implementation.
// The old providers remain for backward compatibility until all consumers
// are migrated.
//
// Key design decisions:
//   • @Riverpod(keepAlive: true) — auth state must survive auto-dispose
//   • Single AuthState class consolidates all the old StateProviders
//   • Hive persistence on every state change
//   • IAuthService abstraction via abstraction_providers.dart
// ──────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/providers/abstraction_providers.dart';
import '../../../core/abstractions/auth_service.dart';
import '../../../core/services/event_bus.dart';
import '../../../core/services/notification_service.dart' as notif;

part 'auth_notifier_provider.g.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Immutable snapshot of the current authentication state.
///
/// Replaces the many separate `StateProvider<bool/String?>` from the legacy
/// auth_provider.dart with a single cohesive object.
class AuthState {
  final bool isLoggedIn;
  final String? userId;
  final String userRole;
  final String? userName;
  final String? userEmail;
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
    this.userId,
    this.userRole = '',
    this.userName,
    this.userEmail,
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

  /// Convenience getters for role checks
  bool get isOwner => userRole == AppConstants.roleOwner;
  bool get isAdmin => userRole == AppConstants.roleAdmin;
  bool get isTeacher => userRole == AppConstants.roleTeacher;
  bool get isStudent => userRole == AppConstants.roleStudent;
  bool get isParent => userRole == AppConstants.roleParent;

  AuthState copyWith({
    bool? isLoggedIn,
    String? userId,
    String? userRole,
    String? userName,
    String? userEmail,
    String? authMethod,
    String? organizationId,
    bool? hasCompletedSetup,
    String? studentClassId,
    String? studentTeacherId,
    String? studentCode,
    String? studentClassName,
    bool? isLoading,
    String? error,
    // Set to true to explicitly clear nullable fields
    bool clearUserId = false,
    bool clearUserName = false,
    bool clearUserEmail = false,
    bool clearAuthMethod = false,
    bool clearOrganizationId = false,
    bool clearStudentClassId = false,
    bool clearStudentTeacherId = false,
    bool clearStudentCode = false,
    bool clearStudentClassName = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: clearUserId ? null : (userId ?? this.userId),
      userRole: userRole ?? this.userRole,
      userName: clearUserName ? null : (userName ?? this.userName),
      userEmail: clearUserEmail ? null : (userEmail ?? this.userEmail),
      authMethod: clearAuthMethod ? null : (authMethod ?? this.authMethod),
      organizationId:
          clearOrganizationId ? null : (organizationId ?? this.organizationId),
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
      studentClassId:
          clearStudentClassId ? null : (studentClassId ?? this.studentClassId),
      studentTeacherId: clearStudentTeacherId
          ? null
          : (studentTeacherId ?? this.studentTeacherId),
      studentCode:
          clearStudentCode ? null : (studentCode ?? this.studentCode),
      studentClassName: clearStudentClassName
          ? null
          : (studentClassName ?? this.studentClassName),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Build an AuthState by reading persisted values from a Hive box.
  factory AuthState.fromHive(Box box) {
    return AuthState(
      isLoggedIn: box.get('isLoggedIn', defaultValue: false) as bool,
      userId: box.get('userId') as String?,
      userRole: box.get('userRole', defaultValue: '') as String,
      userName: box.get('userName') as String?,
      userEmail: box.get('userEmail') as String?,
      authMethod: box.get('authMethod') as String?,
      organizationId: box.get('organizationId') as String?,
      hasCompletedSetup:
          box.get('hasCompletedSetup', defaultValue: true) as bool,
      studentClassId: box.get('studentClassId') as String?,
      studentTeacherId: box.get('studentTeacherId') as String?,
      studentCode: box.get('studentCode') as String?,
      studentClassName: box.get('studentClassName') as String?,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════════

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Restore state from Hive on initial build
    final box = Hive.box(AppConstants.authBox);
    return AuthState.fromHive(box);
  }

  // ─── Login Methods ──────────────────────────────────────────────────────

  /// Login with email + password (Owner / Teacher / Parent).
  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.loginWithEmail(
        email: email,
        password: password,
      );
      if (result != null) {
        _applyLoginResult(result);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Login failed. Please check your credentials.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Login with Google (Owner / Teacher / Parent).
  Future<void> loginWithGoogle({String? expectedRole}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.loginWithGoogle(
        expectedRole: expectedRole,
      );
      if (result != null) {
        _applyLoginResult(result);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Google sign-in was cancelled or failed.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Login as a student using student code + password.
  Future<void> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.loginStudent(
        studentCode: studentCode,
        password: password,
      );
      if (result != null) {
        _applyStudentLoginResult(result);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Student login failed. Check your code and password.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Registration Methods ───────────────────────────────────────────────

  /// Register a new owner with email + password.
  Future<bool> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.registerOwner(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (result != null) {
        _applyLoginResult(result, authMethod: 'password');
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Registration failed.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Register a new owner via Google Sign-In.
  Future<bool> registerOwnerWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.registerOwnerWithGoogle();
      if (result != null) {
        _applyLoginResult(result, authMethod: 'google');
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Google registration was cancelled or failed.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Register a teacher with email + password + invite code.
  Future<bool> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.registerTeacher(
        email: email,
        password: password,
        fullName: fullName,
        inviteCode: inviteCode,
      );
      if (result != null) {
        _applyLoginResult(result, authMethod: 'password');
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Registration failed.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Register a parent with email + password.
  Future<bool> registerParent({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.registerParent(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (result != null) {
        _applyLoginResult(result, authMethod: 'password');
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'Registration failed.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ─── Setup & Profile ────────────────────────────────────────────────────

  /// Complete owner setup by naming the workspace.
  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.completeOwnerSetup(
        userId: userId,
        organizationId: organizationId,
        workspaceName: workspaceName,
      );
      state = state.copyWith(
        hasCompletedSetup: true,
        organizationId: organizationId,
        isLoading: false,
      );
      _persistToHive();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update profile fields (e.g., after editing in settings).
  void updateProfile({
    String? userName,
    String? userEmail,
    String? organizationId,
    bool? hasCompletedSetup,
  }) {
    state = state.copyWith(
      userName: userName,
      userEmail: userEmail,
      organizationId: organizationId,
      hasCompletedSetup: hasCompletedSetup,
    );
    _persistToHive();
  }

  // ─── Logout ─────────────────────────────────────────────────────────────

  /// Sign out the current user, clear persisted data, and reset state.
  Future<void> logout() async {
    // Fire logout event before clearing
    if (state.userId != null) {
      KlasivoEventBus.instance
          .fire(UserLoggedOutEvent(userId: state.userId!));
    }

    // Sign out from Firebase Auth + Google Sign-In
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (e) {
      debugPrint('AuthNotifier.logout: signOut error: $e');
    }

    // Reset state
    state = const AuthState();

    // Clear Hive
    _clearHive();
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPasswordReset(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ─── Private Helpers ────────────────────────────────────────────────────

  /// Apply the result from a teacher/owner/parent login to state.
  void _applyLoginResult(
    Map<String, dynamic> result, {
    String? authMethod,
  }) {
    final role = result['role'] as String? ?? '';
    final name = result['name'] as String? ?? result['fullName'] as String?;
    final email = result['email'] as String?;
    final orgId = result['organizationId'] as String?;
    final completedSetup = result['hasCompletedSetup'] as bool? ?? true;

    state = state.copyWith(
      isLoggedIn: true,
      userId: result['id'] as String? ?? result['uid'] as String?,
      userRole: role,
      userName: name,
      userEmail: email,
      authMethod: authMethod ?? result['authMethod'] as String? ?? 'password',
      organizationId: orgId,
      hasCompletedSetup: completedSetup,
      isLoading: false,
      clearError: true,
      // Clear student-specific fields
      clearStudentClassId: true,
      clearStudentTeacherId: true,
      clearStudentCode: true,
      clearStudentClassName: true,
    );
    _persistToHive();
    _fireLoginEventAndSubscribe();
  }

  /// Apply the result from a student login to state.
  void _applyStudentLoginResult(Map<String, dynamic> result) {
    state = state.copyWith(
      isLoggedIn: true,
      userId: result['id'] as String? ?? result['uid'] as String?,
      userRole: AppConstants.roleStudent,
      userName: result['name'] as String?,
      authMethod: 'student_code',
      organizationId: result['organizationId'] as String?,
      hasCompletedSetup: true,
      studentClassId: result['classId'] as String?,
      studentTeacherId: result['teacherId'] as String?,
      studentCode: result['studentCode'] as String?,
      studentClassName: result['className'] as String?,
      isLoading: false,
      clearError: true,
    );
    _persistToHive();
    _fireLoginEventAndSubscribe();
  }

  /// Fire the UserLoggedInEvent and subscribe to push notification topics.
  void _fireLoginEventAndSubscribe() {
    KlasivoEventBus.instance.fire(UserLoggedInEvent(
      userId: state.userId ?? '',
      role: state.userRole,
      orgId: state.organizationId,
    ));

    notif.NotificationService.subscribeUserToTopics(
      userId: state.userId ?? '',
      role: state.userRole,
      organizationId: state.organizationId,
      classId: state.studentClassId,
    );
  }

  /// Persist all current auth state fields to the Hive box.
  void _persistToHive() {
    final box = Hive.box(AppConstants.authBox);
    box.put('isLoggedIn', state.isLoggedIn);
    box.put('userId', state.userId);
    box.put('userRole', state.userRole);
    box.put('userName', state.userName);
    box.put('userEmail', state.userEmail);
    box.put('authMethod', state.authMethod);
    box.put('organizationId', state.organizationId);
    box.put('hasCompletedSetup', state.hasCompletedSetup);
    box.put('studentClassId', state.studentClassId);
    box.put('studentTeacherId', state.studentTeacherId);
    box.put('studentCode', state.studentCode);
    box.put('studentClassName', state.studentClassName);
  }

  /// Clear all persisted auth data from the Hive box.
  void _clearHive() {
    final box = Hive.box(AppConstants.authBox);
    box.put('isLoggedIn', false);
    box.delete('userId');
    box.delete('userRole');
    box.delete('userName');
    box.delete('userEmail');
    box.delete('authMethod');
    box.delete('organizationId');
    box.delete('hasCompletedSetup');
    box.delete('studentClassId');
    box.delete('studentTeacherId');
    box.delete('studentCode');
    box.delete('studentClassName');
  }
}
