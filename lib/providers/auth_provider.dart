import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../core/config/app_constants.dart';
import '../core/services/auth_service.dart';
import '../core/services/sentry_service.dart';
import '../core/services/event_bus.dart';
import '../core/services/notification_service.dart';

// ─── Auth Service Provider ───────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ─── Firebase Auth State Stream (with error handling) ────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges().handleError((error) {
    // Handle PigeonUserDetails and other stream errors gracefully
  });
});

// ─── Current User ID Provider ────────────────────────────────────────────────

final currentUserIdProvider = Provider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userId') as String?;
});

// ─── Is Logged In Provider (persisted with Hive) ─────────────────────────────
// This is the SINGLE SOURCE OF TRUTH for whether a user is logged in.

final isLoggedInProvider = StateProvider<bool>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('isLoggedIn', defaultValue: false) as bool;
});

// ─── User Role Provider (persisted with Hive) ────────────────────────────────

final userRoleProvider = StateProvider<String>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userRole', defaultValue: '') as String;
});

// ─── User Name Provider (persisted with Hive) ────────────────────────────────

final userNameProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userName') as String?;
});

// ─── User ID Provider (persisted with Hive) ──────────────────────────────────

final userIdProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userId') as String?;
});

// ─── Auth Provider Type (persisted with Hive) ────────────────────────────────
// Tracks how the user authenticated: 'password', 'google', or 'student_code'

final authMethodProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('authMethod') as String?;
});

// ─── Organization ID Provider (persisted with Hive) ──────────────────────────

final organizationIdProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('organizationId') as String?;
});

// ─── Has Completed Setup Provider ────────────────────────────────────────────

final hasCompletedSetupProvider = StateProvider<bool>((ref) {
  final box = Hive.box(AppConstants.authBox);
  // Default must be false — if Hive hasn't been written yet (cold start before
  // registration completes), assuming true would redirect owners past /welcome
  // to a broken dashboard with no organization data.
  return box.get('hasCompletedSetup', defaultValue: false) as bool;
});

// ─── Student Class ID Provider (persisted with Hive) ─────────────────────────

final studentClassIdProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('studentClassId') as String?;
});

// ─── Student Teacher ID Provider (persisted with Hive) ───────────────────────

final studentTeacherIdProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('studentTeacherId') as String?;
});

// ─── Student Code Provider (persisted with Hive) ─────────────────────────────

final studentCodeProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('studentCode') as String?;
});

// ─── Student Class Name Provider (persisted with Hive) ────────────────────────

final studentClassNameProvider = StateProvider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('studentClassName') as String?;
});

// ─── Auth Loading Provider ───────────────────────────────────────────────────

final authLoadingProvider = StateProvider<bool>((ref) => false);

// ─── Auth Error Provider ─────────────────────────────────────────────────────

final authErrorProvider = StateProvider<String?>((ref) => null);

// ─── Helper: Save auth data locally (for OWNER / TEACHER / PARENT login) ────

Future<void> saveTeacherAuthData({
  required String role,
  required String name,
  required String userId,
  required String email,
  String? organizationId,
  bool hasCompletedSetup = true,
  String authProvider = 'password',
  WidgetRef? ref,
}) async {
  KlasivoSentry.breadcrumb.hive('save_auth_data_start', data: {
    'role': role,
    'userId': userId,
    'authProvider': authProvider,
  });

  // Set Crashlytics custom keys for forensic crash analysis
  await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'SAVE_AUTH_DATA_START');
  await FirebaseCrashlytics.instance.setCustomKey('uid', userId);
  await FirebaseCrashlytics.instance.setCustomKey('userRole', role);
  await FirebaseCrashlytics.instance.setCustomKey('authProvider', authProvider);
  if (organizationId != null) {
    await FirebaseCrashlytics.instance.setCustomKey('orgId', organizationId);
  }

  final box = Hive.box(AppConstants.authBox);
  await box.put('isLoggedIn', true);
  await box.put('userRole', role);
  await box.put('userName', name);
  await box.put('userId', userId);
  await box.put('userEmail', email);
  await box.put('authMethod', authProvider);
  if (organizationId != null) {
    await box.put('organizationId', organizationId);
  }
  await box.put('hasCompletedSetup', hasCompletedSetup);

  // Update Riverpod StateProviders so they reflect the new data immediately
  if (ref != null) {
    ref.read(isLoggedInProvider.notifier).state = true;
    ref.read(userRoleProvider.notifier).state = role;
    ref.read(userNameProvider.notifier).state = name;
    ref.read(userIdProvider.notifier).state = userId;
    ref.read(authMethodProvider.notifier).state = authProvider;
    if (organizationId != null) {
      ref.read(organizationIdProvider.notifier).state = organizationId;
    }
    ref.read(hasCompletedSetupProvider.notifier).state = hasCompletedSetup;
  }

  // Fire login event
  KlasivoEventBus.instance.fire(UserLoggedInEvent(
    userId: userId,
    role: role,
    orgId: organizationId,
  ));

  // Subscribe to FCM topics for push notifications
  NotificationService.subscribeUserToTopics(
    userId: userId,
    role: role,
    organizationId: organizationId,
  );

  KlasivoSentry.breadcrumb.hive('save_auth_data_success', data: {
    'role': role,
    'userId': userId,
  });
}

