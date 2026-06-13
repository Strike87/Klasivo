/// In-class chat message for a LiveKit room.
///
/// Stored as a sub-collection: `livekit_rooms/{roomId}/messages`

class LiveKitChatMessage {
  final String id;
  final String uid;
  final String displayName;
  final String message;
  final String type; // 'text' | 'system' | 'image'
  final DateTime sentAt;

  const LiveKitChatMessage({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.message,
    this.type = 'text',
    required this.sentAt,
  });

  factory LiveKitChatMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return LiveKitChatMessage(
      id: id,
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      sentAt: data['sentAt'] != null
          ? DateTime.tryParse(data['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'displayName': displayName,
      'message': message,
      'type': type,
      'sentAt': sentAt.toIso8601String(),
    };
  }
}
