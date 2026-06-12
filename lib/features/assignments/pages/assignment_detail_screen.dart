import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/assignment_service.dart';
import '../../../providers/assignment_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ASSIGNMENT DETAIL SCREEN — Klasivo v1.7
// Shows assignment info, submission stats, student submissions list with grading
// ═══════════════════════════════════════════════════════════════════════════════

class AssignmentDetailScreen extends ConsumerWidget {
  final String assignmentId;

  const AssignmentDetailScreen({
    Key? key,
    required this.assignmentId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(assignmentsProvider);
    final classes = ref.watch(classesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find the assignment from the list
    final assignment = assignments.where((a) => a.id == assignmentId).firstOrNull;

    if (assignment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Details')),
        body: const KlasivoEmptyState(
          icon: Icons.error_outline,
          title: 'Assignment Not Found',
          subtitle: 'This assignment may have been deleted',
        ),
      );
    }

    // Resolve class name
    String className = 'Unknown Class';
    int totalStudents = 0;
    try {
      final cls = classes.firstWhere((c) => c.id == assignment.classId);
      className = cls.name;
      totalStudents = cls.studentCount;
    } catch (_) {}

    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'publish':
                  final confirmed = await KlasivoModal.confirm(
                    context: context,
                    title: 'Publish Assignment',
                    message:
                        'Once published, students will be able to see and submit this assignment.',
                    confirmLabel: 'Publish',
                  );
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(assignmentServiceProvider)
                          .publishAssignment(assignmentId);
                      if (context.mounted) {
                        KlasivoToast.success(context,
                            message: 'Assignment published!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        KlasivoToast.error(context,
                            message: 'Failed: $e');
                      }
                    }
                  }
                  break;

                case 'edit':
                  context.go(
                    '/teacher/assignments/edit/$assignmentId',
                    extra: assignment,
                  );
                  break;

