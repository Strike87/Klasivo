/// Recording metadata — mirrors the `recordings` Firestore collection.
///
/// Each document represents a session recording with playback URL
/// and storage reference. Video files are stored in Cloudflare R2
/// or Firebase Storage; this collection holds metadata only.

class Recording {
  final String id;
  final String roomId;
  final String roomName;
  final String organizationId;
  final String teacherId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final String? playbackUrl;
  final String? storagePath; // e.g., 'recordings/orgId/roomId/timestamp.mp4'
  final String? storageProvider; // 'cloudflare_r2' | 'firebase_storage'
  final int? fileSizeBytes;
  final String status; // 'recording' | 'processing' | 'ready' | 'failed'
  final DateTime createdAt;

  const Recording({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.organizationId,
    required this.teacherId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.playbackUrl,
    this.storagePath,
    this.storageProvider,
    this.fileSizeBytes,
    this.status = 'recording',
    required this.createdAt,
  });

  factory Recording.fromFirestore(Map<String, dynamic> data, String id) {
    return Recording(
      id: id,
      roomId: data['roomId'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      startedAt: data['startedAt'] != null
          ? DateTime.tryParse(data['startedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endedAt: data['endedAt'] != null
          ? DateTime.tryParse(data['endedAt'].toString())
          : null,
      durationMinutes: data['durationMinutes'] as int?,
      playbackUrl: data['playbackUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      storageProvider: data['storageProvider'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int?,
      status: data['status'] as String? ?? 'recording',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'roomName': roomName,
      'organizationId': organizationId,
      'teacherId': teacherId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'playbackUrl': playbackUrl,
      'storagePath': storagePath,
      'storageProvider': storageProvider,
      'fileSizeBytes': fileSizeBytes,
      'status': status,
    };
  }

  /// Human-readable file size
  String get fileSizeLabel {
    if (fileSizeBytes == null) return 'Unknown';
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb < 1) return '${(fileSizeBytes! / 1024).toStringAsFixed(0)} KB';
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}
