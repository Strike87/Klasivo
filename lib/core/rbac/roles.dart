// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Role Constants
//
// 11 roles organized in a hierarchy:
//
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
//   student  (standalone — self scope)
//   parent   (standalone — linked scope)
// ═══════════════════════════════════════════════════════════════════════════════

/// Centralized role string constants for Klasivo RBAC.
///
/// Use these constants everywhere instead of raw strings.
/// Validation and iteration utilities are provided as static methods.
class KlasivoRole {
  KlasivoRole._();

  // ─── Role Constants ────────────────────────────────────────────────────

  /// Platform-level administrator. Cross-org access.
  static const String superAdmin = 'super_admin';

  /// Organization owner. Full access to their org.
  static const String owner = 'owner';

  /// Organization administrator. Manages users and settings.
  static const String admin = 'admin';

  /// Campus manager. Manages an entire campus within a multi-campus org.
  static const String campusManager = 'campus_manager';

  /// Stage manager. Manages a specific stage (e.g., Primary, Middle).
  static const String stageManager = 'stage_manager';

  /// Academic supervisor. Oversees academic quality within a stage.
  static const String academicSupervisor = 'academic_supervisor';

  /// Teacher. Full academic authority within assigned classes/subjects.
  static const String teacher = 'teacher';

  /// Assistant teacher. Support role — grade, mark attendance, monitor.
  static const String assistantTeacher = 'assistant_teacher';

  /// Observer. Read-only access for inspectors, consultants, QA.
  static const String observer = 'observer';

  /// Student. Self-scoped — take exams, view own results.
  static const String student = 'student';

  /// Parent. Linked scope — view linked children's progress.
  static const String parent = 'parent';

  // ─── Role Collections ──────────────────────────────────────────────────

  /// All valid role strings.
  static const List<String> allRoles = [
    superAdmin,
    owner,
    admin,
    campusManager,
    stageManager,
    academicSupervisor,
    teacher,
    assistantTeacher,
    observer,
    student,
    parent,
  ];

  /// Management roles (participate in the hierarchy above student/parent).
  static const List<String> managementRoles = [
    superAdmin,
    owner,
    admin,
    campusManager,
    stageManager,
    academicSupervisor,
    teacher,
    assistantTeacher,
    observer,
  ];

  /// Staff roles (non-student, non-parent, non-observer).
  static const List<String> staffRoles = [
    superAdmin,
    owner,
    admin,
    campusManager,
    stageManager,
    academicSupervisor,
    teacher,
    assistantTeacher,
  ];

  /// Roles that can manage other users.
  static const List<String> userManagementRoles = [
    superAdmin,
    owner,
    admin,
    campusManager,
    stageManager,
  ];

  /// Roles that require campus/stage/class scope assignment.
  static const List<String> scopedRoles = [
    campusManager,
    stageManager,
    academicSupervisor,
    teacher,
    assistantTeacher,
  ];

  // ─── Validation ────────────────────────────────────────────────────────

  /// Returns true if [role] is a recognized Klasivo role.
  static bool isValid(String role) => allRoles.contains(role);

  /// Returns true if [role] participates in the management hierarchy.
  static bool isManagement(String role) => managementRoles.contains(role);

  /// Returns true if [role] requires explicit scope assignment.
  static bool isScoped(String role) => scopedRoles.contains(role);

  /// Human-readable display name for a role.
  static String displayName(String role) {
    return switch (role) {
      superAdmin => 'Super Admin',
      owner => 'Owner',
      admin => 'Admin',
      campusManager => 'Campus Manager',
      stageManager => 'Stage Manager',
      academicSupervisor => 'Academic Supervisor',
      teacher => 'Teacher',
      assistantTeacher => 'Assistant Teacher',
      observer => 'Observer',
      student => 'Student',
      parent => 'Parent',
      _ => 'Unknown Role',
    };
  }

  /// Short description of a role's scope behavior.
  static String scopeDescription(String role) {
    return switch (role) {
      superAdmin => 'Access across all organizations',
      owner => 'Full access to entire organization',
      admin => 'Full access except org deletion and billing',
      campusManager => 'Access to assigned campuses',
      stageManager => 'Access to assigned stages',
      academicSupervisor => 'Academic oversight within assigned stages',
      teacher => 'Access to assigned classes and subjects',
      assistantTeacher => 'Support access — grade, attendance, monitor',
      observer => 'Read-only access across organization',
      student => 'Access to own data only',
      parent => 'Access to linked children only',
      _ => 'No scope defined',
    };
  }
}
