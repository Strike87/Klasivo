import 'package:flutter/foundation.dart';
import 'analytics_warehouse.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ANALYTICS AGGREGATOR — Aggregation logic for pre-computed analytics
//
// Computes aggregated analytics from raw data and stores results in the
// AnalyticsWarehouse. Designed to run in the background and on-demand.
// ═══════════════════════════════════════════════════════════════════════════════

/// Raw attendance record used for aggregation.
class RawAttendanceRecord {
  final String studentId;
  final String classId;
  final String subjectId;
  final String status; // present, absent, late, excused
  final DateTime date;

  const RawAttendanceRecord({
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.status,
    required this.date,
  });
}

/// Raw exam submission record used for aggregation.
class RawExamSubmission {
  final String studentId;
  final String examId;
  final String subjectId;
  final double score;
  final double maxScore;
  final DateTime submittedAt;

  const RawExamSubmission({
    required this.studentId,
    required this.examId,
    required this.subjectId,
    required this.score,
    required this.maxScore,
    required this.submittedAt,
  });
}

class AnalyticsAggregator {
  AnalyticsAggregator._();
  static final AnalyticsAggregator instance = AnalyticsAggregator._();

  final _warehouse = AnalyticsWarehouse.instance;

  // ─── Attendance Aggregation ─────────────────────────────────────────────

  /// Compute attendance analytics from raw records.
  AttendanceAnalytics computeAttendanceAnalytics(
    List<RawAttendanceRecord> records, {
    int totalStudents = 0,
  }) {
    if (records.isEmpty) {
      return const AttendanceAnalytics(totalStudents: totalStudents);
    }

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;
    final rateByClass = <String, int>{};
    final classTotals = <String, int>{};
    final rateBySubject = <String, int>{};
    final subjectTotals = <String, int>{};
    final trendData = <String, int>{};

    for (final r in records) {
      switch (r.status) {
        case 'present':
          present++;
          rateByClass[r.classId] = (rateByClass[r.classId] ?? 0) + 1;
          rateBySubject[r.subjectId] = (rateBySubject[r.subjectId] ?? 0) + 1;
          break;
        case 'absent':
          absent++;
          break;
        case 'late':
          late++;
          rateByClass[r.classId] = (rateByClass[r.classId] ?? 0) + 1;
          rateBySubject[r.subjectId] = (rateBySubject[r.subjectId] ?? 0) + 1;
          break;
        case 'excused':
          excused++;
          rateByClass[r.classId] = (rateByClass[r.classId] ?? 0) + 1;
          rateBySubject[r.subjectId] = (rateBySubject[r.subjectId] ?? 0) + 1;
          break;
      }

      classTotals[r.classId] = (classTotals[r.classId] ?? 0) + 1;
      subjectTotals[r.subjectId] = (subjectTotals[r.subjectId] ?? 0) + 1;

      final dateKey = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
      trendData[dateKey] = (trendData[dateKey] ?? 0) + 1;
    }

    final total = records.length;
    final overallRate = total > 0 ? (present + late + excused) / total * 100 : 0.0;

    // Convert class/subject counts to rates
    final classRates = <String, double>{};
    for (final entry in rateByClass.entries) {
      final classTotal = classTotals[entry.key] ?? 1;
      classRates[entry.key] = entry.value / classTotal * 100;
    }

    final subjectRates = <String, double>{};
    for (final entry in rateBySubject.entries) {
      final subjectTotal = subjectTotals[entry.key] ?? 1;
      subjectRates[entry.key] = entry.value / subjectTotal * 100;
    }

    final analytics = AttendanceAnalytics(
      overallRate: overallRate,
      rateByClass: classRates,
      rateBySubject: subjectRates,
      trendData: trendData,
      totalStudents: totalStudents,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
    );

    // Cache the result
    _warehouse.put('attendance_overall', analytics);

    return analytics;
  }

  // ─── Exam Analytics Aggregation ─────────────────────────────────────────

  /// Compute exam analytics from raw submission records.
  ExamAnalytics computeExamAnalytics(
    List<RawExamSubmission> submissions, {
    int totalExams = 0,
    double passingThreshold = 50.0,
  }) {
    if (submissions.isEmpty) {
      return ExamAnalytics(totalExams: totalExams);
    }

    double totalScore = 0;
    double highest = double.negativeInfinity;
    double lowest = double.positiveInfinity;
    int passedCount = 0;
    final scoreBySubject = <String, List<double>>{};
    final gradeDistribution = <String, int>{};

    for (final s in submissions) {
      final percentage = s.maxScore > 0 ? (s.score / s.maxScore) * 100 : 0.0;
      totalScore += percentage;

      if (percentage > highest) highest = percentage;
      if (percentage < lowest) lowest = percentage;

      if (percentage >= passingThreshold) passedCount++;

      scoreBySubject.putIfAbsent(s.subjectId, () => []).add(percentage);

      // Grade distribution: A ≥ 90, B ≥ 80, C ≥ 70, D ≥ 60, F < 60
      final grade = _percentageToGrade(percentage);
      gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
    }

    final total = submissions.length;
    final averageScore = total > 0 ? totalScore / total : 0.0;
    final passRate = total > 0 ? passedCount / total * 100 : 0.0;

    // Average by subject
    final subjectAverages = <String, double>{};
    for (final entry in scoreBySubject.entries) {
      final scores = entry.value;
      subjectAverages[entry.key] =
          scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
    }

    final analytics = ExamAnalytics(
      averageScore: averageScore,
      passRate: passRate,
      scoreBySubject: subjectAverages,
      gradeDistribution: gradeDistribution,
      totalExams: totalExams,
      totalSubmissions: total,
      highestScore: highest == double.negativeInfinity ? 0 : highest,
      lowestScore: lowest == double.positiveInfinity ? 0 : lowest,
    );

    _warehouse.put('exam_overall', analytics);

    return analytics;
  }

