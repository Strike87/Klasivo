import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';

class StudentExamListScreen extends ConsumerWidget {
  const StudentExamListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classId = ref.watch(studentClassIdProvider);
    final studentId = ref.watch(userIdProvider);
    final theme = Theme.of(context);

    if (classId == null || classId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Exams'),
          centerTitle: true,
        ),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'No Class Assigned',
          subtitle: 'Please contact your teacher',
        ),
      );
    }

    final examsAsync = ref.watch(classExamsStreamProvider(classId));
    final submissions = ref.watch(studentSubmissionsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Exams'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Active'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: examsAsync.when(
          loading: () =>
              const LoadingIndicator(message: 'Loading exams...'),
          error: (error, stack) => ErrorWidgetCustom(
            message: 'Failed to load exams: $error',
            onRetry: () => ref.invalidate(classExamsStreamProvider(classId)),
          ),
          data: (snapshot) {
            final allExams = snapshot.docs
                .map((doc) => ExamData.fromFirestore(doc))
                .toList();

            final now = DateTime.now();

            // Active: published, currently within start/end dates, not yet submitted
            final activeExams = allExams.where((exam) {
              final hasSubmitted = submissions.any(
                (s) =>
                    s.examId == exam.id &&
                    s.studentId == studentId &&
                    s.isSubmitted,
              );
              return !hasSubmitted &&
                  exam.status == AppConstants.statusPublished &&
                  now.isAfter(exam.startDate) &&
                  now.isBefore(exam.endDate);
            }).toList();

            // Upcoming: published, start date in the future, not yet submitted
            final upcomingExams = allExams.where((exam) {
              final hasSubmitted = submissions.any(
                (s) =>
                    s.examId == exam.id &&
                    s.studentId == studentId &&
                    s.isSubmitted,
              );
              return !hasSubmitted &&
                  exam.status == AppConstants.statusPublished &&
                  now.isBefore(exam.startDate);
            }).toList();

            // Completed: already submitted or exam ended
            final completedExams = allExams.where((exam) {
              final hasSubmitted = submissions.any(
                (s) =>
                    s.examId == exam.id &&
                    s.studentId == studentId &&
                    s.isSubmitted,
              );
              return hasSubmitted || exam.endDate.isBefore(now);
            }).toList();

            return TabBarView(
              children: [
                _ExamTabList(
                  exams: upcomingExams,
                  submissions: submissions,
                  studentId: studentId ?? '',
                  emptyIcon: Icons.event_note,
                  emptyTitle: 'No Upcoming Exams',
                  emptySubtitle: 'Your scheduled exams will appear here',
                  isUpcoming: true,
                ),
                _ExamTabList(
                  exams: activeExams,
                  submissions: submissions,
                  studentId: studentId ?? '',
                  emptyIcon: Icons.play_circle_outline,
                  emptyTitle: 'No Active Exams',
                  emptySubtitle: 'Active exams you can take will appear here',
                  isActive: true,
                ),
                _ExamTabList(
                  exams: completedExams,
                  submissions: submissions,
                  studentId: studentId ?? '',
                  emptyIcon: Icons.check_circle_outline,
                  emptyTitle: 'No Completed Exams',
                  emptySubtitle: 'Your completed exams will appear here',
                  isCompleted: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExamTabList extends ConsumerWidget {
  final List<ExamData> exams;
  final List<SubmissionData> submissions;
  final String studentId;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final bool isUpcoming;
  final bool isActive;
  final bool isCompleted;

  const _ExamTabList({
    required this.exams,
    required this.submissions,
    required this.studentId,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.isUpcoming = false,
    this.isActive = false,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exams.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final classId = ref.read(studentClassIdProvider);
        if (classId != null) {
          ref.invalidate(classExamsStreamProvider(classId));
        }
        ref.invalidate(studentSubmissionsStreamProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exams.length,
        itemBuilder: (context, index) {
          final exam = exams[index];
          final submission = submissions
              .where((s) => s.examId == exam.id && s.studentId == studentId)
              .firstOrNull;

          return _StudentExamCard(
            exam: exam,
            submission: submission,
            isActive: isActive,
            isCompleted: isCompleted,
            isUpcoming: isUpcoming,
            onStart: () => context.go('/student/exams/${exam.id}/take'),
            onViewResult: () =>
                context.go('/student/results/${submission?.id}'),
          );
        },
      ),
    );
  }
}

class _StudentExamCard extends StatelessWidget {
  final ExamData exam;
  final SubmissionData? submission;
  final bool isActive;
  final bool isCompleted;
  final bool isUpcoming;
  final VoidCallback onStart;
  final VoidCallback onViewResult;

  const _StudentExamCard({
    required this.exam,
    this.submission,
    required this.isActive,
    required this.isCompleted,
    required this.isUpcoming,
    required this.onStart,
    required this.onViewResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: isActive ? onStart : (isCompleted && submission != null ? onViewResult : null),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
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
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (isCompleted && submission != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (submission!.percentage >= exam.passingScore
                            ? Colors.green
                            : Colors.red)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${submission!.percentage}%',
                    style: TextStyle(
                      color: submission!.percentage >= exam.passingScore
                          ? Colors.green
                          : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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

          // ── Info Chips ──
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.durationMinutes} min',
                    style: TextStyle(
                        color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.questionCount} Q',
                    style: TextStyle(
                        color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_outlined,
                      size: 14, color: Colors.purple),
                  const SizedBox(width: 4),
                  Text(
                    '${exam.totalMarks} marks',
                    style: TextStyle(
                        color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Schedule ──
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${dateFormat.format(exam.startDate)} ${timeFormat.format(exam.startDate)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(' → ',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              Text(
                timeFormat.format(exam.endDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),

          // ── Action Button for Active Exams ──
          if (isActive) ...[
            const SizedBox(height: 12),
            KlasivoButton(
              label: 'Start Exam',
              icon: Icons.play_arrow,
              onPressed: onStart,
              fullWidth: true,
            ),
          ],

          if (isCompleted && submission != null) ...[
            const SizedBox(height: 12),
            KlasivoButton(
              label: 'View Result',
              icon: Icons.assessment_outlined,
              variant: KlasivoButtonVariant.secondary,
              onPressed: onViewResult,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
}
