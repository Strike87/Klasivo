import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_modal.dart';

// ─── Notification Detail Screen ────────────────────────────────────────────────

class NotificationDetailScreen extends ConsumerWidget {
  final String notificationId;

  const NotificationDetailScreen({Key? key, required this.notificationId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection(AppConstants.notificationsCollection)
            .doc(notificationId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48,
                    color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary),
                  const SizedBox(height: KlasivoSpacing.md),
                  Text('Notification not found',
                    style: KlasivoTypography.titleMedium.copyWith(
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                  const SizedBox(height: KlasivoSpacing.sm),
                  Text('It may have been deleted or is no longer available.',
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data['title'] ?? 'Notification';
          final body = data['body'] ?? '';
          final type = data['type'] ?? '';
          final isRead = data['isRead'] ?? false;
          final createdAt = data['createdAt'] as Timestamp?;

          // Mark as read when viewing
          if (!isRead) {
            FirebaseFirestore.instance
                .collection(AppConstants.notificationsCollection)
                .doc(notificationId)
                .update({'isRead': true});
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(KlasivoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Type Badge & Time ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.md),
                      decoration: BoxDecoration(
                        color: _typeColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.md),
                      ),
                      child: Icon(_typeIcon(type), color: _typeColor(type), size: 28),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KlasivoSpacing.sm,
                              vertical: KlasivoSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: _typeColor(type).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                            ),
                            child: Text(
                              _typeLabel(type),
                              style: KlasivoTypography.labelSmall.copyWith(
                                color: _typeColor(type),
                              ),
                            ),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(height: KlasivoSpacing.xs),
                            Text(
                              _formatDateTime(createdAt.toDate()),
                              style: KlasivoTypography.caption.copyWith(
                                color: isDark
                                    ? KlasivoColors.darkTextTertiary
                                    : KlasivoColors.lightTextTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Title ──
                Text(
                  title,
                  style: KlasivoTypography.headlineMedium.copyWith(
                    color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Body ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(KlasivoSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
                    borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    border: Border.all(
                      color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    body,
                    style: KlasivoTypography.bodyLarge.copyWith(
                      color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Related Data ──
                if (data['examId'] != null || data['classId'] != null) ...[
                  Text('Related', style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                  )),
                  const SizedBox(height: KlasivoSpacing.sm),
                  if (data['examId'] != null)
                    ListTile(
                      leading: const Icon(Icons.quiz_outlined, size: 20),
                      title: const Text('View Exam'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: () {
                        // Navigate to exam detail
                      },
                    ),
                  if (data['classId'] != null)
                    ListTile(
                      leading: const Icon(Icons.class_outlined, size: 20),
                      title: const Text('View Class'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: () {
                        // Navigate to class detail
                      },
                    ),
                ],

                // ── Delete Action ──
                const SizedBox(height: KlasivoSpacing.xxxl),
                Center(
                  child: KlasivoButton(
                    label: 'Delete Notification',
                    onPressed: () async {
                      final confirmed = await KlasivoModal.confirm(
                        context: context,
                        title: 'Delete Notification',
                        message: 'Are you sure you want to delete this notification?',
                        confirmLabel: 'Delete',
                        isDangerous: true,
                      );
                      if (confirmed == true && context.mounted) {
                        await FirebaseFirestore.instance
                            .collection(AppConstants.notificationsCollection)
                            .doc(notificationId)
                            .delete();
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    variant: KlasivoButtonVariant.danger,
                    icon: Icons.delete_outline_rounded,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case AppConstants.notificationExamPublished:
        return Icons.publish_outlined;
      case AppConstants.notificationExamReminder:
        return Icons.timer_outlined;
      case AppConstants.notificationResultPublished:
        return Icons.assessment_outlined;
      case AppConstants.notificationAnnouncement:
        return Icons.campaign_outlined;
      case AppConstants.notificationViolation:
        return Icons.warning_amber_outlined;
      case AppConstants.notificationNewMessage:
        return Icons.message_outlined;
      case AppConstants.notificationAssignmentPublished:
        return Icons.assignment_outlined;
      case AppConstants.notificationAssignmentGraded:
        return Icons.grade_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case AppConstants.notificationExamPublished:
        return KlasivoColors.primary;
      case AppConstants.notificationExamReminder:
        return KlasivoColors.accent;
      case AppConstants.notificationResultPublished:
        return KlasivoColors.secondary;
      case AppConstants.notificationAnnouncement:
        return KlasivoColors.accent;
      case AppConstants.notificationViolation:
        return KlasivoColors.error;
      case AppConstants.notificationNewMessage:
        return KlasivoColors.primary;
      default:
        return KlasivoColors.primary;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case AppConstants.notificationExamPublished:
        return 'Exam Published';
      case AppConstants.notificationExamReminder:
        return 'Exam Reminder';
      case AppConstants.notificationResultPublished:
        return 'Results Published';
      case AppConstants.notificationAnnouncement:
        return 'Announcement';
      case AppConstants.notificationViolation:
        return 'Violation';
      case AppConstants.notificationNewMessage:
        return 'New Message';
      case AppConstants.notificationAssignmentPublished:
        return 'Assignment';
      case AppConstants.notificationAssignmentGraded:
        return 'Graded';
      default:
        return 'Notification';
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
