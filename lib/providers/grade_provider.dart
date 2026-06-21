import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/grade_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

final gradeServiceProvider = Provider<GradeService>((ref) => GradeService());

final gradesByStageStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, stageId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null || orgId.isEmpty) return const Stream.empty();
  return ref.read(gradeServiceProvider).getGradesByStageStream(stageId, organizationId: orgId);
});

final gradesByStageListProvider =
    Provider.family<List<GradeData>, String>((ref, stageId) {
  final asyncGrades = ref.watch(gradesByStageStreamProvider(stageId));
  return asyncGrades.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => GradeData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

class GradeData {
  final String id;
  final String stageId;
  final String name;
  final String organizationId;
  final int studentCount;
  final bool isArchived;
  final DateTime? createdAt;

  GradeData({
    required this.id,
    required this.stageId,
    required this.name,
    required this.organizationId,
    this.studentCount = 0,
    this.isArchived = false,
    this.createdAt,
  });

  factory GradeData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GradeData(
      id: doc.id,
      stageId: data['stageId'] ?? '',
      name: data['name'] ?? '',
      organizationId: data['organizationId'] ?? '',
      studentCount: data['studentCount'] ?? 0,
      isArchived: data['isArchived'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
