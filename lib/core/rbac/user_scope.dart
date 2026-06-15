// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — User Scope Model
//
// Defines the boundaries of a user's access within their organization.
//
// Scope array semantics depend on ScopeAccessLevel:
//   - all:      Empty arrays = access everything
//   - campus:   Empty campusIds = all campuses (backward compat; tighten in v1.8)
//   - stage:    Empty stageIds = all stages (backward compat; tighten in v1.8)
//   - class_:   Empty classIds = all classes (backward compat; tighten in v1.8)
//   - self:     classIds contains the student's enrolled class
//   - linked:   studentIds contains the parent's linked children
//
// TODO (v1.8): Migrate to Freezed:
//   @freezed
//   class UserScope with _$UserScope { ... }
// ═══════════════════════════════════════════════════════════════════════════════

/// Immutable scope model defining the boundaries of a user's access.
///
/// Each scope array narrows access to specific organizational units.
/// The interpretation of empty arrays depends on the user's ScopeAccessLevel.
class UserScope {
  final List<String> campusIds;
  final List<String> stageIds;
  final List<String> classIds;
  final List<String> subjectIds;
  final List<String> academicYearIds;
  final List<String> studentIds;

  const UserScope({
    this.campusIds = const [],
    this.stageIds = const [],
    this.classIds = const [],
    this.subjectIds = const [],
    this.academicYearIds = const [],
    this.studentIds = const [],
  });

  /// Empty scope — default for new users before scope assignment.
  static const empty = UserScope();

  // ─── Serialization ─────────────────────────────────────────────────────

  /// Create from Firestore document map.
  factory UserScope.fromJson(Map<String, dynamic> json) {
    return UserScope(
      campusIds: List<String>.from(json['campusIds'] ?? []),
      stageIds: List<String>.from(json['stageIds'] ?? []),
      classIds: List<String>.from(json['classIds'] ?? []),
      subjectIds: List<String>.from(json['subjectIds'] ?? []),
      academicYearIds: List<String>.from(json['academicYearIds'] ?? []),
      studentIds: List<String>.from(json['studentIds'] ?? []),
    );
  }

  /// Convert to Firestore document map.
  Map<String, dynamic> toJson() {
    return {
      'campusIds': campusIds,
      'stageIds': stageIds,
      'classIds': classIds,
      'subjectIds': subjectIds,
      'academicYearIds': academicYearIds,
      'studentIds': studentIds,
    };
  }

  // ─── Copy-With ─────────────────────────────────────────────────────────

  UserScope copyWith({
    List<String>? campusIds,
    List<String>? stageIds,
    List<String>? classIds,
    List<String>? subjectIds,
    List<String>? academicYearIds,
    List<String>? studentIds,
  }) {
    return UserScope(
      campusIds: campusIds ?? this.campusIds,
      stageIds: stageIds ?? this.stageIds,
      classIds: classIds ?? this.classIds,
      subjectIds: subjectIds ?? this.subjectIds,
      academicYearIds: academicYearIds ?? this.academicYearIds,
      studentIds: studentIds ?? this.studentIds,
    );
  }

  // ─── Merge (additive union of two scopes) ──────────────────────────────

  /// Merge this scope with [other], producing the union of all arrays.
  /// Useful for v1.9 multi-role support.
  UserScope merge(UserScope other) {
    return UserScope(
      campusIds: {...campusIds, ...other.campusIds}.toList(),
      stageIds: {...stageIds, ...other.stageIds}.toList(),
      classIds: {...classIds, ...other.classIds}.toList(),
      subjectIds: {...subjectIds, ...other.subjectIds}.toList(),
      academicYearIds: {...academicYearIds, ...other.academicYearIds}.toList(),
      studentIds: {...studentIds, ...other.studentIds}.toList(),
    );
  }

  // ─── Equality ──────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserScope &&
          _listEquals(campusIds, other.campusIds) &&
          _listEquals(stageIds, other.stageIds) &&
          _listEquals(classIds, other.classIds) &&
          _listEquals(subjectIds, other.subjectIds) &&
          _listEquals(academicYearIds, other.academicYearIds) &&
          _listEquals(studentIds, other.studentIds);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(campusIds),
        Object.hashAll(stageIds),
        Object.hashAll(classIds),
        Object.hashAll(subjectIds),
        Object.hashAll(academicYearIds),
        Object.hashAll(studentIds),
      );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'UserScope('
        'campusIds: $campusIds, '
        'stageIds: $stageIds, '
        'classIds: $classIds, '
        'subjectIds: $subjectIds, '
        'academicYearIds: $academicYearIds, '
        'studentIds: $studentIds)';
  }

  /// Whether this scope has any non-empty arrays (i.e., has been assigned).
  bool get hasAssignedScope =>
      campusIds.isNotEmpty ||
      stageIds.isNotEmpty ||
      classIds.isNotEmpty ||
      subjectIds.isNotEmpty ||
      academicYearIds.isNotEmpty ||
      studentIds.isNotEmpty;
}
