/// Session analytics — mirrors the `session_analytics` Firestore collection.
///
/// Written by the `onLiveKitRoomUpdated` Cloud Function when a live class ends.
/// Contains aggregated metrics: attendance, duration, engagement.
/// Clients have read-only access (no create/update).

import 'livekit_room_model.dart';

class SessionAnalytics {
  final String id;
  final String roomId;
  final String roomName;
  final String organizationId;
  final String? campusId;
  final String teacherId;
  final RoomType roomType;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationMinutes;
  final int attendanceCount;
  final int peakParticipants;
  final int messagesCount;
  final int raisedHandsCount;
  final bool wasRecorded;
  final DateTime createdAt;

  const SessionAnalytics({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.organizationId,
    this.campusId,
    required this.teacherId,
    required this.roomType,
    this.startedAt,
    this.endedAt,
    required this.durationMinutes,
    required this.attendanceCount,
    required this.peakParticipants,
    required this.messagesCount,
    required this.raisedHandsCount,
    required this.wasRecorded,
    required this.createdAt,
  });

  factory SessionAnalytics.fromFirestore(Map<String, dynamic> data, String id) {
    return SessionAnalytics(
      id: id,
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      campusId: data['campusId'] as String?,
      teacherId: data['teacherId'] as String? ?? '',
      roomType: RoomType.fromString(data['roomType'] as String?),
      startedAt: data['startedAt'] != null
          ? DateTime.tryParse(data['startedAt'].toString())
          : null,
      endedAt: data['endedAt'] != null
          ? DateTime.tryParse(data['endedAt'].toString())
          : null,
      durationMinutes: data['durationMinutes'] as int? ?? 0,
      attendanceCount: data['attendanceCount'] as int? ?? 0,
      peakParticipants: data['peakParticipants'] as int? ?? 0,
      messagesCount: data['messagesCount'] as int? ?? 0,
      raisedHandsCount: data['raisedHandsCount'] as int? ?? 0,
      wasRecorded: data['wasRecorded'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Average engagement per attendee (messages + hand raises / attendance).
  double get engagementPerAttendee {
    if (attendanceCount == 0) return 0;
    return (messagesCount + raisedHandsCount) / attendanceCount;
  }

  /// Duration as a formatted string (e.g., "1h 23m" or "45m").
  String get durationLabel {
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return '${durationMinutes}m';
  }
}
