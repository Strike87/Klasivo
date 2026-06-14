// ─── Student Domain Model ────────────────────────────────────────────────────
// Extracted from student_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

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
