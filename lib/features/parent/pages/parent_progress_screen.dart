import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/parent_link_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_components.dart';

// ─── Parent Progress Screen — View-Only Academic Progress Overview ────────────

class ParentProgressScreen extends ConsumerWidget {
  const ParentProgressScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final links = ref.watch(parentLinksProvider);
    final approvedLinks = links.where((l) => l.isApproved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Progress',
          style: KlasivoTypography.titleLarge.copyWith(
            color: isDark
                ? KlasivoColors.darkTextPrimary
                : KlasivoColors.lightTextPrimary,
          ),
        ),
      ),
      body: approvedLinks.isEmpty
          ? Center(
              child: KlasivoEmptyState(
                icon: Icons.child_care_outlined,
                title: 'No children linked',
                subtitle: 'Link your child to view their progress.',
                actionLabel: 'Link a Child',
                onAction: () =>
                    context.go(AppConstants.routeParentLink),
                iconColor: KlasivoColors.secondary,
              ),
            )
          : _ParentProgressContent(
              studentId: approvedLinks.first.studentId,
              studentName: approvedLinks.first.studentName ?? 'Student',
            ),
    );
  }
}

// ─── Progress Content — Hero Card + Breakdown + Grade Level ───────────────────

class _ParentProgressContent extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const _ParentProgressContent({
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.progressTrackingCollection)
          .where('studentId', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: KlasivoLoading());
        }

        if (snapshot.hasError) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading progress',
              subtitle: 'Please try again later',
              iconColor: KlasivoColors.error,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.trending_up_outlined,
              title: 'No progress data yet',
              subtitle:
                  'Progress tracking will appear once your child has academic records',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        // Aggregate progress data
        double examAverage = 0;
        double attendanceRate = 0;
        double assignmentCompletion = 0;
        String gradeLevel = 'average';
        double overallProgress = 0;

        // Use the most recent progress doc or aggregate all
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          examAverage =
              (data['examAverage'] as num?)?.toDouble() ?? examAverage;
          attendanceRate =
              (data['attendanceRate'] as num?)?.toDouble() ?? attendanceRate;
          assignmentCompletion =
              (data['assignmentCompletion'] as num?)?.toDouble() ??
                  assignmentCompletion;
          gradeLevel =
              data['gradeLevel'] as String? ?? gradeLevel;
          overallProgress =
              (data['overallProgress'] as num?)?.toDouble() ?? overallProgress;
        }

        // If overallProgress not stored, compute it as weighted average
        if (overallProgress == 0 &&
            (examAverage > 0 || attendanceRate > 0 || assignmentCompletion > 0)) {
          overallProgress =
              (examAverage * 0.4 + attendanceRate * 0.3 + assignmentCompletion * 0.3);
        }

        // Grade level config
        final gradeConfig = _gradeLevelConfig(gradeLevel);
        final isAtRisk = gradeLevel == 'at_risk';

        return RefreshIndicator(
          onRefresh: () async {
            // Force rebuild by re-reading the stream
            (context as Element).markNeedsBuild();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: KlasivoSpacing.lg,
              vertical: KlasivoSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── At-Risk Warning Banner ──
                if (isAtRisk) ...[
                  _AtRiskWarningBanner(studentName: studentName),
                  const SizedBox(height: KlasivoSpacing.lg),
                ],

                // ── Hero Progress Card ──
                _OverallProgressCard(
                  overallProgress: overallProgress,
                  gradeLevel: gradeLevel,
                  gradeConfig: gradeConfig,
                  studentName: studentName,
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Breakdown Section ──
                KlasivoSectionHeader(title: 'Breakdown'),
                const SizedBox(height: KlasivoSpacing.md),

                // ── Analytics Cards Row 1 ──
                Row(
                  children: [
                    Expanded(
                      child: KlasivoAnalyticsCard(
                        value: examAverage > 0
                            ? '${examAverage.toStringAsFixed(0)}%'
                            : '-',
                        label: 'Exam Average',
                        icon: Icons.bar_chart_outlined,
                        color: KlasivoColors.primary,
                      ),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),
                    Expanded(
                      child: KlasivoAnalyticsCard(
                        value: attendanceRate > 0
                            ? '${attendanceRate.toStringAsFixed(0)}%'
                            : '-',
                        label: 'Attendance Rate',
                        icon: Icons.calendar_today_outlined,
                        color: KlasivoColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KlasivoSpacing.md),

                // ── Analytics Cards Row 2 ──
                KlasivoAnalyticsCard(
                  value: assignmentCompletion > 0
                      ? '${assignmentCompletion.toStringAsFixed(0)}%'
                      : '-',
                  label: 'Assignment Completion',
                  icon: Icons.assignment_turned_in_outlined,
                  color: KlasivoColors.accent,
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Grade Level Badge Section ──
                KlasivoSectionHeader(title: 'Performance Level'),
                const SizedBox(height: KlasivoSpacing.md),
                _GradeLevelBadge(config: gradeConfig),
                const SizedBox(height: KlasivoSpacing.xxxl),
              ],
            ),
          ),
        );
      },
    );
  }

  _GradeConfig _gradeLevelConfig(String gradeLevel) {
    switch (gradeLevel) {
      case 'excellent':
        return _GradeConfig(
          label: 'Excellent',
          color: KlasivoColors.secondary,
          icon: Icons.emoji_events_rounded,
          description: 'Outstanding academic performance across all areas',
        );
      case 'good':
        return _GradeConfig(
          label: 'Good',
          color: KlasivoColors.primary,
          icon: Icons.thumb_up_rounded,
          description: 'Strong performance with room for minor improvements',
        );
      case 'average':
        return _GradeConfig(
          label: 'Average',
          color: KlasivoColors.accent,
          icon: Icons.trending_flat_rounded,
          description: 'Meeting expectations; focused effort can raise performance',
        );
      case 'below_average':
        return _GradeConfig(
          label: 'Below Average',
          color: KlasivoColors.accentDark,
          icon: Icons.trending_down_rounded,
          description: 'Additional support and attention recommended',
        );
      case 'at_risk':
        return _GradeConfig(
          label: 'At Risk',
          color: KlasivoColors.error,
          icon: Icons.warning_rounded,
          description: 'Immediate intervention and support needed',
        );
      default:
        return _GradeConfig(
          label: 'Average',
          color: KlasivoColors.accent,
          icon: Icons.trending_flat_rounded,
          description: 'Meeting expectations; focused effort can raise performance',
        );
    }
  }
}