                case 'delete':
                  final confirmed = await KlasivoModal.confirm(
                    context: context,
                    title: 'Delete Assignment',
                    message:
                        'Are you sure? All submissions will also be deleted.',
                    confirmLabel: 'Delete',
                    isDangerous: true,
                  );
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(assignmentServiceProvider)
                          .deleteAssignment(assignmentId);
                      if (context.mounted) {
                        KlasivoToast.success(context, message: 'Assignment deleted');
                        context.go('/teacher/assignments');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        KlasivoToast.error(context,
                            message: 'Failed: $e');
                      }
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              if (assignment.isDraft)
                const PopupMenuItem(
                  value: 'publish',
                  child: Row(
                    children: [
                      Icon(Icons.publish, size: 20),
                      SizedBox(width: KlasivoSpacing.sm),
                      Text('Publish'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: KlasivoSpacing.sm),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: KlasivoColors.error),
                    SizedBox(width: KlasivoSpacing.sm),
                    Text('Delete', style: TextStyle(color: KlasivoColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KlasivoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Card ──
            KlasivoCard(
              variant: KlasivoCardVariant.outlined,
              padding: const EdgeInsets.all(KlasivoSpacing.xxl),
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          assignment.title,
                          style: KlasivoTypography.headlineSmall.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextPrimary
                                : KlasivoColors.lightTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: KlasivoSpacing.sm),
                      _DetailStatusBadge(assignment: assignment),
                    ],
                  ),

                  // Description
                  if (assignment.description != null &&
                      assignment.description!.isNotEmpty) ...[
                    const SizedBox(height: KlasivoSpacing.md),
                    Text(
                      assignment.description!,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextSecondary
                            : KlasivoColors.lightTextSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: KlasivoSpacing.lg),

                  // Due Date Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KlasivoSpacing.md,
                      vertical: KlasivoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: (assignment.isOverdue && assignment.isPublished
                              ? KlasivoColors.errorSurface
                              : isDark
                                  ? KlasivoColors.darkSurface
                                  : KlasivoColors.primarySurface)
                          .withValues(alpha: isDark ? 0.15 : 1.0),
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: assignment.isOverdue && assignment.isPublished
                              ? KlasivoColors.error
                              : KlasivoColors.primary,
                        ),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Text(
                          'Due ${dateFormat.format(assignment.dueDate)}',
                          style: KlasivoTypography.bodyMedium.copyWith(
                            color: assignment.isOverdue && assignment.isPublished
                                ? KlasivoColors.error
                                : isDark
                                    ? KlasivoColors.darkTextSecondary
                                    : KlasivoColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: KlasivoSpacing.md),

                  // Class info
                  Row(
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 16,
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                      const SizedBox(width: KlasivoSpacing.xs),
                      Text(
                        className,
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                      if (assignment.attachments.isNotEmpty) ...[
                        const SizedBox(width: KlasivoSpacing.md),
                        Icon(
                          Icons.attach_file,
                          size: 16,
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        const SizedBox(width: KlasivoSpacing.xs),
                        Text(
                          '${assignment.attachments.length} file${assignment.attachments.length != 1 ? 's' : ''}',
                          style: KlasivoTypography.bodySmall.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextTertiary
                                : KlasivoColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Submission Stats ──
            _SubmissionStatsSection(
              assignmentId: assignmentId,
              totalStudents: totalStudents,
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Student Submissions List ──
            KlasivoSectionHeader(title: 'Submissions'),
            const SizedBox(height: KlasivoSpacing.md),
            _SubmissionsList(assignmentId: assignmentId),
            const SizedBox(height: KlasivoSpacing.xxxl),

            // ── Publish Button (for drafts) ──
            if (assignment.isDraft)
              KlasivoButton(
                label: 'Publish Assignment',
                icon: Icons.publish,
                fullWidth: true,
                onPressed: () async {
                  final confirmed = await KlasivoModal.confirm(
                    context: context,
                    title: 'Publish Assignment',
                    message:
                        'Once published, students will be able to see and submit this assignment.',
                    confirmLabel: 'Publish',
                  );
                  if (confirmed == true) {
                    try {
                      await ref
                          .read(assignmentServiceProvider)
                          .publishAssignment(assignmentId);
                      if (context.mounted) {
                        KlasivoToast.success(context,
                            message: 'Assignment published!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        KlasivoToast.error(context,
                            message: 'Failed: $e');
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Status Badge ──────────────────────────────────────────────────────

class _DetailStatusBadge extends StatelessWidget {
  final AssignmentData assignment;

  const _DetailStatusBadge({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final isOverdue = assignment.isOverdue && assignment.isPublished;
    final isDraft = assignment.isDraft;

    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    if (isOverdue) {
      bgColor = KlasivoColors.errorSurface;
      textColor = KlasivoColors.error;
      label = 'Overdue';
      icon = Icons.warning_amber_rounded;
    } else if (isDraft) {
      bgColor = KlasivoColors.accentSurface;
      textColor = KlasivoColors.accent;
      label = 'Draft';
      icon = Icons.edit_outlined;
    } else if (assignment.status == AppConstants.assignmentStatusGraded) {
      bgColor = KlasivoColors.secondarySurface;
      textColor = KlasivoColors.secondary;
      label = 'Graded';
      icon = Icons.grade_outlined;
    } else {
      bgColor = KlasivoColors.secondarySurface;
      textColor = KlasivoColors.secondary;
      label = 'Published';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.md,
        vertical: KlasivoSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            label,
            style: KlasivoTypography.labelMedium.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

// ─── Submission Stats Section ─────────────────────────────────────────────────

class _SubmissionStatsSection extends StatelessWidget {
  final String assignmentId;
  final int totalStudents;

  const _SubmissionStatsSection({
    required this.assignmentId,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: AssignmentService().getSubmissionsByAssignmentStream(assignmentId),
      builder: (context, snapshot) {
        final submittedCount = snapshot.data?.docs.length ?? 0;
        final gradedCount = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == AppConstants.assignmentStatusGraded;
        }).length ?? 0;

        return Row(
          children: [
            Expanded(
              child: KlasivoAnalyticsCard(
                value: '$submittedCount',
                label: 'Submitted',
                icon: Icons.upload_outlined,
                color: KlasivoColors.primary,
              ),
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            Expanded(
              child: KlasivoAnalyticsCard(
                value: '$totalStudents',
                label: 'Total Students',
                icon: Icons.people_outline,
                color: KlasivoColors.accent,
              ),
            ),
            const SizedBox(width: KlasivoSpacing.sm),
            Expanded(
              child: KlasivoAnalyticsCard(
                value: '$gradedCount',
                label: 'Graded',
                icon: Icons.grade_outlined,
                color: KlasivoColors.secondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Submissions List ─────────────────────────────────────────────────────────

class _SubmissionsList extends StatelessWidget {
  final String assignmentId;

  const _SubmissionsList({required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: AssignmentService().getSubmissionsByAssignmentStream(assignmentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(KlasivoSpacing.xxxl),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(KlasivoSpacing.xxxl),
              child: Text(
                'Error loading submissions',
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: KlasivoColors.error,
                ),
              ),
            ),
          );
        }

        final submissions = snapshot.data?.docs ?? [];

        if (submissions.isEmpty) {
          return KlasivoEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Submissions Yet',
            subtitle: 'Student submissions will appear here once they submit',
            iconColor: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          );
        }

        return Column(
          children: submissions.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return _SubmissionCard(
              submissionId: doc.id,
              studentName: data['studentId'] ?? 'Unknown Student',
              status: data['status'] ?? AppConstants.assignmentStatusSubmitted,
              grade: (data['grade'] as num?)?.toDouble(),
              feedback: data['feedback'] as String?,
              submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Submission Card ──────────────────────────────────────────────────────────

class _SubmissionCard extends StatelessWidget {
  final String submissionId;
  final String studentName;
  final String status;
  final double? grade;
  final String? feedback;
  final DateTime? submittedAt;

  const _SubmissionCard({
    required this.submissionId,
    required this.studentName,
    required this.status,
    this.grade,
    this.feedback,
    this.submittedAt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, yyyy · hh:mm a');

    final isGraded = status == AppConstants.assignmentStatusGraded;
    final isSubmitted = status == AppConstants.assignmentStatusSubmitted;

    // Status color
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isGraded) {
      statusColor = KlasivoColors.secondary;
      statusLabel = 'Graded';
      statusIcon = Icons.check_circle;
    } else if (isSubmitted) {
      statusColor = KlasivoColors.primary;
      statusLabel = 'Submitted';
      statusIcon = Icons.upload_outlined;
    } else {
      statusColor = KlasivoColors.accent;
      statusLabel = 'Pending';
      statusIcon = Icons.schedule;
    }

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: () => _showGradingDialog(context),
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      margin: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
      child: Row(
        children: [
          // Avatar
          KlasivoAvatar(
            name: studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
            size: KlasivoAvatarSize.md,
            backgroundColor: statusColor.withValues(alpha: 0.1),
          ),
          const SizedBox(width: KlasivoSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: KlasivoTypography.titleSmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: KlasivoSpacing.xs),
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: KlasivoSpacing.xs),
                    Text(
                      statusLabel,
                      style: KlasivoTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (submittedAt != null) ...[
                      const SizedBox(width: KlasivoSpacing.sm),
                      Text(
                        '· ${dateFormat.format(submittedAt!)}',
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Grade badge
          if (isGraded && grade != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.md,
                vertical: KlasivoSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: KlasivoColors.secondarySurface,
                borderRadius: BorderRadius.circular(KlasivoRadius.pill),
              ),
              child: Text(
                '${grade!.toStringAsFixed(grade! % 1 == 0 ? 0 : 1)}%',
                style: KlasivoTypography.labelMedium.copyWith(
                  color: KlasivoColors.secondary,
                ),
              ),
            ),

          if (!isGraded)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.md,
                vertical: KlasivoSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: KlasivoColors.primarySurface,
                borderRadius: BorderRadius.circular(KlasivoRadius.pill),
              ),
              child: Text(
                'Grade',
                style: KlasivoTypography.labelSmall.copyWith(
                  color: KlasivoColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Grading Dialog ─────────────────────────────────────────────────────

  void _showGradingDialog(BuildContext context) {
    final scoreController = TextEditingController(
      text: grade != null ? grade!.toStringAsFixed(grade! % 1 == 0 ? 0 : 1) : '',
    );
    final feedbackController = TextEditingController(text: feedback ?? '');
    final formKey = GlobalKey<FormState>();

    KlasivoModal.showForm(
      context: context,
      title: 'Grade: $studentName',
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score
            KlasivoTextField(
              controller: scoreController,
              label: 'Score *',
              hint: 'e.g. 85',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final val = double.tryParse(v);
                if (val == null || val < 0 || val > 100) return '0-100';
                return null;
              },
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // Feedback
            KlasivoTextField(
              controller: feedbackController,
              label: 'Feedback (optional)',
              hint: 'Comments for the student...',
              maxLines: 3,
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KlasivoButton(
                  label: 'Cancel',
                  variant: KlasivoButtonVariant.tertiary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: KlasivoSpacing.sm),
                KlasivoButton(
                  label: 'Submit Grade',
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final score = double.parse(scoreController.text.trim());
                    final fb = feedbackController.text.trim().isEmpty
                        ? null
                        : feedbackController.text.trim();

                    try {
                      await AssignmentService().gradeSubmission(
                        submissionId: submissionId,
                        grade: score,
                        feedback: fb,
                        gradedBy: '', // Will be set from auth context in provider
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        KlasivoToast.success(context, message: 'Submission graded!');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        KlasivoToast.error(context,
                            message: 'Failed: $e');
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
