// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Role Hierarchy + Role Resolver
//
// The hierarchy defines role inheritance:
//   super_admin
//    └─ owner
//         └─ admin
//              ├─ campus_manager
//              ├─ stage_manager
//              │    └─ academic_supervisor
//              │         └─ teacher
//              │              └─ assistant_teacher
//              └─ observer
//
//   student  (standalone — no inheritance)
//   parent   (standalone — no inheritance)
//
// Inheritance rule: A parent role inherits ALL permissions from every
// descendant in its subtree. Each role defines only DELTA permissions
// (unique to that role, not inherited). The RoleResolver walks the
// hierarchy tree to compute effective permissions.
//
// Example:
//   owner's effective = owner_delta + admin_effective
//   admin's effective = admin_delta + campus_manager_delta
//                         + stage_manager_effective + observer_delta
//   teacher's effective = teacher_delta + assistant_teacher_delta
// ═══════════════════════════════════════════════════════════════════════════════

import 'permissions.dart';
import 'roles.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE HIERARCHY — Tree structure
// ═══════════════════════════════════════════════════════════════════════════════

/// Defines the role inheritance tree for Klasivo.
///
/// The tree is represented as a map of parent → children.
/// A parent inherits all permissions from its descendants.
class RoleHierarchy {
  RoleHierarchy._();

  /// Parent → Children mapping.
  /// Children are listed in order of precedence (not that it matters for sets).
  static const Map<String, List<String>> tree = {
    KlasivoRole.superAdmin: [KlasivoRole.owner],
    KlasivoRole.owner: [KlasivoRole.admin],
    KlasivoRole.admin: [
      KlasivoRole.campusManager,
      KlasivoRole.stageManager,
      KlasivoRole.observer,
    ],
    KlasivoRole.campusManager: [], // Leaf in this branch
    KlasivoRole.stageManager: [KlasivoRole.academicSupervisor],
    KlasivoRole.academicSupervisor: [KlasivoRole.teacher],
    KlasivoRole.teacher: [KlasivoRole.assistantTeacher],
    KlasivoRole.assistantTeacher: [], // Leaf
    KlasivoRole.observer: [], // Leaf
    KlasivoRole.student: [], // Standalone
    KlasivoRole.parent: [], // Standalone
  };

  /// Get all descendants of a role (recursive, depth-first).
  static Set<String> getDescendants(String role) {
    final descendants = <String>{};
    final children = tree[role] ?? [];
    for (final child in children) {
      descendants.add(child);
      descendants.addAll(getDescendants(child));
    }
    return descendants;
  }

  /// Get all ancestors of a role (recursive).
  /// An ancestor is any role that has this role in its subtree.
  static Set<String> getAncestors(String role) {
    final ancestors = <String>{};
    for (final entry in tree.entries) {
      if (entry.value.contains(role)) {
        ancestors.add(entry.key);
        ancestors.addAll(getAncestors(entry.key));
      }
    }
    return ancestors;
  }

  /// Check if [role] inherits from [potentialAncestor].
  ///
  /// Returns true if [potentialAncestor] is an ancestor of [role],
  /// meaning [potentialAncestor] has all of [role]'s permissions and more.
  ///
  /// Example: `inheritsFrom('teacher', 'admin')` → true
  ///   (because admin has all of teacher's permissions via inheritance)
  static bool inheritsFrom(String role, String potentialAncestor) {
    if (role == potentialAncestor) return true;
    return getAncestors(role).contains(potentialAncestor);
  }

  /// Check if [potentialDescendant] is a descendant of [role].
  ///
  /// Example: `isDescendantOf('assistant_teacher', 'owner')` → true
  static bool isDescendantOf(String role, String potentialDescendant) {
    return getDescendants(role).contains(potentialDescendant);
  }

  /// Get the parent of a role, or null if it's a root.
  static String? getParent(String role) {
    for (final entry in tree.entries) {
      if (entry.value.contains(role)) return entry.key;
    }
    return null;
  }

