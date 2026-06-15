import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/exam_stats_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_toast.dart';
import '../../../core/services/pdf_service.dart';

class ExamResultsScreen extends ConsumerWidget {
  final String examId;

  const ExamResultsScreen({
    Key? key,
    required this.examId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsStreamProvider);
    final submissions = ref.watch(examSubmissionsProvider(examId));
    final theme = Theme.of(context);

    return examsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: const LoadingIndicator(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: ErrorWidgetCustom(
          message: 'Failed to load: $error',
          onRetry: () => ref.invalidate(examsStreamProvider),
        ),
      ),
      data: (snapshot) {
        final examDoc = snapshot.docs.where((d) => d.id == examId).firstOrNull;
        if (examDoc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Results')),
            body: const EmptyState(
              icon: Icons.error_outline,
              title: 'Exam Not Found',
              subtitle: 'This exam may have been deleted',
            ),
          );
        }

        final exam = ExamData.fromFirestore(examDoc);
        final submittedSubs = submissions
            .where((s) =>
                s.status == AppConstants.submissionStatusSubmitted ||
                s.status == AppConstants.submissionStatusFlagged)
            .toList();

        // Calculate stats
        int totalSubs = submittedSubs.length;
        int flagged =
            submittedSubs.where((s) => s.isFlagged).length;
        int totalScore = submittedSubs.fold(0, (sum, s) => sum + s.score);
        int avgScore = totalSubs > 0 ? (totalScore / totalSubs).round() : 0;
        int highScore = submittedSubs.isEmpty
            ? 0
            : submittedSubs
                .map((s) => s.score)
                .reduce((a, b) => a > b ? a : b);
        int lowScore = submittedSubs.isEmpty
            ? 0
            : submittedSubs
                .map((s) => s.score)
                .reduce((a, b) => a < b ? a : b);

        // Get class students count for "absent"
        final students = ref.watch(studentsByClassListProvider(exam.classId));
        final absentCount = students.length - totalSubs;

        // Get precomputed stats for quick access
        final liveStats = ref.watch(liveExamStatsProvider(examId));

        return Scaffold(
          appBar: AppBar(
            title: Text('${exam.title} - Results'),
            centerTitle: true,
            actions: [
              _PdfExportButton(
                examId: examId,
                examTitle: exam.title,
                className: exam.getClassName(ref.watch(classesProvider)),
                totalMarks: exam.totalMarks,
                passingScore: exam.passingScore,
                submissions: submittedSubs,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(examSubmissionsStreamProvider(examId));
              ref.invalidate(examStatsDataProvider(examId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Precomputed Stats Banner ──
                  if (liveStats != null)
                    KlasivoCard(
                      variant: KlasivoCardVariant.filled,
                      padding: const EdgeInsets.all(12),
                      margin: EdgeInsets.zero,
                      child: Row(
                        children: [
                          Icon(Icons.analytics_outlined,
                              color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live Stats: Avg ${liveStats.averagePercentage}% | Pass Rate ${liveStats.passRate.toStringAsFixed(0)}% | Std Dev ${liveStats.standardDeviation.toStringAsFixed(1)}',
                              style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (liveStats != null) const SizedBox(height: 12),

                  // ── Stats Grid ──
                  Row(
                    children: [
                      _StatCard(
                        label: 'Total',
                        value: '${students.length}',
                        icon: Icons.people_outline,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Submitted',
                        value: '$totalSubs',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Absent',
                        value: '${absentCount < 0 ? 0 : absentCount}',
                        icon: Icons.person_off_outlined,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Flagged',
                        value: '$flagged',
                        icon: Icons.flag_outlined,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        label: 'Avg Score',
                        value: '$avgScore',
                        icon: Icons.bar_chart_outlined,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'High Score',
                        value: '$highScore',
                        icon: Icons.arrow_upward,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Low Score',
                        value: '$lowScore',
                        icon: Icons.arrow_downward,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      _StatCard(
                        label: 'Total Marks',
                        value: '${exam.totalMarks}',
                        icon: Icons.stars_outlined,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Grade Distribution (from precomputed stats) ──
                  if (liveStats != null &&
                      liveStats.gradeDistribution.isNotEmpty) ...[
                    Text(
                      'Grade Distribution',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: liveStats.gradeDistributionList.map((g) {
                        final range = g['range'] as String;
                        final count = g['count'] as int;
                        final pct = g['percentage'] as int;
                        final color = _getGradeColor(range);
                        return Chip(
                          label: Text('$range: $count ($pct%)',
                              style: TextStyle(fontSize: 11, color: color)),
                          backgroundColor: color.withValues(alpha: 0.1),
                          side: BorderSide(color: color.withValues(alpha: 0.3)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Submissions List ──
                  Text(
                    'Student Results',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (submittedSubs.isEmpty)
                    const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No Submissions Yet',
                      subtitle:
                          'Students who submit their exams will appear here',
                    )
                  else
                    ...submittedSubs.map((sub) => _StudentResultCard(
                          submission: sub,
                          totalMarks: exam.totalMarks,
                          passingScore: exam.passingScore,
                        )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getGradeColor(String range) {
    switch (range) {
      case '0-20%':
        return Colors.red;
      case '21-40%':
        return Colors.orange;
      case '41-60%':
        return Colors.amber;
      case '61-80%':
        return Colors.lightGreen;
      case '81-100%':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}


// ─── PDF Export ─────────────────────────────────────────────────────────────

class _PdfExportButton extends ConsumerWidget {
  final String examId;
  final String examTitle;
  final String className;
  final int totalMarks;
  final int passingScore;
  final List<SubmissionData> submissions;

  const _PdfExportButton({
    required this.examId,
    required this.examTitle,
    required this.className,
    required this.totalMarks,
    required this.passingScore,
    required this.submissions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: 'Export PDF Report',
      onPressed: () => _exportPdf(context, ref),
    );
  }

  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    try {
      KlasivoToast.info(context, message: 'Generating PDF report...');

      final submittedSubs = submissions.where((s) => s.isSubmitted).toList();
      final totalStudents = ref.read(studentsByClassListProvider(
        submissions.isNotEmpty ? submissions.first.classId : ''
      )).length;

      // Calculate stats
      int totalScore = submittedSubs.fold(0, (sum, s) => sum + s.score);
      double avgScore = submittedSubs.isNotEmpty ? totalScore / submittedSubs.length : 0;
      int highScore = submittedSubs.isEmpty ? 0 : submittedSubs.map((s) => s.score).reduce((a, b) => a > b ? a : b);
      int lowScore = submittedSubs.isEmpty ? 0 : submittedSubs.map((s) => s.score).reduce((a, b) => a < b ? a : b);
      int passCount = submittedSubs.where((s) => s.percentage >= passingScore).length;
      double passRate = submittedSubs.isNotEmpty ? (passCount / submittedSubs.length) * 100 : 0;

      // Grade distribution
      final gradeDist = <Map<String, dynamic>>[];
      for (var range in [('0-20%', 0, 20), ('21-40%', 21, 40), ('41-60%', 41, 60), ('61-80%', 61, 80), ('81-100%', 81, 100)]) {
        final count = submittedSubs.where((s) => s.percentage >= range.$2 && s.percentage <= range.$3).length;
        gradeDist.add({'range': range.$1, 'count': count, 'percentage': submittedSubs.isNotEmpty ? (count / submittedSubs.length * 100).round() : 0});
      }

      // Student results for table
      final students = ref.read(allStudentsProvider);
      final studentResults = submittedSubs.map((s) {
        final student = students.where((st) => st.id == s.studentId).firstOrNull;
        return {'name': student?.fullName ?? 'Unknown', 'code': student?.studentCode ?? '', 'score': s.score, 'totalMarks': totalMarks, 'percentage': s.percentage, 'status': s.isFlagged ? 'Flagged' : (s.percentage >= passingScore ? 'Passed' : 'Failed')};
      }).toList();

      // Get question analysis for the enhanced PDF (Phase D)
      List<Map<String, dynamic>>? questionAnalysis;
      try {
        final questions = await ref.read(questionAnalysisProvider(examId).future);
        if (questions.isNotEmpty) {
          questionAnalysis = questions.map((q) => q.toMap()).toList();
        }
      } catch (_) {
        // Non-critical: PDF will be generated without question analysis
      }

      final file = await PdfService.generateExamReport(
        examTitle: examTitle,
        className: className,
        totalStudents: totalStudents,
        submittedStudents: submittedSubs.length,
        averageScore: avgScore,
        highestScore: highScore,
        lowestScore: lowScore,
        passRate: passRate,
        totalMarks: totalMarks,
        passingScore: passingScore,
        gradeDistribution: gradeDist,
        studentResults: studentResults,
        questionAnalysis: questionAnalysis,
      );

      if (context.mounted) {
        await PdfService.sharePdf(file);
      }
    } catch (e) {
      if (context.mounted) KlasivoToast.error(context, message: 'PDF failed: $e');
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: KlasivoCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentResultCard extends ConsumerWidget {
  final SubmissionData submission;
  final int totalMarks;
  final int passingScore;

  const _StudentResultCard({
    required this.submission,
    required this.totalMarks,
    required this.passingScore,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final passed = submission.percentage >= passingScore;
    final timeMin = submission.timeSpent ~/ 60;
    final timeSec = submission.timeSpent % 60;

    // Get student name
    final students = ref.watch(allStudentsProvider);
    final student = students
        .where((s) => s.id == submission.studentId)
        .firstOrNull;
    final studentName = student?.fullName ?? 'Unknown Student';
    final studentCode = student?.studentCode ?? '';

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: KlasivoAvatar(
          name: '${submission.percentage}%',
          size: KlasivoAvatarSize.md,
          backgroundColor:
              (passed ? Colors.green : Colors.red).withValues(alpha: 0.1),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                studentName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (submission.isFlagged)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FLAGGED',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$studentCode · ${submission.score}/$totalMarks marks · ${timeMin}m ${timeSec}s',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (submission.submittedAt != null)
              Text(
                'Submitted: ${DateFormat('MMM dd, hh:mm a').format(submission.submittedAt!)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
          ],
        ),
        trailing: Icon(
          passed ? Icons.check_circle : Icons.cancel,
          color: passed ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
