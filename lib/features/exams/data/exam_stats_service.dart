import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/performance_trace_service.dart';

class ExamStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // PRECOMPUTED EXAM STATS
  // ══════════════════════════════════════════════════════════════════════════

  /// Recalculate and upsert precomputed exam stats.
  /// Called after every submission to keep stats fresh.
  Future<void> recalculateExamStats(String examId) async {
    await PerformanceTraceService.instance.traceOperation(
      PerformanceTraces.statsRecalculate,
      () => _recalculateExamStatsImpl(examId),
      attributes: {'exam_id': examId},
    );
  }

  Future<void> _recalculateExamStatsImpl(String examId) async {
    try {
      // Get exam info
      final examDoc = await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .get();
      if (!examDoc.exists) return;

      final examData = examDoc.data()!;
      final passingScore = examData['passingScore'] as int? ?? 50;
      final totalMarks = examData['totalMarks'] as int? ?? 0;
      final classId = examData['classId'] as String? ?? '';
      final institutionId =
          examData['organizationId'] as String? ?? AppConstants.defaultInstitutionId;

      // Get all submissions for this exam
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // Get class student count
      final classStudentsSnapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .get();
      final totalStudents = classStudentsSnapshot.size;

      // Calculate stats
      int submittedStudents = 0;
      int totalScore = 0;
      int highestScore = 0;
      int lowestScore = 0;
      bool firstScore = true;
      int passCount = 0;
      int totalViolations = 0;
      int totalTimeSpent = 0;
      final List<int> scores = [];

      for (final doc in submissionsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final score = data['score'] as int? ?? 0;
        final percentage = data['percentage'] as int? ?? 0;
        final violations = data['violationCount'] as int? ?? 0;
        final timeSpent = data['timeSpent'] as int? ?? 0;

        if (status == AppConstants.submissionStatusSubmitted ||
            status == AppConstants.submissionStatusFlagged) {
          submittedStudents++;
          totalScore += score;
          scores.add(score);
          totalViolations += violations;
          totalTimeSpent += timeSpent;

          if (firstScore) {
            highestScore = score;
            lowestScore = score;
            firstScore = false;
          } else {
            if (score > highestScore) highestScore = score;
            if (score < lowestScore) lowestScore = score;
          }

          if (percentage >= passingScore) passCount++;
        }
      }

      final averageScore = submittedStudents > 0
          ? (totalScore / submittedStudents).round()
          : 0;
      final averagePercentage = submittedStudents > 0 && totalMarks > 0
          ? (totalScore / (submittedStudents * totalMarks) * 100).round()
          : 0;
      final passRate = submittedStudents > 0
          ? (passCount / submittedStudents) * 100
          : 0.0;
      final averageTimeSpent = submittedStudents > 0
          ? (totalTimeSpent / submittedStudents).round()
          : 0;

      // Grade distribution
      final gradeDistribution = _calculateGradeDistribution(scores, totalMarks);

      // Standard deviation
      final stdDev = _calculateStdDev(scores);

      // Upsert stats document
      final statsSnapshot = await _firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .limit(1)
          .get();

      final statsData = <String, dynamic>{
        'examId': examId,
        'classId': classId,
        'organizationId': institutionId,
        'totalStudents': totalStudents,
        'submittedStudents': submittedStudents,
        'absentStudents': totalStudents - submittedStudents,
        'averageScore': averageScore,
        'averagePercentage': averagePercentage,
        'highestScore': highestScore,
        'lowestScore': lowestScore,
        'passRate': passRate,
        'passCount': passCount,
        'failCount': submittedStudents - passCount,
        'totalMarks': totalMarks,
        'passingScore': passingScore,
        'standardDeviation': stdDev,
        'averageTimeSpent': averageTimeSpent,
        'totalViolations': totalViolations,
        'gradeDistribution': gradeDistribution,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (statsSnapshot.docs.isNotEmpty) {
        await _firestore
            .collection(AppConstants.examStatsCollection)
            .doc(statsSnapshot.docs.first.id)
            .update(statsData);
      } else {
        statsData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection(AppConstants.examStatsCollection)
            .add(statsData);
      }

      // Also calculate question-level stats
      await _recalculateQuestionStats(examId);
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate grade distribution from scores
  Map<String, dynamic> _calculateGradeDistribution(
      List<int> scores, int totalMarks) {
    final distribution = <String, int>{
      '0-20%': 0,
      '21-40%': 0,
      '41-60%': 0,
      '61-80%': 0,
      '81-100%': 0,
    };

    for (final score in scores) {
      final percentage =
          totalMarks > 0 ? (score / totalMarks * 100).round() : 0;
      if (percentage <= 20) {
        distribution['0-20%'] = distribution['0-20%']! + 1;
      } else if (percentage <= 40) {
        distribution['21-40%'] = distribution['21-40%']! + 1;
      } else if (percentage <= 60) {
        distribution['41-60%'] = distribution['41-60%']! + 1;
      } else if (percentage <= 80) {
        distribution['61-80%'] = distribution['61-80%']! + 1;
      } else {
        distribution['81-100%'] = distribution['81-100%']! + 1;
      }
    }

    return distribution;
  }

  /// Calculate standard deviation of scores
  double _calculateStdDev(List<int> scores) {
    if (scores.length < 2) return 0.0;
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final sumSquaredDiff =
        scores.map((s) => (s - mean) * (s - mean)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiff / (scores.length - 1));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUESTION-LEVEL STATS
  // ══════════════════════════════════════════════════════════════════════════

  /// Recalculate per-question stats for an exam
  Future<void> _recalculateQuestionStats(String examId) async {
    try {
      // Get all questions
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // Get all submitted submissions for this exam
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      final submittedSubmissionIds = <String>[];
      for (final doc in submissionsSnapshot.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (status == AppConstants.submissionStatusSubmitted ||
            status == AppConstants.submissionStatusFlagged) {
          submittedSubmissionIds.add(doc.id);
        }
      }

      if (submittedSubmissionIds.isEmpty) return;

      // Batch fetch ALL answers for this exam's submissions in ONE query
      // instead of N queries (one per question).
      // We query by examId (requires composite index on answers.examId).
      // Then group by questionId in memory.
      final allAnswersSnapshot = submittedSubmissionIds.isNotEmpty
          ? await _firestore
              .collection(AppConstants.answersCollection)
              .where('examId', isEqualTo: examId)
              .get()
          : await _firestore
              .collection(AppConstants.answersCollection)
              .where('submissionId', whereIn: submittedSubmissionIds.take(30).toList())
              .get();

      // Group answers by questionId for O(1) lookup
      final answersByQuestion = <String, List<QueryDocumentSnapshot>>{};
      for (final aDoc in allAnswersSnapshot.docs) {
        final data = aDoc.data();
        final questionId = data['questionId'] as String? ?? '';
        final submissionId = data['submissionId'] as String? ?? '';

        // Only count answers from submitted submissions
        if (!submittedSubmissionIds.contains(submissionId)) continue;

        answersByQuestion.putIfAbsent(questionId, () => []).add(aDoc);
      }

      // Batch update all question stats using a WriteBatch
      final batch = _firestore.batch();
      int batchOpCount = 0;

      for (final qDoc in questionsSnapshot.docs) {
        final questionId = qDoc.id;
        final questionAnswers = answersByQuestion[questionId] ?? [];
        int totalAttempts = questionAnswers.length;
        int correctAttempts = 0;

        for (final aDoc in questionAnswers) {
          final data = aDoc.data();
          final dataMap = data as Map<String, dynamic>?;
          if (dataMap?['isCorrect'] as bool? ?? false) {
            correctAttempts++;
          }
        }

        final correctPercentage = totalAttempts > 0
            ? (correctAttempts / totalAttempts * 100).round()
            : 0;

        batch.update(
          _firestore.collection(AppConstants.questionsCollection).doc(questionId),
          {
            'stats.totalAttempts': totalAttempts,
            'stats.correctAttempts': correctAttempts,
            'stats.correctPercentage': correctPercentage,
            'stats.updatedAt': FieldValue.serverTimestamp(),
          },
        );
        batchOpCount++;

        // Firestore batches support max 500 operations
        if (batchOpCount >= 450) {
          await batch.commit();
          batchOpCount = 0;
        }
      }

      // Commit remaining batch operations
      if (batchOpCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      // Non-critical: don't fail the submission
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FETCH PRECOMPUTED STATS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get precomputed stats for a single exam
  Future<ExamStatsData?> getExamStats(String examId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return ExamStatsData.fromFirestore(snapshot.docs.first);
    } catch (e) {
      rethrow;
    }
  }

  /// Get precomputed stats for all exams of a class
  Future<List<ExamStatsData>> getClassExamStats(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.examStatsCollection)
          .where('classId', isEqualTo: classId)
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ExamStatsData.fromFirestore(doc))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all exam stats for a teacher (across all classes)
  Future<List<ExamStatsData>> getTeacherExamStats(String teacherId) async {
    try {
      // First get all exams by this teacher
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (examsSnapshot.docs.isEmpty) return [];

      final examIds = examsSnapshot.docs.map((d) => d.id).toList();

      // Fetch stats for those exams (Firestore 'in' queries support max 30)
      final List<ExamStatsData> allStats = [];
      for (var i = 0; i < examIds.length; i += 30) {
        final chunk = examIds.sublist(i, i + 30 > examIds.length ? examIds.length : i + 30);
        final statsSnapshot = await _firestore
            .collection(AppConstants.examStatsCollection)
            .where('examId', whereIn: chunk)
            .get();

        allStats.addAll(statsSnapshot.docs
            .map((doc) => ExamStatsData.fromFirestore(doc)));
      }

      return allStats;
    } catch (e) {
      rethrow;
    }
  }

  /// Get question-level analysis for an exam
  Future<List<QuestionStatsData>> getQuestionAnalysis(String examId) async {
    try {
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .orderBy('order', descending: false)
          .get();

      return questionsSnapshot.docs
          .map((doc) => QuestionStatsData.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Fallback: try without ordering
      try {
        final questionsSnapshot = await _firestore
            .collection(AppConstants.questionsCollection)
            .where('examId', isEqualTo: examId)
            .get();

        return questionsSnapshot.docs
            .map((doc) => QuestionStatsData.fromFirestore(doc))
            .toList();
      } catch (e2) {
        rethrow;
      }
    }
  }

  /// Stream of exam stats for real-time dashboard updates
  Stream<QuerySnapshot> getExamStatsStream(String examId) {
    return _firestore
        .collection(AppConstants.examStatsCollection)
        .where('examId', isEqualTo: examId)
        .snapshots();
  }

  /// Stream of all exam stats for a class
  Stream<QuerySnapshot> getClassExamStatsStream(String classId) {
    return _firestore
        .collection(AppConstants.examStatsCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERFORMANCE TRENDS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get performance trend data across exams for a class (for line charts)
  Future<List<PerformanceTrendPoint>> getClassPerformanceTrend(
      String classId) async {
    try {
      final stats = await getClassExamStats(classId);
      // Batch fetch exam documents instead of N+1 individual queries
      final examIds = stats.map((s) => s.examId).toList();
      final Map<String, DocumentSnapshot> examDocs = {};

      // Firestore 'in' queries support max 30 items per query
      for (var i = 0; i < examIds.length; i += 30) {
        final chunk = examIds.sublist(
          i,
          i + 30 > examIds.length ? examIds.length : i + 30,
        );
        final snapshot = await _firestore
            .collection(AppConstants.examsCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          examDocs[doc.id] = doc;
        }
      }

      final List<PerformanceTrendPoint> trend = [];

      for (final stat in stats) {
        final examDoc = examDocs[stat.examId];
        if (examDoc != null && examDoc.exists) {
          final data = examDoc.data() as Map<String, dynamic>?;
          if (data != null) {
            trend.add(PerformanceTrendPoint(
              examId: stat.examId,
              examTitle: data['title'] as String? ?? 'Unknown',
              date: (data['publishedAt'] as Timestamp?)?.toDate() ??
                  (data['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              averageScore: stat.averagePercentage,
              passRate: stat.passRate,
              submittedStudents: stat.submittedStudents,
            ));
          }
        }
      }

      // Sort by date ascending for the chart
      trend.sort((a, b) => a.date.compareTo(b.date));
      return trend;
    } catch (e) {
      rethrow;
    }
  }

  /// Get performance trend for a single student across exams
  Future<List<StudentPerformancePoint>> getStudentPerformanceTrend(
      String studentId, String classId) async {
    try {
      // Get all published exams for this class
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('classId', isEqualTo: classId)
          .where('status', isEqualTo: AppConstants.statusPublished)
          .orderBy('publishedAt', descending: false)
          .get();

      // Batch fetch all submissions for this student across these exams
      // instead of N+1 individual queries per exam
      final examIds = examsSnapshot.docs.map((d) => d.id).toList();
      final Map<String, Map<String, dynamic>> submissionsByExam = {};

      for (var i = 0; i < examIds.length; i += 30) {
        final chunk = examIds.sublist(
          i,
          i + 30 > examIds.length ? examIds.length : i + 30,
        );
        final subSnapshot = await _firestore
            .collection(AppConstants.submissionsCollection)
            .where('examId', whereIn: chunk)
            .where('studentId', isEqualTo: studentId)
            .get();
        for (final doc in subSnapshot.docs) {
          final data = doc.data();
          submissionsByExam[data['examId'] as String? ?? ''] = data;
        }
      }

      final List<StudentPerformancePoint> trend = [];

      for (final examDoc in examsSnapshot.docs) {
        final examData = examDoc.data();
        final subData = submissionsByExam[examDoc.id];

        if (subData != null) {
          trend.add(StudentPerformancePoint(
            examId: examDoc.id,
            examTitle: examData['title'] as String? ?? 'Unknown',
            date: (examData['publishedAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
            score: subData['score'] as int? ?? 0,
            totalMarks: subData['totalMarks'] as int? ?? 0,
            percentage: subData['percentage'] as int? ?? 0,
          ));
        }
      }

      return trend;
    } catch (e) {
      rethrow;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ════════════════════════════════════════════════════════════════════════════

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
