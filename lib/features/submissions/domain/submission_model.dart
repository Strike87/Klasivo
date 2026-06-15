// ─── Submission Domain Models ────────────────────────────────────────────────
// Extracted from submission_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';

class SubmissionData {
  final String id;
  final String examId;
  final String studentId;
  final String classId;
  final String status;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int timeSpent;
  final int totalMarks;
  final int score;
  final int percentage;
  final int violationCount;

  SubmissionData({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.classId,
    required this.status,
    this.startedAt,
    this.submittedAt,
    this.timeSpent = 0,
    this.totalMarks = 0,
    this.score = 0,
    this.percentage = 0,
    this.violationCount = 0,
  });

  factory SubmissionData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubmissionData(
      id: doc.id,
      examId: data['examId'] ?? '',
      studentId: data['studentId'] ?? '',
      classId: data['classId'] ?? '',
      status: data['status'] ?? AppConstants.submissionStatusStarted,
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      timeSpent: data['timeSpent'] ?? 0,
      totalMarks: data['totalMarks'] ?? 0,
      score: data['score'] ?? 0,
      percentage: data['percentage'] ?? 0,
      violationCount: data['violationCount'] ?? 0,
    );
  }

  bool get isSubmitted =>
      status == AppConstants.submissionStatusSubmitted ||
      status == AppConstants.submissionStatusFlagged;

  bool get isFlagged => status == AppConstants.submissionStatusFlagged;

  String get statusLabel {
    switch (status) {
      case 'started':
        return 'In Progress';
      case 'submitted':
        return 'Submitted';
      case 'flagged':
        return 'Flagged';
      default:
        return status;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'studentId': studentId,
      'classId': classId,
      'status': status,
      'timeSpent': timeSpent,
      'totalMarks': totalMarks,
      'score': score,
      'percentage': percentage,
      'violationCount': violationCount,
    };
  }
}

class StudentExamStats {
  final int upcoming;
  final int completed;
  final double averageScore;
  final int totalSubmissions;

  StudentExamStats({
    required this.upcoming,
    required this.completed,
    required this.averageScore,
    required this.totalSubmissions,
  });
}
