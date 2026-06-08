import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/parent_link_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_components.dart';
import '../parent/pages/parent_dashboard.dart';

// ─── Parent Navigation Shell ──────────────────────────────────────────────────

class ParentShell extends ConsumerStatefulWidget {
  final Widget child;

  const ParentShell({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _currentIndex = 0;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/parent',
    ),
    _NavDestination(
      label: 'Results',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment_rounded,
      route: '/parent/results',
    ),
    _NavDestination(
      label: 'Attendance',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      route: '/parent/attendance',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncIndexWithRoute();
  }

  void _syncIndexWithRoute() {
    final location = GoRouterState.of(context).matchedLocation;
    // Match the longest prefix (e.g., '/parent/results' before '/parent')
    int bestMatch = -1;
    int bestLength = 0;
    for (int i = 0; i < _destinations.length; i++) {
      final route = _destinations[i].route;
      if (location.startsWith(route) && route.length > bestLength) {
        bestMatch = i;
        bestLength = route.length;
      }
    }
    if (bestMatch != -1 && bestMatch != _currentIndex) {
      setState(() => _currentIndex = bestMatch);
    }
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTap,
        backgroundColor: isDark
            ? KlasivoColors.darkSurface
            : KlasivoColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: KlasivoColors.secondarySurface,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KlasivoTypography.labelSmall.copyWith(
              color: KlasivoColors.secondary,
            );
          }
          return KlasivoTypography.labelSmall.copyWith(
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          );
        }),

        destinations: _destinations
            .map((dest) => NavigationDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon),
                  label: dest.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

// ─── Parent Results View — Inline Tab Content ────────────────────────────────

class ParentResultsView extends ConsumerWidget {
  const ParentResultsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final links = ref.watch(parentLinksProvider);
    final approvedLinks = links.where((l) => l.isApproved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Results',
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
                subtitle:
                    'Link your child to view their exam results.',
                actionLabel: 'Link a Child',
                onAction: () =>
                    context.go(AppConstants.routeParentLink),
                iconColor: KlasivoColors.secondary,
              ),
            )
          : _ParentFullResultsList(
              studentId: approvedLinks.first.studentId,
            ),
    );
  }
}

// ─── Full Results List (for Results tab) ──────────────────────────────────────

class _ParentFullResultsList extends ConsumerWidget {
  final String studentId;

  const _ParentFullResultsList({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resultsAsync =
        ref.watch(parentStudentResultsProvider(studentId));

    return resultsAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (_, __) => Center(
        child: KlasivoEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading results',
          subtitle: 'Please try again later',
          iconColor: KlasivoColors.error,
        ),
      ),
      data: (snapshot) {
        final docs = snapshot.docs;

        if (docs.isEmpty) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.assessment_outlined,
              title: 'No results yet',
              subtitle: 'Exam results will appear here once available',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.lg,
            vertical: KlasivoSpacing.sm,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
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

            return Card(
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(KlasivoRadius.sm),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: (passed
                          ? KlasivoColors.secondary
                          : KlasivoColors.error)
                      .withValues(alpha: 0.1),
                  child: Text(
                    '$percentage%',
                    style: KlasivoTypography.labelMedium.copyWith(
                      color: passed
                          ? KlasivoColors.secondary
                          : KlasivoColors.error,
                    ),
                  ),
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
          },
        );
      },
    );
  }
}

// ─── Parent Attendance View — Inline Tab Content ──────────────────────────────

class ParentAttendanceView extends ConsumerWidget {
  const ParentAttendanceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final links = ref.watch(parentLinksProvider);
    final approvedLinks = links.where((l) => l.isApproved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance',
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
                subtitle:
                    'Link your child to view their attendance records.',
                actionLabel: 'Link a Child',
                onAction: () =>
                    context.go(AppConstants.routeParentLink),
                iconColor: KlasivoColors.secondary,
              ),
            )
          : _ParentFullAttendanceList(
              studentId: approvedLinks.first.studentId,
            ),
    );
  }
}

// ─── Full Attendance List (for Attendance tab) ────────────────────────────────

class _ParentFullAttendanceList extends ConsumerWidget {
  final String studentId;

  const _ParentFullAttendanceList({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendanceAsync =
        ref.watch(parentStudentAttendanceProvider(studentId));

    return attendanceAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (_, __) => Center(
        child: KlasivoEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading attendance',
          subtitle: 'Please try again later',
          iconColor: KlasivoColors.error,
        ),
      ),
      data: (snapshot) {
        final docs = snapshot.docs;

        if (docs.isEmpty) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No attendance records',
              subtitle: 'Attendance records will appear here',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.lg,
            vertical: KlasivoSpacing.sm,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status =
                data['status'] as String? ?? 'unknown';
            final date = data['date'] as Timestamp?;
            final subject =
                data['subject'] as String? ?? data['subjectName'] as String?;
            final dateFormat = DateFormat('MMM dd, yyyy');

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

            return Card(
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(KlasivoRadius.sm),
              ),
              child: ListTile(
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
          },
        );
      },
    );
  }
}
