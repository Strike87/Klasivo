import 'roles.dart';

/// A single permission definition in the Klasivo platform.
///
/// Each permission has a unique [id] (dot-separated, e.g. `exam.create`),
/// a [displayName] for the UI, the [module] it belongs to, a [description],
/// and a map of [defaultGrants] that specifies which roles are granted
/// this permission by default.
class Permission {
  final String id;
  final String displayName;
  final String module;
  final String description;
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
}

/// The central permission engine for the Klasivo platform.
///
/// Defines all permissions organized by module and provides static methods
/// to query permissions by role, module, or individual permission ID.
///
/// ## Hierarchical Role Inheritance
///
/// Roles are organized in a hierarchy from highest to lowest privilege.
/// The [isSeniorRole] method determines hierarchy position, and
/// [getAllPermissions] returns permissions with inherited grants.
///
/// Inheritance rules:
///   - **academicManager** inherits all `teacher` permissions +
///     stage/class management
///   - **stageSupervisor** inherits all `teacher` permissions +
///     stage-level management
///   - **assistantTeacher** gets a subset of `teacher` permissions
///     (no publish, no delete)
///
/// This engine works in concert with the existing [PermissionService] which
/// handles Firestore overrides (explicit allow/deny). The evaluation order is:
///   1. Check explicit deny (Firestore override)
///   2. Check explicit allow (Firestore override)
///   3. Check default grants from this engine (including inheritance)
///   4. Deny by default
class PermissionEngine {
  // Private constructor — this class is not meant to be instantiated.
  PermissionEngine._();

  // ═══════════════════════════════════════════════════════════════════════════
  // ROLE HIERARCHY
  // ═══════════════════════════════════════════════════════════════════════════

  /// The role hierarchy, ordered from highest to lowest privilege.
  ///
  /// A role at a lower index is "senior" to one at a higher index.
  /// This is used for permission inheritance — senior roles implicitly
  /// gain the permissions of junior roles below them in the hierarchy.
  ///
  /// Note: [observer] and [student]/[parent] are NOT in the inheritance
  /// chain for teaching/management roles. They have their own scoped
  /// permissions.
  static const List<KlasivoRole> roleHierarchy = [
    KlasivoRole.superAdmin,
    KlasivoRole.tenantOwner,
    KlasivoRole.owner,
    KlasivoRole.admin,
    KlasivoRole.academicManager,
    KlasivoRole.campusManager,
    KlasivoRole.stageSupervisor,
    KlasivoRole.teacher,
    KlasivoRole.assistantTeacher,
    KlasivoRole.student,
    KlasivoRole.parent,
    KlasivoRole.observer,
  ];

  /// Check if [roleA] is senior to [roleB] (for permission inheritance).
  ///
  /// Returns `true` if [roleA] appears before [roleB] in [roleHierarchy],
  /// meaning [roleA] has higher or equal privilege.
  ///
  /// Example:
  /// ```dart
  /// isSeniorRole(KlasivoRole.admin, KlasivoRole.teacher) // true
  /// isSeniorRole(KlasivoRole.teacher, KlasivoRole.admin) // false
  /// isSeniorRole(KlasivoRole.admin, KlasivoRole.admin)   // true (equal)
  /// ```
  static bool isSeniorRole(KlasivoRole roleA, KlasivoRole roleB) {
    final indexA = roleHierarchy.indexOf(roleA);
    final indexB = roleHierarchy.indexOf(roleB);
    if (indexA == -1 || indexB == -1) return false;
    return indexA <= indexB;
  }

  /// Check if [roleA] is strictly senior to [roleB] (not equal).
  static bool isStrictlySeniorRole(KlasivoRole roleA, KlasivoRole roleB) {
    final indexA = roleHierarchy.indexOf(roleA);
    final indexB = roleHierarchy.indexOf(roleB);
    if (indexA == -1 || indexB == -1) return false;
    return indexA < indexB;
  }

  /// Get the direct permissions for a role (without inheritance).
  ///
  /// These are only the permissions explicitly granted in [allPermissions].
  static List<String> getDirectPermissions(KlasivoRole role) {
    return allPermissions
        .where((p) => p.isGrantedByDefault(role))
        .map((p) => p.id)
        .toList();
  }

