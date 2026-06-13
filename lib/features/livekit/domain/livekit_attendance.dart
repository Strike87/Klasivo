/// Attendance record for a participant in a LiveKit room.
///
/// Stored as a sub-collection: `livekit_rooms/{roomId}/attendance`
/// Each participant has one document keyed by their UID.

class LiveKitAttendance {
  final String uid;
  final String displayName;
  final String role; // 'teacher' | 'student'
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime updatedAt;
  final int? durationSeconds;

  const LiveKitAttendance({
    required this.uid,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.leftAt,
    required this.updatedAt,
    this.durationSeconds,
  });

  /// Whether the participant is still in the room.
  bool get isPresent => leftAt == null;

  /// Duration in the room so far.
  Duration get duration => leftAt != null
      ? leftAt!.difference(joinedAt)
      : DateTime.now().difference(joinedAt);

  factory LiveKitAttendance.fromFirestore(Map<String, dynamic> data, String id) {
    return LiveKitAttendance(
      uid: id,
      displayName: data['displayName'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      joinedAt: data['joinedAt'] != null
          ? DateTime.tryParse(data['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      leftAt: data['leftAt'] != null
          ? DateTime.tryParse(data['leftAt'].toString())
          : null,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationSeconds: data['durationSeconds'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
    };
  }
}
