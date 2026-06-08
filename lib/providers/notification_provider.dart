import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Unread Count (from stream) ──────────────────────────────────────────────

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

// ─── Notifications by Type ────────────────────────────────────────────────────

final notificationsByTypeProvider = Provider<Map<String, List<NotificationData>>>((ref) {
  final notifications = ref.watch(notificationsProvider);
  final Map<String, List<NotificationData>> grouped = {};

  for (final n in notifications) {
    final category = _getCategory(n.type);
    grouped.putIfAbsent(category, () => []).add(n);
  }

  return grouped;
});

String _getCategory(String type) {
  switch (type) {
    case AppConstants.notificationExamPublished:
    case AppConstants.notificationExamReminder:
    case AppConstants.notificationResultPublished:
    case AppConstants.notificationAssignmentPublished:
    case AppConstants.notificationAssignmentGraded:
      return 'academic';
    case AppConstants.notificationNewMessage:
      return 'messages';
    case AppConstants.notificationAnnouncement:
    case AppConstants.notificationOrgUpdate:
      return 'announcements';
    case AppConstants.notificationAttendance:
    case AppConstants.notificationViolation:
      return 'alerts';
    case AppConstants.notificationTeacherInvited:
    case AppConstants.notificationStudentJoined:
      return 'people';
    default:
      return 'other';
  }
}

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

  /// Get the icon for this notification type.
  IconData get icon {
    switch (type) {
      case AppConstants.notificationExamPublished:
      case AppConstants.notificationExamReminder:
        return Icons.quiz_outlined;
      case AppConstants.notificationResultPublished:
        return Icons.bar_chart_outlined;
      case AppConstants.notificationNewMessage:
        return Icons.chat_bubble_outline;
      case AppConstants.notificationAssignmentPublished:
        return Icons.assignment_outlined;
      case AppConstants.notificationAssignmentGraded:
        return Icons.grading_outlined;
      case AppConstants.notificationAttendance:
        return Icons.how_to_reg_outlined;
      case AppConstants.notificationTeacherInvited:
        return Icons.person_add_outlined;
      case AppConstants.notificationStudentJoined:
        return Icons.person_outline;
      case AppConstants.notificationAnnouncement:
      case AppConstants.notificationOrgUpdate:
        return Icons.campaign_outlined;
      case AppConstants.notificationViolation:
        return Icons.warning_amber_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Get color for this notification type.
  int get colorValue {
    switch (type) {
      case AppConstants.notificationExamPublished:
      case AppConstants.notificationExamReminder:
        return 0xFF3B5BDB; // Indigo
      case AppConstants.notificationResultPublished:
        return 0xFF845EF7; // Purple
      case AppConstants.notificationNewMessage:
        return 0xFF12B886; // Emerald
      case AppConstants.notificationAssignmentPublished:
      case AppConstants.notificationAssignmentGraded:
        return 0xFFF59F00; // Amber
      case AppConstants.notificationAttendance:
        return 0xFF12B886; // Emerald
      case AppConstants.notificationAnnouncement:
      case AppConstants.notificationOrgUpdate:
        return 0xFF3B5BDB; // Indigo
      case AppConstants.notificationViolation:
        return 0xFFE03131; // Red
      case AppConstants.notificationTeacherInvited:
      case AppConstants.notificationStudentJoined:
        return 0xFF5C7CFA; // Light Indigo
      default:
        return 0xFF495057; // Gray
    }
  }

  /// Get a deep link route for this notification.
  String? get deepLinkRoute {
    if (relatedId == null) return null;

    switch (relatedType) {
      case 'exam':
        return '${AppConstants.routeExams}/$relatedId';
      case 'assignment':
        return '${AppConstants.routeAssignments}/$relatedId';
      case 'conversation':
        return '${AppConstants.routeConversation}'.replaceAll(':id', relatedId!);
      case 'attendance':
        return AppConstants.routeAttendance;
      default:
        return null;
    }
  }

  /// Get category for Inbox tab grouping.
  String get category => _getCategory(type);
}
