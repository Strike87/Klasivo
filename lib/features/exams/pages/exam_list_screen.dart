import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsStreamProvider);
    final classes = ref.watch(classesProvider);
    final theme = Theme.of(context);

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
        body: examsAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading exams...'),
          error: (error, stack) => ErrorWidgetCustom(
            message: 'Failed to load exams: $error',
            onRetry: () => ref.invalidate(examsStreamProvider),
          ),
          data: (snapshot) {
            final allExams = snapshot.docs
                .map((doc) => ExamData.fromFirestore(doc))
                .toList();

            final now = DateTime.now();
            final upcoming = allExams
                .where((e) =>
                    e.status == AppConstants.statusPublished &&
                    e.endDate.isAfter(now))
                .toList();
            final completed = allExams
                .where((e) =>
                    e.status == AppConstants.statusPublished &&
                    e.endDate.isBefore(now))
                .toList();
            final drafts = allExams
                .where((e) => e.status == AppConstants.statusDraft)
                .toList();

            return TabBarView(
              children: [
                _ExamTabList(
                  exams: upcoming,
                  classes: classes,
                  emptyIcon: Icons.event_note,
                  emptyTitle: 'No Upcoming Exams',
                  emptySubtitle: 'Create and publish an exam to see it here',
                ),
                _ExamTabList(
                  exams: completed,
                  classes: classes,
                  emptyIcon: Icons.check_circle_outline,
                  emptyTitle: 'No Completed Exams',
                  emptySubtitle: 'Completed exams will appear here',
                ),
                _ExamTabList(
                  exams: drafts,
                  classes: classes,
                  emptyIcon: Icons.edit_note,
                  emptyTitle: 'No Draft Exams',
                  emptySubtitle: 'Draft exams are shown here before publishing',
                ),
              ],
            );
          },
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

class _ExamTabList extends ConsumerWidget {
  final List<ExamData> exams;
  final List<ClassData> classes;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const _ExamTabList({
    required this.exams,
    required this.classes,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exams.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: 'Create Exam',
        onAction: () => context.go('/teacher/exams/create'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(examsStreamProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exams.length,
        itemBuilder: (context, index) {
          final exam = exams[index];
          return _ExamCard(
            exam: exam,
            className: exam.getClassName(classes),
            onTap: () => context.go('/teacher/exams/${exam.id}'),
            onDelete: () async {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: 'Delete Exam',
                message:
                    'Are you sure you want to delete "${exam.title}"? All questions and submissions will also be deleted.',
                confirmLabel: 'Delete',
                isDangerous: true,
              );
              if (confirmed == true) {
                try {
                  await ref.read(examServiceProvider).deleteExam(exam.id);
                  if (context.mounted) {
                    showSnackBar(context, message: 'Exam deleted');
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
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
