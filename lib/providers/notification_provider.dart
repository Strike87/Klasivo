import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/notification_service.dart' as notif_service;
import 'auth_provider.dart';

// ─── Notifications Stream ────────────────────────────────────────────────────

final notificationsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  return notif_service.NotificationService.getUserNotificationsStream(userId);
});

// ─── Parsed Notifications List ───────────────────────────────────────────────

final notificationsProvider = Provider<List<NotificationData>>((ref) {
  final asyncNotifs = ref.watch(notificationsStreamProvider);
  return asyncNotifs.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => NotificationData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Unread Count ────────────────────────────────────────────────────────────

final unreadNotificationsProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

// ─── Unread Count (async, for badge) ─────────────────────────────────────────

final unreadCountProvider = FutureProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;

  return notif_service.NotificationService.getUnreadCount(userId);
});

// ─── Notification Data Model ─────────────────────────────────────────────────

class NotificationData {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? organizationId;
  final String? relatedId;
  final String? relatedType;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  NotificationData({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.organizationId,
    this.relatedId,
    this.relatedType,
    this.data = const {},
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationData(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? '',
      organizationId: data['organizationId'],
      relatedId: data['relatedId'],
      relatedType: data['relatedType'],
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'organizationId': organizationId,
      'relatedId': relatedId,
      'relatedType': relatedType,
      'data': data,
      'isRead': isRead,
    };
  }

  /// Get the icon name for this notification type.
  String get iconName {
    switch (type) {
      case AppConstants.notificationExamPublished:
      case AppConstants.notificationExamReminder:
        return 'quiz';
      case AppConstants.notificationResultPublished:
        return 'bar_chart';
      case AppConstants.notificationNewMessage:
        return 'chat';
      case AppConstants.notificationAssignmentPublished:
        return 'assignment';
      case AppConstants.notificationAttendance:
        return 'how_to_reg';
      case AppConstants.notificationTeacherInvited:
        return 'person_add';
      case AppConstants.notificationAnnouncement:
        return 'campaign';
      case AppConstants.notificationViolation:
        return 'warning';
      default:
        return 'notifications';
    }
  }

  /// Get a deep link route for this notification.
  String? get deepLinkRoute {
    if (relatedId == null) return null;

    switch (relatedType) {
      case 'exam':
        return '/exam/$relatedId';
      case 'assignment':
        return '/assignments/$relatedId';
      case 'conversation':
        return '/messages/$relatedId';
      default:
        return null;
    }
  }
}
