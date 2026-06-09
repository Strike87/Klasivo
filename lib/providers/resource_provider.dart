import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/resource_service.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final resourceServiceProvider = Provider<ResourceService>((ref) => ResourceService());

// ─── Data Model ────────────────────────────────────────────────────────────

class ResourceData {
  final String id;
  final String organizationId;
  final String subjectId;
  final String gradeId;
  final String title;
  final String description;
  final String type; // worksheet/template/past_exam/question_bank/document
  final String fileUrl;
  final String fileName;
  final int fileSize;
  final String category;
  final List<String> tags;
  final String accessType;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int version;
  final int downloadCount;

  ResourceData({
    required this.id,
    required this.organizationId,
    required this.subjectId,
    required this.gradeId,
    required this.title,
    required this.description,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.category,
    required this.tags,
    required this.accessType,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
    this.version = 1,
    this.downloadCount = 0,
  });

  factory ResourceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ResourceData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      gradeId: data['gradeId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'document',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      category: data['category'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      accessType: data['accessType'] ?? '',
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      version: data['version'] ?? 1,
      downloadCount: data['downloadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'subjectId': subjectId,
    'gradeId': gradeId,
    'title': title,
    'description': description,
    'type': type,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'fileSize': fileSize,
    'category': category,
    'tags': tags,
    'accessType': accessType,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'version': version,
    'downloadCount': downloadCount,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  bool get isEditable => accessType == 'editable';

  String get typeLabel {
    switch (type) {
      case 'worksheet': return 'Worksheet';
      case 'template': return 'Template';
      case 'past_exam': return 'Past Exam';
      case 'question_bank': return 'Question Bank';
      case 'document': return 'Document';
      default: return type;
    }
  }

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get versionLabel => 'v$version';
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final resourcesByOrgStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(resourceServiceProvider).getResourcesByOrganizationStream(orgId);
});

final resourcesByTypeStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, type) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(resourceServiceProvider).getResourcesByTypeStream(orgId, type);
});

final resourcesBySubjectStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, subjectId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(resourceServiceProvider).getResourcesBySubjectStream(orgId, subjectId);
});

// ─── Derived List Providers ────────────────────────────────────────────────

final resourcesProvider = Provider<List<ResourceData>>((ref) {
  final asyncResources = ref.watch(resourcesByOrgStreamProvider);
  return asyncResources.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => ResourceData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Resources provider error: $e'); return []; },
  );
});

final resourcesByTypeProvider = Provider.family<List<ResourceData>, String>((ref, type) {
  final resources = ref.watch(resourcesProvider);
  return resources.where((r) => r.type == type).toList();
});

final resourcesBySubjectProvider = Provider.family<List<ResourceData>, String>((ref, subjectId) {
  final resources = ref.watch(resourcesProvider);
  return resources.where((r) => r.subjectId == subjectId).toList();
});

final recentResourcesProvider = Provider<List<ResourceData>>((ref) {
  final resources = ref.watch(resourcesProvider);
  final sorted = [...resources]..sort((a, b) {
    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted.take(10).toList();
});

final popularResourcesProvider = Provider<List<ResourceData>>((ref) {
  final resources = ref.watch(resourcesProvider);
  final sorted = [...resources]..sort((a, b) => b.downloadCount.compareTo(a.downloadCount));
  return sorted.take(10).toList();
});
