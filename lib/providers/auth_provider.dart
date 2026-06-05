import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/services/auth_service.dart';

// ─── Auth Service Provider ───────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// ─── Firebase Auth State Stream ──────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
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

// ─── Helper: Save auth data locally ──────────────────────────────────────────

Future<void> saveAuthData({
  required String role,
  required String name,
  required String userId,
  String? classId,
  String? teacherId,
  String? studentCode,
  String? className,
}) async {
  final box = Hive.box(AppConstants.authBox);
  await box.put('userRole', role);
  await box.put('userName', name);
  await box.put('userId', userId);
  if (classId != null) await box.put('studentClassId', classId);
  if (teacherId != null) await box.put('studentTeacherId', teacherId);
  if (studentCode != null) await box.put('studentCode', studentCode);
  if (className != null) await box.put('studentClassName', className);
}

// ─── Helper: Clear auth data ─────────────────────────────────────────────────

Future<void> clearAuthData() async {
  final box = Hive.box(AppConstants.authBox);
  await box.delete('userRole');
  await box.delete('userName');
  await box.delete('userId');
  await box.delete('studentClassId');
  await box.delete('studentTeacherId');
  await box.delete('studentCode');
  await box.delete('studentClassName');
}
