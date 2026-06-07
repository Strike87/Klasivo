import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import 'auth_provider.dart';

final notificationsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final userId = ref.watch(userIdProvider);
  if (userId == null || userId.isEmpty) {
    return const Stream.empty();
  }
  return FirebaseFirestore.instance
      .collection(AppConstants.notificationsCollection)
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .snapshots();
});

final notificationsProvider = Provider<List<NotificationData>>((ref) {
  final asyncNotifs = ref.watch(notificationsStreamProvider);
  return asyncNotifs.when(
    data: (snapshot) => snapshot.docs.map((doc) => NotificationData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final unreadNotificationsProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});

class NotificationData {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  NotificationData({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
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
      'isRead': isRead,
    };
  }
}
