/// LiveKit room model — mirrors the `livekit_rooms` Firestore collection.
///
/// Each document represents a virtual classroom or proctored exam session
/// that can be joined via LiveKit.

class LiveKitRoom {
  final String id;
  final String name;
  final String organizationId;
  final String? campusId;
  final String createdBy;
  final String roomType; // 'classroom' | 'exam_proctoring' | 'meeting'
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

  /// Construct from a Firestore document snapshot.
  factory LiveKitRoom.fromFirestore(Map<String, dynamic> data, String id) {
    return LiveKitRoom(
      id: id,
      name: data['name'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      campusId: data['campusId'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      roomType: data['roomType'] as String? ?? 'classroom',
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
      'createdBy': createdBy,
      'roomType': roomType,
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
