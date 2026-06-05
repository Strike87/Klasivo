import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/submission_provider.dart';
import '../../providers/student_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userName = ref.watch(userNameProvider);
    final classId = ref.watch(studentClassIdProvider);
    final stats = ref.watch(studentExamStatsProvider);
    final submissions = ref.watch(studentSubmissionsProvider);
    final theme = Theme.of(context);

    // Get class name from student data
    final students = ref.watch(allStudentsProvider);
    final currentStudent = students.isNotEmpty
        ? students.where((s) => s.id == ref.watch(userIdProvider)).firstOrNull
        : null;
    final className = currentStudent?.className ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Exam Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Phase 7 - Notifications
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final confirmed = await showConfirmationDialog(
                  context: context,
                  title: 'Logout',
                  message: 'Are you sure you want to logout?',
                  confirmLabel: 'Logout',
                  isDangerous: true,
                );
                if (confirmed == true && context.mounted) {
                  await clearAuthData();
                  await ref.read(authServiceProvider).logout();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: authState.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorWidgetCustom(
          message: 'Error: $error',
          onRetry: () => ref.invalidate(authStateProvider),
        ),
        data: (user) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(examsStreamProvider);
            ref.invalidate(studentSubmissionsStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Welcome Section ──
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade700,
                          Colors.green.shade500,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello,',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName ?? 'Student',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ready for your next exam?',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Stats Cards ──
                Row(
                  children: [
                    _StudentStatCard(
                      title: 'Upcoming',
                      value: '${stats.upcoming}',
                      icon: Icons.upcoming_outlined,
                      color: Colors.orange,
                      onTap: () => context.go('/student/exams'),
                    ),
                    const SizedBox(width: 12),
                    _StudentStatCard(
                      title: 'Completed',
                      value: '${stats.completed}',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      onTap: () => context.go('/student/exams'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StudentStatCard(
                      title: 'Average Score',
                      value: stats.averageScore > 0
                          ? '${stats.averageScore.toStringAsFixed(0)}%'
                          : '-',
                      icon: Icons.bar_chart_outlined,
                      color: Colors.blue,
                      onTap: () => context.go('/student/results'),
                    ),
                    const SizedBox(width: 12),
                    _StudentStatCard(
                      title: 'My Class',
                      value: className,
                      icon: Icons.class_outlined,
                      color: Colors.purple,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Active Exams Section ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Exams',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/student/exams'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ActiveExamsList(classId: classId),
                const SizedBox(height: 24),

                // ── Recent Results Section ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Results',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/student/results'),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RecentResultsList(submissions: submissions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active Exams List Widget ────────────────────────────────────────────────

class _ActiveExamsList extends ConsumerWidget {
  final String? classId;

  const _ActiveExamsList({required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classId == null || classId!.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.quiz_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No class assigned',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final examsAsync = ref.watch(classExamsStreamProvider(classId!));
    final submissions = ref.watch(studentSubmissionsProvider);
    final studentId = ref.watch(userIdProvider);
    final now = DateTime.now();

    return examsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text('Error loading exams',
                style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      ),
      data: (snapshot) {
        final allExams = snapshot.docs
            .map((doc) => ExamData.fromFirestore(doc))
            .toList();

        // Filter: only upcoming & active exams (not ended, not yet submitted)
        final activeExams = allExams.where((exam) {
          final hasSubmitted = submissions.any(
            (s) =>
                s.examId == exam.id &&
                s.studentId == studentId &&
                s.isSubmitted,
          );
          return !hasSubmitted && exam.endDate.isAfter(now);
        }).take(3).toList();

        if (activeExams.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No available exams',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your upcoming exams will appear here',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: activeExams.map((exam) {
            final isActive = exam.isActive;
            final canStart = exam.canStart;
            final dateFormat = DateFormat('MMM dd, hh:mm a');

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: isActive ? 2 : 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isActive
                    ? BorderSide(color: Colors.orange.shade300, width: 1.5)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: canStart
                    ? () => context.go('/student/exams/${exam.id}/take')
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isActive
                                  ? Colors.orange
                                  : Theme.of(context).colorScheme.primary)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isActive
                              ? Icons.play_circle_outline
                              : Icons.schedule,
                          color: isActive
                              ? Colors.orange
                              : Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exam.durationMinutes} min · ${exam.questionCount} Q · ${exam.totalMarks} marks',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isActive
                                  ? 'Started · Ends ${dateFormat.format(exam.endDate)}'
                                  : 'Starts ${dateFormat.format(exam.startDate)}',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.orange[700]
                                    : Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canStart)
                        Icon(Icons.chevron_right,
                            color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

}

// ─── Recent Results List Widget ──────────────────────────────────────────────

class _RecentResultsList extends ConsumerWidget {
  final List<SubmissionData> submissions;

  const _RecentResultsList({required this.submissions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final submittedSubs = submissions
        .where((s) =>
            s.status == AppConstants.submissionStatusSubmitted ||
            s.status == AppConstants.submissionStatusFlagged)
        .take(5)
        .toList();

    if (submittedSubs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.assessment_outlined,
                    size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No results yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your exam results will appear here',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: submittedSubs.map((sub) {
        final passed = sub.percentage >= 50; // Will compare with exam passingScore in Phase 5
        final dateFormat = DateFormat('MMM dd, yyyy');

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor:
                  (passed ? Colors.green : Colors.red).withOpacity(0.1),
              child: Text(
                '${sub.percentage}%',
                style: TextStyle(
                  color: passed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${sub.score}/${sub.totalMarks}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (sub.isFlagged)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Flagged',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            subtitle: sub.submittedAt != null
                ? Text(
                    dateFormat.format(sub.submittedAt!),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  )
                : null,
            trailing: Icon(
              passed ? Icons.check_circle : Icons.cancel,
              color: passed ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StudentStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StudentStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
