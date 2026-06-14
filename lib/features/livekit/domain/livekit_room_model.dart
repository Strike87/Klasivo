/// LiveKit room model — mirrors the `livekit_rooms` Firestore collection.
///
/// Each document represents a virtual classroom or proctored exam session
/// that can be joined via LiveKit.
///
/// Scope fields (classId, stageId, campusId, subjectId) are used by the
/// server-side scope validator to enforce class-level authorization.
/// For roomType 'classroom', classId is mandatory.
/// For roomType 'meeting', only org-level authorization is required.

/// Explicit room type — determines which authorization rules apply.
///
/// - classroom:  classId required, scope validation enforced, fail-closed
/// - meeting:    org boundary only, creator or admin role required
/// - webinar:    org boundary + role-based access (future)
enum RoomType {
  classroom('classroom'),
  meeting('meeting'),
  webinar('webinar');

  const RoomType(this.value);
  final String value;

  /// Parse from Firestore string, defaults to classroom if unknown.
  static RoomType fromString(String? value) {
    return RoomType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RoomType.classroom,
    );
  }
}

class LiveKitRoom {
  final String id;
  final String name;
  final String organizationId;
  final String? campusId;
  final String? stageId;
  final String? classId;
  final String? subjectId;
  final String createdBy;
  final RoomType roomType;
  final int? maxParticipants;
  final bool isActive;
  final bool isRecording;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  const LiveKitRoom({
    required this.id,
    required this.name,
    required this.organizationId,
    this.campusId,
    this.stageId,
    this.classId,
    this.subjectId,
    required this.createdBy,
    required this.roomType,
    this.maxParticipants,
    this.isActive = true,
    this.isRecording = false,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  /// The LiveKit server URL for this room.
  /// Derived from metadata or uses a default.
  String get livekitUrl => metadata['livekitUrl'] as String? ?? 'wss://klasivo.livekit.cloud';

  /// Subject name for this room (if set).
  String? get subjectName => metadata['subjectName'] as String?;

  /// Class/grade name for this room (if set).
  String? get className => metadata['className'] as String?;

  /// Whether this room requires scope-level authorization.
  bool get requiresScopeAuthorization => roomType == RoomType.classroom;

  /// Construct from a Firestore document snapshot.
  factory LiveKitRoom.fromFirestore(Map<String, dynamic> data, String id) {
    return LiveKitRoom(
      id: id,
      name: data['name'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      campusId: data['campusId'] as String?,
      stageId: data['stageId'] as String?,
      classId: data['classId'] as String?,
      subjectId: data['subjectId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      roomType: RoomType.fromString(data['roomType'] as String?),
      maxParticipants: data['maxParticipants'] as int?,
      isActive: data['isActive'] as bool? ?? true,
      isRecording: data['isRecording'] as bool? ?? false,
      startedAt: data['startedAt'] != null
          ? DateTime.tryParse(data['startedAt'].toString())
          : null,
      endedAt: data['endedAt'] != null
          ? DateTime.tryParse(data['endedAt'].toString())
          : null,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'organizationId': organizationId,
      'campusId': campusId,
      'stageId': stageId,
      'classId': classId,
      'subjectId': subjectId,
      'createdBy': createdBy,
      'roomType': roomType.value,
      'maxParticipants': maxParticipants,
      'isActive': isActive,
      'isRecording': isRecording,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  LiveKitRoom copyWith({
    String? name,
    bool? isActive,
    bool? isRecording,
    int? maxParticipants,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return LiveKitRoom(
      id: id,
      name: name ?? this.name,
      organizationId: organizationId,
      campusId: campusId,
      stageId: stageId,
      classId: classId,
      subjectId: subjectId,
      createdBy: createdBy,
      roomType: roomType,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      isActive: isActive ?? this.isActive,
      isRecording: isRecording ?? this.isRecording,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
