import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/student_service.dart';
import 'organization_provider.dart';

final studentServiceProvider =
    Provider<StudentService>((ref) => StudentService());

final studentsByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(studentServiceProvider).getStudentsByClassStream(classId);
});

final studentsByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(studentServiceProvider).getStudentsByOrganizationStream(orgId);
});

final allStudentsProvider = Provider<List<StudentData>>((ref) {
  final asyncStudents = ref.watch(studentsByOrgProvider);
  return asyncStudents.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => StudentData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
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
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

final totalStudentsProvider = Provider<int>((ref) {
  return ref.watch(allStudentsProvider).length;
});

class StudentData {
  final String id;
  final String organizationId;
  final String classId;
  final String fullName;
  final String studentCode;
  final String? grade;
  final String? teacherId;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isActive;
  final DateTime? createdAt;

  StudentData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.fullName,
    required this.studentCode,
    this.grade,
    this.teacherId,
    this.email,
    this.phone,
    this.photoUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory StudentData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      fullName: data['fullName'] ?? '',
      studentCode: data['studentCode'] ?? '',
      grade: data['grade'],
      teacherId: data['teacherId'],
      email: data['email'],
      phone: data['phone'],
      photoUrl: data['photoUrl'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'classId': classId,
      'fullName': fullName,
      'studentCode': studentCode,
      'grade': grade,
      'teacherId': teacherId,
      'email': email,
      'phone': phone,
      'isActive': isActive,
    };
  }
}

// Alias for backward compatibility with screen files
final allStudentsStreamProvider = studentsByOrgProvider;
