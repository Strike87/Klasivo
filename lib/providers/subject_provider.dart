import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/subject_service.dart';

final subjectServiceProvider = Provider<SubjectService>((ref) => SubjectService());

final subjectsByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(subjectServiceProvider).getSubjectsByClassStream(classId);
});

final subjectsByClassListProvider =
    Provider.family<List<SubjectData>, String>((ref, classId) {
  final asyncSubjects = ref.watch(subjectsByClassProvider(classId));
  return asyncSubjects.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => SubjectData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final subjectsByTeacherProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, teacherId) {
  return ref.read(subjectServiceProvider).getSubjectsByTeacherStream(teacherId);
});

class SubjectData {
  final String id;
  final String organizationId;
  final String classId;
  final String name;
  final String color;
  final String? teacherId;
  final String createdBy;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SubjectData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.name,
    this.color = '#2196F3',
    this.teacherId,
    this.createdBy = '',
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  factory SubjectData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubjectData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      name: data['name'] ?? '',
      color: data['color'] ?? '#2196F3',
      teacherId: data['teacherId'],
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
      'classId': classId,
      'name': name,
      'color': color,
      'teacherId': teacherId,
      'isArchived': isArchived,
    };
  }
}
