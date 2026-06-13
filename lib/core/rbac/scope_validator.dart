// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Scope Validator
//
// Validates whether a user's scope grants access to a specific resource.
//
// Validation rules by ScopeAccessLevel:
//
//   all      → Always true (super_admin, owner, admin, observer)
//   campus   → Check campusIds first, then fall through to stage/class/subject
//   stage    → Check stageIds first, then fall through to class/subject
//   class_   → Check classIds and subjectIds
//   self     → Handled at service layer (compare resource.studentId == userId)
//   linked   → Check studentIds (parent's linked children)
//
// Backward compatibility: For scoped roles (campus, stage, class_),
// empty scope arrays = "all access" until explicitly tightened in v1.8.
// ═══════════════════════════════════════════════════════════════════════════════

import 'roles.dart';
import 'scope_access_level.dart';
import 'user_scope.dart';

/// Validates whether a user's scope grants access to a specific resource.
///
/// Usage:
/// ```dart
/// final validator = ScopeValidator(
///   scope: userScope,
///   accessLevel: scopeAccessLevelForRole(role),
/// );
///
/// if (validator.validate(scopeType: 'class', scopeId: 'class_5A')) {
///   // Access granted
/// }
/// ```
class ScopeValidator {
  final UserScope scope;
  final ScopeAccessLevel accessLevel;

  const ScopeValidator({
    required this.scope,
    required this.accessLevel,
  });

  /// Convenience constructor from a role string.
  factory ScopeValidator.forRole(String role, {required UserScope scope}) {
    return ScopeValidator(
      scope: scope,
      accessLevel: scopeAccessLevelForRole(role),
    );
  }

  /// Validate scope for a given resource type and ID.
  ///
  /// [scopeType] — The type of resource being accessed:
  ///   'campus', 'stage', 'class', 'subject', 'academic_year', 'student'
  ///
  /// [scopeId] — The ID of the specific resource.
  ///
  /// Returns true if the user's scope grants access to this resource.
  bool validate({
    required String scopeType,
    required String scopeId,
  }) {
    switch (accessLevel) {
      case ScopeAccessLevel.all:
        return _validateAll();

      case ScopeAccessLevel.campus:
        return _validateCampus(scopeType, scopeId);

      case ScopeAccessLevel.stage:
        return _validateStage(scopeType, scopeId);

      case ScopeAccessLevel.class_:
        return _validateClass(scopeType, scopeId);

      case ScopeAccessLevel.self:
        return _validateSelf(scopeType, scopeId);

      case ScopeAccessLevel.linked:
        return _validateLinked(scopeType, scopeId);
    }
  }

  // ─── all: Full access ──────────────────────────────────────────────────

  bool _validateAll() => true;

  // ─── campus: Campus-scoped access ──────────────────────────────────────

  bool _validateCampus(String scopeType, String scopeId) {
    switch (scopeType) {
      case 'campus':
        return scope.campusIds.isEmpty || scope.campusIds.contains(scopeId);
      case 'stage':
        // If campusIds are set, stage must belong to an in-scope campus.
        // Direct stageIds check as fallback.
        return scope.stageIds.isEmpty || scope.stageIds.contains(scopeId);
      case 'class':
        return scope.classIds.isEmpty || scope.classIds.contains(scopeId);
      case 'subject':
        return scope.subjectIds.isEmpty || scope.subjectIds.contains(scopeId);
      case 'academic_year':
        return scope.academicYearIds.isEmpty ||
            scope.academicYearIds.contains(scopeId);
      case 'student':
        return scope.studentIds.isEmpty || scope.studentIds.contains(scopeId);
      default:
        return false;
    }
  }

  // ─── stage: Stage-scoped access ────────────────────────────────────────

  bool _validateStage(String scopeType, String scopeId) {
    switch (scopeType) {
      case 'campus':
        // Stage-scoped users can access the campus their stage belongs to.
        // Cannot validate without service-level data; allow and let
        // the service layer tighten if needed.
        return true;
      case 'stage':
        return scope.stageIds.isEmpty || scope.stageIds.contains(scopeId);
      case 'class':
        return scope.classIds.isEmpty || scope.classIds.contains(scopeId);
      case 'subject':
        return scope.subjectIds.isEmpty || scope.subjectIds.contains(scopeId);
      case 'academic_year':
        return scope.academicYearIds.isEmpty ||
            scope.academicYearIds.contains(scopeId);
      case 'student':
        return scope.studentIds.isEmpty || scope.studentIds.contains(scopeId);
      default:
        return false;
    }
  }

