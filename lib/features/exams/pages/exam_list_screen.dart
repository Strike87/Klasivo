import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/paginated_providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/pagination_service.dart';

import '../../../widgets/klasivo_paginated_list.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Exams'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Drafts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PaginatedExamTab(
              status: AppConstants.statusPublished,
              isUpcoming: true,
              classes: classes,
              emptyIcon: Icons.event_note,
              emptyTitle: 'No Upcoming Exams',
              emptySubtitle: 'Create and publish an exam to see it here',
            ),
            _PaginatedExamTab(
              status: AppConstants.statusPublished,
              isUpcoming: false,
              classes: classes,
              emptyIcon: Icons.check_circle_outline,
              emptyTitle: 'No Completed Exams',
              emptySubtitle: 'Completed exams will appear here',
            ),
            _PaginatedExamTab(
              status: AppConstants.statusDraft,
              isUpcoming: null,
              classes: classes,
              emptyIcon: Icons.edit_note,
              emptyTitle: 'No Draft Exams',
              emptySubtitle: 'Draft exams are shown here before publishing',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/teacher/exams/create'),
          icon: const Icon(Icons.add),
          label: const Text('New Exam'),
        ),
      ),
    );
  }
}

/// A single tab that uses KlasivoPaginatedList for server-side
/// paginated exam listing instead of loading all exams at once.
class _PaginatedExamTab extends ConsumerWidget {
  final String status;
  final bool? isUpcoming; // null = drafts (no date filter)
  final List<ClassData> classes;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const _PaginatedExamTab({
    required this.status,
    required this.isUpcoming,
    required this.classes,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherId = ref.watch(currentUserIdProvider);
    final orgId = ref.watch(currentOrganizationIdProvider);
    final paginationService = ref.watch(paginationServiceProvider);

    final filters = <QueryFilter>[
      if (teacherId != null) QueryFilter.equalTo('teacherId', teacherId),
      if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
      QueryFilter.equalTo('status', status),
    ];

    // For upcoming exams, sort by startDate ascending (nearest first)
    // For completed/drafts, sort by createdAt descending (newest first)
    final orderBy = isUpcoming == true ? 'startDate' : 'createdAt';
    final descending = isUpcoming != true;

    return KlasivoPaginatedList<ExamData>(
      loader: (cursor) => paginationService.fetchPage(
        collectionPath: 'exams',
        fromFirestore: ExamData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: orderBy,
        descending: descending,
        filters: filters,
      ),
      padding: const EdgeInsets.all(16),
      separator: const SizedBox(height: 12),
      emptyWidget: EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Create Exam',
        onAction: () => context.go('/teacher/exams/create'),
      ),
      itemBuilder: (context, exam, index) {
        // Client-side filter for upcoming vs completed
        if (status == AppConstants.statusPublished && isUpcoming != null) {
          final now = DateTime.now();
          if (isUpcoming! && exam.endDate.isBefore(now)) {
            return const SizedBox.shrink();
          }
          if (!isUpcoming! && exam.endDate.isAfter(now)) {
            return const SizedBox.shrink();
          }
        }

        return _ExamCard(
          exam: exam,
          className: exam.getClassName(classes),
          onTap: () => context.go('/teacher/exams/${exam.id}'),
          onDelete: () async {
            final confirmed = await KlasivoModal.confirm(
              context: context,
              title: 'Delete Exam',
              message:
                  'Are you sure you want to delete "${exam.title}"? All questions and submissions will also be deleted.',
              confirmLabel: 'Delete',
              isDangerous: true,
            );
            if (confirmed == true) {
              try {
                await ref.read(examServiceProvider).deleteExam(examId: exam.id);
                if (context.mounted) {
                  KlasivoToast.success(context, message: 'Exam deleted');
                }
              } catch (e) {
                if (context.mounted) {
                  KlasivoToast.error(context, message: 'Failed: $e');
                }
              }
            }
          },
        );
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamData exam;
  final String className;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExamCard({
    required this.exam,
    required this.className,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return KlasivoCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      variant: KlasivoCardVariant.interactive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title + Status Badge ──
          Row(
            children: [
              Expanded(
                child: Text(
                  exam.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(status: exam.status),
            ],
          ),

          if (exam.description != null &&
              exam.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              exam.description!,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // ── Info Row ──
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.class_outlined,
                label: className,
                color: Colors.blue,
              ),
              _InfoChip(
                icon: Icons.timer_outlined,
                label: '${exam.durationMinutes} min',
                color: Colors.orange,
              ),
              _InfoChip(
                icon: Icons.quiz_outlined,
                label: '${exam.questionCount} Q',
                color: Colors.green,
              ),
              _InfoChip(
                icon: Icons.stars_outlined,
                label: '${exam.totalMarks} marks',
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Date Row ──
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${dateFormat.format(exam.startDate)} ${timeFormat.format(exam.startDate)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey[500]),
              ),
              Flexible(
                child: Text(
                  '${dateFormat.format(exam.endDate)} ${timeFormat.format(exam.endDate)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: Colors.red[400]),
                onPressed: onDelete,
                tooltip: 'Delete',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'published':
        color = Colors.green;
        label = 'Published';
        icon = Icons.check_circle;
        break;
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        icon = Icons.edit;
        break;
      case 'active':
        color = Colors.orange;
        label = 'Active';
        icon = Icons.play_circle;
        break;
      default:
        color = Colors.grey;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
