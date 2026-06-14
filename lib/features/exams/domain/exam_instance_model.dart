// ─── Exam Instance Domain Model ──────────────────────────────────────────────
// Extracted from exam_instance_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ExamInstanceData {
  final String id;
  final String? organizationId;
  final String examId;
  final String studentId;
  final String? classId;
  final String? teacherId;
  final List<String> randomizedQuestions;
  final bool isRandomized;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? submissionId;

  ExamInstanceData({
    required this.id,
    this.organizationId,
    required this.examId,
    required this.studentId,
    this.classId,
    this.teacherId,
    this.randomizedQuestions = const [],
    this.isRandomized = false,
    this.startedAt,
    this.completedAt,
    this.submissionId,
  });

  factory ExamInstanceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamInstanceData(
      id: doc.id,
      organizationId: data['organizationId'] as String? ?? data['institutionId'] as String?,
      examId: data['examId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String?,
      teacherId: data['teacherId'] as String?,
      randomizedQuestions: (data['randomizedQuestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isRandomized: data['isRandomized'] as bool? ?? false,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      submissionId: data['submissionId'] as String?,
    );
  }

  bool get isCompleted => completedAt != null;
  bool get hasSubmission => submissionId != null;
}
