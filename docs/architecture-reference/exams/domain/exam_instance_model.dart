// ═══════════════════════════════════════════════════════════════════════════════
// ⚠️  ARCHITECTURE REFERENCE — NOT COMPILED, NOT WIRED INTO THE APP  ⚠️
// ─────────────────────────────────────────────────────────────────────────────
// This file was MOVED here from lib/features/exams/domain/ as part of the Sprint 1
// scaffold cleanup (Phase 5+). It is preserved as a DESIGN REFERENCE for a
// future typed-model migration, but it is NOT included in the Flutter build
// (this directory is outside `lib/`).
//
// Before relying on this as the design source for a migration, verify field
// shapes match what the live service actually writes to Firestore. See
// download/scaffold-investigation-report.md for full context.
// ═══════════════════════════════════════════════════════════════════════════════

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