  /// Get all permissions for a role, including inherited ones.
  ///
  /// Inheritance rules:
  ///   - **academicManager** inherits all `teacher` permissions +
  ///     stage/class management permissions
  ///   - **stageSupervisor** inherits all `teacher` permissions +
  ///     stage-level permissions
  ///   - **assistantTeacher** inherits a subset of `teacher` permissions
  ///     (excludes publish, delete, and create actions)
  ///
  /// For roles above `teacher` in the hierarchy, all direct permissions
  /// are returned (they already have more permissions than teachers).
  static List<String> getAllPermissions(KlasivoRole role) {
    final directPermissions = getDirectPermissions(role).toSet();

    // ── Inheritance for academic_manager ─────────────────────────────────
    // Inherits teacher permissions + gets stage/class management
    if (role == KlasivoRole.academicManager) {
      directPermissions.addAll(getDirectPermissions(KlasivoRole.teacher));
      // Academic manager gets additional management permissions
      directPermissions.addAll([
        'stage.manage',
        'stage.view',
        'class.manage',
        'class.view',
        'subject.manage',
        'subject.view',
        'academic.manage',
        'academic.view',
        'curriculum.manage',
      ]);
    }

    // ── Inheritance for stage_supervisor ─────────────────────────────────
    // Inherits teacher permissions + gets stage-level permissions
    if (role == KlasivoRole.stageSupervisor) {
      directPermissions.addAll(getDirectPermissions(KlasivoRole.teacher));
      // Stage supervisor gets stage-level management permissions
      directPermissions.addAll([
        'stage.manage',
        'stage.view',
        'class.view',
        'class.manage_grades',
        'subject.view',
        'academic.view',
      ]);
    }

    // ── Inheritance for assistant_teacher ────────────────────────────────
    // Subset of teacher permissions — NO publish, NO delete, NO create
    if (role == KlasivoRole.assistantTeacher) {
      // Remove dangerous permissions that assistant teachers should NOT have
      directPermissions.remove('exam.create');
      directPermissions.remove('exam.publish');
      directPermissions.remove('exam.delete');
      directPermissions.remove('exam.edit');
      directPermissions.remove('assignment.create');
      directPermissions.remove('assignment.delete');
      directPermissions.remove('assignment.edit');
      directPermissions.remove('lms.manage');
      directPermissions.remove('question.create');
      directPermissions.remove('question.delete');
      directPermissions.remove('material.upload');
      directPermissions.remove('material.delete');
      directPermissions.remove('lesson.create');
      directPermissions.remove('lesson.delete');
    }

    // ── Inheritance for campus_manager ──────────────────────────────────
    // Inherits teacher + academic_manager scoped to their campus
    if (role == KlasivoRole.campusManager) {
      directPermissions.addAll(getDirectPermissions(KlasivoRole.teacher));
      directPermissions.addAll([
        'stage.manage',
        'stage.view',
        'class.manage',
        'class.view',
        'subject.manage',
        'subject.view',
        'academic.view',
        'campus.manage',
        'campus.view',
      ]);
    }

    return directPermissions.toList()..sort();
  }

  /// Get all permissions for a role using the string ID (from Firestore).
  ///
  /// Returns an empty list if the role ID is not recognized.
  static List<String> getAllPermissionsByRoleId(String roleId) {
    final role = KlasivoRole.fromId(roleId);
    if (role == null) return [];
    return getAllPermissions(role);
  }

  /// Check if a role has a specific permission, considering inheritance.
  ///
  /// This is the enhanced version that considers the full permission set
  /// including inherited permissions.
  static bool hasPermissionWithInheritance(
    KlasivoRole role,
    String permissionId,
  ) {
    return getAllPermissions(role).contains(permissionId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALL DEFINED PERMISSIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<Permission> allPermissions = [
    // ─── Exam Module ─────────────────────────────────────────────────────
    Permission(
      id: 'exam.create',
      displayName: 'Create Exam',
      module: 'exams',
      description: 'Create new exams and question papers',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'exam.edit',
      displayName: 'Edit Exam',
      module: 'exams',
      description: 'Edit existing exams and their settings',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'exam.publish',
      displayName: 'Publish Exam',
      module: 'exams',
      description: 'Publish exams for students to take',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'exam.delete',
      displayName: 'Delete Exam',
      module: 'exams',
      description: 'Permanently delete exams',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'exam.grade',
      displayName: 'Grade Exam',
      module: 'exams',
      description: 'Grade student submissions',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
      },
    ),
    Permission(
      id: 'exam.view',
      displayName: 'View Exams',
      module: 'exams',
      description: 'View exam listings and details',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.observer: true,
      },
    ),
    Permission(
      id: 'exam.view_results',
      displayName: 'View Exam Results',
      module: 'exams',
      description: 'View exam results and analytics',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.parent: true,
      },
    ),
    Permission(
      id: 'exam.take',
      displayName: 'Take Exam',
      module: 'exams',
      description: 'Take an exam as a student',
      defaultGrants: {
        KlasivoRole.student: true,
      },
    ),

