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
import '../../../widgets/klasivo_avatar.dart';

// ─── Parent Results View ──────────────────────────────────────────────────────

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

            return KlasivoCard(
              variant: KlasivoCardVariant.elevated,
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: KlasivoAvatar(
                  name: '$percentage%',
                  size: KlasivoAvatarSize.md,
                  backgroundColor: (passed
                          ? KlasivoColors.secondary
                          : KlasivoColors.error)
                      .withValues(alpha: 0.1),
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
