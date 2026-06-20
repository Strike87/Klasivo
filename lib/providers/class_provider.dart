import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/class_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ─────────────────────────────────────────────────────────

final classServiceProvider = Provider<ClassService>((ref) => ClassService());

// ─── Classes by Stage (stream) ────────────────────────────────────────────────

final classesByStageProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, stageId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null || orgId.isEmpty) return const Stream.empty();
  return ref.read(classServiceProvider).getClassesByStageStream(stageId, organizationId: orgId);
});

// ─── Classes by Organization (stream) ─────────────────────────────────────────

final classesByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(classServiceProvider).getClassesByOrganizationStream(orgId);
});

// ─── Parsed Classes List (org-wide) ──────────────────────────────────────────

final classesProvider = Provider<List<ClassData>>((ref) {
  final asyncClasses = ref.watch(classesByOrgProvider);
  return asyncClasses.when(
    skipLoadingOnReload: true,  // P0-9: prevent dashboard flicker on pull-to-refresh
    data: (snapshot) =>
        snapshot.docs.map((doc) => ClassData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Parsed Classes List (by stage) ──────────────────────────────────────────

final classesByStageListProvider =
    Provider.family<List<ClassData>, String>((ref, stageId) {
  final asyncClasses = ref.watch(classesByStageProvider(stageId));
  return asyncClasses.when(
    skipLoadingOnReload: true,  // P0-9: prevent dashboard flicker on pull-to-refresh
    data: (snapshot) =>
        snapshot.docs.map((doc) => ClassData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Total Classes Count ──────────────────────────────────────────────────────

final totalClassesProvider = Provider<int>((ref) {
  return ref.watch(classesProvider).length;
});

// ─── Single Class by ID ───────────────────────────────────────────────────────

final classByIdProvider =
    Provider.family<ClassData?, String>((ref, classId) {
  final classes = ref.watch(classesProvider);
  try {
    return classes.firstWhere((c) => c.id == classId);
  } catch (_) {
    return null;
  }
});

// ─── Alias for backward compatibility ─────────────────────────────────────────

final classesStreamProvider = classesByOrgProvider;

// ─── Class Data Model ─────────────────────────────────────────────────────────

class ClassData {
  final String id;
  final String organizationId;
  final String stageId;
  final String name;
  final String code;
  final int capacity;
  final String? homeroomTeacherId;
  final String? grade;
  final String? teacherId;
  final String? academicYear;
  final int studentCount;
  final String createdBy;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClassData({
    required this.id,
    required this.organizationId,
    required this.stageId,
    required this.name,
    this.code = '',
    this.capacity = 0,
    this.homeroomTeacherId,
    this.grade,
    this.teacherId,
    this.academicYear,
    this.studentCount = 0,
    this.createdBy = '',
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ClassData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      stageId: data['stageId'] ?? '',
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      capacity: data['capacity'] ?? 0,
      homeroomTeacherId: data['homeroomTeacherId'] as String?,
      grade: data['grade'] as String?,
      teacherId: data['teacherId'] as String?,
      academicYear: data['academicYear'] as String?,
      studentCount: data['studentCount'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      isArchived: data['isArchived'] ?? false,
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      archivedBy: data['archivedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'stageId': stageId,
      'name': name,
      'code': code,
      'capacity': capacity,
      'homeroomTeacherId': homeroomTeacherId,
      'grade': grade,
      'teacherId': teacherId,
      'academicYear': academicYear,
      'studentCount': studentCount,
      'isArchived': isArchived,
      'archivedAt': archivedAt,
      'archivedBy': archivedBy,
    };
  }

  ClassData copyWith({
    String? name,
    String? stageId,
    String? code,
    int? capacity,
    String? homeroomTeacherId,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
  }) {
    return ClassData(
      id: id,
      organizationId: organizationId,
      stageId: stageId ?? this.stageId,
      name: name ?? this.name,
      code: code ?? this.code,
      capacity: capacity ?? this.capacity,
      homeroomTeacherId: homeroomTeacherId ?? this.homeroomTeacherId,
      grade: grade,
      teacherId: teacherId,
      academicYear: academicYear,
      studentCount: studentCount,
      createdBy: createdBy,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
