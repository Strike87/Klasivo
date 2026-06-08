import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/teacher_assignment_service.dart';
import 'organization_provider.dart';

final teacherAssignmentServiceProvider =
    Provider<TeacherAssignmentService>((ref) => TeacherAssignmentService());

final teacherAssignmentsByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(teacherAssignmentServiceProvider)
      .getAssignmentsByOrganizationStream(orgId);
});

final teacherAssignmentsByTeacherProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, teacherId) {
  return ref
      .read(teacherAssignmentServiceProvider)
      .getAssignmentsByTeacherStream(teacherId);
});

final teacherAssignmentsByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref
      .read(teacherAssignmentServiceProvider)
      .getAssignmentsByClassStream(classId);
});

final teacherAssignmentsProvider =
    Provider<List<TeacherAssignmentData>>((ref) {
  final asyncAssignments = ref.watch(teacherAssignmentsByOrgProvider);
  return asyncAssignments.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => TeacherAssignmentData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

class TeacherAssignmentData {
  final String id;
  final String organizationId;
  final String teacherId;
  final String classId;
  final String subjectId;
  final String createdBy;
  final DateTime? createdAt;

  TeacherAssignmentData({
    required this.id,
    required this.organizationId,
    required this.teacherId,
    required this.classId,
    required this.subjectId,
    this.createdBy = '',
    this.createdAt,
  });

  factory TeacherAssignmentData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherAssignmentData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      classId: data['classId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'teacherId': teacherId,
      'classId': classId,
      'subjectId': subjectId,
    };
  }
}
