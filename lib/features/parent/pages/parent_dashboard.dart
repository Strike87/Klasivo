import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_link_provider.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_modal.dart';

// ─── Parent Dashboard — View-Only Child Overview ──────────────────────────────

class ParentDashboard extends ConsumerWidget {
  const ParentDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final links = ref.watch(parentLinksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter only approved links
    final approvedLinks = links.where((l) => l.isApproved).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(parentLinksStreamProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Pinned App Bar ──
            SliverAppBar(
              pinned: true,
              floating: true,
              title: Text(
                'Klasivo Parent',
                style: KlasivoTypography.titleLarge.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
              actions: [
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
                          context.go(AppConstants.routeAuth);
                        }
                      }
                    } else if (value == 'link') {
                      context.go(AppConstants.routeParentLink);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'link',
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded,
                              color: KlasivoColors.secondary),
                          SizedBox(width: KlasivoSpacing.sm),
                          Text('Link Another Child'),
                        ],
                      ),
                    ),
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

            // ── Hero Welcome Section — Emerald Gradient ──
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
                        userName ?? 'Parent',
                        style: KlasivoTypography.headlineLarge
                            .copyWith(color: Colors.white),
                      ),
                      if (approvedLinks.isNotEmpty) ...[
                        const SizedBox(height: KlasivoSpacing.sm),
                        Text(
                          'Viewing ${approvedLinks.first.studentName ?? 'your child'}\'s progress',
                          style: KlasivoTypography.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── No Linked Students Empty State ──
            if (approvedLinks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KlasivoSpacing.lg,
                    KlasivoSpacing.xxl,
                    KlasivoSpacing.lg,
                    0,
                  ),
                  child: KlasivoCard(
                    child: KlasivoEmptyState(
                      icon: Icons.child_care_outlined,
                      title: 'No children linked',
                      subtitle:
                          'Link your child using a code from their teacher to see their academic progress here.',
                      actionLabel: 'Link a Child',
                      onAction: () =>
                          context.go(AppConstants.routeParentLink),
                      iconColor: KlasivoColors.secondary,
                    ),
                  ),
                ),
              ),

            // ── Linked Student Data ──
            if (approvedLinks.isNotEmpty) ...[
              // ── Results Overview Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KlasivoSpacing.lg,
                    KlasivoSpacing.xxl,
                    KlasivoSpacing.lg,
                    KlasivoSpacing.md,
                  ),
                  child: KlasivoSectionHeader(
                    title: 'Results Overview',
                  ),
                ),
              ),

              // ── Results Analytics Cards ──
              SliverToBoxAdapter(
                child: _ResultsAnalyticsRow(
                  studentId: approvedLinks.first.studentId,
                ),
              ),

              // ── Recent Results List ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KlasivoSpacing.lg,
                    KlasivoSpacing.md,
                    KlasivoSpacing.lg,
                    0,
                  ),
                  child: _ParentResultsList(
                    studentId: approvedLinks.first.studentId,
                  ),
                ),
              ),

              // ── Attendance Overview Section ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KlasivoSpacing.lg,
                    KlasivoSpacing.xxl,
                    KlasivoSpacing.lg,
                    KlasivoSpacing.md,
                  ),
                  child: KlasivoSectionHeader(
                    title: 'Attendance Overview',
                  ),
                ),
              ),

              // ── Attendance Analytics Card ──
              SliverToBoxAdapter(
                child: _AttendanceAnalyticsCard(
                  studentId: approvedLinks.first.studentId,
                ),
              ),

              // ── Recent Attendance Records ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KlasivoSpacing.lg,
                    KlasivoSpacing.md,
                    KlasivoSpacing.lg,
                    KlasivoSpacing.xxxl,
                  ),
                  child: _ParentAttendanceList(
                    studentId: approvedLinks.first.studentId,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Results Analytics Row — Average Score & Exams Completed ──────────────────

class _ResultsAnalyticsRow extends ConsumerWidget {
  final String studentId;

  const _ResultsAnalyticsRow({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync =
        ref.watch(parentStudentResultsProvider(studentId));

    return resultsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
        child: Row(
          children: [
            Expanded(child: _skeletonCard()),
            const SizedBox(width: KlasivoSpacing.md),
            Expanded(child: _skeletonCard()),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (snapshot) {
        final docs = snapshot.docs;
        final totalExams = docs.length;
        double avgScore = 0;
        if (docs.isNotEmpty) {
          double total = 0;
          int count = 0;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final score = (data['score'] as num?)?.toDouble() ?? 0;
            final totalMarks =
                (data['totalMarks'] as num?)?.toDouble() ?? 1;
            if (totalMarks > 0) {
              total += (score / totalMarks) * 100;
              count++;
            }
          }
          avgScore = count > 0 ? total / count : 0;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: KlasivoAnalyticsCard(
                  value: avgScore > 0
                      ? '${avgScore.toStringAsFixed(0)}%'
                      : '-',
                  label: 'Average Score',
                  icon: Icons.bar_chart_outlined,
                  color: KlasivoColors.primary,
                ),
              ),
              const SizedBox(width: KlasivoSpacing.md),
              Expanded(
                child: KlasivoAnalyticsCard(
                  value: '$totalExams',
                  label: 'Exams Completed',
                  icon: Icons.check_circle_outline,
                  color: KlasivoColors.secondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _skeletonCard() {
    return KlasivoCard(
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KlasivoColors.lightBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.md),
          Container(
            width: 60,
            height: 24,
            decoration: BoxDecoration(
              color: KlasivoColors.lightBorder.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(KlasivoRadius.xs),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.xs),
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: KlasivoColors.lightBorder.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(KlasivoRadius.xs),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parent Results List — Read-Only ─────────────────────────────────────────

class _ParentResultsList extends ConsumerWidget {
  final String studentId;

  const _ParentResultsList({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resultsAsync =
        ref.watch(parentStudentResultsProvider(studentId));

    return resultsAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: KlasivoLoading(),
      ),
      error: (_, __) => KlasivoCard(
        child: KlasivoEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading results',
          subtitle: 'Please try again later',
          iconColor: KlasivoColors.error,
        ),
      ),
      data: (snapshot) {
        final docs = snapshot.docs.take(5).toList();

        if (docs.isEmpty) {
          return KlasivoCard(
            child: KlasivoEmptyState(
              icon: Icons.assessment_outlined,
              title: 'No results yet',
              subtitle: 'Your child\'s exam results will appear here',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final score = (data['score'] as num?)?.toDouble() ?? 0;
            final totalMarks =
                (data['totalMarks'] as num?)?.toDouble() ?? 1;
            final percentage = totalMarks > 0
                ? ((score / totalMarks) * 100).round()
                : 0;
            final passed = percentage >= 50;
            final examTitle =
                data['examTitle'] as String? ?? 'Untitled Exam';
            final submittedAt = data['submittedAt'] as Timestamp?;
            final dateFormat = DateFormat('MMM dd, yyyy');

            return KlasivoCard(
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              padding: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                leading: KlasivoAvatar(
                  name: '$percentage%',
                  backgroundColor: passed ? KlasivoColors.secondary : KlasivoColors.error,
                  size: KlasivoAvatarSize.md,
                ),
                title: Text(
                  examTitle,
                  style: KlasivoTypography.titleSmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${score.toInt()}/${totalMarks.toInt()}',
                  style: KlasivoTypography.bodySmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (submittedAt != null)
                      Text(
                        dateFormat.format(submittedAt.toDate()),
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    const SizedBox(width: KlasivoSpacing.sm),
                    Icon(
                      passed ? Icons.check_circle : Icons.cancel,
                      color: passed
                          ? KlasivoColors.secondary
                          : KlasivoColors.error,
                      size: 20,
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

// ─── Attendance Analytics Card ────────────────────────────────────────────────

class _AttendanceAnalyticsCard extends ConsumerWidget {
  final String studentId;

  const _AttendanceAnalyticsCard({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync =
        ref.watch(parentStudentAttendanceProvider(studentId));

    return attendanceAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
        child: KlasivoCard(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KlasivoColors.lightBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.md),
                Container(
                  width: 60,
                  height: 24,
                  decoration: BoxDecoration(
                    color: KlasivoColors.lightBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(KlasivoRadius.xs),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xs),
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: KlasivoColors.lightBorder.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(KlasivoRadius.xs),
                  ),
                ),
              ],
            ),
          ),
        ),
      error: (_, __) => const SizedBox.shrink(),
      data: (snapshot) {
        final docs = snapshot.docs;
        double attendanceRate = 0;
        if (docs.isNotEmpty) {
          int presentCount = 0;
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? '';
            if (status == AppConstants.attendanceStatusPresent ||
                status == AppConstants.attendanceStatusLate) {
              presentCount++;
            }
          }
          attendanceRate = (presentCount / docs.length) * 100;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
          child: KlasivoAnalyticsCard(
            value: docs.isNotEmpty
                ? '${attendanceRate.toStringAsFixed(0)}%'
                : '-',
            label: 'Attendance Rate',
            icon: Icons.calendar_today_outlined,
            color: KlasivoColors.secondary,
          ),
        );
      },
    );
  }
}

// ─── Parent Attendance List — Read-Only ───────────────────────────────────────

class _ParentAttendanceList extends ConsumerWidget {
  final String studentId;

  const _ParentAttendanceList({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendanceAsync =
        ref.watch(parentStudentAttendanceProvider(studentId));

    return attendanceAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: KlasivoLoading(),
      ),
      error: (_, __) => KlasivoCard(
        child: KlasivoEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading attendance',
          subtitle: 'Please try again later',
          iconColor: KlasivoColors.error,
        ),
      ),
      data: (snapshot) {
        final docs = snapshot.docs.take(7).toList();

        if (docs.isEmpty) {
          return KlasivoCard(
            child: KlasivoEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No attendance records',
              subtitle:
                  'Your child\'s attendance records will appear here',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status =
                data['status'] as String? ?? 'unknown';
            final date = data['date'] as Timestamp?;
            final subject =
                data['subject'] as String? ?? data['subjectName'] as String?;
            final dateFormat = DateFormat('MMM dd, yyyy');

            // Status color and icon
            Color statusColor;
            IconData statusIcon;
            String statusLabel;
            switch (status) {
              case AppConstants.attendanceStatusPresent:
                statusColor = KlasivoColors.secondary;
                statusIcon = Icons.check_circle_rounded;
                statusLabel = 'Present';
                break;
              case AppConstants.attendanceStatusAbsent:
                statusColor = KlasivoColors.error;
                statusIcon = Icons.cancel_rounded;
                statusLabel = 'Absent';
                break;
              case AppConstants.attendanceStatusLate:
                statusColor = KlasivoColors.accent;
                statusIcon = Icons.access_time_rounded;
                statusLabel = 'Late';
                break;
              case AppConstants.attendanceStatusExcused:
                statusColor = KlasivoColors.primary;
                statusIcon = Icons.info_rounded;
                statusLabel = 'Excused';
                break;
              default:
                statusColor = isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary;
                statusIcon = Icons.help_outline_rounded;
                statusLabel = status;
            }

            return KlasivoCard(
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              padding: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.sm),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.sm),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                title: Text(
                  date != null
                      ? dateFormat.format(date.toDate())
                      : 'Unknown date',
                  style: KlasivoTypography.titleSmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
                subtitle: subject != null
                    ? Text(
                        subject,
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextSecondary
                              : KlasivoColors.lightTextSecondary,
                        ),
                      )
                    : null,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.sm,
                    vertical: KlasivoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  child: Text(
                    statusLabel,
                    style: KlasivoTypography.labelSmall.copyWith(
                      color: statusColor,
                    ),
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
