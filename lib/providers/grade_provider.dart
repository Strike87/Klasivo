import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/grade_service.dart';
import 'auth_provider.dart';

final gradeServiceProvider = Provider<GradeService>((ref) => GradeService());

final gradesByStageProvider = StreamProvider.family<QuerySnapshot, String>((ref, stageId) {
  return ref.read(gradeServiceProvider).getGradesByStageStream(stageId);
});

final gradesByTeacherProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  return ref.read(gradeServiceProvider).getGradesByTeacherStream(teacherId);
});

final allGradesProvider = Provider<List<GradeData>>((ref) {
  final asyncGrades = ref.watch(gradesByTeacherProvider);
  return asyncGrades.when(
    data: (snapshot) => snapshot.docs.map((doc) => GradeData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final gradesByStageListProvider = Provider.family<List<GradeData>, String>((ref, stageId) {
  final asyncGrades = ref.watch(gradesByStageProvider(stageId));
  return asyncGrades.when(
    data: (snapshot) => snapshot.docs.map((doc) => GradeData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class GradeData {
  final String id;
  final String stageId;
  final String name;
  final String teacherId;
  final String institutionId;
  final DateTime? createdAt;

  GradeData({
    required this.id,
    required this.stageId,
    required this.name,
    required this.teacherId,
    this.institutionId = AppConstants.defaultInstitutionId,
    this.createdAt,
  });

  factory GradeData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GradeData(
      id: doc.id,
      stageId: data['stageId'] ?? '',
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      institutionId: data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stageId': stageId,
      'name': name,
      'teacherId': teacherId,
      'institutionId': institutionId,
    };
  }
}
