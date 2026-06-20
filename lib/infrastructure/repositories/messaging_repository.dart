// ─── Messaging Repository (Repository Pattern) ─────────────────────────────────
// Abstract interface + Firestore implementation for messaging data access.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/app_constants.dart';

// ─── Messaging Domain Models ───────────────────────────────────────────────────

/// Represents a conversation between two or more participants.
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

  const ConversationData({
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
      participantIds: List<String>.from(data['participantIds'] ?? []),
      classId: data['classId'] as String?,
      groupId: data['groupId'] as String?,
      name: data['name'] as String?,
      createdBy: data['createdBy'] as String?,
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Represents a single message within a conversation.
class MessageData {
  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final bool isRead;
  final List<String> readBy;
  final DateTime? createdAt;

  const MessageData({
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
      isRead: data['isRead'] as bool? ?? false,
      readBy: List<String>.from(data['readBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

// ─── Abstract Interface ────────────────────────────────────────────────────────

/// Abstract interface for messaging data access.
/// All queries are scoped by [organizationId] for multi-tenant safety.
abstract class IMessagingRepository {
  /// Get or create a direct conversation between two users.
  Future<String> getOrCreateDirectConversation({
    required String organizationId,
    required String userId1,
    required String userId2,
  });

  /// Create a conversation (direct, class, or group). Returns the conversation ID.
  Future<String> createConversation(ConversationData conversation);

  /// Watch conversations for a specific user.
  /// AUDIT FIX #14: added required organizationId for rule isInSameOrg().
  Stream<List<ConversationData>> getConversations(String userId, {required String organizationId});

  /// Watch conversations for a class.
  Stream<List<ConversationData>> getClassConversations({
    required String organizationId,
    required String classId,
  });

  /// Watch messages in a conversation, ordered by time ascending.
  /// AUDIT FIX #16: added required organizationId for rule isInSameOrg().
  Stream<List<MessageData>> getMessages(String conversationId, {required String organizationId});

  /// Send a text message in a conversation. Returns the message ID.
  /// AUDIT FIX #15: fetches conversation to stamp organizationId on the new
  /// message doc — otherwise the create rule isInComingSameOrg() denies it.
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  });

  /// Mark all messages in a conversation as read by [userId].
  /// AUDIT FIX #16: added required organizationId for rule isInSameOrg().
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
    required String organizationId,
  });

  /// Get the number of unread messages for a user in a conversation.
  /// AUDIT FIX #16: added required organizationId for rule isInSameOrg().
  Future<int> getUnreadCount({
    required String conversationId,
    required String userId,
    required String organizationId,
  });

  /// Delete a single message by ID.
  Future<void> deleteMessage(String messageId);

  /// Delete an entire conversation and all its messages.
  Future<void> deleteConversation(String conversationId);
}

// ─── Firestore Implementation ──────────────────────────────────────────────────

class FirestoreMessagingRepository implements IMessagingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _db.collection(AppConstants.conversationsCollection);

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection(AppConstants.messagesCollection);

  // ─── GetOrCreateDirectConversation ────────────────────────────────────

  @override
  Future<String> getOrCreateDirectConversation({
    required String organizationId,
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Check if a direct conversation already exists between these users
      final snapshot = await _conversations
          .where('organizationId', isEqualTo: organizationId)
          .where('type', isEqualTo: 'direct')
          .where('participantIds', arrayContains: userId1)
          .get();

      for (final doc in snapshot.docs) {
        final participants =
            List<String>.from(doc.data()['participantIds'] ?? []);
        if (participants.contains(userId2)) {
          return doc.id;
        }
      }

      // Create new direct conversation
      final docRef = await _conversations.add({
        'organizationId': organizationId,
        'type': 'direct',
        'participantIds': [userId1, userId2],
        'classId': null,
        'groupId': null,
        'name': null,
        'createdBy': null,
        'lastMessageText': null,
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── CreateConversation ───────────────────────────────────────────────

  @override
  Future<String> createConversation(ConversationData conversation) async {
    try {
      // For direct conversations, check if one already exists
      if (conversation.type == 'direct' &&
          conversation.participantIds.length == 2) {
        final existing = await _conversations
            .where('organizationId', isEqualTo: conversation.organizationId)
            .where('type', isEqualTo: 'direct')
            .where('participantIds',
                arrayContains: conversation.participantIds.first)
            .get();

        for (final doc in existing.docs) {
          final participants =
              List<String>.from(doc.data()['participantIds'] ?? []);
          if (participants.contains(conversation.participantIds.last)) {
            return doc.id;
          }
        }
      }

      final docRef = await _conversations.add({
        'organizationId': conversation.organizationId,
        'type': conversation.type,
        'participantIds': conversation.participantIds,
        'classId': conversation.classId,
        'groupId': conversation.groupId,
        'name': conversation.name,
        'createdBy': conversation.createdBy,
        'lastMessageText': null,
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── GetConversations ─────────────────────────────────────────────────

  @override
  Stream<List<ConversationData>> getConversations(String userId, {required String organizationId}) {
    // AUDIT FIX #14: scope by organizationId
    return _conversations
        .where('participantIds', arrayContains: userId)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConversationData.fromFirestore(doc))
            .toList());
  }

  // ─── GetClassConversations ────────────────────────────────────────────

  @override
  Stream<List<ConversationData>> getClassConversations({
    required String organizationId,
    required String classId,
  }) {
    return _conversations
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ConversationData.fromFirestore(doc))
            .toList());
  }

  // ─── GetMessages ──────────────────────────────────────────────────────

  @override
  Stream<List<MessageData>> getMessages(String conversationId, {required String organizationId}) {
    // AUDIT FIX #16: scope by organizationId
    return _messages
        .where('conversationId', isEqualTo: conversationId)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageData.fromFirestore(doc)).toList());
  }

  // ─── SendMessage ──────────────────────────────────────────────────────

  @override
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      // AUDIT FIX #15: fetch conversation doc to get organizationId + participants,
      // then stamp on the new message doc — otherwise isInComingSameOrg() denies.
      final conversationDoc = await _conversations.doc(conversationId).get();
      if (!conversationDoc.exists) {
        throw Exception('Conversation not found.');
      }
      final conversationData = conversationDoc.data()!;
      final organizationId = conversationData['organizationId'] as String?;
      final participantIds = List<String>.from(conversationData['participantIds'] ?? []);

      // Create the message — AUDIT FIX #15: stamp organizationId + participants
      final docRef = await _messages.add({
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        'organizationId': organizationId,  // AUDIT FIX #15
        'participants': participantIds,    // rule also checks participants hasAny(uid)
        'isRead': false,
        'readBy': [senderId], // Sender has read their own message
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the conversation's last message info
      await _conversations.doc(conversationId).update({
        'lastMessageText':
            text.length > 100 ? '${text.substring(0, 100)}...' : text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── MarkAsRead ───────────────────────────────────────────────────────

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String userId,
    required String organizationId,
  }) async {
    try {
      // Get all messages in this conversation not sent by this user
      // AUDIT FIX #16: scope by organizationId
      final snapshot = await _messages
          .where('conversationId', isEqualTo: conversationId)
          .where('organizationId', isEqualTo: organizationId)
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          readBy.add(userId);
          batch.update(doc.reference, {
            'readBy': readBy,
            'isRead': true,
          });
        }
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── GetUnreadCount ───────────────────────────────────────────────────

  @override
  Future<int> getUnreadCount({
    required String conversationId,
    required String userId,
    required String organizationId,
  }) async {
    try {
      // AUDIT FIX #16: scope by organizationId
      final snapshot = await _messages
          .where('conversationId', isEqualTo: conversationId)
          .where('organizationId', isEqualTo: organizationId)
          .where('senderId', isNotEqualTo: userId)
          .get();

      int unread = 0;
      for (final doc in snapshot.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          unread++;
        }
      }
      return unread;
    } catch (e) {
      rethrow;
    }
  }

  // ─── DeleteMessage ────────────────────────────────────────────────────

  @override
  Future<void> deleteMessage(String messageId) async {
    try {
      await _messages.doc(messageId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // ─── DeleteConversation ───────────────────────────────────────────────

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages in this conversation
      final messagesSnapshot = await _messages
          .where('conversationId', isEqualTo: conversationId)
          .get();

      final batch = _db.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_conversations.doc(conversationId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
