import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            KlasivoButton(
              label: 'Mark all read ($unreadCount)',
              icon: Icons.done_all,
              variant: KlasivoButtonVariant.tertiary,
              size: KlasivoButtonSize.sm,
              onPressed: () async {
                // Mark all as read
                for (final n in notifications.where((n) => !n.isRead)) {
                  await FirebaseFirestore.instance
                      .collection(AppConstants.notificationsCollection)
                      .doc(n.id)
                      .update({'isRead': true});
                }
              },
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No Notifications',
              subtitle: 'You\'re all caught up!',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationCard(notification: n);
              },
            ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationData notification;
  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: () async {
        if (!notification.isRead) {
          await FirebaseFirestore.instance
              .collection(AppConstants.notificationsCollection)
              .doc(notification.id)
              .update({'isRead': true});
        }
      },
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title,
                    style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(notification.body, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                if (notification.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_formatTime(notification.createdAt!), style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
        ],
      ),
    );
  }

  IconData get _typeIcon {
    switch (notification.type) {
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
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _typeColor {
    switch (notification.type) {
      case AppConstants.notificationExamPublished:
        return Colors.blue;
      case AppConstants.notificationExamReminder:
        return Colors.orange;
      case AppConstants.notificationResultPublished:
        return Colors.green;
      case AppConstants.notificationAnnouncement:
        return Colors.purple;
      case AppConstants.notificationViolation:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
