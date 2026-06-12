import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/submission_provider.dart';
import '../../../providers/exam_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_toast.dart';
import '../../../core/services/pdf_service.dart';

class StudentResultsScreen extends ConsumerWidget {
  const StudentResultsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissions = ref.watch(studentSubmissionsProvider);

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

  Future<void> _downloadReport(BuildContext context, WidgetRef ref) async {
    try {
      final exams = ref.read(examsProvider);
      final exam = exams.where((e) => e.id == submission.examId).firstOrNull;
      final studentName = ref.read(userNameProvider) ?? 'Student';
      final className = ref.read(studentClassNameProvider) ?? '';
      final timeMin = submission.timeSpent ~/ 60;

      // Get answers for the report
      final answers = await ref.read(submissionServiceProvider).getAnswers(submission.id);
      final answerMaps = answers.map((a) => {
        'questionText': a['questionId'] ?? '',
        'answer': a['answer'] ?? '',
        'correctAnswer': '',
        'isCorrect': a['isCorrect'] ?? false,
        'marksAwarded': a['marksAwarded'] ?? 0,
        'marks': 0,
      }).toList();

      final file = await PdfService.generateStudentReport(
        studentName: studentName,
        examTitle: exam?.title ?? 'Exam',
        score: submission.score,
        totalMarks: submission.totalMarks,
        percentage: submission.percentage,
        className: className,
        answers: answerMaps,
        violationCount: submission.violationCount,
        timeSpentMinutes: timeMin,
      );

      if (context.mounted) {
        await PdfService.sharePdf(file);
      }
    } catch (e) {
      if (context.mounted) KlasivoToast.error(context, message: 'PDF failed: ${e.toString()}');
    }
  }

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

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => context.go('/student/results/${submission.id}'),
        borderRadius: BorderRadius.circular(12),
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
                        .withValues(alpha: 0.1),
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
                  color: Colors.red.withValues(alpha: 0.1),
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
                        .withValues(alpha: 0.1),
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

            // ── Action Buttons ──
            Row(
              children: [
                Expanded(
                  child: KlasivoButton(
                    variant: KlasivoButtonVariant.secondary,
                    label: 'Details',
                    icon: Icons.visibility_outlined,
                    size: KlasivoButtonSize.sm,
                    onPressed: () =>
                        context.go('/student/results/${submission.id}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: KlasivoButton(
                    variant: KlasivoButtonVariant.secondary,
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    size: KlasivoButtonSize.sm,
                    onPressed: () => _downloadReport(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

