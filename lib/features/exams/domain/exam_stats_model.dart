// ─── Exam Stats Domain Models ────────────────────────────────────────────────
// Extracted from exam_stats_service.dart and exam_stats_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';

class ExamStatsData {
  final String id;
  final String examId;
  final String classId;
  final String organizationId;
  final int totalStudents;
  final int submittedStudents;
  final int absentStudents;
  final int averageScore;
  final int averagePercentage;
  final int highestScore;
  final int lowestScore;
  final double passRate;
  final int passCount;
  final int failCount;
  final int totalMarks;
  final int passingScore;
  final double standardDeviation;
  final int averageTimeSpent;
  final int totalViolations;
  final Map<String, dynamic> gradeDistribution;
  final DateTime? updatedAt;

  ExamStatsData({
    required this.id,
    required this.examId,
    required this.classId,
    this.organizationId = AppConstants.defaultInstitutionId,
    this.totalStudents = 0,
    this.submittedStudents = 0,
    this.absentStudents = 0,
    this.averageScore = 0,
    this.averagePercentage = 0,
    this.highestScore = 0,
    this.lowestScore = 0,
    this.passRate = 0.0,
    this.passCount = 0,
    this.failCount = 0,
    this.totalMarks = 0,
    this.passingScore = 50,
    this.standardDeviation = 0.0,
    this.averageTimeSpent = 0,
    this.totalViolations = 0,
    this.gradeDistribution = const {},
    this.updatedAt,
  });

  factory ExamStatsData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamStatsData(
      id: doc.id,
      examId: data['examId'] ?? '',
      classId: data['classId'] ?? '',
      organizationId: data['organizationId'] ?? data['institutionId'] ?? AppConstants.defaultInstitutionId,
      totalStudents: data['totalStudents'] as int? ?? 0,
      submittedStudents: data['submittedStudents'] as int? ?? 0,
      absentStudents: data['absentStudents'] as int? ?? 0,
      averageScore: data['averageScore'] as int? ?? 0,
      averagePercentage: data['averagePercentage'] as int? ?? 0,
      highestScore: data['highestScore'] as int? ?? 0,
      lowestScore: data['lowestScore'] as int? ?? 0,
      passRate: (data['passRate'] as num?)?.toDouble() ?? 0.0,
      passCount: data['passCount'] as int? ?? 0,
      failCount: data['failCount'] as int? ?? 0,
      totalMarks: data['totalMarks'] as int? ?? 0,
      passingScore: data['passingScore'] as int? ?? 50,
      standardDeviation: (data['standardDeviation'] as num?)?.toDouble() ?? 0.0,
      averageTimeSpent: data['averageTimeSpent'] as int? ?? 0,
      totalViolations: data['totalViolations'] as int? ?? 0,
      gradeDistribution: data['gradeDistribution'] as Map<String, dynamic>? ?? {},
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Get grade distribution as a list of maps for charts/PDF
  List<Map<String, dynamic>> get gradeDistributionList {
    return gradeDistribution.entries
        .map((e) => {
              'range': e.key,
              'count': e.value,
              'percentage': submittedStudents > 0
                  ? ((e.value as int) / submittedStudents * 100).round()
                  : 0,
            })
        .toList();
  }
}

class QuestionStatsData {
  final String id;
  final String questionText;
  final String questionType;
  final String difficulty;
  final int marks;
  final int totalAttempts;
  final int correctAttempts;
  final int correctPercentage;

  QuestionStatsData({
    required this.id,
    this.questionText = '',
    this.questionType = '',
    this.difficulty = '',
    this.marks = 0,
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.correctPercentage = 0,
  });

  factory QuestionStatsData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    return QuestionStatsData(
      id: doc.id,
      questionText: data['questionText'] ?? '',
      questionType: data['questionType'] ?? '',
      difficulty: data['difficulty'] ?? '',
      marks: data['marks'] as int? ?? 0,
      totalAttempts: stats['totalAttempts'] as int? ?? 0,
      correctAttempts: stats['correctAttempts'] as int? ?? 0,
      correctPercentage: stats['correctPercentage'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionText': questionText,
      'questionType': questionType,
      'difficulty': difficulty,
      'marks': marks,
      'correctPercentage': correctPercentage,
    };
  }
}

class PerformanceTrendPoint {
  final String examId;
  final String examTitle;
  final DateTime date;
  final int averageScore;
  final double passRate;
  final int submittedStudents;

  PerformanceTrendPoint({
    required this.examId,
    required this.examTitle,
    required this.date,
    required this.averageScore,
    required this.passRate,
    required this.submittedStudents,
  });
}

class StudentPerformancePoint {
  final String examId;
  final String examTitle;
  final DateTime date;
  final int score;
  final int totalMarks;
  final int percentage;

  StudentPerformancePoint({
    required this.examId,
    required this.examTitle,
    required this.date,
    required this.score,
    required this.totalMarks,
    required this.percentage,
  });
}

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
