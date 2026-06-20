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

// ─── Exam Template Domain Model ──────────────────────────────────────────────
// Extracted from exam_template_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ExamTemplateData {
  final String id;
  final String organizationId;
  final String teacherId;
  final String name;
  final String? description;
  final int durationMinutes;
  final int questionCount;
  final double totalMarks;
  final String? subjectId;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExamTemplateData({
    required this.id,
    required this.organizationId,
    required this.teacherId,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.questionCount,
    required this.totalMarks,
    this.subjectId,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ExamTemplateData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamTemplateData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      durationMinutes: data['durationMinutes'] ?? 60,
      questionCount: data['questionCount'] ?? 0,
      totalMarks: (data['totalMarks'] ?? 0).toDouble(),
      subjectId: data['subjectId'],
      shuffleQuestions: data['shuffleQuestions'] ?? false,
      shuffleOptions: data['shuffleOptions'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'teacherId': teacherId,
      'name': name,
      'description': description,
      'durationMinutes': durationMinutes,
      'questionCount': questionCount,
      'totalMarks': totalMarks,
      'subjectId': subjectId,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
    };
  }
}