    // ─── Attendance Module ───────────────────────────────────────────────
    Permission(
      id: 'attendance.create',
      displayName: 'Take Attendance',
      module: 'attendance',
      description: 'Record student attendance',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
      },
    ),
    Permission(
      id: 'attendance.view',
      displayName: 'View Attendance',
      module: 'attendance',
      description: 'View attendance records',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),
    Permission(
      id: 'attendance.export',
      displayName: 'Export Attendance',
      module: 'attendance',
      description: 'Export attendance data to CSV/PDF',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
      },
    ),

    // ─── Assignment Module ───────────────────────────────────────────────
    Permission(
      id: 'assignment.create',
      displayName: 'Create Assignment',
      module: 'assignments',
      description: 'Create and assign work to students',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'assignment.edit',
      displayName: 'Edit Assignment',
      module: 'assignments',
      description: 'Edit existing assignments',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'assignment.delete',
      displayName: 'Delete Assignment',
      module: 'assignments',
      description: 'Permanently delete assignments',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'assignment.grade',
      displayName: 'Grade Assignment',
      module: 'assignments',
      description: 'Grade student assignment submissions',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
      },
    ),
    Permission(
      id: 'assignment.view',
      displayName: 'View Assignments',
      module: 'assignments',
      description: 'View assignment listings and details',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),
    Permission(
      id: 'assignment.submit',
      displayName: 'Submit Assignment',
      module: 'assignments',
      description: 'Submit assignment work as a student',
      defaultGrants: {
        KlasivoRole.student: true,
      },
    ),

    // ─── Messaging Module ────────────────────────────────────────────────
    Permission(
      id: 'messaging.send',
      displayName: 'Send Messages',
      module: 'messaging',
      description: 'Send messages to other users',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
      },
    ),
    Permission(
      id: 'messaging.manage',
      displayName: 'Manage Messaging',
      module: 'messaging',
      description: 'Manage conversations and moderation',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),

    // ─── LMS Module ──────────────────────────────────────────────────────
    Permission(
      id: 'lms.manage',
      displayName: 'Manage LMS Content',
      module: 'lms',
      description: 'Create and manage LMS materials and lessons',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'lms.view',
      displayName: 'View LMS Content',
      module: 'lms',
      description: 'Access LMS materials and lessons',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Question Bank ──────────────────────────────────────────────────
    Permission(
      id: 'question.create',
      displayName: 'Create Questions',
      module: 'questions',
      description: 'Create questions for question banks',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'question.edit',
      displayName: 'Edit Questions',
      module: 'questions',
      description: 'Edit existing questions',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'question.delete',
      displayName: 'Delete Questions',
      module: 'questions',
      description: 'Permanently delete questions',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'question.view',
      displayName: 'View Questions',
      module: 'questions',
      description: 'View questions in question banks',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Stage Management ────────────────────────────────────────────────
    Permission(
      id: 'stage.manage',
      displayName: 'Manage Stages',
      module: 'stages',
      description: 'Create, edit, and manage academic stages/levels',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),
    Permission(
      id: 'stage.view',
      displayName: 'View Stages',
      module: 'stages',
      description: 'View academic stages and their structure',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Class Management ────────────────────────────────────────────────
    Permission(
      id: 'class.manage',
      displayName: 'Manage Classes',
      module: 'classes',
      description: 'Create, edit, and manage class sections',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),
    Permission(
      id: 'class.view',
      displayName: 'View Classes',
      module: 'classes',
      description: 'View class sections and their details',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.observer: true,
      },
    ),
    Permission(
      id: 'class.manage_grades',
      displayName: 'Manage Grades',
      module: 'classes',
      description: 'Enter and edit student grades within a class',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
      },
    ),

    // ─── Subject Management ──────────────────────────────────────────────
    Permission(
      id: 'subject.manage',
      displayName: 'Manage Subjects',
      module: 'subjects',
      description: 'Create, edit, and manage subjects',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),
    Permission(
      id: 'subject.view',
      displayName: 'View Subjects',
      module: 'subjects',
      description: 'View subject listings and details',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Academic Management ─────────────────────────────────────────────
    Permission(
      id: 'academic.manage',
      displayName: 'Manage Academics',
      module: 'academic',
      description: 'Manage academic programs, curricula, and schedules',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),
    Permission(
      id: 'academic.view',
      displayName: 'View Academics',
      module: 'academic',
      description: 'View academic programs and curricula',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.observer: true,
      },
    ),
    Permission(
      id: 'curriculum.manage',
      displayName: 'Manage Curriculum',
      module: 'academic',
      description: 'Create and edit curriculum frameworks',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),

    // ─── Campus Management ───────────────────────────────────────────────
    Permission(
      id: 'campus.manage',
      displayName: 'Manage Campus',
      module: 'campus',
      description: 'Manage campus settings, staff, and resources',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.campusManager: true,
      },
    ),
    Permission(
      id: 'campus.view',
      displayName: 'View Campus',
      module: 'campus',
      description: 'View campus information and structure',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── User Management ─────────────────────────────────────────────────
    Permission(
      id: 'user.manage',
      displayName: 'Manage Users',
      module: 'users',
      description: 'Create, edit, and deactivate user accounts',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'user.view',
      displayName: 'View Users',
      module: 'users',
      description: 'View user profiles and directory',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Organization Management ─────────────────────────────────────────
    Permission(
      id: 'org.manage',
      displayName: 'Manage Organization',
      module: 'organization',
      description: 'Edit organization settings and configuration',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
      },
    ),
    Permission(
      id: 'org.view',
      displayName: 'View Organization',
      module: 'organization',
      description: 'View organization details',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Tenant Management ───────────────────────────────────────────────
    Permission(
      id: 'tenant.manage',
      displayName: 'Manage Tenant',
      module: 'tenant',
      description: 'Manage tenant-wide settings, plans, and organizations',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
      },
    ),
    Permission(
      id: 'tenant.view',
      displayName: 'View Tenant',
      module: 'tenant',
      description: 'View tenant information and statistics',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
      },
    ),

    // ─── Analytics ───────────────────────────────────────────────────────
    Permission(
      id: 'analytics.view',
      displayName: 'View Analytics',
      module: 'analytics',
      description: 'View organization-wide analytics and reports',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'analytics.export',
      displayName: 'Export Analytics',
      module: 'analytics',
      description: 'Export analytics data to CSV/PDF',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),

    // ─── Reports ─────────────────────────────────────────────────────────
    Permission(
      id: 'report.generate',
      displayName: 'Generate Reports',
      module: 'reports',
      description: 'Generate academic and administrative reports',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'report.view',
      displayName: 'View Reports',
      module: 'reports',
      description: 'View generated reports',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),
    Permission(
      id: 'report.export',
      displayName: 'Export Reports',
      module: 'reports',
      description: 'Export reports to PDF/Excel',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
      },
    ),

    // ─── Feature Flags ───────────────────────────────────────────────────
    Permission(
      id: 'feature_flags.manage',
      displayName: 'Manage Feature Flags',
      module: 'feature_flags',
      description: 'Enable/disable feature modules for the organization',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
      },
    ),

    // ─── Integrity / Violations ──────────────────────────────────────────
    Permission(
      id: 'integrity.view',
      displayName: 'View Integrity Violations',
      module: 'integrity',
      description: 'View exam integrity violation reports',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'integrity.manage',
      displayName: 'Manage Integrity',
      module: 'integrity',
      description: 'Configure integrity settings and manage violations',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),

    // ─── Finance ─────────────────────────────────────────────────────────
    Permission(
      id: 'finance.manage',
      displayName: 'Manage Finance',
      module: 'finance',
      description: 'Access financial records and billing',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'finance.view',
      displayName: 'View Finance',
      module: 'finance',
      description: 'View financial reports and summaries',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.campusManager: true,
      },
    ),

    // ─── Transport ───────────────────────────────────────────────────────
    Permission(
      id: 'transport.manage',
      displayName: 'Manage Transport',
      module: 'transport',
      description: 'Manage transportation routes and tracking',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),

    // ─── Material / Resource Management ──────────────────────────────────
    Permission(
      id: 'material.upload',
      displayName: 'Upload Materials',
      module: 'materials',
      description: 'Upload educational materials and resources',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'material.delete',
      displayName: 'Delete Materials',
      module: 'materials',
      description: 'Permanently delete uploaded materials',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'material.view',
      displayName: 'View Materials',
      module: 'materials',
      description: 'View and download educational materials',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Lesson Management ───────────────────────────────────────────────
    Permission(
      id: 'lesson.create',
      displayName: 'Create Lessons',
      module: 'lessons',
      description: 'Create new lessons within the LMS',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'lesson.delete',
      displayName: 'Delete Lessons',
      module: 'lessons',
      description: 'Permanently delete lessons',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'lesson.view',
      displayName: 'View Lessons',
      module: 'lessons',
      description: 'View lesson content and structure',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),

    // ─── Progress Tracking ───────────────────────────────────────────────
    Permission(
      id: 'progress.view',
      displayName: 'View Progress',
      module: 'progress',
      description: 'View student progress and learning analytics',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.parent: true,
      },
    ),
    Permission(
      id: 'progress.view_own',
      displayName: 'View Own Progress',
      module: 'progress',
      description: 'View own learning progress and analytics',
      defaultGrants: {
        KlasivoRole.student: true,
      },
    ),

    // ─── Parent Portal ───────────────────────────────────────────────────
    Permission(
      id: 'parent.link',
      displayName: 'Link Parent',
      module: 'parent',
      description: 'Link a parent account to a student',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'parent.view_children',
      displayName: 'View Children',
      module: 'parent',
      description: 'View linked children data',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.parent: true,
      },
    ),

    // ─── Notifications ───────────────────────────────────────────────────
    Permission(
      id: 'notification.send',
      displayName: 'Send Notifications',
      module: 'notifications',
      description: 'Send notifications to users',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
      },
    ),
    Permission(
      id: 'notification.manage',
      displayName: 'Manage Notifications',
      module: 'notifications',
      description: 'Configure notification settings and templates',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
      },
    ),
    Permission(
      id: 'notification.view',
      displayName: 'View Notifications',
      module: 'notifications',
      description: 'View received notifications',
      defaultGrants: {
        KlasivoRole.superAdmin: true,
        KlasivoRole.tenantOwner: true,
        KlasivoRole.owner: true,
        KlasivoRole.admin: true,
        KlasivoRole.academicManager: true,
        KlasivoRole.campusManager: true,
        KlasivoRole.stageSupervisor: true,
        KlasivoRole.teacher: true,
        KlasivoRole.assistantTeacher: true,
        KlasivoRole.student: true,
        KlasivoRole.parent: true,
        KlasivoRole.observer: true,
      },
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // QUERY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if a role has a specific permission by default.
  ///
  /// Throws [ArgumentError] if [permissionId] is not a known permission.
  static bool hasPermission(KlasivoRole role, String permissionId) {
    final permission = allPermissions.firstWhere(
      (p) => p.id == permissionId,
      orElse: () => throw ArgumentError('Unknown permission: $permissionId'),
    );
    return permission.isGrantedByDefault(role);
  }

  /// Check if a role has a specific permission by default.
  ///
  /// Returns `false` if the permission ID is unknown (non-throwing version).
  static bool maybeHasPermission(KlasivoRole role, String permissionId) {
    final permission = _permissionById[permissionId];
    if (permission == null) return false;
    return permission.isGrantedByDefault(role);
  }

  /// Get all permission IDs granted to a role by default (direct only).
  static List<String> getPermissionsForRole(KlasivoRole role) {
    return allPermissions
        .where((p) => p.isGrantedByDefault(role))
        .map((p) => p.id)
        .toList();
  }

  /// Get all [Permission] objects granted to a role by default (direct only).
  static List<Permission> getPermissionObjectsForRole(KlasivoRole role) {
    return allPermissions.where((p) => p.isGrantedByDefault(role)).toList();
  }

  /// Get all permissions for a specific module.
  static List<Permission> getPermissionsForModule(String module) {
    return allPermissions.where((p) => p.module == module).toList();
  }

  /// Get all available module names, sorted alphabetically.
  static List<String> get modules =>
      allPermissions.map((p) => p.module).toSet().toList()..sort();

  /// Look up a permission by its ID.
  ///
  /// Returns `null` if no permission with the given ID exists.
  static Permission? findById(String permissionId) {
    return _permissionById[permissionId];
  }

  /// Get a summary of a role's effective permissions including inheritance.
  ///
  /// Returns a map with:
  /// - `role`: The role name
  /// - `direct`: Directly granted permissions
  /// - `inherited`: Inherited permissions (from other roles)
  /// - `effective`: All effective permissions (direct + inherited)
  static Map<String, dynamic> getRolePermissionSummary(KlasivoRole role) {
    final direct = getPermissionsForRole(role);
    final effective = getAllPermissions(role);
    final inherited = effective.where((p) => !direct.contains(p)).toList();

    return {
      'role': role.id,
      'directCount': direct.length,
      'inheritedCount': inherited.length,
      'effectiveCount': effective.length,
      'direct': direct,
      'inherited': inherited,
      'effective': effective,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE CACHE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pre-built lookup table for O(1) permission ID lookups.
  static final Map<String, Permission> _permissionById = {
    for (final p in allPermissions) p.id: p,
  };

  /// Pre-built cache of inherited permissions per role.
  static final Map<KlasivoRole, List<String>> _inheritedPermissionsCache = {
    for (final role in KlasivoRole.values) role: getAllPermissions(role),
  };
}
