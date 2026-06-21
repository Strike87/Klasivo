import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/services/permission_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PERMISSION PROVIDERS
// Riverpod integration for granular RBAC with real-time permission checks.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Permission Service Provider ──────────────────────────────────────────
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService.instance;
});

// ─── Current User Role Provider (from auth state) ────────────────────────
final currentUserRoleProvider = Provider<String>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userRole', defaultValue: '') as String;
});

// ─── Current User ID Provider (from auth state) ──────────────────────────
final currentUserIdProvider = Provider<String>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('userId', defaultValue: '') as String;
});

// ─── Current Org ID Provider ─────────────────────────────────────────────
// ⚠️ KNOWN STALENESS BUG (deferred — needs architectural design):
// This provider reads `organizationId` from Hive synchronously, which works
// correctly for cold start and offline use. BUT it does NOT update when an
// admin reassigns the user to a different organization server-side — the
// cached value stays stale until the user logs out and logs back in.
//
// The fix is to add a private `_userDocStreamProvider` (StreamProvider) that
// watches `users/{uid}` in Firestore and writes back to Hive on change. The
// pattern was sketched in the deleted scaffold file `lib/features/auth/
// providers/auth_providers.dart` (recoverable from git history at commit
// 83a427f if needed). DO NOT change this provider's type from `Provider<String?>`
// to `StreamProvider<String?>` — that would force ~16 downstream consumers
// (messaging_provider, feature_flag_provider, paginated_providers,
// calendar_event_provider, this file's own hasPermissionProvider, etc.) to
// switch from `ref.watch(...)` (returns String?) to `.when(...)` /
// `.valueOrNull`. Instead, keep the sync Provider type and add a background
// stream that writes back to Hive; downstream consumers that watch this
// provider will rebuild when Hive is updated.
//
// Why deferred:
//   1. Needs `flutter analyze` to verify (not available in container).
//   2. Needs cold-start + org-reassignment test coverage.
//   3. Cascading invalidation of downstream providers that read Hive directly
//      (not via this provider) needs separate audit — they won't auto-update.
//   4. Should be coordinated with Sprint 2 multi-tenant sync work.
//
// Tracked in: download/scaffold-phase2-report.md (Follow-up Items).
final currentOrgIdProvider = Provider<String?>((ref) {
  final box = Hive.box(AppConstants.authBox);
  return box.get('organizationId') as String?;
});

// ─── Permission Check Model ──────────────────────────────────────────────
class PermissionCheck {
  final String permission;
  final String? resourceId;
  final String? resourceType;

  const PermissionCheck({
    required this.permission,
    this.resourceId,
    this.resourceType,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionCheck &&
          runtimeType == other.runtimeType &&
          permission == other.permission &&
          resourceId == other.resourceId &&
          resourceType == other.resourceType;

  @override
  int get hashCode => Object.hash(permission, resourceId, resourceType);
}

// ─── Single Permission Check Provider ─────────────────────────────────────
// Usage: ref.watch(hasPermissionProvider(PermissionCheck(permission: 'exam:create')))
final hasPermissionProvider = Provider.family<bool, PermissionCheck>((ref, check) {
  final service = ref.watch(permissionServiceProvider);
  final role = ref.watch(currentUserRoleProvider);
  final userId = ref.watch(currentUserIdProvider);
  final orgId = ref.watch(currentOrgIdProvider);

  return service.hasPermission(
    userId: userId,
    role: role,
    permission: check.permission,
    resourceId: check.resourceId,
    resourceType: check.resourceType,
    orgId: orgId,
  );
});

// ─── Multiple Permission Check Provider ───────────────────────────────────
// Returns a map of permission → isGranted for a batch of permissions.
// Usage: ref.watch(permissionsCheckProvider(['exam:create', 'class:edit']))
final permissionsCheckProvider = Provider.family<Map<String, bool>, List<String>>((
  ref,
  permissions,
) {
  final service = ref.watch(permissionServiceProvider);
  final role = ref.watch(currentUserRoleProvider);
  final userId = ref.watch(currentUserIdProvider);
  final orgId = ref.watch(currentOrgIdProvider);

  return {
    for (final perm in permissions)
      perm: service.hasPermission(
        userId: userId,
        role: role,
        permission: perm,
        orgId: orgId,
      ),
  };
});

// ─── Role Permissions List Provider ───────────────────────────────────────
// Returns all permissions for the current user's role.
final rolePermissionsProvider = Provider<List<String>>((ref) {
  final service = ref.watch(permissionServiceProvider);
  final role = ref.watch(currentUserRoleProvider);
  return service.getPermissionsForRole(role);
});

// ─── Is Owner Check ───────────────────────────────────────────────────────
final isOwnerProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == AppConstants.roleOwner;
});

// ─── Is Admin Check ───────────────────────────────────────────────────────
final isAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == AppConstants.roleOwner ||
      role == AppConstants.roleAdmin ||
      role == AppConstants.roleSuperAdmin;
});

// ─── Is Teacher Check ─────────────────────────────────────────────────────
final isTeacherProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == AppConstants.roleTeacher ||
      role == AppConstants.roleOwner ||
      role == AppConstants.roleAdmin;
});

// ─── Is Student Check ─────────────────────────────────────────────────────
final isStudentProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == AppConstants.roleStudent;
});

// ─── Is Parent Check ──────────────────────────────────────────────────────
final isParentProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);
  return role == AppConstants.roleParent;
});

// ─── Can Manage Exams ─────────────────────────────────────────────────────
final canManageExamsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider(
    const PermissionCheck(permission: Permission.examCreate),
  ));
});

// ─── Can Manage Classes ───────────────────────────────────────────────────
final canManageClassesProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider(
    const PermissionCheck(permission: Permission.classCreate),
  ));
});

// ─── Can Manage People ────────────────────────────────────────────────────
final canManagePeopleProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider(
    const PermissionCheck(permission: Permission.userManage),
  ));
});

// ─── Can View Analytics ───────────────────────────────────────────────────
final canViewAnalyticsProvider = Provider<bool>((ref) {
  return ref.watch(hasPermissionProvider(
    const PermissionCheck(permission: Permission.analyticsView),
  ));
});
