import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/exam_stats_service.dart';
import 'auth_provider.dart';
import 'exam_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final examStatsServiceProvider =
    Provider<ExamStatsService>((ref) => ExamStatsService());

// ─── Single Exam Stats Provider ──────────────────────────────────────────────

final examStatsDataProvider =
    FutureProvider.family<ExamStatsData?, String>((ref, examId) async {
  final service = ref.read(examStatsServiceProvider);
  return service.getExamStats(examId);
});

// ─── Single Exam Stats Stream ────────────────────────────────────────────────

final examStatsStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, examId) {
  return ref.read(examStatsServiceProvider).getExamStatsStream(examId);
});

// ─── Live Exam Stats (from stream) ───────────────────────────────────────────

final liveExamStatsProvider =
    Provider.family<ExamStatsData?, String>((ref, examId) {
  final asyncStats = ref.watch(examStatsStreamProvider(examId));
  return asyncStats.when(
    data: (snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return ExamStatsData.fromFirestore(snapshot.docs.first);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// ─── Class Exam Stats Provider ───────────────────────────────────────────────

final classExamStatsProvider =
    FutureProvider.family<List<ExamStatsData>, String>((ref, classId) async {
  final service = ref.read(examStatsServiceProvider);
  return service.getClassExamStats(classId);
});

// ─── Class Exam Stats Stream ─────────────────────────────────────────────────

final classExamStatsStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(examStatsServiceProvider).getClassExamStatsStream(classId);
});

// ─── Teacher All Stats Provider ──────────────────────────────────────────────

final teacherAllStatsProvider =
    FutureProvider<List<ExamStatsData>>((ref) async {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) return [];

  final service = ref.read(examStatsServiceProvider);
  return service.getTeacherExamStats(teacherId);
});

// ─── Question Analysis Provider ──────────────────────────────────────────────

final questionAnalysisProvider =
    FutureProvider.family<List<QuestionStatsData>, String>((ref, examId) async {
  final service = ref.read(examStatsServiceProvider);
  return service.getQuestionAnalysis(examId);
});

// ─── Performance Trend Provider ──────────────────────────────────────────────

final classPerformanceTrendProvider =
    FutureProvider.family<List<PerformanceTrendPoint>, String>(
        (ref, classId) async {
  final service = ref.read(examStatsServiceProvider);
  return service.getClassPerformanceTrend(classId);
});

// ─── Student Performance Trend Provider ──────────────────────────────────────

final studentPerformanceTrendProvider =
    FutureProvider.family<List<StudentPerformancePoint>, String>(
        (ref, studentId) async {
  final classId = ref.watch(studentClassIdProvider);
  if (classId == null || classId.isEmpty) return [];

  final service = ref.read(examStatsServiceProvider);
  return service.getStudentPerformanceTrend(studentId, classId);
});

// ─── Teacher Analytics Summary Provider ──────────────────────────────────────

final teacherAnalyticsSummaryProvider =
    FutureProvider<TeacherAnalyticsSummary>((ref) async {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return TeacherAnalyticsSummary.empty();
  }

  final allStats = await ref.watch(teacherAllStatsProvider.future);
  final exams = ref.watch(examsProvider);

  if (allStats.isEmpty) {
    return TeacherAnalyticsSummary.empty();
  }

  // Calculate aggregated stats
  double totalPassRate = 0;
  double totalAvgScore = 0;
  int totalSubmissions = 0;
  int totalViolations = 0;
  int examsWithSubmissions = 0;

  for (final stat in allStats) {
    if (stat.submittedStudents > 0) {
      totalPassRate += stat.passRate;
      totalAvgScore += stat.averagePercentage;
      totalSubmissions += stat.submittedStudents;
      totalViolations += stat.totalViolations;
      examsWithSubmissions++;
    }
  }

  final avgPassRate =
      examsWithSubmissions > 0 ? totalPassRate / examsWithSubmissions : 0.0;
  final avgScore = examsWithSubmissions > 0
      ? totalAvgScore / examsWithSubmissions
      : 0.0;

  return TeacherAnalyticsSummary(
    totalExams: exams.length,
    completedExams:
        exams.where((e) => e.status == AppConstants.statusPublished && e.isEnded).length,
    totalSubmissions: totalSubmissions,
    averagePassRate: avgPassRate,
    averageScore: avgScore,
    totalViolations: totalViolations,
    allStats: allStats,
  );
});

// ─── Analytics Summary Model ─────────────────────────────────────────────────

class TeacherAnalyticsSummary {
  final int totalExams;
  final int completedExams;
  final int totalSubmissions;
  final double averagePassRate;
  final double averageScore;
  final int totalViolations;
  final List<ExamStatsData> allStats;

  TeacherAnalyticsSummary({
    required this.totalExams,
    required this.completedExams,
    required this.totalSubmissions,
    required this.averagePassRate,
    required this.averageScore,
    required this.totalViolations,
    required this.allStats,
  });

  factory TeacherAnalyticsSummary.empty() => TeacherAnalyticsSummary(
        totalExams: 0,
        completedExams: 0,
        totalSubmissions: 0,
        averagePassRate: 0,
        averageScore: 0,
        totalViolations: 0,
        allStats: [],
      );
}
