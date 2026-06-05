import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/services/student_service.dart';
import 'auth_provider.dart';

// ─── Student Service Provider ────────────────────────────────────────────────

final studentServiceProvider = Provider<StudentService>((ref) => StudentService());

// ─── Students by Class Stream Provider ───────────────────────────────────────

final studentsByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(studentServiceProvider).getStudentsByClassStream(classId);
});

// ─── All Students for Teacher Stream Provider ────────────────────────────────

final allStudentsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  return ref.read(studentServiceProvider).getStudentsByTeacherStream(teacherId);
});

// ─── All Students List (parsed data) ─────────────────────────────────────────

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

// ─── Students by Class List (parsed data) ────────────────────────────────────

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

// ─── Total Students Count Provider ───────────────────────────────────────────

final totalStudentsProvider = Provider<int>((ref) {
  return ref.watch(allStudentsProvider).length;
});

// ─── Selected Class ID Provider (for filtering) ─────────────────────────────

final selectedClassIdProvider = StateProvider<String?>((ref) => null);

// ─── Student Data Model ──────────────────────────────────────────────────────

class StudentData {
  final String id;
  final String teacherId;
  final String classId;
  final String className;
  final String fullName;
  final String studentCode;
  // Note: password is NOT exposed in the data model for security.
  // It is only accessed directly in AuthService for login verification.
  final String? grade;
  final DateTime? createdAt;

  StudentData({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.className,
    required this.fullName,
    required this.studentCode,
    this.grade,
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
      'createdAt': createdAt,
    };
  }
}
