// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Scope Assignment Screen
//
// Visual tree selection for campus/stage/class hierarchy.
// Shows which scope level is relevant for the user's role and allows
// multi-select with a hierarchical tree view.
//
// Tree structure:
//   Campus A
//    ├─ Primary (Stage)
//    │   ├─ Class 1A
//    │   ├─ Class 1B
//    └─ Secondary (Stage)
//        ├─ Class 7A
//        └─ Class 7B
//
// Calls the `assignScope` Cloud Function on save.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../core/tokens/tokens.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/scope_access_level.dart';
import '../../../core/rbac/permissions.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_permission_gate.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_toast.dart';
import '../data/user_management_repository.dart';
import '../providers/user_management_providers.dart';

class ScopeAssignmentScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String currentRole;
  final List<String> currentCampusIds;
  final List<String> currentStageIds;
  final List<String> currentClassIds;
  final List<String> currentSubjectIds;

  const ScopeAssignmentScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.currentRole,
    this.currentCampusIds = const [],
    this.currentStageIds = const [],
    this.currentClassIds = const [],
    this.currentSubjectIds = const [],
  }) : super(key: key);

  @override
  ConsumerState<ScopeAssignmentScreen> createState() =>
      _ScopeAssignmentScreenState();
}

class _ScopeAssignmentScreenState extends ConsumerState<ScopeAssignmentScreen> {
  late Set<String> _selectedCampusIds;
  late Set<String> _selectedStageIds;
  late Set<String> _selectedClassIds;
  late Set<String> _selectedSubjectIds;
  bool _loading = false;
  Map<String, String> _idToNameCache = {};

  @override
  void initState() {
    super.initState();
    _selectedCampusIds = Set.from(widget.currentCampusIds);
    _selectedStageIds = Set.from(widget.currentStageIds);
    _selectedClassIds = Set.from(widget.currentClassIds);
    _selectedSubjectIds = Set.from(widget.currentSubjectIds);
  }

  ScopeAccessLevel get _scopeLevel => scopeAccessLevelForRole(widget.currentRole);

  bool get _showCampusPicker => _scopeLevel == ScopeAccessLevel.campus ||
      _scopeLevel == ScopeAccessLevel.all;

  bool get _showStagePicker => _scopeLevel == ScopeAccessLevel.stage ||
      _scopeLevel == ScopeAccessLevel.campus;

