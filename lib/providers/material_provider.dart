import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/material_service.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final materialServiceProvider = Provider<MaterialService>((ref) => MaterialService());

// ─── Data Model ────────────────────────────────────────────────────────────

class MaterialData {
  final String id;
  final String organizationId;
  final String subjectId;
  final String chapterId;
  final String lessonId;
  final String title;
  final String description;
  final String type; // pdf/word/powerpoint/image/video/link
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String thumbnailUrl;
  final String accessType;
  final String targetId;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int downloadCount;

  MaterialData({
    required this.id,
    required this.organizationId,
    required this.subjectId,
    required this.chapterId,
    required this.lessonId,
    required this.title,
    required this.description,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.thumbnailUrl,
    required this.accessType,
    required this.targetId,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.downloadCount = 0,
  });

  factory MaterialData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      chapterId: data['chapterId'] ?? '',
      lessonId: data['lessonId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'pdf',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      accessType: data['accessType'] ?? '',
      targetId: data['targetId'] ?? '',
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      downloadCount: data['downloadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'subjectId': subjectId,
    'chapterId': chapterId,
    'lessonId': lessonId,
    'title': title,
    'description': description,
    'type': type,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'fileSize': fileSize,
    'thumbnailUrl': thumbnailUrl,
    'accessType': accessType,
    'targetId': targetId,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'downloadCount': downloadCount,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  bool get isVideo => type == 'video';

  bool get isDocument => ['pdf', 'word', 'powerpoint'].contains(type);

  bool get isLink => type == 'link';

  String get fileTypeIcon {
    switch (type) {
      case 'pdf': return '📄';
      case 'word': return '📝';
      case 'powerpoint': return '📊';
      case 'image': return '🖼️';
      case 'video': return '🎬';
      case 'link': return '🔗';
      default: return '📁';
    }
  }

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final materialsByOrgStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(materialServiceProvider).getMaterialsByOrganizationStream(orgId);
});

final materialsBySubjectStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, subjectId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(materialServiceProvider).getMaterialsBySubjectStream(orgId, subjectId);
});

final materialsByChapterStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, chapterId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(materialServiceProvider).getMaterialsByChapterStream(orgId, chapterId);
});

final materialsByLessonStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, lessonId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(materialServiceProvider).getMaterialsByLessonStream(orgId, lessonId);
});

// ─── Derived List Providers ────────────────────────────────────────────────

final materialsProvider = Provider<List<MaterialData>>((ref) {
  final asyncMaterials = ref.watch(materialsByOrgStreamProvider);
  return asyncMaterials.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => MaterialData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Materials provider error: $e'); return []; },
  );
});

final materialsBySubjectProvider = Provider.family<List<MaterialData>, String>((ref, subjectId) {
  final materials = ref.watch(materialsProvider);
  return materials.where((m) => m.subjectId == subjectId).toList();
});

final materialsByChapterProvider = Provider.family<List<MaterialData>, String>((ref, chapterId) {
  final materials = ref.watch(materialsProvider);
  return materials.where((m) => m.chapterId == chapterId).toList();
});

final materialsByTypeProvider = Provider.family<List<MaterialData>, String>((ref, type) {
  final materials = ref.watch(materialsProvider);
  return materials.where((m) => m.type == type).toList();
});

final recentMaterialsProvider = Provider<List<MaterialData>>((ref) {
  final materials = ref.watch(materialsProvider);
  final sorted = [...materials]..sort((a, b) {
    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted.take(10).toList();
});
