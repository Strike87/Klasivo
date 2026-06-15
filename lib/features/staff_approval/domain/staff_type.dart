// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Staff Type Enum
//
// Categorizes the type of staff member being onboarded.
// Designed to be extensible: start with teacher/assistant_teacher/counselor,
// add principal, coordinator, librarian, etc. as needed — without
// creating a separate onboarding system.
//
// The staffType maps to an assignedRole on approval, which then
// flows through the RBAC system for permissions and scope.
// ═══════════════════════════════════════════════════════════════════════════════

/// The type of staff member being onboarded.
///
/// Each staffType determines the default role that will be assigned
/// upon approval. The mapping is:
/// - teacher           → KlasivoRole.teacher
/// - assistantTeacher  → KlasivoRole.assistantTeacher
/// - counselor         → KlasivoRole.teacher (with counselor scope override)
///
/// Future types can be added without changing the onboarding system:
/// - principal         → KlasivoRole.admin
/// - coordinator       → KlasivoRole.academicSupervisor
/// - librarian         → KlasivoRole.observer (custom override)
/// - labAssistant      → KlasivoRole.assistantTeacher
enum StaffType {
  /// Full teacher with academic authority within assigned scope.
  /// Can create, publish, grade exams; create assignments; mark attendance.
  teacher('teacher'),

  /// Support teacher — can grade, mark attendance, monitor.
  /// Cannot create/publish/delete exams or assignments.
  assistantTeacher('assistant_teacher'),

  /// Counselor — provides student support, views records.
  /// Mapped to teacher role with a scope override for counseling access.
  counselor('counselor');

  const StaffType(this.value);

  /// Firestore-compatible string value.
  final String value;

  /// Parse from a Firestore string value.
  /// Returns [teacher] for unknown values (safest default for onboarding).
  static StaffType fromString(String? value) {
    return StaffType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StaffType.teacher,
    );
  }

  /// Human-readable display name.
  String get displayName => switch (this) {
        teacher => 'Teacher',
        assistantTeacher => 'Assistant Teacher',
        counselor => 'Counselor',
      };

  /// The default RBAC role to assign upon approval.
  /// This can be overridden by the reviewer at approval time.
  String get defaultRole => switch (this) {
        teacher => 'teacher',
        assistantTeacher => 'assistant_teacher',
        counselor => 'teacher', // Counselor gets teacher role + scope override
      };

  /// Whether this staff type requires scope assignment
  /// (campus, stage, class, subject) upon approval.
  bool get requiresScopeAssignment => true;

  /// All valid staff type string values (for validation and iteration).
  static List<String> get allValues =>
      StaffType.values.map((e) => e.value).toList();
}
