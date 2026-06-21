// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Effective Permissions Viewer
//
// Read-only computed view showing how a user's effective permissions
// are derived from their role defaults + overrides.
//
// Displays:
//   - OverrideDiff visualization (granted/denied by overrides)
//   - Category-grouped permission list with status indicators
//   - Summary statistics
//
// Used inline in the User Detail "Effective" tab and standalone.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../core/config/theme.dart';
import '../../../core/tokens/tokens.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/role_hierarchy.dart';
import '../../../core/rbac/permission_overrides.dart';
import '../../../core/rbac/permission_groups.dart';
import '../../../core/rbac/roles.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_badge.dart';

class EffectivePermissionsViewer extends StatelessWidget {
  final String role;
  final Map<String, bool> overrides;

  const EffectivePermissionsViewer({
    Key? key,
    required this.role,
    this.overrides = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diff = PermissionOverrides.getOverrideDiff(role, overrides);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Summary Card ──────────────────────────────────────────
        KlasivoCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Effective Permissions',
                        style: theme.textTheme.titleMedium),
                    const Spacer(),
                    KlasivoBadge(
                      label: '${diff.effectivePermissions.length} total',
                      variant: KlasivoBadgeVariant.custom,
                      customColor: AppColors.primary,
                      size: KlasivoBadgeSize.md,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Role defaults',
                  count: diff.defaultPermissions.length,
                  color: AppColors.info,
                ),
                if (diff.hasGrants)
                  _SummaryRow(
                    label: 'Granted by overrides',
                    count: diff.grantedByOverrides.length,
                    color: AppColors.success,
                  ),
                if (diff.hasDenials)
                  _SummaryRow(
                    label: 'Denied by overrides',
                    count: diff.deniedByOverrides.length,
                    color: AppColors.error,
                  ),
                const Divider(height: 20),
                _SummaryRow(
                  label: 'Effective total',
                  count: diff.effectivePermissions.length,
                  color: AppColors.primary,
                  isBold: true,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Role Info ─────────────────────────────────────────────
        KlasivoCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Role: ', style: theme.textTheme.bodySmall),
                Text(KlasivoRole.displayName(role),
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                if (diff.hasOverrides)
                  KlasivoBadge(
                    label: diff.summary,
                    variant: KlasivoBadgeVariant.custom,
                    customColor: AppColors.warning,
                    size: KlasivoBadgeSize.sm,
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ─── Category-Grouped Permissions ──────────────────────────
        ...Permission.categories.entries.map((entry) {
          final category = entry.key;
          final perms = entry.value;

          // Only show categories that have at least one effective permission
          final effectiveInCategory = perms
              .where((p) => diff.effectivePermissions.contains(p))
              .toList();
          if (effectiveInCategory.isEmpty) return const SizedBox.shrink();

          final deniedInCategory = perms
              .where((p) => diff.deniedByOverrides.contains(p))
              .toList();
          final grantedInCategory = perms
              .where((p) => diff.grantedByOverrides.contains(p))
              .toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: KlasivoCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _categoryDisplayName(category),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${effectiveInCategory.length}/${perms.length}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Permission list
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: perms.map((perm) {
                        final isEffective =
                            diff.effectivePermissions.contains(perm);
                        final isDenied =
                            diff.deniedByOverrides.contains(perm);
                        final isGranted =
                            diff.grantedByOverrides.contains(perm);

                        return _PermissionChip(
                          permission: perm,
                          isEffective: isEffective,
                          isDenied: isDenied,
                          isGranted: isGranted,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _categoryDisplayName(String cat) => switch (cat) {
        'org' => 'Organization',
        'users' => 'Users',
        'students' => 'Students',
        'attendance' => 'Attendance',
        'assignments' => 'Assignments',
        'exams' => 'Exams',
        'questions' => 'Questions',
        'messaging' => 'Messaging',
        'analytics' => 'Analytics',
        'billing' => 'Billing',
        'reports' => 'Reports',
        'notifications' => 'Notifications',
        'stages' => 'Stages',
        'classes' => 'Classes',
        'subjects' => 'Subjects',
        'groups' => 'Groups',
        'results' => 'Results',
        'lessons' => 'Lessons',
        'materials' => 'Materials',
        'progress' => 'Progress',
        'parent' => 'Parent',
        'integrity' => 'Integrity',
        'fees' => 'Fees',
        'payments' => 'Payments',
        'payroll' => 'Payroll',
        'inventory' => 'Inventory',
        _ => cat[0].toUpperCase() + cat.substring(1),
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SummaryRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.count,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: isBold
                    ? theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)
                    : theme.textTheme.bodySmall),
          ),
          Text('$count',
              style: (isBold ? theme.textTheme.bodyLarge : theme.textTheme.bodyMedium)
                  ?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              )),
        ],
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  final String permission;
  final bool isEffective;
  final bool isDenied;
  final bool isGranted;

  const _PermissionChip({
    required this.permission,
    required this.isEffective,
    required this.isDenied,
    required this.isGranted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (bgColor, borderColor, textColor) = isDenied
        ? (AppColors.error.withOpacity(0.06),
            AppColors.error.withOpacity(0.3),
            AppColors.error)
        : isGranted
            ? (AppColors.success.withOpacity(0.06),
                AppColors.success.withOpacity(0.3),
                AppColors.success)
            : isEffective
                ? (AppColors.primary.withOpacity(0.06),
                    AppColors.primary.withOpacity(0.2),
                    isDark ? AppColors.primaryLight : AppColors.primary)
                : (AppColors.lightTextTertiary.withOpacity(0.04),
                    AppColors.lightTextTertiary.withOpacity(0.15),
                    AppColors.lightTextTertiary);

    final action = permission.contains(':')
        ? permission.split(':')[1]
        : permission;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDenied
                ? Icons.remove_circle_outline_rounded
                : isGranted
                    ? Icons.add_circle_outline_rounded
                    : isEffective
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
            size: 10,
            color: textColor,
          ),
          const SizedBox(width: 3),
          Text(
            action,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 10,
              decoration: isDenied ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
