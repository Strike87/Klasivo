// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Permission State Model
//
// Riverpod-compatible state model that wraps the PermissionService
// configuration. Used by the StateNotifier in rbac_provider.dart.
// ═══════════════════════════════════════════════════════════════════════════════

import 'user_scope.dart';

/// Immutable state model for the RBAC system.
///
/// This is the state object managed by the Riverpod StateNotifier.
/// When any field changes, the entire state is replaced, triggering
/// reactive rebuilds in the UI.
class PermissionState {
  final String role;
  final UserScope scope;
  final Map<String, bool> permissionOverrides;
  final String organizationId;
  final int roleVersion;
  final String userId;

  const PermissionState({
    this.role = '',
    this.scope = UserScope.empty,
    this.permissionOverrides = const {},
    this.organizationId = '',
    this.roleVersion = 0,
    this.userId = '',
  });

  /// Initial/unauthenticated state.
  static const initial = PermissionState();

  /// Whether a user is authenticated and has a role assigned.
  bool get isAuthenticated => role.isNotEmpty && userId.isNotEmpty;

  /// Create a copy with modified fields.
  PermissionState copyWith({
    String? role,
    UserScope? scope,
    Map<String, bool>? permissionOverrides,
    String? organizationId,
    int? roleVersion,
    String? userId,
  }) {
    return PermissionState(
      role: role ?? this.role,
      scope: scope ?? this.scope,
      permissionOverrides: permissionOverrides ?? this.permissionOverrides,
      organizationId: organizationId ?? this.organizationId,
      roleVersion: roleVersion ?? this.roleVersion,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionState &&
          role == other.role &&
          scope == other.scope &&
          _mapEquals(permissionOverrides, other.permissionOverrides) &&
          organizationId == other.organizationId &&
          roleVersion == other.roleVersion &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(
        role,
        scope,
        Object.hashAll(permissionOverrides.entries.map((e) => Object.hash(e.key, e.value))),
        organizationId,
        roleVersion,
        userId,
      );

  static bool _mapEquals(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'PermissionState('
        'userId: $userId, '
        'role: $role, '
        'orgId: $organizationId, '
        'roleVersion: $roleVersion, '
        'scope: $scope, '
        'overrides: ${permissionOverrides.length})';
  }
}
