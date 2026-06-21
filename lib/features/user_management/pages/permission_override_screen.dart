// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Permission Override Screen
//
// Category-grouped toggle grid for permission overrides with:
//   - Quick-apply presets (Teacher Full, Teacher No Publish, Teacher Grade Only,
//     Read Only Observer, Custom)
//   - "Preview Diff" showing OverrideDiff before saving
//   - Category expansion/collapse
//
// Calls `setPermissionOverrides` Cloud Function with merge mode.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../core/tokens/tokens.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/permission_overrides.dart';
import '../../../core/rbac/permission_groups.dart';
import '../../../core/rbac/role_hierarchy.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_toast.dart';
import '../providers/user_management_providers.dart';

// ─── Preset Definitions ────────────────────────────────────────────────────────

enum OverridePreset {
  teacherFull('Teacher Full', 'All default teacher permissions — no restrictions'),
  teacherNoPublish('Teacher No Publish', 'Cannot publish exams or assignments'),
  teacherGradeOnly('Teacher Grade Only', 'Can only grade — no create/edit/publish'),
  readOnlyObserver('Read Only Observer', 'No write permissions — view only'),
  custom('Custom', 'Manually configure permission overrides');

  final String label;
  final String description;
  const OverridePreset(this.label, this.description);

  /// Build override map for a preset, relative to a role's defaults.
  Map<String, bool> buildOverrides(String role) {
    return switch (this) {
      OverridePreset.teacherFull => {}, // No overrides = full role defaults
      OverridePreset.teacherNoPublish => PermissionGroups.teacherNoPublish,
      OverridePreset.teacherGradeOnly => PermissionGroups.gradeOnly,
      OverridePreset.readOnlyObserver => _buildReadOnlyOverrides(role),
      OverridePreset.custom => {}, // User will toggle manually
    };
  }

  /// Build a read-only override set: deny all write actions, keep reads.
  static Map<String, bool> _buildReadOnlyOverrides(String role) {
    final defaults = RoleResolver.getEffectivePermissions(role);
    final writeActions = {'create', 'edit', 'delete', 'publish', 'grade',
        'upload', 'manage', 'send', 'mark', 'broadcast', 'submit'};
    final overrides = <String, bool>{};

    for (final perm in defaults) {
      final parts = perm.split(':');
      if (parts.length == 2 && writeActions.contains(parts[1])) {
        overrides[perm] = false;
      }
    }
    return overrides;
  }
}

// ─── Permission Override Screen ────────────────────────────────────────────────

class PermissionOverrideScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String currentRole;
  final Map<String, bool> currentOverrides;

  const PermissionOverrideScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.currentRole,
    this.currentOverrides = const {},
  }) : super(key: key);

  @override
  ConsumerState<PermissionOverrideScreen> createState() =>
      _PermissionOverrideScreenState();
}

