import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/lesson_service.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final lessonServiceProvider = Provider<LessonService>((ref) => LessonService());

// ─── Data Model ────────────────────────────────────────────────────────────

class LessonData {
  final String id;
  final String organizationId;
  final String subjectId;
  final String chapterId;
  final String classId;
  final String title;
  final String description;
  final String type; // recorded/youtube/zoom/google_drive
  final String videoUrl;
  final String thumbnailUrl;
  final int duration;
  final int viewCount;
  final String accessType;
  final String targetId;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LessonData({
    required this.id,
    required this.organizationId,
    required this.subjectId,
    required this.chapterId,
    this.classId = '',
    required this.title,
    required this.description,
    required this.type,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.viewCount,
    required this.accessType,
    required this.targetId,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  factory LessonData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LessonData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      chapterId: data['chapterId'] ?? '',
      classId: data['classId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'recorded',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      duration: data['duration'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      accessType: data['accessType'] ?? '',
      targetId: data['targetId'] ?? '',
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'subjectId': subjectId,
    'chapterId': chapterId,
    'classId': classId,
    'title': title,
    'description': description,
    'type': type,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'duration': duration,
    'viewCount': viewCount,
    'accessType': accessType,
    'targetId': targetId,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  bool get isExternal => ['youtube', 'zoom', 'google_drive'].contains(type);

  String get durationFormatted {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get typeLabel {
    switch (type) {
      case 'recorded': return 'Recorded Lesson';
      case 'youtube': return 'YouTube';
      case 'zoom': return 'Zoom Meeting';
      case 'google_drive': return 'Google Drive';
      default: return type;
    }
  }
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final lessonsByOrgStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(lessonServiceProvider).getLessonsByOrganizationStream(orgId);
});

final lessonsBySubjectStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, subjectId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(lessonServiceProvider).getLessonsBySubjectStream(orgId, subjectId);
});

// ─── Derived List Providers ────────────────────────────────────────────────

final lessonsProvider = Provider<List<LessonData>>((ref) {
  final asyncLessons = ref.watch(lessonsByOrgStreamProvider);
  return asyncLessons.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => LessonData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Lessons provider error: $e'); return []; },
  );
});

final lessonsBySubjectProvider = Provider.family<List<LessonData>, String>((ref, subjectId) {
  final lessons = ref.watch(lessonsProvider);
  return lessons.where((l) => l.subjectId == subjectId).toList();
});

final recentLessonsProvider = Provider<List<LessonData>>((ref) {
  final lessons = ref.watch(lessonsProvider);
  final sorted = [...lessons]..sort((a, b) {
    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted.take(10).toList();
});
