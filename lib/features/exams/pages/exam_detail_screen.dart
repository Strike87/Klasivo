import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/question_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

class ExamDetailScreen extends ConsumerWidget {
  final String examId;

  const ExamDetailScreen({
    Key? key,
    required this.examId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsStreamProvider);
    final classes = ref.watch(classesProvider);
    final theme = Theme.of(context);

    return examsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Exam Details')),
        body: const LoadingIndicator(),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Exam Details')),
        body: ErrorWidgetCustom(
          message: 'Failed to load exam: $error',
          onRetry: () => ref.invalidate(examsStreamProvider),
        ),
      ),
      data: (snapshot) {
        final examDoc = snapshot.docs.where((d) => d.id == examId).firstOrNull;
        if (examDoc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Exam Details')),
            body: const EmptyState(
              icon: Icons.error_outline,
              title: 'Exam Not Found',
              subtitle: 'This exam may have been deleted',
            ),
          );
        }

        final exam = ExamData.fromFirestore(examDoc);
        final className = exam.getClassName(classes);
        final isDraft = exam.status == AppConstants.statusDraft;
        final dateFormat = DateFormat('MMM dd, yyyy');
        final timeFormat = DateFormat('hh:mm a');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Exam Details'),
            centerTitle: true,
            actions: [
              if (isDraft)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      context.go(
                        '/teacher/exams/edit/$examId',
                        extra: exam,
                      );
                    } else if (value == 'delete') {
                      final confirmed = await KlasivoModal.confirm(
                        context: context,
                        title: 'Delete Exam',
                        message:
                            'Are you sure? All questions and submissions will be deleted.',
                        confirmLabel: 'Delete',
                        isDangerous: true,
                      );
                      if (confirmed == true) {
                        try {
                          await ref
                              .read(examServiceProvider)
                              .deleteExam(examId);
                          if (context.mounted) {
                            KlasivoToast.success(context, message: 'Exam deleted');
                            context.go('/teacher/exams');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            KlasivoToast.error(context,
                                message: 'Failed: $e');
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Exam Title & Status ──
                KlasivoCard(
                  variant: KlasivoCardVariant.elevated,
                  padding: const EdgeInsets.all(20),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exam.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _StatusBadge(status: exam.status),
                        ],
                      ),
                      if (exam.description != null &&
                          exam.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          exam.description!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Info Grid ──
                Row(
                  children: [
                    _InfoCard(
                      icon: Icons.class_outlined,
                      label: 'Class',
                      value: className,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _InfoCard(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: '${exam.durationMinutes} min',
                      color: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoCard(
                      icon: Icons.quiz_outlined,
                      label: 'Questions',
                      value: '${exam.questionCount}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _InfoCard(
                      icon: Icons.stars_outlined,
                      label: 'Total Marks',
                      value: '${exam.totalMarks}',
                      color: Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Schedule ──
                KlasivoCard(
                  padding: const EdgeInsets.all(16),
                  margin: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Schedule',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ScheduleRow(
                        label: 'Start',
                        date: dateFormat.format(exam.startDate),
                        time: timeFormat.format(exam.startDate),
                      ),
                      const SizedBox(height: 8),
                      _ScheduleRow(
                        label: 'End',
                        date: dateFormat.format(exam.endDate),
                        time: timeFormat.format(exam.endDate),
                      ),
                      const SizedBox(height: 8),
                      _ScheduleRow(
                        label: 'Pass Score',
                        date: '${exam.passingScore}%',
                        time: '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Questions Section ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Questions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isDraft)
                      KlasivoButton(
                        label: 'Manage',
                        icon: Icons.add,
                        variant: KlasivoButtonVariant.tertiary,
                        onPressed: () => context.go(
                          '/teacher/exams/$examId/questions',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _QuestionsList(examId: examId, isDraft: isDraft),
                const SizedBox(height: 24),

                // ── Publish Button ──
                if (isDraft)
                  KlasivoButton(
                    label: 'Publish Exam',
                    icon: Icons.publish,
                    onPressed: () async {
                      if (exam.questionCount == 0) {
                        KlasivoToast.error(
                          context,
                          message:
                              'Add at least one question before publishing',
                        );
                        return;
                      }
                      final confirmed = await KlasivoModal.confirm(
                        context: context,
                        title: 'Publish Exam',
                        message:
                            'Once published, the exam will be visible to students. You won\'t be able to edit questions after publishing.',
                        confirmLabel: 'Publish',
                      );
                      if (confirmed == true) {
                        try {
                          await ref
                              .read(examServiceProvider)
                              .publishExam(examId);
                          if (context.mounted) {
                            KlasivoToast.success(context,
                                message: 'Exam published successfully!');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            KlasivoToast.error(context,
                                message: e.toString().replaceAll(
                                    'Exception: ', ''));
                          }
                        }
                      }
                    },
                    fullWidth: true,
                  ),

                if (!isDraft && exam.status == AppConstants.statusPublished)
                  KlasivoButton(
                    label: 'Unpublish Exam',
                    icon: Icons.unpublished,
                    variant: KlasivoButtonVariant.secondary,
                    onPressed: () async {
                      final confirmed = await KlasivoModal.confirm(
                        context: context,
                        title: 'Unpublish Exam',
                        message:
                            'Unpublishing will hide the exam from students.',
                        confirmLabel: 'Unpublish',
                        isDangerous: true,
                      );
                      if (confirmed == true) {
                        try {
                          await ref
                              .read(examServiceProvider)
                              .unpublishExam(examId);
                          if (context.mounted) {
                            KlasivoToast.success(context,
                                message: 'Exam unpublished');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            KlasivoToast.error(context,
                                message: 'Failed: $e');
                          }
                        }
                      }
                    },
                    fullWidth: true,
                  ),

                // ── View Results Button (for published/completed exams) ──
                if (!isDraft)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: KlasivoButton(
                      label: 'View Results',
                      icon: Icons.assessment_outlined,
                      onPressed: () => context.go(
                        '/teacher/exams/$examId/results',
                      ),
                      fullWidth: true,
                    ),
                  ),

                // ── View Exam Instances (Phase C) ──
                if (!isDraft)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: KlasivoButton(
                      label: 'View Exam Instances',
                      icon: Icons.shuffle,
                      variant: KlasivoButtonVariant.secondary,
                      onPressed: () => context.go(
                        '/teacher/exams/$examId/instances',
                      ),
                      fullWidth: true,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Questions List Widget ───────────────────────────────────────────────────

class _QuestionsList extends ConsumerWidget {
  final String examId;
  final bool isDraft;

  const _QuestionsList({required this.examId, required this.isDraft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsStreamProvider(examId));

    return questionsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Text('Error loading questions'),
      data: (snapshot) {
        final questions = snapshot.docs
            .map((doc) => QuestionData.fromFirestore(doc))
            .toList();

        if (questions.isEmpty) {
          return KlasivoCard(
            padding: const EdgeInsets.all(24),
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                Icon(Icons.help_outline, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  isDraft
                      ? 'No questions yet. Add questions to this exam.'
                      : 'No questions found.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: questions.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            return KlasivoCard(
              variant: KlasivoCardVariant.elevated,
              margin: const EdgeInsets.only(bottom: 6),
              padding: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                leading: KlasivoAvatar(
                  name: '${index + 1}',
                  size: KlasivoAvatarSize.sm,
                  backgroundColor: q.typeColor.withValues(alpha: 0.1),
                ),
                title: Text(
                  q.questionText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  '${q.typeLabel} · ${q.marks} mark${q.marks != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Status Badge ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'published':
        color = Colors.green;
        label = 'Published';
        break;
      case 'draft':
        color = Colors.grey;
        label = 'Draft';
        break;
      default:
        color = Colors.orange;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Info Card ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: KlasivoCard(
        padding: const EdgeInsets.all(12),
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
    );
  }
}

// ─── Schedule Row ────────────────────────────────────────────────────────────

class _ScheduleRow extends StatelessWidget {
  final String label;
  final String date;
  final String time;

  const _ScheduleRow({
    required this.label,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          child: Text(
            date,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (time.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              time,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
