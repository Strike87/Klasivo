import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/submission_provider.dart';
import '../../../providers/exam_provider.dart';
import '../../../providers/question_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';

class StudentResultsScreen extends ConsumerWidget {
  const StudentResultsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(studentSubmissionsProvider);
    final theme = Theme.of(context);

    final submittedSubs = submissions
        .where((s) =>
            s.status == AppConstants.submissionStatusSubmitted ||
            s.status == AppConstants.submissionStatusFlagged)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Results'),
        centerTitle: true,
      ),
      body: submittedSubs.isEmpty
          ? const EmptyState(
              icon: Icons.assessment_outlined,
              title: 'No Results Yet',
              subtitle: 'Your exam results will appear here after submission',
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(studentSubmissionsStreamProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: submittedSubs.length,
                itemBuilder: (context, index) {
                  final sub = submittedSubs[index];
                  return _ResultCard(submission: sub);
                },
              ),
            ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  final SubmissionData submission;

  const _ResultCard({required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy · hh:mm a');
    final exams = ref.watch(examsProvider);
    final exam =
        exams.where((e) => e.id == submission.examId).firstOrNull;

    final passed = exam != null
        ? submission.percentage >= exam.passingScore
        : submission.percentage >= 50;
    final timeSpentMin = submission.timeSpent ~/ 60;
    final timeSpentSec = submission.timeSpent % 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.go('/student/results/${submission.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam?.title ?? 'Exam',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Pass/Fail badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (passed ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          passed ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: passed ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          passed ? 'PASSED' : 'FAILED',
                          style: TextStyle(
                            color: passed ? Colors.green : Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (submission.isFlagged) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag, size: 12, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Flagged for violations',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── Score Display ──
              Row(
                children: [
                  // Score circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (passed ? Colors.green : Colors.red)
                          .withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        '${submission.percentage}%',
                        style: TextStyle(
                          color: passed ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Score details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${submission.score} / ${submission.totalMarks} marks',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (exam != null)
                          Text(
                            'Passing: ${exam.passingScore}%',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Time: ${timeSpentMin}m ${timeSpentSec}s',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Submitted date ──
              if (submission.submittedAt != null)
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Submitted: ${dateFormat.format(submission.submittedAt!)}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 12),

              // ── View Details Button ──
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/student/results/${submission.id}'),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Single Result Detail Screen ──────────────────────────────────────────────

class StudentResultDetailScreen extends ConsumerWidget {
  final String submissionId;

  const StudentResultDetailScreen({
    Key? key,
    required this.submissionId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result Details'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: ref.read(submissionServiceProvider).getSubmission(submissionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading result...');
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Result Not Found',
              subtitle: 'This result may have been removed',
            );
          }

          final data = snapshot.data!;
          final examId = data['examId'] as String? ?? '';
          final score = data['score'] as int? ?? 0;
          final totalMarks = data['totalMarks'] as int? ?? 0;
          final percentage = data['percentage'] as int? ?? 0;
          final timeSpent = data['timeSpent'] as int? ?? 0;
          final status = data['status'] as String? ?? '';
          final violationCount = data['violationCount'] as int? ?? 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Score Card ──
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: percentage >= 50
                            ? [Colors.green.shade700, Colors.green.shade500]
                            : [Colors.red.shade700, Colors.red.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$score / $totalMarks marks',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status == AppConstants.submissionStatusFlagged
                              ? 'Flagged'
                              : 'Submitted',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Stats Row ──
                Row(
                  children: [
                    _DetailCard(
                      label: 'Time Spent',
                      value:
                          '${timeSpent ~/ 60}m ${timeSpent % 60}s',
                      icon: Icons.timer_outlined,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _DetailCard(
                      label: 'Violations',
                      value: '$violationCount',
                      icon: Icons.warning_amber,
                      color: violationCount > 0 ? Colors.red : Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Answers Review ──
                Text(
                  'Answer Review',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _AnswersReviewList(
                  examId: examId,
                  submissionId: submissionId,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

class _AnswersReviewList extends ConsumerWidget {
  final String examId;
  final String submissionId;

  const _AnswersReviewList({
    required this.examId,
    required this.submissionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsStreamProvider(examId));

    return questionsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (error, _) => ErrorWidgetCustom(
        message: 'Failed to load questions',
        onRetry: () => ref.invalidate(questionsStreamProvider(examId)),
      ),
      data: (snapshot) {
        final questions = snapshot.docs
            .map((doc) => QuestionData.fromFirestore(doc))
            .toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future:
              ref.read(submissionServiceProvider).getAnswers(submissionId),
          builder: (context, ansSnapshot) {
            if (ansSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingIndicator();
            }

            final answers = ansSnapshot.data ?? [];
            final answersMap = <String, Map<String, dynamic>>{};
            for (final ans in answers) {
              answersMap[ans['questionId'] as String] = ans;
            }

            return Column(
              children: questions.asMap().entries.map((entry) {
                final index = entry.key;
                final q = entry.value;
                final ans = answersMap[q.id];
                final isCorrect = ans?['isCorrect'] as bool? ?? false;
                final studentAnswer =
                    ans?['answer'] as String? ?? 'Not answered';
                final marksAwarded = ans?['marksAwarded'] as int? ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isCorrect
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: (isCorrect
                                      ? Colors.green
                                      : Colors.red)
                                  .withOpacity(0.1),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isCorrect
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    q.typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                q.typeLabel,
                                style: TextStyle(
                                  color: q.typeColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              isCorrect
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: isCorrect
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$marksAwarded/${q.marks}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isCorrect
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          q.questionText,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your answer: $studentAnswer',
                          style: TextStyle(
                            color: isCorrect
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                        if (!isCorrect) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Correct: ${q.correctAnswer}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
