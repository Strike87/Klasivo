import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Conversations ───────────────────────────────────────────────────────

  /// Create a conversation between two users or a broadcast conversation.
  /// [type] can be: 'direct', 'class', 'group'
  /// [participantIds] should include all participants (including sender).
  Future<String> createConversation({
    required String organizationId,
    required String type, // 'direct', 'class', 'group'
    required List<String> participantIds,
    String? classId,
    String? groupId,
    String? name, // Required for class/group conversations
    String? createdBy,
  }) async {
    try {
      // For direct conversations, check if one already exists between these two users
      if (type == 'direct' && participantIds.length == 2) {
        final existing = await _findDirectConversation(
          organizationId: organizationId,
          userId1: participantIds[0],
          userId2: participantIds[1],
        );
        if (existing != null) return existing.id;
      }

      final docRef = await _firestore
          .collection(AppConstants.conversationsCollection)
          .add({
        'organizationId': organizationId,
        'type': type,
        'participantIds': participantIds,
        'classId': classId,
        'groupId': groupId,
        'name': name,
        'createdBy': createdBy,
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

  /// Find an existing direct conversation between two users.
  Future<DocumentSnapshot?> _findDirectConversation({
    required String organizationId,
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Query for conversations containing both users
      final snapshot = await _firestore
          .collection(AppConstants.conversationsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('type', isEqualTo: 'direct')
          .where('participantIds', arrayContains: userId1)
          .get();

      for (final doc in snapshot.docs) {
        final participants =
            List<String>.from(doc.data()['participantIds'] ?? []);
        if (participants.contains(userId2)) {
          return doc;
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get or create a direct conversation between two users.
  Future<String> getOrCreateDirectConversation({
    required String organizationId,
    required String userId1,
    required String userId2,
  }) async {
    return createConversation(
      organizationId: organizationId,
      type: 'direct',
      participantIds: [userId1, userId2],
    );
  }

  /// Get conversations for a user (where they are a participant).
  Stream<QuerySnapshot> getUserConversationsStream(String userId) {
    return _firestore
        .collection(AppConstants.conversationsCollection)
        .where('participantIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Get conversations for a class.
  Stream<QuerySnapshot> getClassConversationsStream({
    required String organizationId,
    required String classId,
  }) {
    return _firestore
        .collection(AppConstants.conversationsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Get conversations for a group.
  Stream<QuerySnapshot> getGroupConversationsStream({
    required String organizationId,
    required String groupId,
  }) {
    return _firestore
        .collection(AppConstants.conversationsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('groupId', isEqualTo: groupId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages in this conversation
      final messagesSnapshot = await _firestore
          .collection(AppConstants.messagesCollection)
          .where('conversationId', isEqualTo: conversationId)
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(_firestore
          .collection(AppConstants.conversationsCollection)
          .doc(conversationId));

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Messages ────────────────────────────────────────────────────────────

  /// Send a text message in a conversation.
  /// Also triggers push notifications for all participants (except the sender).
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    try {
      // Create the message
      final docRef = await _firestore
          .collection(AppConstants.messagesCollection)
          .add({
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        'isRead': false,
        'readBy': [senderId], // Sender has read their own message
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Get conversation details for notification
      final conversationDoc = await _firestore
          .collection(AppConstants.conversationsCollection)
          .doc(conversationId)
          .get();

      final conversationData = conversationDoc.data();
      final participantIds = List<String>.from(
        conversationData?['participantIds'] ?? [],
      );
      final organizationId = conversationData?['organizationId'] as String?;
      final conversationName = conversationData?['name'] as String?;

      // Update the conversation's last message info
      await _firestore
          .collection(AppConstants.conversationsCollection)
          .doc(conversationId)
          .update({
        'lastMessageText': text.length > 100 ? '${text.substring(0, 100)}...' : text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send push notifications to all participants except the sender
      await _sendNewMessageNotifications(
        senderId: senderId,
        participantIds: participantIds,
        messageText: text,
        conversationId: conversationId,
        conversationName: conversationName,
        organizationId: organizationId,
      );

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Send in-app + push notifications for new messages to all recipients.
  Future<void> _sendNewMessageNotifications({
    required String senderId,
    required List<String> participantIds,
    required String messageText,
    required String conversationId,
    String? conversationName,
    String? organizationId,
  }) async {
    try {
      // Get sender's display name
      final senderDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(senderId)
          .get();
      final senderName = senderDoc.data()?['name'] as String? ?? 'Someone';

      // Determine notification title
      final title = conversationName ?? senderName;
      final preview = messageText.length > 100
          ? '${messageText.substring(0, 100)}...'
          : messageText;

      // Send notification to each recipient (excluding sender)
      final recipientIds = participantIds.where((id) => id != senderId).toList();
      for (final recipientId in recipientIds) {
        await NotificationService.notifyNewMessage(
          recipientId: recipientId,
          senderName: title,
          messagePreview: preview,
          conversationId: conversationId,
          organizationId: organizationId,
        );
      }
    } catch (e) {
      // Non-critical: notification failure shouldn't block message sending
    }
  }

  /// Get messages for a conversation, ordered by time.
  Stream<QuerySnapshot> getConversationMessagesStream(
      String conversationId) {
    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Mark messages as read by a user in a conversation.
  Future<void> markMessagesAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      // Get all unread messages in this conversation not sent by this user
      final snapshot = await _firestore
          .collection(AppConstants.messagesCollection)
          .where('conversationId', isEqualTo: conversationId)
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();
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

  /// Get unread message count for a user in a conversation.
  Future<int> getUnreadCount({
    required String conversationId,
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.messagesCollection)
          .where('conversationId', isEqualTo: conversationId)
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

  /// Delete a single message.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore
          .collection(AppConstants.messagesCollection)
          .doc(messageId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Broadcast Messaging ─────────────────────────────────────────────────

  /// Send a message to an entire class (owner/teacher → class broadcast).
  Future<String> sendClassMessage({
    required String organizationId,
    required String classId,
    required String senderId,
    required String text,
    required List<String> participantIds,
    String? className,
  }) async {
    try {
      // Find or create the class conversation
      final existingSnapshot = await _firestore
          .collection(AppConstants.conversationsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('type', isEqualTo: 'class')
          .where('classId', isEqualTo: classId)
          .limit(1)
          .get();

      String conversationId;
      if (existingSnapshot.docs.isNotEmpty) {
        conversationId = existingSnapshot.docs.first.id;
      } else {
        conversationId = await createConversation(
          organizationId: organizationId,
          type: 'class',
          participantIds: participantIds,
          classId: classId,
          name: className ?? 'Class',
          createdBy: senderId,
        );
      }

      return sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        text: text,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Send a message to an entire group (teacher → group broadcast).
  Future<String> sendGroupMessage({
    required String organizationId,
    required String groupId,
    required String senderId,
    required String text,
    required List<String> participantIds,
    String? groupName,
  }) async {
    try {
      // Find or create the group conversation
      final existingSnapshot = await _firestore
          .collection(AppConstants.conversationsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('type', isEqualTo: 'group')
          .where('groupId', isEqualTo: groupId)
          .limit(1)
          .get();

      String conversationId;
      if (existingSnapshot.docs.isNotEmpty) {
        conversationId = existingSnapshot.docs.first.id;
      } else {
        conversationId = await createConversation(
          organizationId: organizationId,
          type: 'group',
          participantIds: participantIds,
          groupId: groupId,
          name: groupName ?? 'Group',
          createdBy: senderId,
        );
      }

      return sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        text: text,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Owner sends a message to all teachers in the organization.
  Future<String> sendOrganizationTeachersMessage({
    required String organizationId,
    required String senderId,
    required String text,
    required List<String> teacherIds,
  }) async {
    try {
      // Find or create an owner-teachers conversation
      final allParticipants = [senderId, ...teacherIds];
      final existingSnapshot = await _firestore
          .collection(AppConstants.conversationsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('type', isEqualTo: 'class') // Reuse 'class' type for broadcast
          .where('name', isEqualTo: 'Teachers')
          .limit(1)
          .get();

      String conversationId;
      if (existingSnapshot.docs.isNotEmpty) {
        conversationId = existingSnapshot.docs.first.id;
      } else {
        conversationId = await createConversation(
          organizationId: organizationId,
          type: 'class',
          participantIds: allParticipants,
          name: 'Teachers',
          createdBy: senderId,
        );
      }

      return sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        text: text,
      );
    } catch (e) {
      rethrow;
    }
  }
}
