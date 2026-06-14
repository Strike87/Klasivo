import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/parent_link_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_card.dart';

// ─── Parent Attendance View ───────────────────────────────────────────────────

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

            return KlasivoCard(
              variant: KlasivoCardVariant.elevated,
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              padding: EdgeInsets.zero,
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
