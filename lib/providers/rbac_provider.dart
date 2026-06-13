// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Riverpod Providers
//
// New providers for the RBAC system. These coexist with the existing
// permission_provider.dart during the migration period.
//
// Migration path (Sprint 2):
//   1. Replace old permission_provider.dart imports with this file
//   2. Remove old PermissionCheck / hasPermissionProvider
//   3. Update all screens to use new API
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/rbac/rbac.dart';
import '../core/services/claims_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// STATE NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════════

/// Manages the RBAC state for the current user.
///
/// Reads initial state from Hive (backward compatible with existing auth flow).
/// Updates state when role/scope changes via Cloud Functions.
class RbacNotifier extends StateNotifier<PermissionState> {
  RbacNotifier() : super(PermissionState.initial) {
    _loadFromHive();
  }

  /// Load initial state from Hive (existing auth persistence).
  void _loadFromHive() {
    final box = Hive.box(AppConstants.authBox);
    final role = box.get('userRole', defaultValue: '') as String;
    final userId = box.get('userId', defaultValue: '') as String;
    final orgId = box.get('organizationId', defaultValue: '') as String;
    final mustChangePassword = box.get('mustChangePassword', defaultValue: false) as bool;

    if (role.isNotEmpty && userId.isNotEmpty) {
      state = PermissionState(
        role: role,
        userId: userId,
        organizationId: orgId ?? '',
        scope: UserScope.empty, // Will be populated from Firestore in Sprint 2
        mustChangePassword: mustChangePassword,
      );
    }
  }

  /// Update the full RBAC state (after login or role change).
  void updateState(PermissionState newState) {
    state = newState;
  }

  /// Update the user's role (after assignRole Cloud Function).
  void updateRole(String newRole) {
    state = state.copyWith(role: newRole);
  }

  /// Update the user's scope (after assignScope Cloud Function).
  void updateScope(UserScope newScope) {
    state = state.copyWith(scope: newScope);
  }

  /// Update permission overrides (loaded from Firestore).
  void updateOverrides(Map<String, bool> overrides) {
    state = state.copyWith(permissionOverrides: overrides);
  }

  /// Update role version (for custom claims sync).
  void updateRoleVersion(int version) {
    state = state.copyWith(roleVersion: version);
  }

  /// Reset state (after logout).
  void reset() {
    state = PermissionState.initial;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// RbacNotifier provider.
final rbacProvider = StateNotifierProvider<RbacNotifier, PermissionState>((ref) {
  return RbacNotifier();
});

/// PermissionService provider — derived from RBAC state.
/// Re-creates the service whenever state changes.
final rbacPermissionServiceProvider = Provider<PermissionService>((ref) {
  final state = ref.watch(rbacProvider);
  return PermissionService(
    role: state.role,
    scope: state.scope,
    permissionOverrides: state.permissionOverrides,
    organizationId: state.organizationId,
    roleVersion: state.roleVersion,
  );
});

// ─── Role Providers ─────────────────────────────────────────────────────────

/// Current user's role.
final rbacRoleProvider = Provider<String>((ref) {
  return ref.watch(rbacProvider).role;
});

/// Current user's organization ID.
final rbacOrgIdProvider = Provider<String>((ref) {
  return ref.watch(rbacProvider).organizationId;
});

/// Current user's ID.
final rbacUserIdProvider = Provider<String>((ref) {
  return ref.watch(rbacProvider).userId;
});

/// Whether scope has been loaded from Firestore.
final rbacScopeLoadedProvider = Provider<bool>((ref) {
  return ref.watch(rbacProvider).scopeLoaded;
});

/// Whether the current user's scope is missing (fail-closed state).
/// Returns true for scoped roles with empty scope arrays.
final rbacScopeMissingProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.isScopeMissing;
});

/// Current user's scope.
final rbacScopeProvider = Provider<UserScope>((ref) {
  return ref.watch(rbacProvider).scope;
});

/// Current user's role version (for claims sync).
final rbacRoleVersionProvider = Provider<int>((ref) {
  return ref.watch(rbacProvider).roleVersion;
});

// ─── Permission Check Providers ─────────────────────────────────────────────

/// Single permission check — returns true if the current user has the permission.
///
/// Usage:
/// ```dart
/// final canCreate = ref.watch(rbacCanProvider(Permission.examCreate));
/// ```
final rbacCanProvider = Provider.family<bool, String>((ref, permission) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.can(permission);
});

/// Scoped permission check — returns true if the user has the permission
/// AND the scope includes the specified resource.
///
/// Usage:
/// ```dart
/// final canCreateInClass = ref.watch(
///   rbacCanScopedProvider(RbacScopedCheck(
///     permission: Permission.examCreate,
///     scopeType: 'class',
///     scopeId: 'class_5A',
///   )),
/// );
/// ```
class RbacScopedCheck {
  final String permission;
  final String scopeType;
  final String scopeId;

  const RbacScopedCheck({
    required this.permission,
    required this.scopeType,
    required this.scopeId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RbacScopedCheck &&
          permission == other.permission &&
          scopeType == other.scopeType &&
          scopeId == other.scopeId;

  @override
  int get hashCode => Object.hash(permission, scopeType, scopeId);
}

final rbacCanScopedProvider =
    Provider.family<bool, RbacScopedCheck>((ref, check) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.can(
    check.permission,
    scopeType: check.scopeType,
    scopeId: check.scopeId,
  );
});

/// Multiple permission check — returns a map of permission → isGranted.
///
/// Usage:
/// ```dart
/// final perms = ref.watch(rbacPermissionsCheckProvider([
///   Permission.examCreate,
///   Permission.examPublish,
/// ]));
/// if (perms[Permission.examCreate] == true) { ... }
/// ```
final rbacPermissionsCheckProvider =
    Provider.family<Map<String, bool>, List<String>>((ref, permissions) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return {
    for (final perm in permissions) perm: service.can(perm),
  };
});

