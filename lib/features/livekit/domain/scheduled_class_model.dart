/// Scheduled class — mirrors the `scheduled_classes` Firestore collection.
///
/// Represents an upcoming live class with a set start time.
/// Students see upcoming classes; teachers manage their schedule.
/// The `scheduledClassReminder` Cloud Function sends push notifications
/// 10 minutes before start.

class ScheduledClass {
  final String id;
  final String title;
  final String organizationId;
  final String? campusId;
  final String teacherId;
  final String teacherName;
  final String? subjectName;
  final String? className;
  final String roomType; // 'classroom' | 'exam_proctoring' | 'meeting'
  final DateTime startsAt;
  final int? durationMinutes;
  final String? description;
  final String? roomId; // Linked livekit_rooms doc (created when class starts)
  final bool reminderSent;
  final bool isStarted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScheduledClass({
    required this.id,
    required this.title,
    required this.organizationId,
    this.campusId,
    required this.teacherId,
    required this.teacherName,
    this.subjectName,
    this.className,
    this.roomType = 'classroom',
    required this.startsAt,
    this.durationMinutes,
    this.description,
    this.roomId,
    this.reminderSent = false,
    this.isStarted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ScheduledClass.fromFirestore(Map<String, dynamic> data, String id) {
    return ScheduledClass(
      id: id,
      title: data['title'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      campusId: data['campusId'] as String?,
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      subjectName: data['subjectName'] as String?,
      className: data['className'] as String?,
      roomType: data['roomType'] as String? ?? 'classroom',
      startsAt: data['startsAt'] != null
          ? DateTime.tryParse(data['startsAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      durationMinutes: data['durationMinutes'] as int?,
      description: data['description'] as String?,
      roomId: data['roomId'] as String?,
      reminderSent: data['reminderSent'] as bool? ?? false,
      isStarted: data['isStarted'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'organizationId': organizationId,
      'campusId': campusId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subjectName': subjectName,
      'className': className,
      'roomType': roomType,
      'startsAt': startsAt.toIso8601String(),
      'durationMinutes': durationMinutes,
      'description': description,
      'roomId': roomId,
      'reminderSent': reminderSent,
      'isStarted': isStarted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Whether this class starts within the next [minutes] minutes.
  bool startsWithin(int minutes) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(minutes: minutes));
    return startsAt.isAfter(now) && startsAt.isBefore(cutoff);
  }

  /// Whether this class has already passed its start time.
  bool get hasPassed => startsAt.isBefore(DateTime.now());

  /// Time until this class starts (negative if already passed).
  Duration get timeUntilStart => startsAt.difference(DateTime.now());
}