  bool get _showClassPicker => _scopeLevel == ScopeAccessLevel.class_;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Scope: ${widget.userName}'),
        actions: [
          KlasivoPermissionGate(
            permission: Permission.userAssignRole,
            fallback: const SizedBox.shrink(),
            child: Padding(
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
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Scope Level Info ────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            child: KlasivoCard(
              accentColor: KlasivoRole.isScoped(widget.currentRole)
                  ? AppColors.warning
                  : AppColors.success,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_tree_rounded,
                      color: KlasivoRole.isScoped(widget.currentRole)
                          ? AppColors.warning
                          : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${KlasivoRole.displayName(widget.currentRole)} — ${_scopeLabel(_scopeLevel)} scope',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _scopeDescription(_scopeLevel),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Selection Summary ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_showCampusPicker)
                  _SelectionPill(
                      label: 'Campuses', count: _selectedCampusIds.length),
                if (_showStagePicker) ...[
                  const SizedBox(width: 8),
                  _SelectionPill(
                      label: 'Stages', count: _selectedStageIds.length),
                ],
                if (_showClassPicker) ...[
                  const SizedBox(width: 8),
                  _SelectionPill(
                      label: 'Classes', count: _selectedClassIds.length),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ─── Tree / Selection Area ───────────────────────────────
          Expanded(
            child: _buildScopePicker(),
          ),
        ],
      ),
    );
  }

  Widget _buildScopePicker() {
    // Class-scoped roles see a visual tree (Campus → Stage → Class)
    if (_showClassPicker) {
      return _ClassScopeTree(
        selectedStageIds: _selectedStageIds,
        selectedClassIds: _selectedClassIds,
        onStageToggle: _toggleStage,
        onClassToggle: _toggleClass,
        onStageNameResolved: _cacheName,
        onClassNameResolved: _cacheName,
      );
    }

    // Stage-scoped roles see stage list
    if (_showStagePicker) {
      return _StageScopeList(
        selectedStageIds: _selectedStageIds,
        onStageToggle: _toggleStage,
        onNameResolved: _cacheName,
      );
    }

    // Campus-scoped roles see campus list
    if (_showCampusPicker) {
      return _CampusScopeList(
        selectedCampusIds: _selectedCampusIds,
        onCampusToggle: _toggleCampus,
        onNameResolved: _cacheName,
      );
    }

    // All-access roles don't need scope
    return const KlasivoEmptyState(
      icon: Icons.check_circle_rounded,
      title: 'No scope assignment needed',
      subtitle: 'This role has full access within the organization',
    );
  }

  void _cacheName(String id, String name) {
    _idToNameCache[id] = name;
  }

  void _toggleCampus(String id) {
    setState(() {
      if (_selectedCampusIds.contains(id)) {
        _selectedCampusIds.remove(id);
      } else {
        _selectedCampusIds.add(id);
      }
    });
  }

  void _toggleStage(String id) {
    setState(() {
      if (_selectedStageIds.contains(id)) {
        _selectedStageIds.remove(id);
      } else {
        _selectedStageIds.add(id);
      }
    });
  }

  void _toggleClass(String id) {
    setState(() {
      if (_selectedClassIds.contains(id)) {
        _selectedClassIds.remove(id);
      } else {
        _selectedClassIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    try {
      final scopeData = <String, dynamic>{};

      if (_showCampusPicker && _selectedCampusIds.isNotEmpty) {
        scopeData['campusIds'] = _selectedCampusIds.toList();
      }
      if (_showStagePicker && _selectedStageIds.isNotEmpty) {
        scopeData['stageIds'] = _selectedStageIds.toList();
      }
      if (_showClassPicker) {
        if (_selectedClassIds.isNotEmpty) {
          scopeData['classIds'] = _selectedClassIds.toList();
        }
        if (_selectedStageIds.isNotEmpty) {
          scopeData['stageIds'] = _selectedStageIds.toList();
        }
      }

      await ref.read(userManagementRepoProvider).assignScope(
            targetUserId: widget.userId,
            scopeData: scopeData,
          );

      if (mounted) {
        KlasivoToast.show(
          context,
          message: 'Scope updated for ${widget.userName}',
          type: KlasivoToastType.success,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.show(
          context,
          message: 'Failed to update scope: $e',
          type: KlasivoToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _scopeLabel(ScopeAccessLevel level) => switch (level) {
        ScopeAccessLevel.all => 'All',
        ScopeAccessLevel.campus => 'Campus',
        ScopeAccessLevel.stage => 'Stage',
        ScopeAccessLevel.class_ => 'Class',
        ScopeAccessLevel.self => 'Self',
        ScopeAccessLevel.linked => 'Linked',
      };

  String _scopeDescription(ScopeAccessLevel level) => switch (level) {
        ScopeAccessLevel.all => 'Full access to all data in the organization',
        ScopeAccessLevel.campus =>
          'Can only access data within assigned campuses',
        ScopeAccessLevel.stage =>
          'Can only access data within assigned stages',
        ScopeAccessLevel.class_ =>
          'Can only access data within assigned classes and subjects',
        ScopeAccessLevel.self => 'Can only view their own data',
        ScopeAccessLevel.linked => 'Can only view linked children\'s data',
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
// VISUAL TREE — Campus → Stage → Class hierarchy for class-scoped roles
// ═══════════════════════════════════════════════════════════════════════════════

class _ClassScopeTree extends ConsumerWidget {
  final Set<String> selectedStageIds;
  final Set<String> selectedClassIds;
  final void Function(String id) onStageToggle;
  final void Function(String id) onClassToggle;
  final void Function(String id, String name) onStageNameResolved;
  final void Function(String id, String name) onClassNameResolved;

  const _ClassScopeTree({
    required this.selectedStageIds,
    required this.selectedClassIds,
    required this.onStageToggle,
    required this.onClassToggle,
    required this.onStageNameResolved,
    required this.onClassNameResolved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(scopeTreeProvider);

    return treeAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => Center(child: Text('Error loading tree: $e')),
      data: (tree) {
        if (tree.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.account_tree_rounded,
            title: 'No organizational structure',
            subtitle: 'Create stages and classes first',
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: tree
              .expand((campus) => [
                    // Campus header (non-selectable, just grouping)
                    _CampusHeader(name: campus.name),
                    // Stage → Class subtree
                    ...campus.children.expand((stage) => [
                          _StageTile(
                            name: stage.name,
                            id: stage.id,
                            isSelected: selectedStageIds.contains(stage.id),
                            onToggle: () {
                              onStageNameResolved(stage.id, stage.name);
                              onStageToggle(stage.id);
                            },
                            childCount: stage.children.length,
                          ),
                          // Class children
                          ...stage.children.map((cls) => _ClassTile(
                                name: cls.name,
                                id: cls.id,
                                isSelected:
                                    selectedClassIds.contains(cls.id),
                                onToggle: () {
                                  onClassNameResolved(cls.id, cls.name);
                                  onClassToggle(cls.id);
                                },
                                parentSelected:
                                    selectedStageIds.contains(stage.id),
                              )),
                        ]),
                  ])
              .toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAGE SCOPE LIST — For stage_manager / academic_supervisor
// ═══════════════════════════════════════════════════════════════════════════════

class _StageScopeList extends ConsumerWidget {
  final Set<String> selectedStageIds;
  final void Function(String id) onStageToggle;
  final void Function(String id, String name) onNameResolved;

  const _StageScopeList({
    required this.selectedStageIds,
    required this.onStageToggle,
    required this.onNameResolved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagesAsync = ref.watch(stagesProvider);

    return stagesAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stages) {
        if (stages.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.stairs_rounded,
            title: 'No stages',
            subtitle: 'Create stages first in Academic',
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: stages
              .map((stage) => _StageTile(
                    name: stage.name,
                    id: stage.id,
                    isSelected: selectedStageIds.contains(stage.id),
                    onToggle: () {
                      onNameResolved(stage.id, stage.name);
                      onStageToggle(stage.id);
                    },
                    childCount: 0,
                  ))
              .toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPUS SCOPE LIST — For campus_manager
// ═══════════════════════════════════════════════════════════════════════════════

class _CampusScopeList extends ConsumerWidget {
  final Set<String> selectedCampusIds;
  final void Function(String id) onCampusToggle;
  final void Function(String id, String name) onNameResolved;

  const _CampusScopeList({
    required this.selectedCampusIds,
    required this.onCampusToggle,
    required this.onNameResolved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campusesAsync = ref.watch(campusesProvider);

    return campusesAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (campuses) {
        if (campuses.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.location_city_rounded,
            title: 'No campuses',
            subtitle: 'Create campuses first in Organization Settings',
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: campuses
              .map((campus) => _CampusTile(
                    name: campus.name,
                    id: campus.id,
                    isSelected: selectedCampusIds.contains(campus.id),
                    onToggle: () {
                      onNameResolved(campus.id, campus.name);
                      onCampusToggle(campus.id);
                    },
                  ))
              .toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TREE TILE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _CampusHeader extends StatelessWidget {
  final String name;
  const _CampusHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.location_city_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(name, style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _CampusTile extends StatelessWidget {
  final String name;
  final String id;
  final bool isSelected;
  final VoidCallback onToggle;

  const _CampusTile({
    required this.name,
    required this.id,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Icon(Icons.location_city_rounded,
                  size: 16,
                  color: isSelected ? AppColors.primary : AppColors.lightTextTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final String name;
  final String id;
  final bool isSelected;
  final VoidCallback onToggle;
  final int childCount;

  const _StageTile({
    required this.name,
    required this.id,
    required this.isSelected,
    required this.onToggle,
    required this.childCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.success.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.success
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Tree connector
              const Text('├─ ', style: TextStyle(fontFamily: 'monospace')),
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.success,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Icon(Icons.stairs_rounded,
                  size: 14,
                  color: isSelected ? AppColors.success : AppColors.lightTextTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
              if (childCount > 0)
                Text('$childCount classes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.lightTextTertiary,
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  final String name;
  final String id;
  final bool isSelected;
  final VoidCallback onToggle;
  final bool parentSelected;

  const _ClassTile({
    required this.name,
    required this.id,
    required this.isSelected,
    required this.onToggle,
    required this.parentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInherited = parentSelected && !isSelected;

    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.warning.withOpacity(0.06)
                : isInherited
                    ? AppColors.success.withOpacity(0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? AppColors.warning
                  : isInherited
                      ? AppColors.success.withOpacity(0.3)
                      : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Tree connector
              const Text('│  ├─ ',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
              Checkbox(
                value: isSelected || isInherited,
                tristate: isInherited,
                onChanged: isInherited ? null : (_) => onToggle(),
                activeColor: AppColors.warning,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              Icon(Icons.groups_rounded,
                  size: 12,
                  color: isSelected
                      ? AppColors.warning
                      : isInherited
                          ? AppColors.success.withOpacity(0.5)
                          : AppColors.lightTextTertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isInherited ? AppColors.lightTextTertiary : null,
                  ),
                ),
              ),
              if (isInherited)
                Text('inherited',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    )),
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

class _SelectionPill extends StatelessWidget {
  final String label;
  final int count;

  const _SelectionPill({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.primary.withOpacity(0.08)
            : AppColors.lightTextTertiary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: count > 0 ? AppColors.primary : AppColors.lightTextTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
