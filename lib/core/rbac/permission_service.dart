// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Permission Service
//
// The core RBAC service that provides the permission-checking API:
//
//   can()             — Check a single permission with optional scope
//   canAny()          — Check if user has ANY of the given permissions
//   canAll()          — Check if user has ALL of the given permissions
//   hasRole()         — Check if user has a role (including hierarchy)
//   validateScope()   — Validate that scope includes a resource
//   getEffectivePermissions() — Get all effective permissions
//   getScope()        — Get the user's scope
//
// Evaluation order (same as v1 with additions):
//   1. Check explicit deny   (permissionOverrides[perm] == false)
//   2. Check explicit allow  (permissionOverrides[perm] == true)
//   3. Check role-based defaults via RoleResolver (with hierarchy)
//   4. If scopeId provided, also validate scope
//   5. Deny by default
// ═══════════════════════════════════════════════════════════════════════════════

import 'permissions.dart';
import 'role_hierarchy.dart';
import 'roles.dart';
import 'scope_access_level.dart';
import 'scope_validator.dart';
import 'user_scope.dart';

/// Core RBAC permission service for Klasivo.
///
/// This is a pure Dart class with NO Firebase dependencies for Sprint 1.
/// Firebase integration (loading overrides from Firestore) comes in Sprint 2.
///
/// The service holds the current user's RBAC state:
///   - role: The user's current role
///   - scope: The user's scope boundaries
///   - permissionOverrides: Explicit allow/deny overrides
///   - organizationId: The user's organization
///
/// Usage:
/// ```dart
/// final service = PermissionService(
///   role: KlasivoRole.teacher,
///   scope: UserScope(classIds: ['class_5A', 'class_5B'], subjectIds: ['math']),
/// );
///
/// if (service.can(Permission.examCreate, scopeType: 'class', scopeId: 'class_5A')) {
///   // Teacher can create exams in class 5A
/// }
///
/// if (service.can(Permission.examPublish)) {
///   // Teacher can publish (but scope is not checked here)
/// }
/// ```
class PermissionService {
  String _role;
  UserScope _scope;
  Map<String, bool> _permissionOverrides;
  String _organizationId;
  int _roleVersion;

  PermissionService({
    required String role,
    UserScope scope = UserScope.empty,
    Map<String, bool> permissionOverrides = const {},
    String organizationId = '',
    int roleVersion = 0,
  })  : _role = role,
        _scope = scope,
        _permissionOverrides = Map.from(permissionOverrides),
        _organizationId = organizationId,
        _roleVersion = roleVersion;

  // ═══════════════════════════════════════════════════════════════════════
  // Core API
  // ═══════════════════════════════════════════════════════════════════════

  /// Check a single permission with optional scope validation.
  ///
  /// If [scopeType] and [scopeId] are provided, the scope is also validated.
  /// If they are omitted, only the permission check is performed.
  ///
  /// Evaluation order:
  ///   1. Explicit deny   → return false
  ///   2. Explicit allow  → return true
  ///   3. Role-based check (with hierarchy)
  ///   4. Scope validation (if scopeType + scopeId provided)
  ///   5. Deny by default
  bool can(String permission, {String? scopeType, String? scopeId}) {
    // 1. Check explicit deny (overrides)
    if (_permissionOverrides[permission] == false) return false;

    // 2. Check explicit allow (overrides)
    if (_permissionOverrides[permission] == true) return true;

    // 3. Check role-based permissions (with hierarchy)
    if (!RoleResolver.roleHasPermission(_role, permission)) return false;

    // 4. If scope specified, also validate scope
    if (scopeType != null && scopeId != null) {
      return validateScope(scopeType: scopeType, scopeId: scopeId);
    }

    return true;
  }

  /// Check if user has ANY of the given permissions.
  ///
  /// Does NOT perform scope validation. Use [can()] individually
  /// if scope validation is needed.
  bool canAny(List<String> permissions) {
    return permissions.any((p) => can(p));
  }

  /// Check if user has ALL of the given permissions.
  ///
  /// Does NOT perform scope validation.
  bool canAll(List<String> permissions) {
    return permissions.every((p) => can(p));
  }

  /// Check if user has a specific role (including hierarchy).
  ///
  /// This uses the hierarchy: `hasRole('admin')` returns true for
  /// owner and super_admin as well, since they inherit admin's role.
  ///
  /// Use [hasExactRole] for strict equality.
  bool hasRole(String role) {
    return RoleHierarchy.inheritsFrom(_role, role);
  }

  /// Check if user has exactly this role (no hierarchy).
  bool hasExactRole(String role) {
    return _role == role;
  }

  /// Validate that the user's scope includes a resource.
  ///
  /// [scopeType] — 'campus', 'stage', 'class', 'subject',
  ///               'academic_year', 'student'
  /// [scopeId] — The resource ID to check
  bool validateScope({
    required String scopeType,
    required String scopeId,
  }) {
    final validator = ScopeValidator(
      scope: _scope,
      accessLevel: scopeAccessLevelForRole(_role),
    );
    return validator.validate(scopeType: scopeType, scopeId: scopeId);
  }

