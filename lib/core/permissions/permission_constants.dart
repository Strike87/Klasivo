/// Klasivo v2.0 - Permission constants
///
/// Extracted from permission_service.dart and permission_engine.dart.
/// Defines the [Permission] class and all permission IDs as constants
/// for type-safe permission checking throughout the app.
library;

import 'role_definitions.dart';

/// A single permission definition in the Klasivo platform.
///
/// Each permission has a unique [id] (dot-separated, e.g. `exam.create`),
/// a [displayName] for the UI, the [module] it belongs to, a [description],
/// and a map of [defaultGrants] that specifies which roles are granted
/// this permission by default.
class Permission {
  /// Unique dot-separated identifier (e.g., 'exam.create').
  final String id;

  /// Human-readable name for UI display.
  final String displayName;

  /// Module this permission belongs to (e.g., 'exams', 'attendance').
  final String module;

  /// Description of what this permission allows.
  final String description;

  /// Default grant map: which roles get this permission by default.
  final Map<KlasivoRole, bool> defaultGrants;

  const Permission({
    required this.id,
    required this.displayName,
    required this.module,
    required this.description,
    required this.defaultGrants,
  });

  /// Whether this permission is granted to [role] by default.
  ///
  /// Returns `false` if the role is not in the [defaultGrants] map.
  bool isGrantedByDefault(KlasivoRole role) => defaultGrants[role] ?? false;

  /// Whether this permission belongs to a given [moduleId].
  bool isInModule(String moduleId) => module == moduleId;
}

// ─── Permission ID Constants ────────────────────────────────────────────────
//
// These constants provide compile-time safety for permission checks.
// Use them instead of raw strings: PermissionIds.examCreate vs 'exam.create'.

class PermissionIds {
  PermissionIds._();

  // ─── Exam Module ─────────────────────────────────────────────────────
  static const String examCreate = 'exam.create';
  static const String examPublish = 'exam.publish';
  static const String examDelete = 'exam.delete';
  static const String examGrade = 'exam.grade';
  static const String examViewResults = 'exam.view_results';

  // ─── Attendance Module ───────────────────────────────────────────────
  static const String attendanceCreate = 'attendance.create';
  static const String attendanceView = 'attendance.view';

  // ─── Assignment Module ───────────────────────────────────────────────
  static const String assignmentCreate = 'assignment.create';
  static const String assignmentGrade = 'assignment.grade';

  // ─── Messaging Module ────────────────────────────────────────────────
  static const String messagingSend = 'messaging.send';

  // ─── LMS Module ──────────────────────────────────────────────────────
  static const String lmsManage = 'lms.manage';
  static const String lmsView = 'lms.view';

  // ─── User Management ─────────────────────────────────────────────────
  static const String userManage = 'user.manage';

  // ─── Organization Management ─────────────────────────────────────────
  static const String orgManage = 'org.manage';

  // ─── Analytics ───────────────────────────────────────────────────────
  static const String analyticsView = 'analytics.view';

  // ─── Feature Flags ───────────────────────────────────────────────────
  static const String featureFlagsManage = 'feature_flags.manage';

  // ─── Finance (future) ────────────────────────────────────────────────
  static const String financeManage = 'finance.manage';

  // ─── Transport (future) ──────────────────────────────────────────────
  static const String transportManage = 'transport.manage';
}

// ─── Module ID Constants ────────────────────────────────────────────────────

class ModuleIds {
  ModuleIds._();

  static const String exams = 'exams';
  static const String attendance = 'attendance';
  static const String assignments = 'assignments';
  static const String messaging = 'messaging';
  static const String lms = 'lms';
  static const String users = 'users';
  static const String organization = 'organization';
  static const String analytics = 'analytics';
  static const String featureFlags = 'feature_flags';
  static const String finance = 'finance';
  static const String transport = 'transport';
}
