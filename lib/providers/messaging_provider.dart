import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/messaging_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final messagingServiceProvider =
    Provider<MessagingService>((ref) => MessagingService());

// ─── Current Conversation ID ────────────────────────────────────────────────

final currentConversationIdProvider = StateProvider<String?>((ref) => null);

// ─── User Conversations Stream ──────────────────────────────────────────────

final userConversationsProvider = StreamProvider<QuerySnapshot>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  return ref
      .read(messagingServiceProvider)
      .getUserConversationsStream(userId);
});

// ─── Conversation Messages Stream ───────────────────────────────────────────

final conversationMessagesProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, conversationId) {
  return ref
      .read(messagingServiceProvider)
      .getConversationMessagesStream(conversationId);
});

// ─── Class Conversations Stream ─────────────────────────────────────────────

final classConversationsProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();

  return ref.read(messagingServiceProvider).getClassConversationsStream(
        organizationId: orgId,
        classId: classId,
      );
});

// ─── Group Conversations Stream ─────────────────────────────────────────────

final groupConversationsProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, groupId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();

  return ref.read(messagingServiceProvider).getGroupConversationsStream(
        organizationId: orgId,
        groupId: groupId,
      );
});

// ─── Conversation Data Model ────────────────────────────────────────────────

class ConversationData {
  final String id;
  final String organizationId;
  final String type; // 'direct', 'class', 'group'
  final List<String> participantIds;
  final String? classId;
  final String? groupId;
  final String? name;
  final String? createdBy;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ConversationData({
    required this.id,
    required this.organizationId,
    required this.type,
    required this.participantIds,
    this.classId,
    this.groupId,
    this.name,
    this.createdBy,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ConversationData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      type: data['type'] ?? 'direct',
      participantIds:
          List<String>.from(data['participantIds'] ?? []),
      classId: data['classId'],
      groupId: data['groupId'],
      name: data['name'],
      createdBy: data['createdBy'],
      lastMessageText: data['lastMessageText'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory ConversationData.fromMap(Map<String, dynamic> map) {
    return ConversationData(
      id: map['id'] ?? '',
      organizationId: map['organizationId'] ?? '',
      type: map['type'] ?? 'direct',
      participantIds:
          List<String>.from(map['participantIds'] ?? []),
      classId: map['classId'],
      groupId: map['groupId'],
      name: map['name'],
      createdBy: map['createdBy'],
      lastMessageText: map['lastMessageText'],
      lastMessageAt: map['lastMessageAt'] is Timestamp
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: map['lastMessageSenderId'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'type': type,
      'participantIds': participantIds,
      'classId': classId,
      'groupId': groupId,
      'name': name,
      'createdBy': createdBy,
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
    };
  }
}

// ─── Message Data Model ─────────────────────────────────────────────────────

class MessageData {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final bool isRead;
  final List<String> readBy;
  final DateTime? createdAt;

  MessageData({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.isRead = false,
    this.readBy = const [],
    this.createdAt,
  });

  factory MessageData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageData(
      id: doc.id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      isRead: data['isRead'] ?? false,
      readBy: List<String>.from(data['readBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  factory MessageData.fromMap(Map<String, dynamic> map) {
    return MessageData(
      id: map['id'] ?? '',
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      isRead: map['isRead'] ?? false,
      readBy: List<String>.from(map['readBy'] ?? []),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'isRead': isRead,
      'readBy': readBy,
    };
  }
}
