import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/submission_provider.dart';
import '../../providers/notification_provider.dart';
import '../../core/config/app_constants.dart';
import '../../core/config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/klasivo_card.dart';
import '../../widgets/klasivo_badge.dart';
import '../../widgets/klasivo_avatar.dart';
import '../../widgets/klasivo_modal.dart';
import '../../widgets/klasivo_components.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final classId = ref.watch(studentClassIdProvider);
    final stats = ref.watch(studentExamStatsProvider);
    final submissions = ref.watch(studentSubmissionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final className = ref.watch(studentClassNameProvider) ?? '-';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(examsStreamProvider);
          ref.invalidate(studentSubmissionsStreamProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Pinned App Bar ──
            SliverAppBar(
              pinned: true,
              floating: true,
              title: Text(
                'Klasivo',
                style: KlasivoTypography.titleLarge.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
              actions: [
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: isDark
                            ? KlasivoColors.darkIconDefault
                            : KlasivoColors.lightIconDefault,
                      ),
                      if ((ref.watch(unreadNotificationsProvider)) > 0)
                        Positioned(
                          top: -4,
                          right: -8,
                          child: KlasivoBadge(
                            label: '${ref.watch(unreadNotificationsProvider)}',
                            variant: KlasivoBadgeVariant.danger,
                            size: KlasivoBadgeSize.sm,
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => context.go('/student/notifications'),
                ),
                IconButton(
                  icon: Icon(
                    Icons.qr_code_scanner,
                    color: isDark
                        ? KlasivoColors.darkIconDefault
                        : KlasivoColors.lightIconDefault,
                  ),
                  onPressed: () => context.go('/student/scan-qr'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'logout') {
                      final confirmed = await KlasivoModal.confirm(
                        context: context,
                        title: 'Logout',
                        message: 'Are you sure you want to logout?',
                        confirmLabel: 'Logout',
                        isDangerous: true,
                      );
                      if (confirmed == true && context.mounted) {
                        await clearAuthData();
                        if (context.mounted) {
                          context.go('/auth');
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: KlasivoColors.error),
                          const SizedBox(width: KlasivoSpacing.sm),
                          Text(
                            'Logout',
                            style: KlasivoTypography.bodyMedium.copyWith(
                              color: KlasivoColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Hero Welcome Section — Emerald Gradient for Student ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.lg,
                  0,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(KlasivoSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.lg),
                    gradient: const LinearGradient(
                      colors: [
                        KlasivoColors.secondary,
                        KlasivoColors.secondaryDark,
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
                        style: KlasivoTypography.bodyLarge
                            .copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: KlasivoSpacing.xs),
                      Text(
                        userName ?? 'Student',
                        style: KlasivoTypography.headlineLarge
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: KlasivoSpacing.sm),
                      Text(
                        'Ready for your next exam?',
                        style: KlasivoTypography.bodyMedium
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Stats Analytics Cards — Row 1 ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KlasivoAnalyticsCard(
                        value: '${stats.upcoming}',
                        label: 'Upcoming',
                        icon: Icons.upcoming_outlined,
                        color: KlasivoColors.accent,
                        onTap: () => context.go('/student/exams'),
                      ),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),
                    Expanded(
                      child: KlasivoAnalyticsCard(
                        value: '${stats.completed}',
                        label: 'Completed',
                        icon: Icons.check_circle_outline,
                        color: KlasivoColors.secondary,
                        onTap: () => context.go('/student/exams'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats Analytics Cards — Row 2 ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.md,
                  KlasivoSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: KlasivoAnalyticsCard(
                        value: stats.averageScore > 0
                            ? '${stats.averageScore.toStringAsFixed(0)}%'
                            : '-',
                        label: 'Average Score',
                        icon: Icons.bar_chart_outlined,
                        color: KlasivoColors.primary,
                        onTap: () => context.go('/student/results'),
                      ),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),
                    Expanded(
                      child: KlasivoAnalyticsCard(
                        value: className,
                        label: 'My Class',
                        icon: Icons.class_outlined,
                        color: KlasivoColors.subjectEnglish,
                        onTap: null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Available Exams Section Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.xxl,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.md,
                ),
                child: KlasivoSectionHeader(
                  title: 'Available Exams',
                  actionLabel: 'View All',
                  onAction: () => context.go('/student/exams'),
                ),
              ),
            ),

            // ── Active Exams List ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KlasivoSpacing.lg,
                ),
                child: _ActiveExamsList(classId: classId),
              ),
            ),

            // ── Recent Results Section Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.xxl,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.md,
                ),
                child: KlasivoSectionHeader(
                  title: 'Recent Results',
                  actionLabel: 'View All',
                  onAction: () => context.go('/student/results'),
                ),
              ),
            ),

            // ── Recent Results List ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  0,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.xxxl,
                ),
                child: _RecentResultsList(submissions: submissions),
              ),
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (classId == null || classId!.isEmpty) {
      return KlasivoCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: KlasivoEmptyState(
          icon: Icons.quiz_outlined,
          title: 'No class assigned',
          subtitle: 'Contact your teacher to be assigned to a class',
          iconColor: isDark
              ? KlasivoColors.darkTextTertiary
              : KlasivoColors.lightTextTertiary,
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
        child: KlasivoLoading(),
      ),
      error: (_, __) => KlasivoCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: KlasivoEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading exams',
          subtitle: 'Please try again later',
          iconColor: KlasivoColors.error,
        ),
      ),
      data: (snapshot) {
        final allExams = snapshot.docs
            .map((doc) => ExamData.fromFirestore(doc))
            .toList();

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
          return KlasivoCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: KlasivoEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No available exams',
              subtitle: 'Your upcoming exams will appear here',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        return Column(
          children: activeExams.map((exam) {
            final isActive = exam.isActive;
            final canStart = exam.canStart;
            final dateFormat = DateFormat('MMM dd, hh:mm a');

            return KlasivoCard(
              variant: KlasivoCardVariant.interactive,
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
              padding: EdgeInsets.zero,
              onTap: canStart
                  ? () => context.go('/student/exams/${exam.id}/take')
                  : null,
              accentColor: isActive ? KlasivoColors.accentLight : null,
              child: Padding(
                padding: const EdgeInsets.all(KlasivoSpacing.lg),
                child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(KlasivoSpacing.md),
                        decoration: BoxDecoration(
                          color: (isActive
                                  ? KlasivoColors.accent
                                  : KlasivoColors.primary)
                              .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(KlasivoRadius.sm),
                        ),
                        child: Icon(
                          isActive
                              ? Icons.play_circle_outline
                              : Icons.schedule,
                          color: isActive
                              ? KlasivoColors.accent
                              : KlasivoColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: KlasivoSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.title,
                              style: KlasivoTypography.titleMedium.copyWith(
                                color: isDark
                                    ? KlasivoColors.darkTextPrimary
                                    : KlasivoColors.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: KlasivoSpacing.xs),
                            Text(
                              '${exam.durationMinutes} min · ${exam.questionCount} Q · ${exam.totalMarks} marks',
                              style: KlasivoTypography.bodySmall.copyWith(
                                color: isDark
                                    ? KlasivoColors.darkTextSecondary
                                    : KlasivoColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: KlasivoSpacing.xs),
                            Text(
                              isActive
                                  ? 'Started · Ends ${dateFormat.format(exam.endDate)}'
                                  : 'Starts ${dateFormat.format(exam.startDate)}',
                              style: KlasivoTypography.caption.copyWith(
                                color: isActive
                                    ? KlasivoColors.accentDark
                                    : (isDark
                                        ? KlasivoColors.darkTextTertiary
                                        : KlasivoColors.lightTextTertiary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canStart)
                        Icon(
                          Icons.chevron_right,
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                    ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final submittedSubs = submissions
        .where((s) =>
            s.status == AppConstants.submissionStatusSubmitted ||
            s.status == AppConstants.submissionStatusFlagged)
        .take(5)
        .toList();

    if (submittedSubs.isEmpty) {
      return KlasivoCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        child: KlasivoEmptyState(
          icon: Icons.assessment_outlined,
          title: 'No results yet',
          subtitle: 'Your exam results will appear here',
          iconColor: isDark
              ? KlasivoColors.darkTextTertiary
              : KlasivoColors.lightTextTertiary,
        ),
      );
    }

    return Column(
      children: submittedSubs.map((sub) {
        final passed = sub.percentage >= 50;
        final dateFormat = DateFormat('MMM dd, yyyy');

        return KlasivoCard(
          variant: KlasivoCardVariant.elevated,
          margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
          padding: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            leading: KlasivoAvatar(
              name: '${sub.percentage}%',
              size: KlasivoAvatarSize.md,
              backgroundColor:
                  (passed ? KlasivoColors.secondary : KlasivoColors.error)
                      .withValues(alpha: 0.1),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${sub.score}/${sub.totalMarks}',
                    style: KlasivoTypography.titleSmall.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                ),
                if (sub.isFlagged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KlasivoSpacing.sm,
                      vertical: KlasivoSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: KlasivoColors.errorSurface,
                      borderRadius:
                          BorderRadius.circular(KlasivoRadius.xs),
                    ),
                    child: Text(
                      'Flagged',
                      style: KlasivoTypography.labelSmall.copyWith(
                        color: KlasivoColors.error,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: sub.submittedAt != null
                ? Text(
                    dateFormat.format(sub.submittedAt!),
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextSecondary
                          : KlasivoColors.lightTextSecondary,
                    ),
                  )
                : null,
            trailing: Icon(
              passed ? Icons.check_circle : Icons.cancel,
              color: passed ? KlasivoColors.secondary : KlasivoColors.error,
              size: 20,
            ),
          ),
        );
      }).toList(),
    );
  }
}
