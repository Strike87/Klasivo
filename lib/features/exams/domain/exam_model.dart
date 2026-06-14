// ─── Exam Domain Models ──────────────────────────────────────────────────────
// Extracted from exam_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';

class ExamData {
  final String id;
  final String teacherId;
  final String title;
  final String? description;
  final String classId;
  final int durationMinutes;
  final DateTime startDate;
  final DateTime endDate;
  final int totalMarks;
  final int passingScore;
  final String status;
  final int questionCount;
  final bool isRandomized;
  final bool allowRetake;
  final String organizationId;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  ExamData({
    required this.id,
    required this.teacherId,
    required this.title,
    this.description,
    required this.classId,
    required this.durationMinutes,
    required this.startDate,
    required this.endDate,
    this.totalMarks = 0,
    this.passingScore = 0,
    this.status = AppConstants.statusDraft,
    this.questionCount = 0,
    this.isRandomized = false,
    this.allowRetake = false,
    this.organizationId = AppConstants.defaultInstitutionId,
    this.createdAt,
    this.publishedAt,
  });

  factory ExamData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamData(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      classId: data['classId'] ?? '',
      durationMinutes: data['durationMinutes'] as int? ?? 30,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalMarks: data['totalMarks'] as int? ?? 0,
      passingScore: data['passingScore'] as int? ?? 0,
      status: data['status'] ?? AppConstants.statusDraft,
      questionCount: data['questionCount'] as int? ?? 0,
      isRandomized: data['isRandomized'] as bool? ?? false,
      allowRetake: data['allowRetake'] as bool? ?? false,
      organizationId: data['organizationId'] ?? data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isActive =>
      status == AppConstants.statusPublished &&
      DateTime.now().isAfter(startDate) &&
      DateTime.now().isBefore(endDate);

  bool get canStart =>
      status == AppConstants.statusPublished &&
      DateTime.now().isAfter(startDate);

  bool get isEnded => DateTime.now().isAfter(endDate);

  // Note: getClassName requires ClassData — use from classes feature domain
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'classId': classId,
      'durationMinutes': durationMinutes,
      'startDate': startDate,
      'endDate': endDate,
      'totalMarks': totalMarks,
      'passingScore': passingScore,
      'status': status,
      'questionCount': questionCount,
      'isRandomized': isRandomized,
      'allowRetake': allowRetake,
      'organizationId': organizationId,
      'createdAt': createdAt,
      'publishedAt': publishedAt,
    };
  }
}
