import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/class_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

final classServiceProvider = Provider<ClassService>((ref) => ClassService());

final classesByStageProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, stageId) {
  return ref.read(classServiceProvider).getClassesByStageStream(stageId);
});

final classesByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(classServiceProvider).getClassesByOrganizationStream(orgId);
});

final classesProvider = Provider<List<ClassData>>((ref) {
  final asyncClasses = ref.watch(classesByOrgProvider);
  return asyncClasses.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => ClassData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final classesByStageListProvider =
    Provider.family<List<ClassData>, String>((ref, stageId) {
  final asyncClasses = ref.watch(classesByStageProvider(stageId));
  return asyncClasses.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => ClassData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final totalClassesProvider = Provider<int>((ref) {
  return ref.watch(classesProvider).length;
});

class ClassData {
  final String id;
  final String organizationId;
  final String stageId;
  final String name;
  final String? grade;
  final String? teacherId;
  final String? academicYear;
  final int studentCount;
  final String createdBy;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClassData({
    required this.id,
    required this.organizationId,
    required this.stageId,
    required this.name,
    this.grade,
    this.teacherId,
    this.academicYear,
    this.studentCount = 0,
    this.createdBy = '',
    this.isArchived = false,
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
      grade: data['grade'],
      teacherId: data['teacherId'],
      academicYear: data['academicYear'],
      studentCount: data['studentCount'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      isArchived: data['isArchived'] ?? false,
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
      'grade': grade,
      'teacherId': teacherId,
      'academicYear': academicYear,
      'studentCount': studentCount,
      'isArchived': isArchived,
    };
  }
}

// Alias for backward compatibility with screen files
final classesStreamProvider = classesByOrgProvider;
