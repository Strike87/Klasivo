// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — People Hub Screen
//
// Tabbed view of all people in the organization:
//   All Users | Students | Teachers | Parents | Staff
//
// Each tab shows a searchable, filterable list with role badges,
// scope indicators, and quick actions (view detail, assign role/scope).
//
// Gated: KlasivoRoleGate(super_admin, owner, admin)
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/theme.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/rbac.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_button.dart';

import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_permission_gate.dart';
import '../../../widgets/klasivo_components.dart';
import '../data/user_management_repository.dart';
import '../providers/user_management_providers.dart';

// ─── People Tab Definition ─────────────────────────────────────────────────────

enum PeopleTab {
  all('All Users', Icons.people_rounded),
  students('Students', Icons.school_rounded),
  teachers('Teachers', Icons.person_rounded),
  parents('Parents', Icons.family_restroom_rounded),
  staff('Staff', Icons.admin_panel_settings_rounded);

  final String label;
  final IconData icon;
  const PeopleTab(this.label, this.icon);
}

// ─── People Hub Screen ─────────────────────────────────────────────────────────

class PeopleHubScreen extends ConsumerStatefulWidget {
  const PeopleHubScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PeopleHubScreen> createState() => _PeopleHubScreenState();
}

class _PeopleHubScreenState extends ConsumerState<PeopleHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: PeopleTab.values.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(peopleSearchQueryProvider.notifier).state = '';
        _searchController.clear();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchQuery = ref.watch(peopleSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: isDark ? AppColors.primaryLight : AppColors.primary,
          unselectedLabelColor:
              isDark ? AppColors.lightTextTertiary : AppColors.darkTextTertiary,
          indicatorColor: isDark ? AppColors.primaryLight : AppColors.primary,
          tabs: PeopleTab.values
              .map((tab) => Tab(
                    icon: Icon(tab.icon, size: 18),
                    text: tab.label,
                  ))
              .toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_rounded),
            tooltip: 'Role Matrix',
            onPressed: () => context.go('/people/roles'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search Bar ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(peopleSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (value) {
                ref.read(peopleSearchQueryProvider.notifier).state = value;
              },
            ),
          ),

          // ─── Tab Content ────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UserListTab(tab: PeopleTab.all, query: searchQuery),
                _UserListTab(tab: PeopleTab.students, query: searchQuery),
                _UserListTab(tab: PeopleTab.teachers, query: searchQuery),
                _UserListTab(tab: PeopleTab.parents, query: searchQuery),
                _UserListTab(tab: PeopleTab.staff, query: searchQuery),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User List Tab ─────────────────────────────────────────────────────────────

class _UserListTab extends ConsumerWidget {
  final PeopleTab tab;
  final String query;

  const _UserListTab({required this.tab, required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUsers = switch (tab) {
      PeopleTab.all => ref.watch(allOrgUsersProvider),
      PeopleTab.students => ref.watch(orgStudentsProvider),
      PeopleTab.teachers => ref.watch(orgTeachersProvider),
      PeopleTab.parents => ref.watch(orgParentsProvider),
      PeopleTab.staff => ref.watch(orgStaffProvider),
    };

    return asyncUsers.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => Center(
        child: Text('Error loading users: $e',
            style: TextStyle(color: AppColors.error)),
      ),
      data: (users) {
        final filtered = filterUsersByQuery(users, query);

        if (filtered.isEmpty) {
          return KlasivoEmptyState(
            icon: tab == PeopleTab.all
                ? Icons.people_outline_rounded
                : Icons.search_off_rounded,
            title: query.isEmpty
                ? 'No ${tab.label.toLowerCase()} yet'
                : 'No results for "$query"',
            subtitle: query.isEmpty
                ? 'Users will appear here once they join the organization'
                : 'Try a different search term',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final user = filtered[index];
            return _UserListTile(user: user);
          },
        );
      },
    );
  }
}

// ─── User List Tile ────────────────────────────────────────────────────────────

class _UserListTile extends ConsumerWidget {
  final UserListItem user;

  const _UserListTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: () => context.go('/people/users/${user.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ─── Avatar ──────────────────────────────────────────
            KlasivoAvatar(
              name: user.fullName,
              imageUrl: user.photoUrl,
              size: KlasivoAvatarSize.md,
            ),
            const SizedBox(width: 12),

            // ─── Info ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.fullName,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoleBadge(role: user.role),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.lightTextTertiary
                          : AppColors.darkTextTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ─── Status Indicators ───────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Scope indicator
                if (KlasivoRole.isScoped(user.role))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.hasScopeAssignment
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: user.hasScopeAssignment
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.hasScopeAssignment ? 'Scoped' : 'No scope',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: user.hasScopeAssignment
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                // Override indicator
                if (user.hasOverrides)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${user.permissionOverrides.length} overrides',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? AppColors.lightTextTertiary
                  : AppColors.darkTextTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Role Badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  Color get _color => switch (role) {
        KlasivoRole.superAdmin => AppColors.primary,
        KlasivoRole.owner => AppColors.primary,
        KlasivoRole.admin => AppColors.primaryLight,
        KlasivoRole.campusManager => AppColors.success,
        KlasivoRole.stageManager => AppColors.success,
        KlasivoRole.academicSupervisor => AppColors.info,
        KlasivoRole.teacher => AppColors.warning,
        KlasivoRole.assistantTeacher => AppColors.warning,
        KlasivoRole.observer => AppColors.lightTextTertiary,
        KlasivoRole.student => AppColors.info,
        KlasivoRole.parent => AppColors.accent,
        _ => AppColors.lightTextTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return KlasivoBadge(
      label: KlasivoRole.displayName(role),
      variant: KlasivoBadgeVariant.custom,
      customColor: _color,
      size: KlasivoBadgeSize.sm,
    );
  }
}