  // ─── class_: Class/subject-scoped access ───────────────────────────────

  bool _validateClass(String scopeType, String scopeId) {
    switch (scopeType) {
      case 'campus':
      case 'stage':
        // Class-scoped users can access the campus/stage their class
        // belongs to. Cannot validate without service-level data; allow.
        return true;
      case 'class':
        return scope.classIds.isEmpty || scope.classIds.contains(scopeId);
      case 'subject':
        return scope.subjectIds.isEmpty || scope.subjectIds.contains(scopeId);
      case 'academic_year':
        return scope.academicYearIds.isEmpty ||
            scope.academicYearIds.contains(scopeId);
      case 'student':
        return scope.studentIds.isEmpty || scope.studentIds.contains(scopeId);
      default:
        return false;
    }
  }

  // ─── self: Student's own data ──────────────────────────────────────────
  // Full scope validation happens at the service layer by comparing
  // resource.studentId or resource.uid == userId. Here we only check
  // class enrollment for class-scoped queries.

  bool _validateSelf(String scopeType, String scopeId) {
    switch (scopeType) {
      case 'class':
        // Student can access their enrolled class(es)
        return scope.classIds.isEmpty || scope.classIds.contains(scopeId);
      case 'subject':
        return scope.subjectIds.isEmpty || scope.subjectIds.contains(scopeId);
      case 'academic_year':
        return scope.academicYearIds.isEmpty ||
            scope.academicYearIds.contains(scopeId);
      default:
        // For 'user', 'exam', 'assignment' etc., service layer
        // validates by comparing resource ownership.
        return true;
    }
  }

  // ─── linked: Parent's linked children ──────────────────────────────────

  bool _validateLinked(String scopeType, String scopeId) {
    switch (scopeType) {
      case 'student':
        // Parent can access data for their linked children only
        return scope.studentIds.contains(scopeId);
      case 'class':
        // Parent can view classes their linked children are enrolled in.
        // Service layer should validate the class belongs to a linked child.
        return scope.classIds.isEmpty || scope.classIds.contains(scopeId);
      case 'subject':
        return scope.subjectIds.isEmpty || scope.subjectIds.contains(scopeId);
      case 'academic_year':
        return scope.academicYearIds.isEmpty ||
            scope.academicYearIds.contains(scopeId);
      default:
        // For other resource types, service layer must validate
        // that the resource belongs to a linked child.
        return false;
    }
  }

  // ─── Utility Methods ───────────────────────────────────────────────────

  /// Get all scope IDs that this user can access for a given scope type.
  ///
  /// Returns null if the scope type has "all access" (empty array for
  /// a scoped role, or ScopeAccessLevel.all).
  List<String>? accessibleIdsFor(String scopeType) {
    switch (scopeType) {
      case 'campus':
        return scope.campusIds.isEmpty ? null : scope.campusIds;
      case 'stage':
        return scope.stageIds.isEmpty ? null : scope.stageIds;
      case 'class':
        return scope.classIds.isEmpty ? null : scope.classIds;
      case 'subject':
        return scope.subjectIds.isEmpty ? null : scope.subjectIds;
      case 'academic_year':
        return scope.academicYearIds.isEmpty ? null : scope.academicYearIds;
      case 'student':
        return scope.studentIds.isEmpty ? null : scope.studentIds;
      default:
        return null;
    }
  }

  /// Check if this scope is effectively "all access" for the role.
  bool get isAllAccess {
    if (accessLevel == ScopeAccessLevel.all) return true;
    if (accessLevel == ScopeAccessLevel.campus) return scope.campusIds.isEmpty;
    if (accessLevel == ScopeAccessLevel.stage) return scope.stageIds.isEmpty;
    if (accessLevel == ScopeAccessLevel.class_) {
      return scope.classIds.isEmpty && scope.subjectIds.isEmpty;
    }
    return false;
  }
}