  // ─── Student Analytics Aggregation ──────────────────────────────────────

  /// Compute analytics for a single student.
  StudentAnalytics computeStudentAnalytics({
    required List<RawExamSubmission> examSubmissions,
    required List<RawAttendanceRecord> attendanceRecords,
    required Map<String, double> subjectScores,
    List<String> upcomingExams = const [],
    List<String> pendingAssignments = const [],
  }) {
    // Compute GPA from exam submissions
    double gpa = 0;
    if (examSubmissions.isNotEmpty) {
      final totalPercentage = examSubmissions.fold<double>(
        0,
        (sum, s) => sum + (s.maxScore > 0 ? s.score / s.maxScore * 100 : 0),
      );
      gpa = totalPercentage / examSubmissions.length / 100 * 4.0; // 4.0 scale
    }

    // Compute attendance rate
    double attendanceRate = 0;
    if (attendanceRecords.isNotEmpty) {
      final presentCount = attendanceRecords.where(
        (r) => r.status == 'present' || r.status == 'late' || r.status == 'excused',
      ).length;
      attendanceRate = presentCount / attendanceRecords.length * 100;
    }

    final analytics = StudentAnalytics(
      gpa: gpa,
      attendanceRate: attendanceRate,
      examsCompleted: examSubmissions.length,
      assignmentsCompleted: 0, // Populated from assignment data
      subjectScores: subjectScores,
      upcomingExams: upcomingExams,
      pendingAssignments: pendingAssignments,
    );

    _warehouse.put('student_${examSubmissions.firstOrNull?.studentId ?? 'unknown'}', analytics);

    return analytics;
  }

  // ─── Class Analytics Aggregation ────────────────────────────────────────

  /// Compute analytics for a class.
  ClassAnalytics computeClassAnalytics({
    required String classId,
    required String className,
    required List<RawExamSubmission> examSubmissions,
    required List<RawAttendanceRecord> attendanceRecords,
    required int studentCount,
  }) {
    double averageScore = 0;
    if (examSubmissions.isNotEmpty) {
      final totalPercentage = examSubmissions.fold<double>(
        0,
        (sum, s) => sum + (s.maxScore > 0 ? s.score / s.maxScore * 100 : 0),
      );
      averageScore = totalPercentage / examSubmissions.length;
    }

    double attendanceRate = 0;
    if (attendanceRecords.isNotEmpty) {
      final presentCount = attendanceRecords.where(
        (r) => r.status == 'present' || r.status == 'late' || r.status == 'excused',
      ).length;
      attendanceRate = presentCount / attendanceRecords.length * 100;
    }

    // Subject averages
    final subjectScores = <String, List<double>>{};
    for (final s in examSubmissions) {
      final percentage = s.maxScore > 0 ? s.score / s.maxScore * 100 : 0.0;
      subjectScores.putIfAbsent(s.subjectId, () => []).add(percentage);
    }
    final subjectAverages = <String, double>{};
    for (final entry in subjectScores.entries) {
      subjectAverages[entry.key] =
          entry.value.isNotEmpty ? entry.value.reduce((a, b) => a + b) / entry.value.length : 0.0;
    }

    final passRate = examSubmissions.isNotEmpty
        ? examSubmissions.where((s) => s.maxScore > 0 && (s.score / s.maxScore * 100) >= 50).length /
            examSubmissions.length * 100
        : 0.0;

    final analytics = ClassAnalytics(
      classId: classId,
      className: className,
      studentCount: studentCount,
      averageScore: averageScore,
      attendanceRate: attendanceRate,
      passRate: passRate,
      subjectAverages: subjectAverages,
    );

    _warehouse.put('class_$classId', analytics);

    return analytics;
  }

  // ─── Batch Refresh ──────────────────────────────────────────────────────

  /// Refresh all cached analytics for an organization.
  Future<void> refreshAll(String orgId) async {
    debugPrint('[AnalyticsAggregator] Refreshing all analytics for org: $orgId');
    _warehouse.invalidatePrefix('attendance_');
    _warehouse.invalidatePrefix('exam_');
    _warehouse.invalidatePrefix('student_');
    _warehouse.invalidatePrefix('class_');
    // Actual recomputation would be triggered by data layer calls
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String _percentageToGrade(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }
}
