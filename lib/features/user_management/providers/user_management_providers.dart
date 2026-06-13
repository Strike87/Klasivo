// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — User Management Providers
//
// Riverpod providers for the People Hub and User Management screens.
// Provides org-scoped user lists (filtered by role tabs), user RBAC profiles,
// scope tree data, audit history, and Cloud Function call wrappers.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/roles.dart';
import '../../../providers/auth_provider.dart';
import '../data/user_management_repository.dart';

// ─── Repository Provider ──────────────────────────────────────────────────────

final userManagementRepoProvider = Provider<UserManagementRepository>((ref) {
  return UserManagementRepository();
});

// ─── People Hub: Org-scoped User Lists ────────────────────────────────────────

/// All active users in the current organization.
final allOrgUsersProvider = StreamProvider<List<UserListItem>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return Stream.value([]);
  return ref.read(userManagementRepoProvider).getUsersStream(orgId);
});

/// Students only (role = 'student').
final orgStudentsProvider = StreamProvider<List<UserListItem>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return Stream.value([]);
  return ref.read(userManagementRepoProvider).getUsersByRoleStream(
        orgId,
        KlasivoRole.student,
      );
});

/// Teachers + Assistant Teachers.
final orgTeachersProvider = StreamProvider<List<UserListItem>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return Stream.value([]);
  return ref.read(userManagementRepoProvider).getUsersByRolesStream(
        orgId,
        [KlasivoRole.teacher, KlasivoRole.assistantTeacher],
      );
});

/// Parents only.
final orgParentsProvider = StreamProvider<List<UserListItem>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return Stream.value([]);
  return ref.read(userManagementRepoProvider).getUsersByRoleStream(
        orgId,
        KlasivoRole.parent,
      );
});

/// Staff = all management roles (super_admin, owner, admin, campus_manager,
/// stage_manager, academic_supervisor, observer).
final orgStaffProvider = StreamProvider<List<UserListItem>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return Stream.value([]);
  return ref.read(userManagementRepoProvider).getUsersByRolesStream(
        orgId,
        KlasivoRole.managementRoles,
      );
});

// ─── Search / Filter ──────────────────────────────────────────────────────────

/// Search query state for the People Hub.
final peopleSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filters a user list by search query (name or email).
List<UserListItem> filterUsersByQuery(
    List<UserListItem> users, String query) {
  if (query.isEmpty) return users;
  final q = query.toLowerCase();
  return users
      .where((u) =>
          u.fullName.toLowerCase().contains(q) ||
          (u.email?.toLowerCase().contains(q) ?? false))
      .toList();
}

// ─── User Detail: Single User RBAC Profile ────────────────────────────────────

/// Stream a single user's full RBAC profile.
final userRbacProfileProvider =
    StreamProvider.family<UserRbacProfile, String>((ref, userId) {
  return ref.read(userManagementRepoProvider).getUserRbacProfileStream(userId);
});

// ─── Scope Tree ───────────────────────────────────────────────────────────────

/// Scope tree for the current organization (Campus → Stage → Class).
final scopeTreeProvider = FutureProvider<List<ScopeTreeNode>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return [];
  return ref.read(userManagementRepoProvider).buildScopeTree(orgId);
});

/// Campuses only (for campus_manager scope assignment).
final campusesProvider = FutureProvider<List<ScopeTreeNode>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return [];
  return ref.read(userManagementRepoProvider).getCampuses(orgId);
});

/// Stages only (for stage_manager/academic_supervisor scope assignment).
final stagesProvider = FutureProvider<List<ScopeTreeNode>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return [];
  return ref.read(userManagementRepoProvider).getStages(orgId);
});

/// Classes only (for teacher/assistant_teacher scope assignment).
final classesProvider = FutureProvider<List<ScopeTreeNode>>((ref) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return [];
  return ref.read(userManagementRepoProvider).getClasses(orgId);
});

// ─── Audit History ────────────────────────────────────────────────────────────

/// Audit log entries for a specific user.
final userAuditHistoryProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  final orgId = ref.watch(organizationIdProvider);
  if (orgId == null) return Stream.value([]);
  return ref.read(userManagementRepoProvider).getUserAuditStream(
        orgId,
        userId,
        limit: 50,
      );
});

// ─── CF Action State ──────────────────────────────────────────────────────────

/// Loading state for CF actions (assignRole, assignScope, setOverrides).
final userManagementLoadingProvider = StateProvider<bool>((ref) => false);

/// Error state for CF actions.
final userManagementErrorProvider = StateProvider<String?>((ref) => null);
