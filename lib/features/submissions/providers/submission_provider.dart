import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/submission_service.dart';
import 'auth_provider.dart';
import 'exam_provider.dart';

// ─── Submission Service Provider ────────────────────────────────────────────

final submissionServiceProvider =
    Provider<SubmissionService>((ref) => SubmissionService());

// ─── Student Submissions Stream Provider ────────────────────────────────────

final studentSubmissionsStreamProvider =
    StreamProvider<QuerySnapshot>((ref) {
  final studentId = ref.watch(userIdProvider);
  if (studentId == null || studentId.isEmpty) {
    return const Stream.empty();
  }
  return ref
      .read(submissionServiceProvider)
      .getStudentSubmissionsStream(studentId);
});

// ─── Student Submissions List Provider ──────────────────────────────────────

final studentSubmissionsProvider = Provider<List<SubmissionData>>((ref) {
  final asyncSubs = ref.watch(studentSubmissionsStreamProvider);
  return asyncSubs.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => SubmissionData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Exam Submissions Stream Provider (for teacher) ────────────────────────

final examSubmissionsStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, examId) {
  return ref
      .read(submissionServiceProvider)
      .getExamSubmissionsStream(examId);
});

// ─── Exam Submissions List Provider ────────────────────────────────────────

final examSubmissionsProvider =
    Provider.family<List<SubmissionData>, String>((ref, examId) {
  final asyncSubs = ref.watch(examSubmissionsStreamProvider(examId));
  return asyncSubs.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => SubmissionData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Student Exam Stats Provider ────────────────────────────────────────────

final studentExamStatsProvider = Provider<StudentExamStats>((ref) {
  final submissions = ref.watch(studentSubmissionsProvider);
  final classId = ref.watch(studentClassIdProvider);
  final now = DateTime.now();

  int upcoming = 0;
  int completed = 0;
  double avgScore = 0;

  // Use class-based exam stream instead of teacher-filtered examsProvider
  if (classId != null && classId.isNotEmpty) {
    final examsAsync = ref.watch(classExamsStreamProvider(classId));
    final exams = examsAsync.when(
      data: (snapshot) =>
          snapshot.docs.map((doc) => ExamData.fromFirestore(doc)).toList(),
      loading: () => <ExamData>[],
      error: (_, __) => <ExamData>[],
    );

    for (final exam in exams) {
      if (exam.status != AppConstants.statusPublished) continue;
      if (exam.endDate.isBefore(now)) {
        completed++;
      } else {
        upcoming++;
      }
    }
  }

  // Calculate average score from submitted submissions
  final submittedSubs = submissions
      .where((s) => s.status == AppConstants.submissionStatusSubmitted)
      .toList();

  if (submittedSubs.isNotEmpty) {
    final totalPercentage =
        submittedSubs.fold<int>(0, (sum, s) => sum + s.percentage);
    avgScore = totalPercentage / submittedSubs.length;
  }

  return StudentExamStats(
    upcoming: upcoming,
    completed: completed,
    averageScore: avgScore,
    totalSubmissions: submittedSubs.length,
  );
});

// ─── Submission Data Model ──────────────────────────────────────────────────

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

// ─── Student Exam Stats Model ───────────────────────────────────────────────

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
