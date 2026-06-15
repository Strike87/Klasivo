// ─── Analytics Repository (Repository Pattern) ─────────────────────────────────
// Abstract interface + Firestore implementation for PRECOMPUTED analytics.
//
// KEY PRINCIPLE: This repository NEVER calculates live analytics.
// All reads come from precomputed collections (analytics_daily,
// analytics_weekly, analytics_monthly). Recomputation is triggered
// explicitly via `recompute*` methods (called by Cloud Functions or
// admin actions).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/config/app_constants.dart';

// ─── Analytics Domain Models ───────────────────────────────────────────────────

/// Precomputed daily analytics snapshot for an organization.
class DailyAnalytics {
  final String id;
  final DateTime date;
  final String orgId;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final double attendanceRate;
  final double averageGrade;
  final int examsCompleted;
  final int submissionsCount;
  final int violationsCount;
  final DateTime? computedAt;

  const DailyAnalytics({
    required this.id,
    required this.date,
    required this.orgId,
    this.totalStudents = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.attendanceRate = 0.0,
    this.averageGrade = 0.0,
    this.examsCompleted = 0,
    this.submissionsCount = 0,
    this.violationsCount = 0,
    this.computedAt,
  });

  factory DailyAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyAnalytics(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orgId: data['orgId'] ?? '',
      totalStudents: data['totalStudents'] as int? ?? 0,
      presentCount: data['presentCount'] as int? ?? 0,
      absentCount: data['absentCount'] as int? ?? 0,
      attendanceRate: (data['attendanceRate'] as num?)?.toDouble() ?? 0.0,
      averageGrade: (data['averageGrade'] as num?)?.toDouble() ?? 0.0,
      examsCompleted: data['examsCompleted'] as int? ?? 0,
      submissionsCount: data['submissionsCount'] as int? ?? 0,
      violationsCount: data['violationsCount'] as int? ?? 0,
      computedAt: (data['computedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'orgId': orgId,
      'totalStudents': totalStudents,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'attendanceRate': attendanceRate,
      'averageGrade': averageGrade,
      'examsCompleted': examsCompleted,
      'submissionsCount': submissionsCount,
      'violationsCount': violationsCount,
    };
  }
}

/// Precomputed weekly analytics snapshot for an organization.
class WeeklyAnalytics {
  final String id;
  final DateTime weekStart;
  final String orgId;
  final double averageAttendanceRate;
  final double averageGrade;
  final int totalExams;
  final int totalSubmissions;
  final List<Map<String, dynamic>> topPerformers;
  final DateTime? computedAt;

  const WeeklyAnalytics({
    required this.id,
    required this.weekStart,
    required this.orgId,
    this.averageAttendanceRate = 0.0,
    this.averageGrade = 0.0,
    this.totalExams = 0,
    this.totalSubmissions = 0,
    this.topPerformers = const [],
    this.computedAt,
  });