// ─── Overall Progress Hero Card ───────────────────────────────────────────────

class _OverallProgressCard extends StatelessWidget {
  final double overallProgress;
  final String gradeLevel;
  final _GradeConfig gradeConfig;
  final String studentName;

  const _OverallProgressCard({
    required this.overallProgress,
    required this.gradeLevel,
    required this.gradeConfig,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressValue = overallProgress.clamp(0.0, 100.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.xxl),
        child: Column(
          children: [
            // ── Student Name ──
            Text(
              studentName,
              style: KlasivoTypography.titleMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Circular Progress Indicator ──
            SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 10,
                      color: (isDark
                              ? KlasivoColors.darkBorder
                              : KlasivoColors.lightBorder)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  // Progress circle
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progressValue / 100,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      color: gradeConfig.color,
                    ),
                  ),
                  // Center text
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${progressValue.toStringAsFixed(0)}%',
                        style: KlasivoTypography.displayMedium.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextPrimary
                              : KlasivoColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        'Overall',
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
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

// ─── At-Risk Warning Banner ───────────────────────────────────────────────────

class _AtRiskWarningBanner extends StatelessWidget {
  final String studentName;

  const _AtRiskWarningBanner({required this.studentName});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      decoration: BoxDecoration(
        color: KlasivoColors.errorSurface.withValues(alpha: isDark ? 0.15 : 1.0),
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        border: Border.all(
          color: KlasivoColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(KlasivoSpacing.sm),
            decoration: BoxDecoration(
              color: KlasivoColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: KlasivoColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: KlasivoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attention Needed',
                  style: KlasivoTypography.titleSmall.copyWith(
                    color: KlasivoColors.error,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xs),
                Text(
                  '$studentName may need additional academic support. Please contact the teacher.',
                  style: KlasivoTypography.bodySmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grade Level Badge ────────────────────────────────────────────────────────

class _GradeLevelBadge extends StatelessWidget {
  final _GradeConfig config;

  const _GradeLevelBadge({required this.config});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.md),
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
              ),
              child: Icon(config.icon, color: config.color, size: 28),
            ),
            const SizedBox(width: KlasivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KlasivoSpacing.md,
                          vertical: KlasivoSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: config.color.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(KlasivoRadius.pill),
                        ),
                        child: Text(
                          config.label,
                          style: KlasivoTypography.labelMedium.copyWith(
                            color: config.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KlasivoSpacing.sm),
                  Text(
                    config.description,
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
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

// ─── Grade Level Configuration ────────────────────────────────────────────────

class _GradeConfig {
  final String label;
  final Color color;
  final IconData icon;
  final String description;

  const _GradeConfig({
    required this.label,
    required this.color,
    required this.icon,
    required this.description,
  });
}
