import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/parent_link_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_components.dart';

// ─── Parent Assignments Screen — View-Only Class Assignments ──────────────────

class ParentAssignmentsScreen extends ConsumerWidget {
  const ParentAssignmentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final links = ref.watch(parentLinksProvider);
    final approvedLinks = links.where((l) => l.isApproved).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assignments',
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
                subtitle: 'Link your child to view assignments.',
                actionLabel: 'Link a Child',
                onAction: () =>
                    context.go(AppConstants.routeParentLink),
                iconColor: KlasivoColors.secondary,
              ),
            )
          : _ParentAssignmentsList(
              studentId: approvedLinks.first.studentId,
              organizationId: approvedLinks.first.organizationId,
            ),
    );
  }
}

// ─── Assignments List (fetched by student's classId) ──────────────────────────

class _ParentAssignmentsList extends ConsumerStatefulWidget {
  final String studentId;
  final String organizationId;

  const _ParentAssignmentsList({
    required this.studentId,
    required this.organizationId,
  });

  @override
  ConsumerState<_ParentAssignmentsList> createState() =>
      _ParentAssignmentsListState();
}

class _ParentAssignmentsListState
    extends ConsumerState<_ParentAssignmentsList> {
  String? _classId;
  bool _loadingClass = true;
  String? _classError;

  @override
  void initState() {
    super.initState();
    _fetchStudentClassId();
  }

  Future<void> _fetchStudentClassId() async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _classId = data['classId'] as String?;
            _loadingClass = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _classError = 'Student record not found';
            _loadingClass = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _classError = e.toString();
          _loadingClass = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadingClass) {
      return const Center(child: KlasivoLoading());
    }

    if (_classError != null) {
      return Center(
        child: KlasivoEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Error loading assignments',
          subtitle: 'Please try again later',
          iconColor: KlasivoColors.error,
        ),
      );
    }

    if (_classId == null || _classId!.isEmpty) {
      return Center(
        child: KlasivoEmptyState(
          icon: Icons.class_outlined,
          title: 'No class assigned',
          subtitle: 'Your child has not been assigned to a class yet.',
          iconColor: isDark
              ? KlasivoColors.darkTextTertiary
              : KlasivoColors.lightTextTertiary,
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.assignmentsCollection)
          .where('classId', isEqualTo: _classId)
          .orderBy('dueDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: KlasivoLoading());
        }

        if (snapshot.hasError) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading assignments',
              subtitle: 'Please try again later',
              iconColor: KlasivoColors.error,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No assignments yet',
              subtitle:
                  'Assignments will appear here once published by the teacher',
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
            final title = data['title'] as String? ?? 'Untitled Assignment';
            final dueDate = data['dueDate'] as Timestamp?;
            final status =
                data['status'] as String? ?? AppConstants.assignmentStatusDraft;
            final subjectName = data['subjectName'] as String?;
            final subjectId = data['subjectId'] as String?;
            final dateFormat = DateFormat('MMM dd, yyyy');

            // Status badge config
            Color statusColor;
            IconData statusIcon;
            String statusLabel;
            switch (status) {
              case AppConstants.assignmentStatusPublished:
                statusColor = KlasivoColors.secondary;
                statusIcon = Icons.publish_rounded;
                statusLabel = 'Published';
                break;
              case AppConstants.assignmentStatusDraft:
                statusColor = KlasivoColors.accent;
                statusIcon = Icons.edit_note_rounded;
                statusLabel = 'Draft';
                break;
              case AppConstants.assignmentStatusGraded:
                statusColor = KlasivoColors.primary;
                statusIcon = Icons.grading_rounded;
                statusLabel = 'Graded';
                break;
              default:
                statusColor = isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary;
                statusIcon = Icons.help_outline_rounded;
                statusLabel = status;
            }

            // Check if assignment is overdue
            final isOverdue = dueDate != null &&
                dueDate.toDate().isBefore(DateTime.now()) &&
                status != AppConstants.assignmentStatusGraded;

            return KlasivoCard(
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
                  title,
                  style: KlasivoTypography.titleSmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subjectName != null)
                      Text(
                        subjectName,
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextSecondary
                              : KlasivoColors.lightTextSecondary,
                        ),
                      ),
                    if (dueDate != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded,
                            size: 12,
                            color: isOverdue
                                ? KlasivoColors.error
                                : (isDark
                                    ? KlasivoColors.darkTextTertiary
                                    : KlasivoColors.lightTextTertiary),
                          ),
                          const SizedBox(width: KlasivoSpacing.xs),
                          Text(
                            'Due: ${dateFormat.format(dueDate.toDate())}',
                            style: KlasivoTypography.caption.copyWith(
                              color: isOverdue
                                  ? KlasivoColors.error
                                  : (isDark
                                      ? KlasivoColors.darkTextTertiary
                                      : KlasivoColors.lightTextTertiary),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
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