  /// Get the depth of a role in the hierarchy (0 = root).
  static int depth(String role) {
    final parent = getParent(role);
    if (parent == null) return 0;
    return 1 + depth(parent);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE RESOLVER — Permission computation
// ═══════════════════════════════════════════════════════════════════════════════

/// Resolves effective permissions for a role by walking the hierarchy.
///
/// Each role defines only its DELTA permissions (unique to that role,
/// not inherited from descendants). The resolver collects delta permissions
/// from the role and ALL its descendants to compute the effective set.
///
/// Resolution algorithm:
///   effective(role) = delta(role) ∪ ∪{ effective(child) | child ∈ tree[role] }
class RoleResolver {
  RoleResolver._();

  // ─── Delta Permissions per Role ────────────────────────────────────────
  // ONLY what's unique to this role, NOT inherited from descendants.
  // A parent inherits all descendant deltas automatically.

  static const Map<String, Set<String>> _deltaPermissions = {
    // ─── assistant_teacher: Support role ──────────────────────────────────
    // Can: mark attendance, view assignments/exams, grade, message, view students
    // Cannot: create/publish/delete exams, create/publish/delete assignments,
    //         export analytics, manage roles
    KlasivoRole.assistantTeacher: {
      Permission.orgView,
      Permission.attendanceMark,
      Permission.attendanceView,
      Permission.assignmentView,
      Permission.assignmentGrade,
      Permission.examView,
      Permission.examGrade,
      Permission.messageSend,
      Permission.messageReceive,
      Permission.studentView,
    },

    // ─── teacher: Full academic authority within scope ────────────────────
    // Delta over assistant_teacher: create/publish/delete exams & assignments,
    // edit attendance, analytics, questions, classes, subjects, groups,
    // lessons, materials, reports, results, notifications
    KlasivoRole.teacher: {
      Permission.examCreate,
      Permission.examEdit,
      Permission.examPublish,
      Permission.examDelete,
      Permission.examEditOwn,
      Permission.examDeleteOwn,
      Permission.examGradeOwn,
      Permission.questionView,
      Permission.questionCreate,
      Permission.questionEdit,
      Permission.questionDelete,
      Permission.questionEditOwn,
      Permission.assignmentCreate,
      Permission.assignmentEdit,
      Permission.assignmentPublish,
      Permission.assignmentDelete,
      Permission.attendanceEdit,
      Permission.attendanceExport,
      Permission.analyticsView,
      Permission.analyticsExport,
      Permission.classView,
      Permission.classCreate,
      Permission.classEdit,
      Permission.subjectView,
      Permission.subjectCreate,
      Permission.subjectEdit,
      Permission.groupView,
      Permission.groupCreate,
      Permission.groupEdit,
      Permission.resultView,
      Permission.resultExport,
      Permission.reportView,
      Permission.reportGenerate,
      Permission.reportExport,
      Permission.notificationSend,
      Permission.notificationView,
      Permission.lessonView,
      Permission.lessonCreate,
      Permission.lessonEdit,
      Permission.lessonDelete,
      Permission.materialView,
      Permission.materialUpload,
      Permission.materialDelete,
      Permission.progressView,
      Permission.parentView,
      Permission.integrityView,
    },

    // ─── academic_supervisor: Stage-level oversight ───────────────────────
    // Delta over teacher: stage view, export capabilities, user view
    KlasivoRole.academicSupervisor: {
      Permission.stageView,
      Permission.examExport,
      Permission.assignmentExport,
      Permission.studentExport,
      Permission.userView,
    },

    // ─── stage_manager: Manage stages ────────────────────────────────────
    // Delta over academic_supervisor: stage CRUD, class/subject/group delete,
    // user create/edit, attendance delete
    KlasivoRole.stageManager: {
      Permission.stageCreate,
      Permission.stageEdit,
      Permission.stageDelete,
      Permission.classDelete,
      Permission.subjectDelete,
      Permission.groupDelete,
      Permission.userCreate,
      Permission.userEdit,
      Permission.attendanceDelete,
    },

    // ─── campus_manager: Campus-wide management ──────────────────────────
    // Sibling of stage_manager under admin. Has comprehensive campus-level
    // permissions since it doesn't inherit from the stage_manager branch.
    KlasivoRole.campusManager: {
      Permission.orgView,
      Permission.orgSettings,
      Permission.stageView,
      Permission.stageCreate,
      Permission.stageEdit,
      Permission.stageDelete,
      Permission.classView,
      Permission.classCreate,
      Permission.classEdit,
      Permission.classDelete,
      Permission.subjectView,
      Permission.subjectCreate,
      Permission.subjectEdit,
      Permission.subjectDelete,
      Permission.groupView,
      Permission.groupCreate,
      Permission.groupEdit,
      Permission.groupDelete,
      Permission.attendanceView,
      Permission.attendanceMark,
      Permission.attendanceEdit,
      Permission.attendanceDelete,
      Permission.attendanceExport,
      Permission.analyticsView,
      Permission.reportView,
      Permission.reportGenerate,
      Permission.reportExport,
      Permission.notificationView,
      Permission.notificationSend,
      Permission.notificationManage,
      Permission.feesView,
      Permission.paymentsView,
      Permission.inventoryView,
      Permission.userView,
      Permission.userCreate,
      Permission.userEdit,
      Permission.studentView,
      Permission.studentExport,
      Permission.examView,
      Permission.examExport,
      Permission.assignmentView,
      Permission.assignmentExport,
      Permission.questionView,
      Permission.resultView,
      Permission.progressView,
      Permission.lessonView,
      Permission.materialView,
    },

    // ─── observer: Read-only across organization ─────────────────────────
    // Standalone under admin (no inheritance from management branches).
    KlasivoRole.observer: {
      Permission.orgView,
      Permission.userView,
      Permission.stageView,
      Permission.classView,
      Permission.subjectView,
      Permission.groupView,
      Permission.examView,
      Permission.questionView,
      Permission.attendanceView,
      Permission.assignmentView,
      Permission.resultView,
      Permission.analyticsView,
      Permission.reportView,
      Permission.progressView,
      Permission.lessonView,
      Permission.materialView,
      Permission.studentView,
      Permission.notificationView,
      Permission.integrityView,
      Permission.feesView,
      Permission.paymentsView,
      Permission.inventoryView,
    },

    // ─── admin: Organization management ──────────────────────────────────
    // Delta over campus_manager + stage_manager + observer:
    // org settings/invite/audit, user management, billing, ERP management
    KlasivoRole.admin: {
      Permission.orgSettings,
      Permission.orgInvite,
      Permission.orgAudit,
      Permission.userManage,
      Permission.userDelete,
      Permission.userAssignRole,
      Permission.billingView,
      Permission.billingManage,
      Permission.feesManage,
      Permission.paymentsManage,
      Permission.payrollView,
      Permission.inventoryManage,
      Permission.messageBroadcast,
      Permission.examCreate,
      Permission.examEdit,
      Permission.examPublish,
      Permission.examGrade,
      Permission.examDelete,
      Permission.examGradeOwn,
      Permission.examEditOwn,
      Permission.examDeleteOwn,
      Permission.assignmentCreate,
      Permission.assignmentEdit,
      Permission.assignmentPublish,
      Permission.assignmentGrade,
      Permission.assignmentDelete,
      Permission.attendanceMark,
      Permission.attendanceEdit,
      Permission.attendanceExport,
      Permission.analyticsView,
      Permission.analyticsExport,
      Permission.notificationSend,
      Permission.parentView,
      Permission.parentLink,
      Permission.integrityView,
      Permission.integrityManage,
      Permission.questionView,
      Permission.questionCreate,
      Permission.questionEdit,
      Permission.questionDelete,
      Permission.lessonView,
      Permission.lessonCreate,
      Permission.lessonEdit,
      Permission.lessonDelete,
      Permission.materialView,
      Permission.materialUpload,
      Permission.materialDelete,
    },

    // ─── owner: Full organization control ────────────────────────────────
    // Delta over admin: org manage/delete/billing/edit, payroll manage
    KlasivoRole.owner: {
      Permission.orgManage,
      Permission.orgDelete,
      Permission.orgBilling,
      Permission.orgEdit,
      Permission.payrollManage,
    },

    // ─── super_admin: Platform level — all permissions ───────────────────
    KlasivoRole.superAdmin: {
      Permission.all,
    },

    // ─── student: Standalone — self-scoped ───────────────────────────────
    KlasivoRole.student: {
      Permission.orgView,
      Permission.classView,
      Permission.subjectView,
      Permission.examView,
      Permission.examTake,
      Permission.assignmentView,
      Permission.assignmentSubmit,
      Permission.resultViewOwn,
      Permission.progressViewOwn,
      Permission.notificationView,
      Permission.lessonView,
      Permission.materialView,
      Permission.messageSend,
      Permission.messageReceive,
    },

    // ─── parent: Standalone — linked scope ───────────────────────────────
    KlasivoRole.parent: {
      Permission.orgView,
      Permission.resultViewOwn,
      Permission.progressViewOwn,
      Permission.parentViewOwnChildren,
      Permission.parentViewOwnChildrenProgress,
      Permission.notificationView,
      Permission.attendanceView,
      Permission.messageSend,
      Permission.messageReceive,
    },
  };

  /// Cached effective permissions per role.
  static final Map<String, Set<String>> _effectiveCache = {};

  /// Get effective permissions for a role (own delta + inherited from descendants).
  ///
  /// The result is cached for performance.
  static Set<String> getEffectivePermissions(String role) {
    if (_effectiveCache.containsKey(role)) {
      return Set.unmodifiable(_effectiveCache[role]!);
    }

    final effective = <String>{};

    // Add this role's delta permissions
    final delta = _deltaPermissions[role];
    if (delta != null) {
      effective.addAll(delta);
    }

    // Add all descendants' delta permissions (inherited)
    final descendants = RoleHierarchy.getDescendants(role);
    for (final descendant in descendants) {
      final descendantDelta = _deltaPermissions[descendant];
      if (descendantDelta != null) {
        effective.addAll(descendantDelta);
      }
    }

    _effectiveCache[role] = Set.unmodifiable(effective);
    return Set.unmodifiable(effective);
  }

  /// Get delta (unique) permissions for a role — NOT including inherited.
  static Set<String> getDeltaPermissions(String role) {
    final delta = _deltaPermissions[role];
    if (delta == null) return const {};
    return Set.unmodifiable(delta);
  }

  /// Check if a role has a specific permission (including inherited).
  ///
  /// Supports three matching modes:
  /// 1. Wildcard: '*' matches everything
  /// 2. Category wildcard: 'exam:*' matches 'exam:create', 'exam:edit', etc.
  /// 3. Exact match: 'exam:create' matches 'exam:create'
  static bool roleHasPermission(String role, String permission) {
    final effective = getEffectivePermissions(role);

    // Wildcard check
    if (effective.contains(Permission.all)) return true;

    // Exact match
    if (effective.contains(permission)) return true;

    // Category wildcard (e.g., 'exam:*' matches 'exam:create')
    final category = Permission.categoryOf(permission);
    if (effective.contains(Permission.wildcardFor(category))) return true;

    return false;
  }

  /// Check if a role has ALL of the given permissions.
  static bool roleHasAllPermissions(String role, List<String> permissions) {
    return permissions.every((p) => roleHasPermission(role, p));
  }

  /// Check if a role has ANY of the given permissions.
  static bool roleHasAnyPermission(String role, List<String> permissions) {
    return permissions.any((p) => roleHasPermission(role, p));
  }

  /// Clear the effective permissions cache.
  /// Useful for testing or when delta permissions are updated dynamically.
  static void clearCache() {
    _effectiveCache.clear();
  }

  /// Get all role names that have a specific permission.
  static Set<String> rolesWithPermission(String permission) {
    return KlasivoRole.allRoles
        .where((role) => roleHasPermission(role, permission))
        .toSet();
  }
}
