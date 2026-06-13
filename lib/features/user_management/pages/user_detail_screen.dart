// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — User Detail Screen
//
// 5-tab RBAC profile for a single user:
//   Overview | Scope | Overrides | Effective Permissions | Audit History
//
// Each tab embeds the relevant editor/viewer inline.
// Quick-action FABs for role assignment, scope assignment, and override editing.
//
// Route: /people/users/:userId
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/config/theme.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/role_hierarchy.dart';
import '../../../core/rbac/permission_overrides.dart';
import '../../../core/rbac/permission_groups.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_permission_gate.dart';
import '../../../widgets/klasivo_components.dart';
import '../data/user_management_repository.dart';
import '../providers/user_management_providers.dart';
import 'role_assignment_sheet.dart';
import 'scope_assignment_screen.dart';
import 'permission_override_screen.dart';
import 'effective_permissions_screen.dart';

enum _DetailTab {
  overview('Overview', Icons.person_rounded),
  scope('Scope', Icons.account_tree_rounded),
  overrides('Overrides', Icons.tune_rounded),
  effective('Effective', Icons.verified_user_rounded),
  audit('Audit History', Icons.history_rounded);

  final String label;
  final IconData icon;
  const _DetailTab(this.label, this.icon);
}

class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailScreen({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _DetailTab.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(userRbacProfileProvider(widget.userId));

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('User Details')),
        body: const Center(child: KlasivoLoading()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('User Details')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (profile) {
        final user = profile.user;

        return Scaffold(
          appBar: AppBar(
            title: Text(user.fullName),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: isDark ? AppColors.primaryLight : AppColors.primary,
              unselectedLabelColor: isDark
                  ? AppColors.lightTextTertiary
                  : AppColors.darkTextTertiary,
              indicatorColor:
                  isDark ? AppColors.primaryLight : AppColors.primary,
              tabs: _DetailTab.values
                  .map((tab) => Tab(
                        icon: Icon(tab.icon, size: 16),
                        text: tab.label,
                      ))
                  .toList(),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _OverviewTab(profile: profile),
              _ScopeTab(profile: profile),
              _OverridesTab(profile: profile),
              _EffectiveTab(profile: profile),
              _AuditTab(userId: widget.userId),
            ],
          ),
          // ─── Quick Action FAB ────────────────────────────────────
          floatingActionButton: KlasivoPermissionGate(
            permission: Permission.userAssignRole,
            fallback: const SizedBox.shrink(),
            child: FloatingActionButton.extended(
              onPressed: () => _showRoleAssignment(context, profile),
              icon: const Icon(Icons.shield_rounded),
              label: const Text('Change Role'),
            ),
          ),
        );
      },
    );
  }

  void _showRoleAssignment(BuildContext context, UserRbacProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => RoleAssignmentSheet(
        userId: profile.user.id,
        currentRole: profile.user.role,
        userName: profile.user.fullName,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends ConsumerWidget {
  final UserRbacProfile profile;

  const _OverviewTab({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = profile.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── User Identity Card ─────────────────────────────────────
        KlasivoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                KlasivoAvatar(
                  name: user.fullName,
                  imageUrl: user.photoUrl,
                  size: KlasivoAvatarSize.lg,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(user.email ?? 'No email',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.lightTextSecondary
                                : AppColors.darkTextSecondary,
                          )),
                      const SizedBox(height: 8),
                      _RoleBadge(role: user.role),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── RBAC Summary ──────────────────────────────────────────
        KlasivoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RBAC Summary',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Role',
                  value: KlasivoRole.displayName(user.role),
                  icon: Icons.shield_rounded,
                ),
                _InfoRow(
                  label: 'Scope Level',
                  value: user.scopeAccessLevel ?? 'Not set',
                  icon: Icons.account_tree_rounded,
                ),
                _InfoRow(
                  label: 'Scope Assigned',
                  value: user.hasScopeAssignment ? 'Yes' : 'No',
                  icon: Icons.check_circle_rounded,
                  valueColor: user.hasScopeAssignment
                      ? AppColors.success
                      : (KlasivoRole.isScoped(user.role)
                          ? AppColors.warning
                          : null),
                ),
                _InfoRow(
                  label: 'Permission Overrides',
                  value: user.hasOverrides
                      ? '${user.permissionOverrides.length} active'
                      : 'None',
                  icon: Icons.tune_rounded,
                ),
                _InfoRow(
                  label: 'Role Version',
                  value: '${profile.roleVersion}',
                  icon: Icons.update_rounded,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Role Description ───────────────────────────────────────
        KlasivoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role Description',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  KlasivoRole.scopeDescription(user.role),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.lightTextSecondary
                        : AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                // Show inherited roles
                Text('Inherits from:',
                    style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                _InheritanceChain(role: user.role),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Quick Stats ────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Default Perms',
                value:
                    '${RoleResolver.getEffectivePermissions(user.role).length}',
                icon: Icons.vpn_key_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Overrides',
                value: '${user.permissionOverrides.length}',
                icon: Icons.tune_rounded,
                color: user.hasOverrides ? AppColors.warning : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Effective',
                value:
                    '${PermissionOverrides.applyToRole(user.role, Map<String, bool>.from(user.permissionOverrides)).length}',
                icon: Icons.verified_user_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCOPE TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ScopeTab extends ConsumerWidget {
  final UserRbacProfile profile;

  const _ScopeTab({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = profile.user;
    final isScoped = KlasivoRole.isScoped(user.role);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scope level indicator
        KlasivoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_tree_rounded,
                        color: isScoped ? AppColors.warning : AppColors.success,
                        size: 20),
                    const SizedBox(width: 8),
                    Text('Scope Access Level',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isScoped
                      ? 'This role requires scope assignment to access data'
                      : 'This role has full access within the organization',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isScoped ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Current scope assignments
        if (user.campusIds.isNotEmpty)
          _ScopeChipList(
              label: 'Campuses', ids: user.campusIds, type: 'campus'),
        if (user.stageIds.isNotEmpty)
          _ScopeChipList(
              label: 'Stages', ids: user.stageIds, type: 'stage'),
        if (user.classIds.isNotEmpty)
          _ScopeChipList(
              label: 'Classes', ids: user.classIds, type: 'class'),
        if (user.subjectIds.isNotEmpty)
          _ScopeChipList(
              label: 'Subjects', ids: user.subjectIds, type: 'subject'),

        if (!user.hasScopeAssignment && isScoped)
          KlasivoCard(
            accentColor: AppColors.warning,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No scope assigned. This user cannot access any data until scope is set.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Edit scope button
        KlasivoPermissionGate(
          permission: Permission.userAssignRole,
          fallback: const SizedBox.shrink(),
          child: KlasivoButton(
            label: 'Edit Scope Assignment',
            icon: Icons.edit_rounded,
            variant: KlasivoButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ScopeAssignmentScreen(
                    userId: user.id,
                    userName: user.fullName,
                    currentRole: user.role,
                    currentCampusIds: user.campusIds,
                    currentStageIds: user.stageIds,
                    currentClassIds: user.classIds,
                    currentSubjectIds: user.subjectIds,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERRIDES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _OverridesTab extends ConsumerWidget {
  final UserRbacProfile profile;

  const _OverridesTab({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = profile.user;
    final overrides = Map<String, bool>.from(user.permissionOverrides);
    final diff = PermissionOverrides.getOverrideDiff(user.role, overrides);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Diff summary card
        KlasivoCard(
          accentColor: diff.hasOverrides ? AppColors.warning : AppColors.success,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Override Impact', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  diff.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: diff.hasOverrides ? AppColors.warning : AppColors.success,
                  ),
                ),
                if (diff.hasGrants) ...[
                  const SizedBox(height: 8),
                  Text('+${diff.grantedByOverrides.length} permissions granted',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success)),
                ],
                if (diff.hasDenials) ...[
                  const SizedBox(height: 4),
                  Text('-${diff.deniedByOverrides.length} permissions denied',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.error)),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Edit overrides button
        KlasivoPermissionGate(
          permission: Permission.userAssignRole,
          fallback: const SizedBox.shrink(),
          child: KlasivoButton(
            label: 'Edit Permission Overrides',
            icon: Icons.tune_rounded,
            variant: KlasivoButtonVariant.secondary,
            fullWidth: true,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PermissionOverrideScreen(
                    userId: user.id,
                    userName: user.fullName,
                    currentRole: user.role,
                    currentOverrides: overrides,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // List of current overrides
        if (overrides.isEmpty)
          KlasivoEmptyState(
            icon: Icons.tune_rounded,
            title: 'No overrides',
            subtitle: 'This user uses their role\'s default permissions',
          )
        else
          ...overrides.entries.map((entry) => _OverrideTile(
                permission: entry.key,
                isGranted: entry.value,
              )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EFFECTIVE PERMISSIONS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _EffectiveTab extends StatelessWidget {
  final UserRbacProfile profile;

  const _EffectiveTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return EffectivePermissionsViewer(
      role: profile.user.role,
      overrides: Map<String, bool>.from(profile.user.permissionOverrides),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AUDIT HISTORY TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _AuditTab extends ConsumerWidget {
  final String userId;

  const _AuditTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auditAsync = ref.watch(userAuditHistoryProvider(userId));

    return auditAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.history_rounded,
            title: 'No audit history',
            subtitle: 'RBAC changes for this user will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final log = logs[index];
            final action = log['action'] as String? ?? '';
            final targetType = log['targetType'] as String? ?? '';
            final details = log['details'] as String? ?? '';
            final userName = log['userName'] as String? ?? 'System';
            final timestamp = log['timestamp'];

            final timeText = timestamp != null
                ? timeago.format((timestamp as dynamic).toDate() as DateTime)
                : '';

            return KlasivoCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _AuditActionIcon(action: action),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _auditDescription(action, targetType, details),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'By $userName · $timeText',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.lightTextTertiary
                                  : AppColors.darkTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _auditDescription(String action, String targetType, String details) {
    if (details.isNotEmpty) return details;
    final verb = switch (action) {
      'create' => 'Created',
      'update' => 'Updated',
      'delete' => 'Deleted',
      'assign_role' => 'Role assigned',
      'assign_scope' => 'Scope assigned',
      'set_overrides' => 'Overrides set',
      _ => action,
    };
    return '$verb ${targetType.isNotEmpty ? targetType.replaceAll('_', ' ') : ''}'.trim();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16,
              color: valueColor ?? AppColors.lightTextTertiary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              )),
        ],
      ),
    );
  }
}

class _InheritanceChain extends StatelessWidget {
  final String role;

  const _InheritanceChain({required this.role});

  @override
  Widget build(BuildContext context) {
    final ancestors = RoleHierarchy.getAncestors(role);
    final descendants = RoleHierarchy.getDescendants(role);

    if (ancestors.isEmpty && descendants.isEmpty) {
      return const Text('Standalone role — no inheritance',
          style: TextStyle(fontStyle: FontStyle.italic));
    }

    final chain = <String>[
      ...ancestors.toList()..reversed,
      role,
    ];

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: chain
          .map((r) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (r != chain.first)
                    const Icon(Icons.arrow_right_rounded, size: 16),
                  KlasivoBadge(
                    label: KlasivoRole.displayName(r),
                    variant: r == role
                        ? KlasivoBadgeVariant.custom
                        : KlasivoBadgeVariant.neutral,
                    customColor: r == role ? AppColors.primary : null,
                    size: KlasivoBadgeSize.sm,
                  ),
                ],
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KlasivoCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 4),
            Text(label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ScopeChipList extends StatelessWidget {
  final String label;
  final List<String> ids;
  final String type;

  const _ScopeChipList({
    required this.label,
    required this.ids,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ids
                .map((id) => Chip(
                      label: Text(id,
                          style: theme.textTheme.labelSmall),
                      avatar: Icon(
                        _typeIcon,
                        size: 14,
                      ),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  IconData get _typeIcon => switch (type) {
        'campus' => Icons.location_city_rounded,
        'stage' => Icons.stairs_rounded,
        'class' => Icons.class__rounded,
        'subject' => Icons.book_rounded,
        _ => Icons.circle_rounded,
      };
}

class _OverrideTile extends StatelessWidget {
  final String permission;
  final bool isGranted;

  const _OverrideTile({required this.permission, required this.isGranted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = Permission.categoryOf(permission);
    final action = permission.contains(':')
        ? permission.split(':')[1]
        : permission;

    return KlasivoCard(
      accentColor: isGranted ? AppColors.success : AppColors.error,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
              color: isGranted ? AppColors.success : AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(permission,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  Text(category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isGranted ? AppColors.success : AppColors.error,
                      )),
                ],
              ),
            ),
            KlasivoBadge(
              label: isGranted ? 'GRANT' : 'DENY',
              variant: KlasivoBadgeVariant.custom,
              customColor: isGranted ? AppColors.success : AppColors.error,
              size: KlasivoBadgeSize.sm,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditActionIcon extends StatelessWidget {
  final String action;

  const _AuditActionIcon({required this.action});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (action) {
      'create' => (Icons.add_circle_rounded, AppColors.success),
      'update' => (Icons.edit_rounded, AppColors.info),
      'delete' => (Icons.delete_rounded, AppColors.error),
      'assign_role' => (Icons.shield_rounded, AppColors.primary),
      'assign_scope' => (Icons.account_tree_rounded, AppColors.warning),
      'set_overrides' => (Icons.tune_rounded, AppColors.accent),
      _ => (Icons.info_rounded, AppColors.lightTextTertiary),
    };

    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

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
      size: KlasivoBadgeSize.md,
    );
  }
}
