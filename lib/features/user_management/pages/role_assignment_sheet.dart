// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Role Assignment Bottom Sheet
//
// Shows the role hierarchy tree with the current role highlighted,
// and a detailed impact preview when selecting a new role:
//   - Permission count delta (e.g., "+63 new permissions")
//   - Scope requirement indicator
//   - Escalation warning for promotions
//
// Calls the `assignRole` Cloud Function on confirm.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/role_hierarchy.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/scope_access_level.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_toast.dart';
import '../data/user_management_repository.dart';
import '../providers/user_management_providers.dart';

class RoleAssignmentSheet extends ConsumerStatefulWidget {
  final String userId;
  final String currentRole;
  final String userName;

  const RoleAssignmentSheet({
    Key? key,
    required this.userId,
    required this.currentRole,
    required this.userName,
  }) : super(key: key);

  @override
  ConsumerState<RoleAssignmentSheet> createState() =>
      _RoleAssignmentSheetState();
}

class _RoleAssignmentSheetState extends ConsumerState<RoleAssignmentSheet> {
  String? _selectedRole;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isChanged = _selectedRole != widget.currentRole;
    final isPromotion = isChanged &&
        RoleHierarchy.inheritsFrom(widget.currentRole, _selectedRole!);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ─── Handle ──────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ─── Title ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Change Role', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  if (isChanged)
                    KlasivoBadge(
                      label: 'Modified',
                      variant: KlasivoBadgeVariant.custom,
                      customColor: AppColors.warning,
                      size: KlasivoBadgeSize.sm,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ─── Impact Preview ──────────────────────────────────────
            if (isChanged) _ImpactPreview(currentRole: widget.currentRole, selectedRole: _selectedRole!),

            // ─── Role List ──────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Management roles section
                  _SectionHeader(title: 'Management Roles'),
                  ...KlasivoRole.managementRoles.map(
                    (role) => _RoleTile(
                      role: role,
                      isSelected: _selectedRole == role,
                      isCurrent: widget.currentRole == role,
                      onTap: () => setState(() => _selectedRole = role),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Standalone roles section
                  _SectionHeader(title: 'Standalone Roles'),
                  ...[KlasivoRole.student, KlasivoRole.parent].map(
                    (role) => _RoleTile(
                      role: role,
                      isSelected: _selectedRole == role,
                      isCurrent: widget.currentRole == role,
                      onTap: () => setState(() => _selectedRole = role),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Action Bar ──────────────────────────────────────────
            if (isChanged)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KlasivoButton(
                        label: 'Cancel',
                        variant: KlasivoButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KlasivoButton(
                        label: 'Assign Role',
                        variant: isPromotion
                            ? KlasivoButtonVariant.danger
                            : KlasivoButtonVariant.primary,
                        icon: Icons.shield_rounded,
                        loading: _loading,
                        onPressed: _assignRole,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _assignRole() async {
    if (_selectedRole == null || _loading) return;

    setState(() => _loading = true);
    ref.read(userManagementLoadingProvider.notifier).state = true;
    ref.read(userManagementErrorProvider.notifier).state = null;

    try {
      await ref.read(userManagementRepoProvider).assignRole(
            targetUserId: widget.userId,
            newRole: _selectedRole!,
          );

      if (mounted) {
        KlasivoToast.show(
          context,
          message:
              'Role changed to ${KlasivoRole.displayName(_selectedRole!)}',
          type: KlasivoToastType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ref.read(userManagementErrorProvider.notifier).state = e.toString();
      if (mounted) {
        KlasivoToast.show(
          context,
          message: 'Failed to assign role: $e',
          type: KlasivoToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      ref.read(userManagementLoadingProvider.notifier).state = false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMPACT PREVIEW — Shows permission count delta and scope requirement
// ═══════════════════════════════════════════════════════════════════════════════

class _ImpactPreview extends StatelessWidget {
  final String currentRole;
  final String selectedRole;

  const _ImpactPreview({
    required this.currentRole,
    required this.selectedRole,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPerms = RoleResolver.getEffectivePermissions(currentRole);
    final newPerms = RoleResolver.getEffectivePermissions(selectedRole);
    final gained = newPerms.difference(currentPerms);
    final lost = currentPerms.difference(newPerms);
    final isPromotion = gained.length > lost.length;

    final newScopeLevel = scopeAccessLevelForRole(selectedRole);
    final requiresScope = KlasivoRole.isScoped(selectedRole);
    final currentScopeLevel = scopeAccessLevelForRole(currentRole);
    final scopeChanged = newScopeLevel != currentScopeLevel;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: KlasivoCard(
        accentColor: isPromotion ? AppColors.warning : AppColors.info,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Permission Delta ───────────────────────────────
              Row(
                children: [
                  Text(KlasivoRole.displayName(currentRole),
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_downward_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(KlasivoRole.displayName(selectedRole),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),

              // Current → New permission counts
              Row(
                children: [
                  _PermCountChip(
                      label: 'Current', count: currentPerms.length),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                  const SizedBox(width: 8),
                  _PermCountChip(
                      label: 'New', count: newPerms.length),
                ],
              ),
              const SizedBox(height: 8),

              // Delta
              if (gained.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_rounded,
                          color: AppColors.success, size: 14),
                      const SizedBox(width: 4),
                      Text('+${gained.length} new permissions',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.success)),
                    ],
                  ),
                ),
              if (lost.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.remove_circle_rounded,
                        color: AppColors.error, size: 14),
                    const SizedBox(width: 4),
                    Text('-${lost.length} permissions removed',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error)),
                  ],
                ),

              const Divider(height: 16),

              // ─── Scope Requirement ──────────────────────────────
              Row(
                children: [
                  Text('Scope Required',
                      style: theme.textTheme.bodySmall),
                  const Spacer(),
                  if (requiresScope)
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.warning, size: 14),
                        const SizedBox(width: 4),
                        Text('Yes — ${_scopeLabel(newScopeLevel)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 14),
                        const SizedBox(width: 4),
                        Text('No — full org access',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.success)),
                      ],
                    ),
                ],
              ),

              // Escalation warning
              if (isPromotion && gained.length > 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This is a significant permission escalation. Verify this change is intentional.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (scopeChanged && requiresScope)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_rounded,
                            color: AppColors.warning, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'After role change, this user will need scope assignment before they can access data.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _scopeLabel(ScopeAccessLevel level) => switch (level) {
        ScopeAccessLevel.all => 'All',
        ScopeAccessLevel.campus => 'Campus',
        ScopeAccessLevel.stage => 'Stage',
        ScopeAccessLevel.class_ => 'Class',
        ScopeAccessLevel.self => 'Self only',
        ScopeAccessLevel.linked => 'Linked children',
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE TILE — Single role option in the list
// ═══════════════════════════════════════════════════════════════════════════════

class _RoleTile extends StatelessWidget {
  final String role;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _RoleTile({
    required this.role,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final permCount = RoleResolver.getEffectivePermissions(role).length;
    final requiresScope = KlasivoRole.isScoped(role);
    final depth = RoleHierarchy.depth(role);

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: KlasivoCard(
        variant: isSelected
            ? KlasivoCardVariant.filled
            : KlasivoCardVariant.interactive,
        accentColor: isSelected ? AppColors.primary : null,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Radio indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 14,
                        color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),

              // Role info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(KlasivoRole.displayName(role),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                            )),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          KlasivoBadge(
                            label: 'Current',
                            variant: KlasivoBadgeVariant.custom,
                            customColor: AppColors.info,
                            size: KlasivoBadgeSize.sm,
                          ),
                        ],
                        if (requiresScope) ...[
                          const SizedBox(width: 8),
                          KlasivoBadge(
                            label: 'Scoped',
                            variant: KlasivoBadgeVariant.custom,
                            customColor: AppColors.warning,
                            size: KlasivoBadgeSize.sm,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$permCount permissions · ${KlasivoRole.scopeDescription(role)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.lightTextTertiary
                            : AppColors.darkTextTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.lightTextTertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
    );
  }
}

class _PermCountChip extends StatelessWidget {
  final String label;
  final int count;

  const _PermCountChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
