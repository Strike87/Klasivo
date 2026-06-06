import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/class_service.dart';
import 'auth_provider.dart';

final classServiceProvider = Provider<ClassService>((ref) => ClassService());

final classesStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  return ref.read(classServiceProvider).getClassesStream(teacherId);
});

final classesProvider = Provider<List<ClassData>>((ref) {
  final asyncClasses = ref.watch(classesStreamProvider);
  return asyncClasses.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => ClassData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final totalClassesProvider = Provider<int>((ref) {
  return ref.watch(classesProvider).length;
});

class ClassData {
  final String id;
  final String teacherId;
  final String name;
  final String? grade;
  final String? gradeId;
  final String? stageId;
  final int studentCount;
  final String institutionId;
  final DateTime? createdAt;

  ClassData({
    required this.id,
    required this.teacherId,
    required this.name,
    this.grade,
    this.gradeId,
    this.stageId,
    this.studentCount = 0,
    this.institutionId = AppConstants.defaultInstitutionId,
    this.createdAt,
  });

  factory ClassData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassData(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      name: data['name'] ?? '',
      grade: data['grade'],
      gradeId: data['gradeId'],
      stageId: data['stageId'],
      studentCount: data['studentCount'] ?? 0,
      institutionId: data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'name': name,
      'grade': grade,
      'gradeId': gradeId,
      'stageId': stageId,
      'studentCount': studentCount,
      'institutionId': institutionId,
      'createdAt': createdAt,
    };
  }
}