class _PermissionOverrideScreenState
    extends ConsumerState<PermissionOverrideScreen> {
  late Map<String, bool> _overrides;
  OverridePreset _selectedPreset = OverridePreset.custom;
  bool _showDiffPreview = false;
  bool _loading = false;
  final _expandedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    _overrides = Map.from(widget.currentOverrides);
    _detectPreset();
  }

  /// Auto-detect which preset matches current overrides.
  void _detectPreset() {
    if (_overrides.isEmpty) {
      _selectedPreset = OverridePreset.teacherFull;
      return;
    }

    for (final preset in OverridePreset.values) {
      if (preset == OverridePreset.custom) continue;
      final presetOverrides = preset.buildOverrides(widget.currentRole);
      if (_mapsEqual(_overrides, presetOverrides)) {
        _selectedPreset = preset;
        return;
      }
    }
    _selectedPreset = OverridePreset.custom;
  }

  bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diff = PermissionOverrides.getOverrideDiff(
        widget.currentRole, _overrides);
    final hasChanges = !_mapsEqual(_overrides, widget.currentOverrides);

    return Scaffold(
      appBar: AppBar(
        title: Text('Overrides: ${widget.userName}'),
        actions: [
          if (hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KlasivoButton(
                label: 'Save',
                variant: KlasivoButtonVariant.primary,
                size: KlasivoButtonSize.sm,
                icon: Icons.check_rounded,
                loading: _loading,
                onPressed: _save,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Preset Selector ──────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            child: KlasivoCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Presets',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: OverridePreset.values
                          .map((preset) => _PresetChip(
                                preset: preset,
                                isSelected: _selectedPreset == preset,
                                onTap: () => _applyPreset(preset),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Diff Summary ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: KlasivoCard(
              accentColor: diff.hasOverrides
                  ? AppColors.warning
                  : AppColors.success,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        diff.summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: diff.hasOverrides
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ),
                    KlasivoButton(
                      label: _showDiffPreview ? 'Hide Diff' : 'Preview',
                      variant: KlasivoButtonVariant.ghost,
                      size: KlasivoButtonSize.sm,
                      onPressed: () =>
                          setState(() => _showDiffPreview = !_showDiffPreview),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Diff Preview (collapsible) ───────────────────────────
          if (_showDiffPreview)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: KlasivoCard(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (diff.grantedByOverrides.isNotEmpty) ...[
                        Text('+ Granted by overrides:',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.success)),
                        ...diff.grantedByOverrides
                            .take(10)
                            .map((p) => Text('  + $p',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.success))),
                        if (diff.grantedByOverrides.length > 10)
                          Text(
                              '  ... and ${diff.grantedByOverrides.length - 10} more',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.success)),
                      ],
                      if (diff.deniedByOverrides.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('- Denied by overrides:',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.error)),
                        ...diff.deniedByOverrides
                            .take(10)
                            .map((p) => Text('  - $p',
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.error))),
                        if (diff.deniedByOverrides.length > 10)
                          Text(
                              '  ... and ${diff.deniedByOverrides.length - 10} more',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ─── Category-Grouped Override Toggles ───────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: Permission.categories.entries.map((entry) {
                final category = entry.key;
                final perms = entry.value;
                final isExpanded = _expandedCategories.contains(category);

                return _CategorySection(
                  category: category,
                  permissions: perms,
                  overrides: _overrides,
                  roleDefaults:
                      RoleResolver.getEffectivePermissions(widget.currentRole),
                  isExpanded: isExpanded,
                  onToggleExpand: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedCategories.remove(category);
                      } else {
                        _expandedCategories.add(category);
                      }
                    });
                  },
                  onOverrideChanged: _toggleOverride,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(OverridePreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != OverridePreset.custom) {
        _overrides = Map.from(preset.buildOverrides(widget.currentRole));
      }
    });
  }

  void _toggleOverride(String permission, bool? value) {
    setState(() {
      _selectedPreset = OverridePreset.custom;
      if (value == null) {
        // Remove override (revert to role default)
        _overrides.remove(permission);
      } else {
        _overrides[permission] = value;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    try {
      await ref.read(userManagementRepoProvider).setPermissionOverrides(
            targetUserId: widget.userId,
            overrides: _overrides,
            mode: 'replace', // Full replacement since we show all overrides
          );

      if (mounted) {
        KlasivoToast.show(
          context,
          message: 'Permission overrides updated',
          type: KlasivoToastType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.show(
          context,
          message: 'Failed to save overrides: $e',
          type: KlasivoToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRESET CHIP
// ═══════════════════════════════════════════════════════════════════════════════

class _PresetChip extends StatelessWidget {
  final OverridePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.lightTextTertiary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
            if (isSelected) const SizedBox(width: 4),
            Text(
              preset.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? AppColors.primary : AppColors.lightTextTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATEGORY SECTION — Expandable permission group
// ═══════════════════════════════════════════════════════════════════════════════

class _CategorySection extends StatelessWidget {
  final String category;
  final List<String> permissions;
  final Map<String, bool> overrides;
  final Set<String> roleDefaults;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(String permission, bool? value) onOverrideChanged;

  const _CategorySection({
    required this.category,
    required this.permissions,
    required this.overrides,
    required this.roleDefaults,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOverrideChanged,
  });

  /// Count how many permissions in this category have overrides.
  int get _overrideCount {
    return permissions.where((p) => overrides.containsKey(p)).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KlasivoCard(
        child: Column(
          children: [
            // ─── Category Header ───────────────────────────────────
            InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.lightTextTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _categoryDisplayName(category),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text('${permissions.length} perms',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.lightTextTertiary)),
                    if (_overrideCount > 0) ...[
                      const SizedBox(width: 6),
                      KlasivoBadge(
                        label: '$_overrideCount',
                        variant: KlasivoBadgeVariant.custom,
                        customColor: AppColors.warning,
                        size: KlasivoBadgeSize.sm,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ─── Permission Toggles ────────────────────────────────
            if (isExpanded)
              Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            if (isExpanded)
              ...permissions.map((perm) => _PermissionToggleRow(
                    permission: perm,
                    hasOverride: overrides.containsKey(perm),
                    overrideValue: overrides[perm],
                    isDefault: roleDefaults.contains(perm),
                    onChanged: (value) => onOverrideChanged(perm, value),
                    onClear: () => onOverrideChanged(perm, null),
                  )),
          ],
        ),
      ),
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
// PERMISSION TOGGLE ROW — Single permission with 3-state toggle
// ═══════════════════════════════════════════════════════════════════════════════

class _PermissionToggleRow extends StatelessWidget {
  final String permission;
  final bool hasOverride;
  final bool? overrideValue;
  final bool isDefault;
  final void Function(bool?) onChanged;
  final VoidCallback onClear;

  const _PermissionToggleRow({
    required this.permission,
    required this.hasOverride,
    this.overrideValue,
    required this.isDefault,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final action = permission.contains(':')
        ? permission.split(':')[1]
        : permission;

    // Determine current effective state
    final bool isGranted;
    if (hasOverride) {
      isGranted = overrideValue ?? false;
    } else {
      isGranted = isDefault;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // 3-state toggle: Deny (red) | Default (grey) | Grant (green)
          _TriStateToggle(
            value: hasOverride ? overrideValue : null,
            isDefault: isDefault,
            onChanged: onChanged,
          ),
          const SizedBox(width: 8),

          // Permission name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(permission,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: hasOverride ? FontWeight.w600 : FontWeight.normal,
                      color: hasOverride
                          ? (overrideValue == true
                              ? AppColors.success
                              : AppColors.error)
                          : null,
                    )),
              ],
            ),
          ),

          // Clear override button
          if (hasOverride)
            InkWell(
              onTap: onClear,
              child: Icon(Icons.clear_rounded,
                  size: 14, color: AppColors.lightTextTertiary),
            ),

          // Default indicator
          if (!hasOverride)
            Text('default',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightTextTertiary,
                  fontStyle: FontStyle.italic,
                )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3-STATE TOGGLE — Deny | Default | Grant
// ═══════════════════════════════════════════════════════════════════════════════

class _TriStateToggle extends StatelessWidget {
  final bool? value; // null = use default, true = grant, false = deny
  final bool isDefault;
  final void Function(bool?) onChanged;

  const _TriStateToggle({
    required this.value,
    required this.isDefault,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Cycle: Default → Grant → Deny → Default
    return InkWell(
      onTap: () {
        if (value == null) {
          onChanged(true); // default → grant
        } else if (value == true) {
          onChanged(false); // grant → deny
        } else {
          onChanged(null); // deny → default (clear override)
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value == null
                ? AppColors.lightTextTertiary.withOpacity(0.4)
                : value == true
                    ? AppColors.success
                    : AppColors.error,
            width: 1.5,
          ),
          color: value == null
              ? Colors.transparent
              : value == true
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.error.withOpacity(0.12),
        ),
        child: Center(
          child: Text(
            value == null
                ? (isDefault ? '✓' : '✗')
                : value == true
                    ? '✓'
                    : '✗',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: value == null
                  ? AppColors.lightTextTertiary
                  : value == true
                      ? AppColors.success
                      : AppColors.error,
            ),
          ),
        ),
      ),
    );
  }
}