  /// Get all effective permissions for the current user.
  ///
  /// Combines role-based defaults (with hierarchy) and overrides.
  Set<String> getEffectivePermissions() {
    final rolePerms = RoleResolver.getEffectivePermissions(_role);
    final result = Set<String>.from(rolePerms);

    // Apply overrides
    for (final entry in _permissionOverrides.entries) {
      if (entry.value) {
        result.add(entry.key);
      } else {
        result.remove(entry.key);
      }
    }

    return result;
  }

  /// Get the user's current scope.
  UserScope getScope() => _scope;

  // ═══════════════════════════════════════════════════════════════════════
  // Convenience Checks (common permission queries)
  // ═══════════════════════════════════════════════════════════════════════

  /// Can manage exams (create, edit, publish, grade, delete).
  bool get canManageExams => can(Permission.examCreate);

  /// Can manage assignments (create, edit, publish, grade, delete).
  bool get canManageAssignments => can(Permission.assignmentCreate);

  /// Can manage classes (create, edit, delete).
  bool get canManageClasses => can(Permission.classCreate);

  /// Can manage people (create, edit, delete users).
  bool get canManagePeople => can(Permission.userManage);

  /// Can view analytics.
  bool get canViewAnalytics => can(Permission.analyticsView);

  /// Can export any data.
  bool get canExportData => canAny([
        Permission.attendanceExport,
        Permission.examExport,
        Permission.assignmentExport,
        Permission.studentExport,
        Permission.analyticsExport,
        Permission.reportExport,
      ]);

  /// Can manage organization settings.
  bool get canManageOrg => can(Permission.orgSettings);

  /// Can manage billing.
  bool get canManageBilling => can(Permission.billingManage);

  /// Is a platform-level user (super_admin).
  bool get isPlatformLevel => _role == KlasivoRole.superAdmin;

  /// Is an organization-level user (owner or admin).
  bool get isOrgLevel => hasRole(KlasivoRole.admin);

  /// Is a campus-level user (campus_manager).
  bool get isCampusLevel => _role == KlasivoRole.campusManager;

  /// Is a stage-level user (stage_manager or academic_supervisor).
  bool get isStageLevel =>
      _role == KlasivoRole.stageManager ||
      _role == KlasivoRole.academicSupervisor;

  /// Is a class-level user (teacher or assistant_teacher).
  bool get isClassLevel =>
      _role == KlasivoRole.teacher ||
      _role == KlasivoRole.assistantTeacher;

  /// Is a read-only user (observer).
  bool get isReadOnly => _role == KlasivoRole.observer;

  /// Is a student.
  bool get isStudent => _role == KlasivoRole.student;

  /// Is a parent.
  bool get isParent => _role == KlasivoRole.parent;

  // ═══════════════════════════════════════════════════════════════════════
  // State Management
  // ═══════════════════════════════════════════════════════════════════════

  /// Update the user's role (e.g., after role change via Cloud Function).
  void updateRole(String newRole) {
    _role = newRole;
  }

  /// Update the user's scope (e.g., after scope assignment).
  void updateScope(UserScope newScope) {
    _scope = newScope;
  }

  /// Update permission overrides (e.g., loaded from Firestore).
  void updateOverrides(Map<String, bool> newOverrides) {
    _permissionOverrides = Map.from(newOverrides);
  }

  /// Update the organization ID.
  void updateOrganizationId(String orgId) {
    _organizationId = orgId;
  }

  /// Update the role version (for custom claims sync).
  void updateRoleVersion(int version) {
    _roleVersion = version;
  }

  /// Full state update (e.g., after re-authentication or claims refresh).
  void updateAll({
    required String role,
    UserScope? scope,
    Map<String, bool>? permissionOverrides,
    String? organizationId,
    int? roleVersion,
  }) {
    _role = role;
    if (scope != null) _scope = scope;
    if (permissionOverrides != null) _permissionOverrides = Map.from(permissionOverrides);
    if (organizationId != null) _organizationId = organizationId;
    if (roleVersion != null) _roleVersion = roleVersion;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════════════

  String get role => _role;
  String get organizationId => _organizationId;
  int get roleVersion => _roleVersion;
  Map<String, bool> get permissionOverrides => Map.unmodifiable(_permissionOverrides);
  ScopeAccessLevel get accessLevel => scopeAccessLevelForRole(_role);

  @override
  String toString() {
    return 'PermissionService('
        'role: $_role, '
        'orgId: $_organizationId, '
        'accessLevel: $accessLevel, '
        'scope: $_scope, '
        'overrides: ${_permissionOverrides.length}, '
        'roleVersion: $_roleVersion)';
  }
}