  factory WeeklyAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeeklyAnalytics(
      id: doc.id,
      weekStart: (data['weekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orgId: data['orgId'] ?? '',
      averageAttendanceRate:
          (data['averageAttendanceRate'] as num?)?.toDouble() ?? 0.0,
      averageGrade: (data['averageGrade'] as num?)?.toDouble() ?? 0.0,
      totalExams: data['totalExams'] as int? ?? 0,
      totalSubmissions: data['totalSubmissions'] as int? ?? 0,
      topPerformers: (data['topPerformers'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      computedAt: (data['computedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekStart': weekStart,
      'orgId': orgId,
      'averageAttendanceRate': averageAttendanceRate,
      'averageGrade': averageGrade,
      'totalExams': totalExams,
      'totalSubmissions': totalSubmissions,
      'topPerformers': topPerformers,
    };
  }
}

/// Precomputed monthly analytics snapshot for an organization.
class MonthlyAnalytics {
  final String id;
  final int month;
  final int year;
  final String orgId;
  final double averageAttendanceRate;
  final double averageGrade;
  final int totalExams;
  final double completionRate;
  final Map<String, dynamic> gradeDistribution;
  final List<Map<String, dynamic>> violationTrend;
  final DateTime? computedAt;

  const MonthlyAnalytics({
    required this.id,
    required this.month,
    required this.year,
    required this.orgId,
    this.averageAttendanceRate = 0.0,
    this.averageGrade = 0.0,
    this.totalExams = 0,
    this.completionRate = 0.0,
    this.gradeDistribution = const {},
    this.violationTrend = const [],
    this.computedAt,
  });

  factory MonthlyAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MonthlyAnalytics(
      id: doc.id,
      month: data['month'] as int? ?? 1,
      year: data['year'] as int? ?? DateTime.now().year,
      orgId: data['orgId'] ?? '',
      averageAttendanceRate:
          (data['averageAttendanceRate'] as num?)?.toDouble() ?? 0.0,
      averageGrade: (data['averageGrade'] as num?)?.toDouble() ?? 0.0,
      totalExams: data['totalExams'] as int? ?? 0,
      completionRate: (data['completionRate'] as num?)?.toDouble() ?? 0.0,
      gradeDistribution:
          data['gradeDistribution'] as Map<String, dynamic>? ?? {},
      violationTrend: (data['violationTrend'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      computedAt: (data['computedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'year': year,
      'orgId': orgId,
      'averageAttendanceRate': averageAttendanceRate,
      'averageGrade': averageGrade,
      'totalExams': totalExams,
      'completionRate': completionRate,
      'gradeDistribution': gradeDistribution,
      'violationTrend': violationTrend,
    };
  }
}

// ─── Firestore Collection Names ────────────────────────────────────────────────

const String _analyticsDailyCollection = 'analytics_daily';
const String _analyticsWeeklyCollection = 'analytics_weekly';
const String _analyticsMonthlyCollection = 'analytics_monthly';

// ─── Abstract Interface ────────────────────────────────────────────────────────

/// Abstract interface for precomputed analytics data access.
///
/// IMPORTANT: This repository never calculates live analytics.
/// All data is read from precomputed collections. Recomputation
/// is triggered explicitly via [recomputeDaily], [recomputeWeekly],
/// and [recomputeMonthly].
abstract class IAnalyticsRepository {
  // ─── Reads ────────────────────────────────────────────────────────────

  /// Get precomputed daily analytics for a specific date.
  Future<DailyAnalytics?> getDailyAnalytics({
    required String orgId,
    required DateTime date,
  });

  /// Get precomputed weekly analytics for a specific week.
  Future<WeeklyAnalytics?> getWeeklyAnalytics({
    required String orgId,
    required DateTime weekStart,
  });

  /// Get precomputed monthly analytics for a specific month/year.
  Future<MonthlyAnalytics?> getMonthlyAnalytics({
    required String orgId,
    required int year,
    required int month,
  });

  /// Watch precomputed daily analytics in real-time.
  Stream<DailyAnalytics> watchDailyAnalytics({
    required String orgId,
    required DateTime date,
  });

  /// Watch precomputed weekly analytics in real-time.
  Stream<WeeklyAnalytics> watchWeeklyAnalytics({
    required String orgId,
    required DateTime weekStart,
  });

  /// Watch precomputed monthly analytics in real-time.
  Stream<MonthlyAnalytics> watchMonthlyAnalytics({
    required String orgId,
    required int year,
    required int month,
  });

  // ─── Recomputation Triggers ───────────────────────────────────────────

  /// Trigger recomputation of daily analytics.
  /// Called by Cloud Functions or admin actions.
  Future<void> recomputeDaily({
    required String orgId,
    required DateTime date,
  });

  /// Trigger recomputation of weekly analytics.
  Future<void> recomputeWeekly({
    required String orgId,
    required DateTime weekStart,
  });

  /// Trigger recomputation of monthly analytics.
  Future<void> recomputeMonthly({
    required String orgId,
    required int year,
    required int month,
  });
}

// ─── Firestore Implementation ──────────────────────────────────────────────────

class FirestoreAnalyticsRepository implements IAnalyticsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _daily =>
      _db.collection(_analyticsDailyCollection);

  CollectionReference<Map<String, dynamic>> get _weekly =>
      _db.collection(_analyticsWeeklyCollection);

  CollectionReference<Map<String, dynamic>> get _monthly =>
      _db.collection(_analyticsMonthlyCollection);

  // ─── Helper: Date formatting ──────────────────────────────────────────

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _weekKey(DateTime weekStart) => _dateKey(weekStart);

  String _monthKey(int year, int month) =>
      '${year}-${month.toString().padLeft(2, '0')}';

  // ─── GetDailyAnalytics ────────────────────────────────────────────────

  @override
  Future<DailyAnalytics?> getDailyAnalytics({
    required String orgId,
    required DateTime date,
  }) async {
    try {
      final docId = '${orgId}_${_dateKey(date)}';
      final doc = await _daily.doc(docId).get();
      if (!doc.exists) return null;
      return DailyAnalytics.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  // ─── GetWeeklyAnalytics ───────────────────────────────────────────────

  @override
  Future<WeeklyAnalytics?> getWeeklyAnalytics({
    required String orgId,
    required DateTime weekStart,
  }) async {
    try {
      final docId = '${orgId}_${_weekKey(weekStart)}';
      final doc = await _weekly.doc(docId).get();
      if (!doc.exists) return null;
      return WeeklyAnalytics.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  // ─── GetMonthlyAnalytics ──────────────────────────────────────────────

  @override
  Future<MonthlyAnalytics?> getMonthlyAnalytics({
    required String orgId,
    required int year,
    required int month,
  }) async {
    try {
      final docId = '${orgId}_${_monthKey(year, month)}';
      final doc = await _monthly.doc(docId).get();
      if (!doc.exists) return null;
      return MonthlyAnalytics.fromFirestore(doc);
    } catch (e) {
      rethrow;
    }
  }

  // ─── WatchDailyAnalytics ──────────────────────────────────────────────

  @override
  Stream<DailyAnalytics> watchDailyAnalytics({
    required String orgId,
    required DateTime date,
  }) {
    final docId = '${orgId}_${_dateKey(date)}';
    return _daily.doc(docId).snapshots().map((doc) {
      if (!doc.exists) {
        return DailyAnalytics(
          id: docId,
          date: date,
          orgId: orgId,
        );
      }
      return DailyAnalytics.fromFirestore(doc);
    });
  }

  // ─── WatchWeeklyAnalytics ─────────────────────────────────────────────

  @override
  Stream<WeeklyAnalytics> watchWeeklyAnalytics({
    required String orgId,
    required DateTime weekStart,
  }) {
    final docId = '${orgId}_${_weekKey(weekStart)}';
    return _weekly.doc(docId).snapshots().map((doc) {
      if (!doc.exists) {
        return WeeklyAnalytics(
          id: docId,
          weekStart: weekStart,
          orgId: orgId,
        );
      }
      return WeeklyAnalytics.fromFirestore(doc);
    });
  }

  // ─── WatchMonthlyAnalytics ────────────────────────────────────────────

  @override
  Stream<MonthlyAnalytics> watchMonthlyAnalytics({
    required String orgId,
    required int year,
    required int month,
  }) {
    final docId = '${orgId}_${_monthKey(year, month)}';
    return _monthly.doc(docId).snapshots().map((doc) {
      if (!doc.exists) {
        return MonthlyAnalytics(
          id: docId,
          month: month,
          year: year,
          orgId: orgId,
        );
      }
      return MonthlyAnalytics.fromFirestore(doc);
    });
  }

  // ─── RecomputeDaily ──────────────────────────────────────────────────

  @override
  Future<void> recomputeDaily({
    required String orgId,
    required DateTime date,
  }) async {
    try {
      final dateStr = _dateKey(date);

      // --- Gather raw data ---
      // 1. Attendance for this org+date
      final attendanceSnapshot = await _db
          .collection(AppConstants.attendanceCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('date', isEqualTo: dateStr)
          .get();

      int totalStudents = attendanceSnapshot.docs.length;
      int presentCount = 0;
      int absentCount = 0;

      for (final doc in attendanceSnapshot.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (status == 'present' || status == 'late') {
          presentCount++;
        } else if (status == 'absent') {
          absentCount++;
        }
      }

      final attendanceRate =
          totalStudents > 0 ? presentCount / totalStudents * 100 : 0.0;

      // 2. Exam submissions for this org
      final examsSnapshot = await _db
          .collection(AppConstants.examsCollection)
          .where('organizationId', isEqualTo: orgId)
          .get();

      int examsCompleted = 0;
      int submissionsCount = 0;
      double totalScore = 0;
      int scoredSubmissions = 0;

      for (final examDoc in examsSnapshot.docs) {
        final examData = examDoc.data();
        final endDate = (examData['endDate'] as Timestamp?)?.toDate();
        final status = examData['status'] as String? ?? '';

        // Count exams that ended by this date
        if (endDate != null &&
            endDate.isBefore(date.add(const Duration(days: 1))) &&
            status != AppConstants.statusDraft) {
          examsCompleted++;
        }

        // Get submissions for this exam
        final subsSnapshot = await _db
            .collection(AppConstants.submissionsCollection)
            .where('examId', isEqualTo: examDoc.id)
            .where('status', whereIn: [
          AppConstants.submissionStatusSubmitted,
          AppConstants.submissionStatusFlagged,
        ]).get();

        for (final subDoc in subsSnapshot.docs) {
          final submittedAt =
              (subDoc.data()['submittedAt'] as Timestamp?)?.toDate();
          if (submittedAt != null &&
              submittedAt.year == date.year &&
              submittedAt.month == date.month &&
              submittedAt.day == date.day) {
            submissionsCount++;
            final score = (subDoc.data()['score'] as num?)?.toDouble() ?? 0;
            totalScore += score;
            scoredSubmissions++;
          }
        }
      }

      final averageGrade =
          scoredSubmissions > 0 ? totalScore / scoredSubmissions : 0.0;

      // 3. Violations for this date
      final violationsSnapshot = await _db
          .collection(AppConstants.violationsCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
          .where('createdAt',
              isLessThan: Timestamp.fromDate(
                  date.add(const Duration(days: 1))))
          .get();

      final violationsCount = violationsSnapshot.docs.length;

      // --- Write precomputed result ---
      final docId = '${orgId}_$dateStr';
      await _daily.doc(docId).set({
        'date': Timestamp.fromDate(date),
        'orgId': orgId,
        'totalStudents': totalStudents,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'attendanceRate': double.parse(attendanceRate.toStringAsFixed(1)),
        'averageGrade': double.parse(averageGrade.toStringAsFixed(1)),
        'examsCompleted': examsCompleted,
        'submissionsCount': submissionsCount,
        'violationsCount': violationsCount,
        'computedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── RecomputeWeekly ─────────────────────────────────────────────────

  @override
  Future<void> recomputeWeekly({
    required String orgId,
    required DateTime weekStart,
  }) async {
    try {
      final weekEnd = weekStart.add(const Duration(days: 7));

      // 1. Aggregate daily analytics for this week
      final dailySnapshot = await _daily
          .where('orgId', isEqualTo: orgId)
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('date', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      double totalAttendanceRate = 0;
      double totalAverageGrade = 0;
      int totalExams = 0;
      int totalSubmissions = 0;
      int dailyCount = dailySnapshot.docs.length;

      for (final doc in dailySnapshot.docs) {
        final data = doc.data();
        totalAttendanceRate +=
            (data['attendanceRate'] as num?)?.toDouble() ?? 0.0;
        totalAverageGrade +=
            (data['averageGrade'] as num?)?.toDouble() ?? 0.0;
        totalExams += data['examsCompleted'] as int? ?? 0;
        totalSubmissions += data['submissionsCount'] as int? ?? 0;
      }

      final averageAttendanceRate =
          dailyCount > 0 ? totalAttendanceRate / dailyCount : 0.0;
      final averageGrade =
          dailyCount > 0 ? totalAverageGrade / dailyCount : 0.0;

      // 2. Determine top performers for this week
      final submissionsSnapshot = await _db
          .collection(AppConstants.submissionsCollection)
          .where('status', whereIn: [
        AppConstants.submissionStatusSubmitted,
        AppConstants.submissionStatusFlagged,
      ]).get();

      final Map<String, double> studentScores = {};
      for (final subDoc in submissionsSnapshot.docs) {
        final subData = subDoc.data();
        final submittedAt =
            (subData['submittedAt'] as Timestamp?)?.toDate();
        if (submittedAt != null &&
            !submittedAt.isBefore(weekStart) &&
            submittedAt.isBefore(weekEnd)) {
          final studentId = subData['studentId'] as String? ?? '';
          final score = (subData['score'] as num?)?.toDouble() ?? 0;
          studentScores[studentId] =
              (studentScores[studentId] ?? 0) + score;
        }
      }

      final topPerformers = studentScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5 = topPerformers.take(5).map((e) {
        return {'studentId': e.key, 'totalScore': e.value};
      }).toList();

      // --- Write precomputed result ---
      final docId = '${orgId}_${_weekKey(weekStart)}';
      await _weekly.doc(docId).set({
        'weekStart': Timestamp.fromDate(weekStart),
        'orgId': orgId,
        'averageAttendanceRate':
            double.parse(averageAttendanceRate.toStringAsFixed(1)),
        'averageGrade': double.parse(averageGrade.toStringAsFixed(1)),
        'totalExams': totalExams,
        'totalSubmissions': totalSubmissions,
        'topPerformers': top5,
        'computedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── RecomputeMonthly ────────────────────────────────────────────────

  @override
  Future<void> recomputeMonthly({
    required String orgId,
    required int year,
    required int month,
  }) async {
    try {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 1);

      // 1. Aggregate weekly analytics for this month
      final weeklySnapshot = await _weekly
          .where('orgId', isEqualTo: orgId)
          .where('weekStart',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('weekStart', isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      double totalAttendanceRate = 0;
      double totalAverageGrade = 0;
      int totalExams = 0;
      int weeklyCount = weeklySnapshot.docs.length;

      for (final doc in weeklySnapshot.docs) {
        final data = doc.data();
        totalAttendanceRate +=
            (data['averageAttendanceRate'] as num?)?.toDouble() ?? 0.0;
        totalAverageGrade +=
            (data['averageGrade'] as num?)?.toDouble() ?? 0.0;
        totalExams += data['totalExams'] as int? ?? 0;
      }

      final averageAttendanceRate =
          weeklyCount > 0 ? totalAttendanceRate / weeklyCount : 0.0;
      final averageGrade =
          weeklyCount > 0 ? totalAverageGrade / weeklyCount : 0.0;

      // 2. Completion rate (submissions / total possible)
      final totalSubmissions = weeklySnapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + ((doc.data()['totalSubmissions'] as int?) ?? 0),
      );

      // Estimate total possible submissions from student count
      final studentsSnapshot = await _db
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .where('isActive', isEqualTo: true)
          .get();

      final studentCount = studentsSnapshot.docs.length;
      final totalPossible = studentCount * totalExams;
      final completionRate =
          totalPossible > 0 ? totalSubmissions / totalPossible * 100 : 0.0;

      // 3. Grade distribution
      final submissionsSnapshot = await _db
          .collection(AppConstants.submissionsCollection)
          .where('status', whereIn: [
        AppConstants.submissionStatusSubmitted,
        AppConstants.submissionStatusFlagged,
      ]).get();

      final Map<String, int> gradeDistribution = {
        '0-20': 0,
        '21-40': 0,
        '41-60': 0,
        '61-80': 0,
        '81-100': 0,
      };

      final List<Map<String, dynamic>> violationTrend = [];

      for (final subDoc in submissionsSnapshot.docs) {
        final subData = subDoc.data();
        final submittedAt =
            (subData['submittedAt'] as Timestamp?)?.toDate();
        if (submittedAt != null &&
            submittedAt.year == year &&
            submittedAt.month == month) {
          final percentage = subData['percentage'] as int? ?? 0;
          if (percentage <= 20) {
            gradeDistribution['0-20'] = (gradeDistribution['0-20'] ?? 0) + 1;
          } else if (percentage <= 40) {
            gradeDistribution['21-40'] =
                (gradeDistribution['21-40'] ?? 0) + 1;
          } else if (percentage <= 60) {
            gradeDistribution['41-60'] =
                (gradeDistribution['41-60'] ?? 0) + 1;
          } else if (percentage <= 80) {
            gradeDistribution['61-80'] =
                (gradeDistribution['61-80'] ?? 0) + 1;
          } else {
            gradeDistribution['81-100'] =
                (gradeDistribution['81-100'] ?? 0) + 1;
          }
        }
      }

      // 4. Violation trend (weekly counts)
      final violationsSnapshot = await _db
          .collection(AppConstants.violationsCollection)
          .where('organizationId', isEqualTo: orgId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('createdAt',
              isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      final Map<String, int> violationsByWeek = {};
      for (final doc in violationsSnapshot.docs) {
        final createdAt =
            (doc.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          // Determine the week number within the month
          final weekOfMonth = ((createdAt.day - 1) ~/ 7) + 1;
          final weekLabel = 'Week $weekOfMonth';
          violationsByWeek[weekLabel] =
              (violationsByWeek[weekLabel] ?? 0) + 1;
        }
      }

      violationTrend.addAll(violationsByWeek.entries
          .map((e) => {'week': e.key, 'count': e.value}));

      // --- Write precomputed result ---
      final docId = '${orgId}_${_monthKey(year, month)}';
      await _monthly.doc(docId).set({
        'month': month,
        'year': year,
        'orgId': orgId,
        'averageAttendanceRate':
            double.parse(averageAttendanceRate.toStringAsFixed(1)),
        'averageGrade': double.parse(averageGrade.toStringAsFixed(1)),
        'totalExams': totalExams,
        'completionRate': double.parse(completionRate.toStringAsFixed(1)),
        'gradeDistribution': gradeDistribution,
        'violationTrend': violationTrend,
        'computedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
