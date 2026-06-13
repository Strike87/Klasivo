// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — RBAC Health Monitor
//
// Diagnoses the health of the RBAC system at runtime.
// Used for debugging, error reporting, and UI warnings when
// scope loading fails or claims are stale.
//
// Checks:
//   - Claims loaded (role + organizationId in custom claims)
//   - Role loaded (role is non-empty)
//   - Scope loaded (scopeLoaded flag is true)
//   - Permissions loaded (effective permissions set is non-empty)
//   - Scope healthy (scoped roles have non-empty scope arrays)
// ═══════════════════════════════════════════════════════════════════════════════

import 'roles.dart';
import 'scope_access_level.dart';
import 'scope_validator.dart';
import 'user_scope.dart';

/// Health status of the RBAC system for the current user.
class RbacHealthState {
  /// Custom claims are present in the ID token.
  final bool claimsLoaded;

  /// User role is set (non-empty string).
  final bool roleLoaded;

  /// User scope has been loaded from Firestore.
  final bool scopeLoaded;

  /// Effective permissions set is non-empty.
  final bool permissionsLoaded;

  /// For scoped roles: scope arrays are populated.
  /// For non-scoped roles: always true (they don't need scope arrays).
  final bool scopeHealthy;

  /// Human-readable diagnosis of any issues found.
  final List<String> issues;

  const RbacHealthState({
    required this.claimsLoaded,
    required this.roleLoaded,
    required this.scopeLoaded,
    required this.permissionsLoaded,
    required this.scopeHealthy,
    this.issues = const [],
  });

  /// Whether the entire RBAC system is healthy.
  bool get isHealthy =>
      claimsLoaded && roleLoaded && scopeLoaded && permissionsLoaded && scopeHealthy;

  /// Whether there are critical issues that should block access.
  /// Critical = role not loaded or scope not loaded for scoped roles.
  bool get hasCriticalIssue =>
      !roleLoaded || (!scopeLoaded && !scopeHealthy);

  @override
  String toString() {
    final checks = [
      'claims: ${claimsLoaded ? "✓" : "✗"}',
      'role: ${roleLoaded ? "✓" : "✗"}',
      'scope: ${scopeLoaded ? "✓" : "✗"}',
      'permissions: ${permissionsLoaded ? "✓" : "✗"}',
      'scopeHealthy: ${scopeHealthy ? "✓" : "✗"}',
    ];
    return 'RbacHealth(${checks.join(", ")}, issues: $issues)';
  }
}

/// Check the health of the RBAC system given the current state.
///
/// This is a pure function — no Firebase or Firestore calls.
/// It evaluates the current in-memory state and reports issues.
RbacHealthState checkRbacHealth({
  required String role,
  required String organizationId,
  required UserScope scope,
  required bool scopeLoaded,
  required Set<String> effectivePermissions,
}) {
  final issues = <String>[];

  // Check claims
  final claimsLoaded = role.isNotEmpty && organizationId.isNotEmpty;
  if (!claimsLoaded) {
    issues.add('Custom claims not loaded — role or organizationId is empty');
  }

  // Check role
  final roleLoaded = role.isNotEmpty;
  if (!roleLoaded) {
    issues.add('Role not loaded — user may not be authenticated');
  }

  // Check scope loaded from Firestore
  if (!scopeLoaded) {
    issues.add('Scope not loaded from Firestore — scope data may be stale');
  }

  // Check permissions
  final permissionsLoaded = effectivePermissions.isNotEmpty || role == KlasivoRole.student || role == KlasivoRole.parent;
  if (!permissionsLoaded && roleLoaded) {
    issues.add('No effective permissions computed — RBAC resolver may have failed');
  }

  // Check scope health for scoped roles
  bool scopeHealthy = true;
  if (roleLoaded) {
    final accessLevel = scopeAccessLevelForRole(role);
    final validator = ScopeValidator(scope: scope, accessLevel: accessLevel);
    scopeHealthy = !validator.isScopeMissing;

    if (validator.isScopeMissing && scopeLoaded) {
      // Scope was loaded but arrays are empty for a scoped role
      final roleLabel = KlasivoRole.displayName(role);
      final accessLabel = scopeAccessLevelToClaim(accessLevel);
      issues.add('$roleLabel has ScopeAccessLevel.$accessLabel but scope arrays are empty — possible misconfiguration');
    } else if (validator.isScopeMissing && !scopeLoaded) {
      // Scope hasn't loaded yet — this is expected during init
      final roleLabel = KlasivoRole.displayName(role);
      issues.add('$roleLabel scope not yet loaded — scoped access will be denied until loaded');
    }
  }

  return RbacHealthState(
    claimsLoaded: claimsLoaded,
    roleLoaded: roleLoaded,
    scopeLoaded: scopeLoaded,
    permissionsLoaded: permissionsLoaded,
    scopeHealthy: scopeHealthy,
    issues: issues,
  );
}
