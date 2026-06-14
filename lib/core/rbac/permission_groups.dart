// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Permission Groups
//
// Named permission templates for common role configurations.
// Used in the Permission UI (Sprint 4) to display and edit
// role defaults and custom overrides.
//
// Groups serve three purposes:
//   1. UI display — show what a role's default permissions look like
//   2. Custom groups — create non-standard roles (e.g., "Lab Assistant")
//   3. Override templates — define common override patterns
// ═══════════════════════════════════════════════════════════════════════════════

import 'permissions.dart';
import 'role_hierarchy.dart';
import 'roles.dart';

/// Predefined permission group templates for Klasivo.
///
/// Each group is a named set of permissions that can be applied to a user
/// as a baseline, with individual overrides on top.
class PermissionGroups {
  PermissionGroups._();

  // ─── Standard Role Groups ──────────────────────────────────────────────
  // These map 1:1 to the RoleResolver's effective permissions.

  /// Get the default (effective) permission set for a role.
  static Set<String> forRole(String role) {
    return RoleResolver.getEffectivePermissions(role);
  }

  /// Get the delta (unique) permission set for a role.
  static Set<String> deltaForRole(String role) {
    return RoleResolver.getDeltaPermissions(role);
  }

  // ─── Named Custom Groups ───────────────────────────────────────────────
  // Non-standard permission configurations for specialized roles.

  static const Map<String, PermissionGroup> customGroups = {
    'lab_assistant': PermissionGroup(
      name: 'Lab Assistant',
      description: 'Can manage lab materials and grade lab assignments',
      permissions: {
        Permission.orgView,
        Permission.materialView,
        Permission.materialUpload,
        Permission.materialDelete,
        Permission.assignmentView,
        Permission.assignmentGrade,
        Permission.examView,
        Permission.examGrade,
        Permission.studentView,
        Permission.attendanceMark,
        Permission.attendanceView,
        Permission.messageSend,
        Permission.messageReceive,
      },
    ),
    'exam_only_observer': PermissionGroup(
      name: 'Exam Observer',
      description: 'Can only view exams and results, nothing else',
      permissions: {
        Permission.orgView,
        Permission.examView,
        Permission.resultView,
        Permission.studentView,
      },
    ),
    'attendance_only': PermissionGroup(
      name: 'Attendance Taker',
      description: 'Can only mark and view attendance',
      permissions: {
        Permission.orgView,
        Permission.attendanceMark,
        Permission.attendanceView,
        Permission.studentView,
        Permission.classView,
      },
    ),
  };

  // ─── Override Templates ────────────────────────────────────────────────
  // Common permission override patterns that admins can apply.

  /// Standard restrictions to downgrade a teacher's capabilities.
  static const Map<String, bool> teacherNoPublish = {
    Permission.examPublish: false,
    Permission.assignmentPublish: false,
  };

  /// Standard restrictions to remove export capabilities.
  static const Map<String, bool> noExport = {
    Permission.attendanceExport: false,
    Permission.examExport: false,
    Permission.assignmentExport: false,
    Permission.studentExport: false,
    Permission.analyticsExport: false,
    Permission.reportExport: false,
    Permission.resultExport: false,
  };

  /// Standard restrictions for a teacher who should only grade (not create).
  static const Map<String, bool> gradeOnly = {
    Permission.examCreate: false,
    Permission.examEdit: false,
    Permission.examPublish: false,
    Permission.examDelete: false,
    Permission.assignmentCreate: false,
    Permission.assignmentEdit: false,
    Permission.assignmentPublish: false,
    Permission.assignmentDelete: false,
  };

  /// Get a custom group by name.
  static PermissionGroup? getCustomGroup(String name) => customGroups[name];

  /// Get all custom group names.
  static List<String> get customGroupNames => customGroups.keys.toList();

  /// Create a permission set by applying overrides to a role's defaults.
  static Set<String> applyOverrides(
    String role,
    Map<String, bool> overrides,
  ) {
    final base = forRole(role);
    final result = Set<String>.from(base);

    for (final entry in overrides.entries) {
      if (entry.value) {
        result.add(entry.key);
      } else {
        result.remove(entry.key);
      }
    }

    return result;
  }
}

/// A named permission group with metadata.
class PermissionGroup {
  final String name;
  final String description;
  final Set<String> permissions;

  const PermissionGroup({
    required this.name,
    required this.description,
    required this.permissions,
  });

  /// Check if this group includes a specific permission.
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Get permissions grouped by category.
  Map<String, Set<String>> get permissionsByCategory {
    final result = <String, Set<String>>{};
    for (final perm in permissions) {
      final category = Permission.categoryOf(perm);
      result.putIfAbsent(category, () => {}).add(perm);
    }
    return result;
  }
}
