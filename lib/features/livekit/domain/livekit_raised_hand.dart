/// Raised hand entry for a LiveKit room.
///
/// Stored as a sub-collection: `livekit_rooms/{roomId}/raised_hands`
/// Each participant has one document keyed by their UID.

class LiveKitRaisedHand {
  final String uid;
  final String displayName;
  final bool isRaised;
  final DateTime? raisedAt;
  final DateTime? loweredAt;

  const LiveKitRaisedHand({
    required this.uid,
    required this.displayName,
    this.isRaised = true,
    this.raisedAt,
    this.loweredAt,
  });

  factory LiveKitRaisedHand.fromFirestore(Map<String, dynamic> data, String id) {
    return LiveKitRaisedHand(
      uid: id,
      displayName: data['displayName'] as String? ?? '',
      isRaised: data['isRaised'] as bool? ?? false,
      raisedAt: data['raisedAt'] != null
          ? DateTime.tryParse(data['raisedAt'].toString())
          : null,
      loweredAt: data['loweredAt'] != null
          ? DateTime.tryParse(data['loweredAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'isRaised': isRaised,
      'raisedAt': raisedAt?.toIso8601String(),
      'loweredAt': loweredAt?.toIso8601String(),
    };
  }
}
