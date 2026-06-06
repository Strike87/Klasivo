import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/services/student_service.dart';
import 'auth_provider.dart';

final studentServiceProvider = Provider<StudentService>((ref) => StudentService());

final studentsByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(studentServiceProvider).getStudentsByClassStream(classId);
});

final allStudentsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  return ref.read(studentServiceProvider).getStudentsByTeacherStream(teacherId);
});

final allStudentsProvider = Provider<List<StudentData>>((ref) {
  final asyncStudents = ref.watch(allStudentsStreamProvider);
  return asyncStudents.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => StudentData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final studentsByClassListProvider =
    Provider.family<List<StudentData>, String>((ref, classId) {
  final asyncStudents = ref.watch(studentsByClassProvider(classId));
  return asyncStudents.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => StudentData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

final totalStudentsProvider = Provider<int>((ref) {
  return ref.watch(allStudentsProvider).length;
});

final selectedClassIdProvider = StateProvider<String?>((ref) => null);

class StudentData {
  final String id;
  final String teacherId;
  final String classId;
  final String className;
  final String fullName;
  final String studentCode;
  final String? grade;
  final String? stageId;
  final String? gradeId;
  final String? groupId;
  final String? phone;
  final String? email;
  final String? parentPhone;
  final String institutionId;
  final DateTime? createdAt;

  StudentData({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.className,
    required this.fullName,
    required this.studentCode,
    this.grade,
    this.stageId,
    this.gradeId,
    this.groupId,
    this.phone,
    this.email,
    this.parentPhone,
    this.institutionId = 'default',
    this.createdAt,
  });

  factory StudentData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentData(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      fullName: data['fullName'] ?? '',
      studentCode: data['studentCode'] ?? '',
      grade: data['grade'],
      stageId: data['stageId'],
      gradeId: data['gradeId'],
      groupId: data['groupId'],
      phone: data['phone'],
      email: data['email'],
      parentPhone: data['parentPhone'],
      institutionId: data['institutionId'] ?? 'default',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'classId': classId,
      'className': className,
      'fullName': fullName,
      'studentCode': studentCode,
      'grade': grade,
      'stageId': stageId,
      'gradeId': gradeId,
      'groupId': groupId,
      'phone': phone,
      'email': email,
      'parentPhone': parentPhone,
      'institutionId': institutionId,
      'createdAt': createdAt,
    };
  }
}
