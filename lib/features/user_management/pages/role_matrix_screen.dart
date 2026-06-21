// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Role Matrix Screen
//
// Permission × Role matrix showing which role has which permission.
// Serves as RBAC documentation and debugging tool.
//
// Layout:
//   Left column: Permission names (grouped by category)
//   Top row: Role headers (scrollable horizontally)
//   Cells: ✓ / ✗ indicators
//
// Route: /people/roles
// Gated: KlasivoRoleGate(super_admin, owner, admin)
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../core/config/theme.dart';
import '../../../core/tokens/tokens.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/rbac/role_hierarchy.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_badge.dart';

class RoleMatrixScreen extends StatelessWidget {
  const RoleMatrixScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Roles to show in the matrix (exclude super_admin which has all perms)
    const displayRoles = [
      KlasivoRole.owner,
      KlasivoRole.admin,
      KlasivoRole.campusManager,
      KlasivoRole.stageManager,
      KlasivoRole.academicSupervisor,
      KlasivoRole.teacher,
      KlasivoRole.assistantTeacher,
      KlasivoRole.observer,
      KlasivoRole.student,
      KlasivoRole.parent,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Matrix'),
      ),
      body: Column(
        children: [
          // ─── Legend ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            child: KlasivoCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.info, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This matrix shows effective permissions for each role, including inherited permissions. Super Admin has all permissions.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Matrix Grid ─────────────────────────────────────────
          Expanded(
            child: _MatrixGrid(
              roles: displayRoles,
              categories: Permission.categories,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixGrid extends StatelessWidget {
  final List<String> roles;
  final Map<String, List<String>> categories;

  const _MatrixGrid({
    required this.roles,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            // ─── Header Row ───────────────────────────────────────
            TableRow(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface,
              ),
              children: [
                // Permission column header
                _HeaderCell('Permission', isPermissionColumn: true),
                // Role column headers
                ...roles.map((role) => _HeaderCell(
                      KlasivoRole.displayName(role),
                      roleColor: _roleColor(role),
                    )),
              ],
            ),

            // ─── Category Rows ────────────────────────────────────
            ...categories.entries.expand((entry) {
              final category = entry.key;
              final perms = entry.value;

              return [
                // Category header row
                TableRow(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkCard
                        : AppColors.lightCard,
                  ),
                  children: [
                    _CategoryHeaderCell(category),
                    ...roles.map((_) => const _CategoryHeaderCell('')),
                  ],
                ),
                // Permission rows
                ...perms.map((perm) => _buildPermissionRow(
                      perm,
                      roles,
                      isDark,
                      theme,
                    )),
              ];
            }),
          ],
        ),
      ),
    );
  }

  TableRow _buildPermissionRow(
    String perm,
    List<String> roles,
    bool isDark,
    ThemeData theme,
  ) {
    final category = Permission.categoryOf(perm);
    final action = perm.contains(':') ? perm.split(':')[1] : perm;

    return TableRow(
      children: [
        // Permission name cell
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            action,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        // Permission cells for each role
        ...roles.map((role) {
          final hasPermission =
              RoleResolver.roleHasPermission(role, perm);
          return _PermissionCell(
            hasPermission: hasPermission,
            isDark: isDark,
          );
        }),
      ],
    );
  }

  Color _roleColor(String role) => switch (role) {
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
// TABLE CELLS
// ═══════════════════════════════════════════════════════════════════════════════

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool isPermissionColumn;
  final Color? roleColor;

  const _HeaderCell(this.label, {this.isPermissionColumn = false, this.roleColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: isPermissionColumn
          ? const BoxConstraints(minWidth: 120)
          : const BoxConstraints(minWidth: 72),
      child: isPermissionColumn
          ? Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ))
          : Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: roleColor ?? AppColors.primary,
              ),
              textAlign: TextAlign.center),
    );
  }
}

class _CategoryHeaderCell extends StatelessWidget {
  final String text;
  const _CategoryHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: text.isEmpty
          ? const SizedBox.shrink()
          : Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
    );
  }
}

class _PermissionCell extends StatelessWidget {
  final bool hasPermission;
  final bool isDark;

  const _PermissionCell({
    required this.hasPermission,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      child: Icon(
        hasPermission ? Icons.check_rounded : Icons.close_rounded,
        size: 14,
        color: hasPermission ? AppColors.success : AppColors.lightTextTertiary.withOpacity(0.4),
      ),
    );
  }
}
