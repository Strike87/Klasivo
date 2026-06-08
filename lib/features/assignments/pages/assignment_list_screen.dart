import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/assignment_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ASSIGNMENT LIST SCREEN — Klasivo v1.7
// Teacher's assignment overview with tabbed filtering (All / Draft / Published)
// ═══════════════════════════════════════════════════════════════════════════════

class AssignmentListScreen extends ConsumerWidget {
  const AssignmentListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(assignmentsProvider);
    final classes = ref.watch(classesProvider);
    final assignmentsAsync = ref.watch(assignmentsByOrgProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Assignments'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Draft'),
              Tab(text: 'Published'),
            ],
          ),
        ),
        body: assignmentsAsync.when(
          loading: () => const KlasivoLoading(message: 'Loading assignments...'),
          error: (error, stack) => ErrorWidgetCustom(
            message: 'Failed to load assignments: $error',
            onRetry: () => ref.invalidate(assignmentsByOrgProvider),
          ),
          data: (_) {
            final allAssignments = assignments
                .where((a) => !a.isArchived)
                .toList();

            final drafts = allAssignments
                .where((a) => a.isDraft)
                .toList();

            final published = allAssignments
                .where((a) => a.isPublished)
                .toList();

            return TabBarView(
              children: [
                _AssignmentTabList(
                  assignments: allAssignments,
                  classes: classes,
                  emptyIcon: Icons.assignment_outlined,
                  emptyTitle: 'No Assignments Yet',
                  emptySubtitle: 'Create your first assignment to get started',
                  onRefresh: () => ref.invalidate(assignmentsByOrgProvider),
                ),
                _AssignmentTabList(
                  assignments: drafts,
                  classes: classes,
                  emptyIcon: Icons.edit_note,
                  emptyTitle: 'No Drafts',
                  emptySubtitle: 'Draft assignments will appear here',
                  onRefresh: () => ref.invalidate(assignmentsByOrgProvider),
                ),
                _AssignmentTabList(
                  assignments: published,
                  classes: classes,
                  emptyIcon: Icons.check_circle_outline,
                  emptyTitle: 'No Published Assignments',
                  emptySubtitle: 'Publish an assignment to make it visible to students',
                  onRefresh: () => ref.invalidate(assignmentsByOrgProvider),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/teacher/assignments/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Assignment'),
        ),
      ),
    );
  }
}

// ─── Tab Content List ─────────────────────────────────────────────────────────

class _AssignmentTabList extends ConsumerWidget {
  final List<AssignmentData> assignments;
  final List<ClassData> classes;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onRefresh;

  const _AssignmentTabList({
    required this.assignments,
    required this.classes,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (assignments.isEmpty) {
      return KlasivoEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Create Assignment',
        onAction: () => context.go('/teacher/assignments/new'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(KlasivoSpacing.lg),
        itemCount: assignments.length,
        separatorBuilder: (_, __) => const SizedBox(height: KlasivoSpacing.sm),
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          final className = _getClassName(assignment.classId);

          return _AssignmentCard(
            assignment: assignment,
            className: className,
            onTap: () => context.go('/teacher/assignments/${assignment.id}'),
            onDelete: () async {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: 'Delete Assignment',
                message:
                    'Are you sure you want to delete "${assignment.title}"? All submissions will also be deleted.',
                confirmLabel: 'Delete',
                isDangerous: true,
              );
              if (confirmed == true) {
                try {
                  await ref
                      .read(assignmentServiceProvider)
                      .deleteAssignment(assignment.id);
                  if (context.mounted) {
                    showSnackBar(context, message: 'Assignment deleted');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showSnackBar(context,
                        message: 'Failed: $e', isError: true);
                  }
                }
              }
            },
          );
        },
      ),
    );
  }

  String _getClassName(String classId) {
    try {
      final cls = classes.firstWhere((c) => c.id == classId);
      return cls.name;
    } catch (_) {
      return 'Unknown Class';
    }
  }
}

// ─── Assignment Card ──────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final AssignmentData assignment;
  final String className;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AssignmentCard({
    required this.assignment,
    required this.className,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Title + Status Badge ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: KlasivoTypography.titleMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  _StatusBadge(assignment: assignment),
                ],
              ),

              // ── Description Snippet ──
              if (assignment.description != null &&
                  assignment.description!.isNotEmpty) ...[
                const SizedBox(height: KlasivoSpacing.xs),
                Text(
                  assignment.description!,
                  style: KlasivoTypography.bodySmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: KlasivoSpacing.md),

              // ── Metadata Row ──
              Row(
                children: [
                  // Class name
                  Icon(
                    Icons.class_outlined,
                    size: 14,
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                  const SizedBox(width: KlasivoSpacing.xs),
                  Text(
                    className,
                    style: KlasivoTypography.caption.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.md),

                  // Due date
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: assignment.isOverdue && assignment.isPublished
                        ? KlasivoColors.error
                        : isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                  ),
                  const SizedBox(width: KlasivoSpacing.xs),
                  Text(
                    'Due ${dateFormat.format(assignment.dueDate)}',
                    style: KlasivoTypography.caption.copyWith(
                      color: assignment.isOverdue && assignment.isPublished
                          ? KlasivoColors.error
                          : isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                    ),
                  ),

                  const Spacer(),

                  // Delete button
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(KlasivoSpacing.xs),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: KlasivoColors.error.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final AssignmentData assignment;

  const _StatusBadge({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final isOverdue = assignment.isOverdue && assignment.isPublished;
    final isDraft = assignment.isDraft;

    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (isOverdue) {
      bgColor = KlasivoColors.errorSurface;
      textColor = KlasivoColors.error;
      label = 'Overdue';
      icon = Icons.warning_amber_rounded;
    } else if (isDraft) {
      bgColor = KlasivoColors.accentSurface;
      textColor = KlasivoColors.accent;
      label = 'Draft';
      icon = Icons.edit_outlined;
    } else {
      bgColor = KlasivoColors.secondarySurface;
      textColor = KlasivoColors.secondary;
      label = 'Published';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.sm,
        vertical: KlasivoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            label,
            style: KlasivoTypography.labelSmall.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