// ─── Helper: Save auth data locally (for STUDENT login) ──────────────────────

Future<void> saveStudentAuthData({
  required String name,
  required String userId,
  String? classId,
  String? teacherId,
  String? studentCode,
  String? className,
  String? organizationId,
  WidgetRef? ref,
}) async {
  KlasivoSentry.breadcrumb.hive('save_student_auth_data_start', data: {
    'userId': userId,
    'role': 'student',
  });

  final box = Hive.box(AppConstants.authBox);
  await box.put('isLoggedIn', true);
  await box.put('userRole', AppConstants.roleStudent);
  await box.put('userName', name);
  await box.put('userId', userId);
  if (classId != null) await box.put('studentClassId', classId);
  if (teacherId != null) await box.put('studentTeacherId', teacherId);
  if (studentCode != null) await box.put('studentCode', studentCode);
  if (className != null) await box.put('studentClassName', className);
  if (organizationId != null) await box.put('organizationId', organizationId);
  await box.put('authMethod', 'student_code');
  await box.put('hasCompletedSetup', true);

  // Update Riverpod StateProviders so they reflect the new data immediately
  if (ref != null) {
    ref.read(isLoggedInProvider.notifier).state = true;
    ref.read(userRoleProvider.notifier).state = AppConstants.roleStudent;
    ref.read(userNameProvider.notifier).state = name;
    ref.read(userIdProvider.notifier).state = userId;
    ref.read(authMethodProvider.notifier).state = 'student_code';
    if (classId != null) ref.read(studentClassIdProvider.notifier).state = classId;
    if (teacherId != null) ref.read(studentTeacherIdProvider.notifier).state = teacherId;
    if (studentCode != null) ref.read(studentCodeProvider.notifier).state = studentCode;
    if (className != null) ref.read(studentClassNameProvider.notifier).state = className;
    if (organizationId != null) ref.read(organizationIdProvider.notifier).state = organizationId;
    ref.read(hasCompletedSetupProvider.notifier).state = true;
  }

  // Fire login event
  KlasivoEventBus.instance.fire(UserLoggedInEvent(
    userId: userId,
    role: AppConstants.roleStudent,
    orgId: organizationId,
  ));

  // Subscribe to FCM topics for push notifications
  NotificationService.subscribeUserToTopics(
    userId: userId,
    role: AppConstants.roleStudent,
    organizationId: organizationId,
    classId: classId,
  );

  KlasivoSentry.breadcrumb.hive('save_student_auth_data_success', data: {
    'userId': userId,
    'role': 'student',
  });
}

// ─── Helper: Save auth data locally (for PARENT login) ───────────────────────

Future<void> saveParentAuthData({
  required String name,
  required String userId,
  required String email,
  String? organizationId,
  bool hasCompletedSetup = true,
  String authProvider = 'password',
  WidgetRef? ref,
}) async {
  final box = Hive.box(AppConstants.authBox);
  await box.put('isLoggedIn', true);
  await box.put('userRole', AppConstants.roleParent);
  await box.put('userName', name);
  await box.put('userId', userId);
  await box.put('userEmail', email);
  await box.put('authMethod', authProvider);
  if (organizationId != null) {
    await box.put('organizationId', organizationId);
  }
  await box.put('hasCompletedSetup', hasCompletedSetup);

  // Update Riverpod StateProviders so they reflect the new data immediately
  if (ref != null) {
    ref.read(isLoggedInProvider.notifier).state = true;
    ref.read(userRoleProvider.notifier).state = AppConstants.roleParent;
    ref.read(userNameProvider.notifier).state = name;
    ref.read(userIdProvider.notifier).state = userId;
    ref.read(authMethodProvider.notifier).state = authProvider;
    if (organizationId != null) {
      ref.read(organizationIdProvider.notifier).state = organizationId;
    }
    ref.read(hasCompletedSetupProvider.notifier).state = hasCompletedSetup;
  }

  // Fire login event
  KlasivoEventBus.instance.fire(UserLoggedInEvent(
    userId: userId,
    role: AppConstants.roleParent,
    orgId: organizationId,
  ));
}

// ─── Helper: Clear auth data ─────────────────────────────────────────────────

Future<void> clearAuthData() async {
  final box = Hive.box(AppConstants.authBox);

  // Fire logout event before clearing data
  final userId = box.get('userId') as String?;
  KlasivoSentry.breadcrumb.auth('clear_auth_data_start', data: {
    'userId': userId ?? 'null',
  });

  if (userId != null) {
    KlasivoEventBus.instance.fire(UserLoggedOutEvent(userId: userId));
  }

  await box.put('isLoggedIn', false);
  await box.delete('userRole');
  await box.delete('userName');
  await box.delete('userId');
  await box.delete('studentClassId');
  await box.delete('studentTeacherId');
  await box.delete('studentCode');
  await box.delete('studentClassName');
  await box.delete('userEmail');
  await box.delete('authMethod');
  await box.delete('organizationId');
  await box.delete('hasCompletedSetup');

  // Also sign out Firebase Auth + Google Sign-In
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}

  // Clear Sentry user context
  await KlasivoSentry.userContext.clearUser();

  KlasivoSentry.breadcrumb.auth('clear_auth_data_success');
}