/// Effective permissions set for the current user.
final rbacEffectivePermissionsProvider = Provider<Set<String>>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.getEffectivePermissions();
});

// ─── Role Check Providers ───────────────────────────────────────────────────

/// Check if the current user has a role (including hierarchy).
///
/// Usage:
/// ```dart
/// final isAdmin = ref.watch(rbacHasRoleProvider(KlasivoRole.admin));
/// ```
final rbacHasRoleProvider = Provider.family<bool, String>((ref, role) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.hasRole(role);
});

/// Is the current user a super_admin or above.
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(rbacRoleProvider) == KlasivoRole.superAdmin;
});

/// Is the current user an org-level user (owner, admin, or above).
final isOrgLevelProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.isOrgLevel;
});

/// Is the current user a teacher or above.
final isTeacherOrAboveProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.hasRole(KlasivoRole.teacher);
});

/// Is the current user a student.
final isStudentProvider = Provider<bool>((ref) {
  return ref.watch(rbacRoleProvider) == KlasivoRole.student;
});

/// Is the current user a parent.
final isParentProvider = Provider<bool>((ref) {
  return ref.watch(rbacRoleProvider) == KlasivoRole.parent;
});

/// Is the current user an observer.
final isObserverProvider = Provider<bool>((ref) {
  return ref.watch(rbacRoleProvider) == KlasivoRole.observer;
});

// ─── Convenience Feature Providers ──────────────────────────────────────────

/// Can manage exams.
final canManageExamsProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.canManageExams;
});

/// Can manage classes.
final canManageClassesProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.canManageClasses;
});

/// Can manage people.
final canManagePeopleProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.canManagePeople;
});

/// Can view analytics.
final canViewAnalyticsProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.canViewAnalytics;
});

/// Can export data.
final canExportDataProvider = Provider<bool>((ref) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.canExportData;
});

// ─── Scope Validation Provider ──────────────────────────────────────────────

/// Validate scope for a specific resource.
///
/// Usage:
/// ```dart
/// final hasAccess = ref.watch(rbacScopeValidatorProvider(
///   RbacScopeCheck(scopeType: 'class', scopeId: 'class_5A'),
/// ));
/// ```
class RbacScopeCheck {
  final String scopeType;
  final String scopeId;

  const RbacScopeCheck({required this.scopeType, required this.scopeId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RbacScopeCheck &&
          scopeType == other.scopeType &&
          scopeId == other.scopeId;

  @override
  int get hashCode => Object.hash(scopeType, scopeId);
}

final rbacScopeValidatorProvider =
    Provider.family<bool, RbacScopeCheck>((ref, check) {
  final service = ref.watch(rbacPermissionServiceProvider);
  return service.validateScope(
    scopeType: check.scopeType,
    scopeId: check.scopeId,
  );
});

/// RBAC Health Monitor — diagnoses issues with the RBAC system.
///
/// Usage:
/// ```dart
/// final health = ref.watch(rbacHealthProvider);
/// if (!health.isHealthy) {
///   debugPrint('RBAC issues: ${health.issues}');
/// }
/// ```
final rbacHealthProvider = Provider<RbacHealthState>((ref) {
  final state = ref.watch(rbacProvider);
  final service = ref.watch(rbacPermissionServiceProvider);
  return checkRbacHealth(
    role: state.role,
    organizationId: state.organizationId,
    scope: state.scope,
    scopeLoaded: state.scopeLoaded,
    effectivePermissions: service.getEffectivePermissions(),
  );
});

// ═══════════════════════════════════════════════════════════════════════════════
// CLAIMS SERVICE & RBAC INIT
// ═══════════════════════════════════════════════════════════════════════════════

/// ClaimsService provider — manages custom claims syncing and roleVersion monitoring.
final claimsServiceProvider = Provider<ClaimsService>((ref) {
  final service = ClaimsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Initialize RBAC state from Firebase Auth + Firestore.
/// Call this after successful login.
///
/// This is the replacement for the old `permissionServiceProvider.loadPermissions()`.
/// It loads claims, scope, overrides, and roleVersion from Firestore,
/// then starts the roleVersion listener for real-time claim sync.
final rbacInitProvider = FutureProvider<void>((ref) async {
  final claimsService = ref.read(claimsServiceProvider);
  final claims = await claimsService.getCurrentClaims();

  if (!claims.isValid) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Load scope, overrides, and roleVersion from Firestore
  final scope = await claimsService.getUserScope(user.uid);
  final mustChangePassword = await claimsService.getMustChangePassword(user.uid);
  final roleVersion = await claimsService.getRoleVersion(user.uid);
  final overrides = await claimsService.getPermissionOverrides(user.uid);

  ref.read(rbacProvider.notifier).updateState(PermissionState(
    role: claims.role,
    userId: user.uid,
    organizationId: claims.organizationId,
    scope: scope,
    mustChangePassword: mustChangePassword,
    roleVersion: roleVersion,
    permissionOverrides: overrides,
    scopeLoaded: true, // ← FAIL-CLOSED: Only true after successful Firestore load
  ));

  // Start roleVersion listener for real-time claim sync
  claimsService.startRoleVersionListener(
    userId: user.uid,
    onRoleVersionChanged: (newClaims, newScope, newVersion) {
      ref.read(rbacProvider.notifier).updateState(PermissionState(
        role: newClaims.role,
        userId: user.uid,
        organizationId: newClaims.organizationId,
        scope: newScope,
        roleVersion: newVersion,
        scopeLoaded: true, // Re-confirmed after version change
      ));
    },
  );
});
