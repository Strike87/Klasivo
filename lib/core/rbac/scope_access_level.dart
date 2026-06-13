// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Scope Access Level
//
// Defines how scope arrays are interpreted for each role:
//
//   all      — super_admin, owner, admin, observer
//              Empty arrays = access everything
//
//   campus   — campus_manager
//              Scoped by campusIds
//
//   stage    — stage_manager, academic_supervisor
//              Scoped by stageIds
//
//   class_   — teacher, assistant_teacher
//              Scoped by classIds + subjectIds
//
//   self     — student
//              Only own data
//
//   linked   — parent
//              Only linked children via studentIds
// ═══════════════════════════════════════════════════════════════════════════════

import 'roles.dart';

/// Defines how scope arrays are interpreted for each role level.
///
/// This enum drives the ScopeValidator's behavior. Each level determines
/// which scope arrays are checked and what empty arrays mean.
enum ScopeAccessLevel {
  /// Full access — empty scope arrays = access everything.
  /// Roles: super_admin, owner, admin, observer (read-only).
  all,

  /// Scoped by campusIds — can access everything within assigned campuses.
  /// Roles: campus_manager.
  campus,

  /// Scoped by stageIds — can access everything within assigned stages.
  /// Roles: stage_manager, academic_supervisor.
  stage,

  /// Scoped by classIds + subjectIds — can access assigned classes/subjects.
  /// Roles: teacher, assistant_teacher.
  class_,

  /// Self-scoped — can only access own data.
  /// Roles: student.
  self,

  /// Linked scope — can only access data for linked children.
  /// Roles: parent.
  linked,
}

/// Static mapping from role → scope access level.
///
/// This is the single source of truth for how each role's scope is interpreted.
/// The ScopeValidator reads from this map.
const Map<String, ScopeAccessLevel> roleScopeAccessLevel = {
  KlasivoRole.superAdmin: ScopeAccessLevel.all,
  KlasivoRole.owner: ScopeAccessLevel.all,
  KlasivoRole.admin: ScopeAccessLevel.all,
  KlasivoRole.campusManager: ScopeAccessLevel.campus,
  KlasivoRole.stageManager: ScopeAccessLevel.stage,
  KlasivoRole.academicSupervisor: ScopeAccessLevel.stage,
  KlasivoRole.teacher: ScopeAccessLevel.class_,
  KlasivoRole.assistantTeacher: ScopeAccessLevel.class_,
  KlasivoRole.observer: ScopeAccessLevel.all,
  KlasivoRole.student: ScopeAccessLevel.self,
  KlasivoRole.parent: ScopeAccessLevel.linked,
};

/// Get the ScopeAccessLevel for a role, with a safe default.
ScopeAccessLevel scopeAccessLevelForRole(String role) {
  return roleScopeAccessLevel[role] ?? ScopeAccessLevel.self;
}
