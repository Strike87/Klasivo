// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Permission Overrides
//
// Manages explicit permission overrides for individual users.
// Overrides take precedence over role-based defaults:
//   - true  → Grant permission even if the role doesn't include it
//   - false → Deny permission even if the role includes it
//
// Storage: Firestore user doc → permissionOverrides: Map<String, bool>
// Server-side: setPermissionOverrides Cloud Function
//
// Evaluation order (in PermissionService.can()):
//   1. Check explicit deny   (permissionOverrides[perm] == false) → DENY
//   2. Check explicit allow  (permissionOverrides[perm] == true)  → ALLOW
//   3. Check role-based defaults via RoleResolver
//   4. Deny by default
// ═══════════════════════════════════════════════════════════════════════════════

import 'permissions.dart';
import 'permission_groups.dart';
import 'role_hierarchy.dart';
import 'roles.dart';

/// Utility class for working with permission overrides.
///
/// Provides helpers for:
///   - Building override maps from templates
///   - Merging overrides with role defaults
///   - Computing effective permissions
///   - Validating override keys
class PermissionOverrides {
  PermissionOverrides._();

  /// Validate that all override keys are valid permission strings.
  ///
  /// Returns a list of invalid keys (empty if all valid).
  static List<String> validateKeys(Map<String, bool> overrides) {
    final invalidKeys = <String>[];
    for (final key in overrides.keys) {
      if (key == Permission.all) continue; // Wildcard is valid
      final category = Permission.categoryOf(key);
      if (category == key && !key.contains(':')) {
        // No colon and not a wildcard — likely invalid
        invalidKeys.add(key);
      }
    }
    return invalidKeys;
  }

  /// Apply overrides to a role's default permission set.
  ///
  /// Returns the resulting effective permission set after applying
  /// all overrides (both grants and denials).
  static Set<String> applyToRole(String role, Map<String, bool> overrides) {
    return PermissionGroups.applyOverrides(role, overrides);
  }

  /// Get a diff description of what overrides change vs role defaults.
  ///
  /// Useful for the Effective Permissions Viewer UI.
  static OverrideDiff getOverrideDiff(String role, Map<String, bool> overrides) {
    final defaultPerms = RoleResolver.getEffectivePermissions(role);
    final effectivePerms = applyToRole(role, overrides);

    final granted = effectivePerms.difference(defaultPerms);
    final denied = defaultPerms.difference(effectivePerms);

    return OverrideDiff(
      role: role,
      defaultPermissions: defaultPerms,
      effectivePermissions: effectivePerms,
      grantedByOverrides: granted,
      deniedByOverrides: denied,
      overrides: overrides,
    );
  }

  /// Build overrides from a named template.
  ///
  /// Templates are defined in [PermissionGroups] (teacherNoPublish,
  /// noExport, gradeOnly).
  static Map<String, bool> fromTemplate(String templateName) {
    return switch (templateName) {
      'teacherNoPublish' => PermissionGroups.teacherNoPublish,
      'noExport' => PermissionGroups.noExport,
      'gradeOnly' => PermissionGroups.gradeOnly,
      _ => {},
    };
  }

  /// Merge two override maps. [newOverrides] takes precedence.
  static Map<String, bool> merge(
    Map<String, bool> existing,
    Map<String, bool> newOverrides,
  ) {
    return {...existing, ...newOverrides};
  }
}

/// Describes the impact of permission overrides on a role.
///
/// Used by the Effective Permissions Viewer to show:
///   - What the role grants by default
///   - What overrides add (grants)
///   - What overrides remove (denials)
///   - The final effective permission set
class OverrideDiff {
  final String role;
  final Set<String> defaultPermissions;
  final Set<String> effectivePermissions;
  final Set<String> grantedByOverrides;
  final Set<String> deniedByOverrides;
  final Map<String, bool> overrides;

  const OverrideDiff({
    required this.role,
    required this.defaultPermissions,
    required this.effectivePermissions,
    required this.grantedByOverrides,
    required this.deniedByOverrides,
    required this.overrides,
  });

  /// Whether any overrides are in effect.
  bool get hasOverrides => overrides.isNotEmpty;

  /// Whether any permissions are being denied by overrides.
  bool get hasDenials => deniedByOverrides.isNotEmpty;

  /// Whether any permissions are being granted by overrides.
  bool get hasGrants => grantedByOverrides.isNotEmpty;

  /// Summary string for display.
  String get summary {
    if (!hasOverrides) return 'No overrides — using role defaults';
    final parts = <String>[];
    if (hasGrants) parts.add('+${grantedByOverrides.length} granted');
    if (hasDenials) parts.add('-${deniedByOverrides.length} denied');
    return parts.join(', ');
  }

  @override
  String toString() => 'OverrideDiff($role: $summary)';
}
