/// Klasivo v2.0 — Enterprise Analytics Data Models
///
/// Pre-computed daily, weekly, and monthly analytics snapshots for
/// fast dashboard loading. Stored in dedicated Firestore collections:
///   - `analytics_daily`   — one document per org/campus per day
///   - `analytics_weekly`  — one document per org/campus per week
///   - `analytics_monthly` — one document per org/campus per month
///
/// Computation is typically done by Cloud Functions or a scheduled job,
/// and the results are written as these pre-aggregated documents so that
/// the client can load dashboards with a single read.
library;

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE ENTRY MODELS
// ═══════════════════════════════════════════════════════════════════════════════

/// A student's performance summary for ranking / leaderboard purposes.
class StudentPerformanceEntry {
  final String studentId;
  final String name;
  final double averageScore;
  final double attendanceRate;
  final int examsCompleted;

  const StudentPerformanceEntry({
    required this.studentId,
    required this.name,
    required this.averageScore,
    required this.attendanceRate,
    required this.examsCompleted,
  });

  factory StudentPerformanceEntry.fromMap(Map<String, dynamic> map) {
    return StudentPerformanceEntry(
      studentId: map['studentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      averageScore: (map['averageScore'] as num?)?.toDouble() ?? 0.0,
      attendanceRate: (map['attendanceRate'] as num?)?.toDouble() ?? 0.0,
      examsCompleted: map['examsCompleted'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'name': name,
      'averageScore': averageScore,
      'attendanceRate': attendanceRate,
      'examsCompleted': examsCompleted,
    };
  }
}

/// A teacher's performance summary for ranking / evaluation purposes.
class TeacherPerformanceEntry {
  final String teacherId;
  final String name;
  final int examsCreated;
  final int studentsTaught;
  final double avgStudentScore;

  const TeacherPerformanceEntry({
    required this.teacherId,
    required this.name,
    required this.examsCreated,
    required this.studentsTaught,
    required this.avgStudentScore,
  });

  factory TeacherPerformanceEntry.fromMap(Map<String, dynamic> map) {
    return TeacherPerformanceEntry(
      teacherId: map['teacherId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      examsCreated: map['examsCreated'] as int? ?? 0,
      studentsTaught: map['studentsTaught'] as int? ?? 0,
      avgStudentScore: (map['avgStudentScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'name': name,
      'examsCreated': examsCreated,
      'studentsTaught': studentsTaught,
      'avgStudentScore': avgStudentScore,
    };
  }
}

/// A class section's performance summary for ranking / comparison purposes.
class ClassPerformanceEntry {
  final String classId;
  final String name;
  final double avgScore;
  final double attendanceRate;
  final int studentCount;

  const ClassPerformanceEntry({
    required this.classId,
    required this.name,
    required this.avgScore,
    required this.attendanceRate,
    required this.studentCount,
  });

  factory ClassPerformanceEntry.fromMap(Map<String, dynamic> map) {
    return ClassPerformanceEntry(
      classId: map['classId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      avgScore: (map['avgScore'] as num?)?.toDouble() ?? 0.0,
      attendanceRate: (map['attendanceRate'] as num?)?.toDouble() ?? 0.0,
      studentCount: map['studentCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'name': name,
      'avgScore': avgScore,
      'attendanceRate': attendanceRate,
      'studentCount': studentCount,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAILY ANALYTICS — Pre-computed daily snapshot
// ═══════════════════════════════════════════════════════════════════════════════

/// Pre-computed daily analytics snapshot.
///
/// Stored in `analytics_daily/{orgId}_{YYYY-MM-DD}` collection.
/// One document per organization (or campus) per day.
class DailyAnalytics {
  /// Composite ID: `{orgId}_{YYYY-MM-DD}` or `{orgId}_{campusId}_{YYYY-MM-DD}`.
  final String id;

  /// The organization this snapshot belongs to.
  final String organizationId;

  /// The tenant this snapshot belongs to (denormalized for fast queries).
  final String tenantId;

  /// The campus this snapshot belongs to (null for org-wide).
  final String? campusId;

  /// The calendar date this snapshot covers.
  final DateTime date;

  // ─── Attendance ─────────────────────────────────────────────────────────

  /// Percentage of students present (0-100).
  final double attendanceRate;

  /// Total number of enrolled students on this date.
  final int totalStudents;

  /// Number of students marked present.
  final int presentCount;

  /// Number of students marked absent.
  final int absentCount;

  /// Number of students marked late.
  final int lateCount;

  /// Number of students marked excused.
  final int excusedCount;

  // ─── Exams ──────────────────────────────────────────────────────────────

  /// Number of new exams created on this date.
  final int examsCreated;

  /// Number of exams that ended / were completed on this date.
  final int examsCompleted;

  /// Average score across all submissions on this date (0-100).
  final double averageScore;

  /// Total number of exam submissions on this date.
  final int submissionsCount;

  /// Number of integrity violations detected on this date.
  final int violationsCount;

  // ─── Assignments ────────────────────────────────────────────────────────

  /// Number of new assignments created on this date.
  final int assignmentsCreated;

  /// Number of assignment submissions on this date.
  final int assignmentsSubmitted;

  /// Percentage of assignments submitted on time (0-100).
  final double assignmentCompletionRate;

  // ─── Engagement ─────────────────────────────────────────────────────────

  /// Number of unique students who logged in on this date.
  final int activeStudents;

  /// Number of unique teachers who logged in on this date.
  final int activeTeachers;

  /// Number of messages sent on this date.
  final int messagesSent;

  /// Number of parent logins on this date.
  final int parentLogins;

  // ─── Metadata ───────────────────────────────────────────────────────────

  /// When this snapshot was computed.
  final DateTime computedAt;

  /// Who computed this snapshot ('system' or a user ID).
  final String computedBy;

  const DailyAnalytics({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    this.campusId,
    required this.date,
    this.attendanceRate = 0.0,
    this.totalStudents = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.excusedCount = 0,
    this.examsCreated = 0,
    this.examsCompleted = 0,
    this.averageScore = 0.0,
    this.submissionsCount = 0,
    this.violationsCount = 0,
    this.assignmentsCreated = 0,
    this.assignmentsSubmitted = 0,
    this.assignmentCompletionRate = 0.0,
    this.activeStudents = 0,
    this.activeTeachers = 0,
    this.messagesSent = 0,
    this.parentLogins = 0,
    required this.computedAt,
    this.computedBy = 'system',
  });

  /// Construct from a Firestore document map.
  factory DailyAnalytics.fromMap(String id, Map<String, dynamic> map) {
    return DailyAnalytics(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      campusId: map['campusId'] as String?,
      date: map['date'] is DateTime
          ? map['date'] as DateTime
          : DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      attendanceRate: (map['attendanceRate'] as num?)?.toDouble() ?? 0.0,
      totalStudents: map['totalStudents'] as int? ?? 0,
      presentCount: map['presentCount'] as int? ?? 0,
      absentCount: map['absentCount'] as int? ?? 0,
      lateCount: map['lateCount'] as int? ?? 0,
      excusedCount: map['excusedCount'] as int? ?? 0,
      examsCreated: map['examsCreated'] as int? ?? 0,
      examsCompleted: map['examsCompleted'] as int? ?? 0,
      averageScore: (map['averageScore'] as num?)?.toDouble() ?? 0.0,
      submissionsCount: map['submissionsCount'] as int? ?? 0,
      violationsCount: map['violationsCount'] as int? ?? 0,
      assignmentsCreated: map['assignmentsCreated'] as int? ?? 0,
      assignmentsSubmitted: map['assignmentsSubmitted'] as int? ?? 0,
      assignmentCompletionRate:
          (map['assignmentCompletionRate'] as num?)?.toDouble() ?? 0.0,
      activeStudents: map['activeStudents'] as int? ?? 0,
      activeTeachers: map['activeTeachers'] as int? ?? 0,
      messagesSent: map['messagesSent'] as int? ?? 0,
      parentLogins: map['parentLogins'] as int? ?? 0,
      computedAt: map['computedAt'] is DateTime
          ? map['computedAt'] as DateTime
          : DateTime.now(),
      computedBy: map['computedBy'] as String? ?? 'system',
    );
  }

  /// Serialize to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'tenantId': tenantId,
      'campusId': campusId,
      'date': date.toIso8601String(),
      'attendanceRate': attendanceRate,
      'totalStudents': totalStudents,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'lateCount': lateCount,
      'excusedCount': excusedCount,
      'examsCreated': examsCreated,
      'examsCompleted': examsCompleted,
      'averageScore': averageScore,
      'submissionsCount': submissionsCount,
      'violationsCount': violationsCount,
      'assignmentsCreated': assignmentsCreated,
      'assignmentsSubmitted': assignmentsSubmitted,
      'assignmentCompletionRate': assignmentCompletionRate,
      'activeStudents': activeStudents,
      'activeTeachers': activeTeachers,
      'messagesSent': messagesSent,
      'parentLogins': parentLogins,
      'computedAt': computedAt,
      'computedBy': computedBy,
    };
  }

  DailyAnalytics copyWith({
    double? attendanceRate,
    int? totalStudents,
    int? presentCount,
    int? absentCount,
    int? lateCount,
    int? excusedCount,
    int? examsCreated,
    int? examsCompleted,
    double? averageScore,
    int? submissionsCount,
    int? violationsCount,
    int? assignmentsCreated,
    int? assignmentsSubmitted,
    double? assignmentCompletionRate,
    int? activeStudents,
    int? activeTeachers,
    int? messagesSent,
    int? parentLogins,
    DateTime? computedAt,
    String? computedBy,
  }) {
    return DailyAnalytics(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      date: date,
      attendanceRate: attendanceRate ?? this.attendanceRate,
      totalStudents: totalStudents ?? this.totalStudents,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      lateCount: lateCount ?? this.lateCount,
      excusedCount: excusedCount ?? this.excusedCount,
      examsCreated: examsCreated ?? this.examsCreated,
      examsCompleted: examsCompleted ?? this.examsCompleted,
      averageScore: averageScore ?? this.averageScore,
      submissionsCount: submissionsCount ?? this.submissionsCount,
      violationsCount: violationsCount ?? this.violationsCount,
      assignmentsCreated: assignmentsCreated ?? this.assignmentsCreated,
      assignmentsSubmitted: assignmentsSubmitted ?? this.assignmentsSubmitted,
      assignmentCompletionRate:
          assignmentCompletionRate ?? this.assignmentCompletionRate,
      activeStudents: activeStudents ?? this.activeStudents,
      activeTeachers: activeTeachers ?? this.activeTeachers,
      messagesSent: messagesSent ?? this.messagesSent,
      parentLogins: parentLogins ?? this.parentLogins,
      computedAt: computedAt ?? this.computedAt,
      computedBy: computedBy ?? this.computedBy,
    );
  }

  /// Generate the document ID for a given org/campus/date combination.
  static String generateId({
    required String organizationId,
    String? campusId,
    required DateTime date,
  }) {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (campusId != null) {
      return '${organizationId}_${campusId}_$dateStr';
    }
    return '${organizationId}_$dateStr';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEEKLY ANALYTICS — Aggregated from daily snapshots
// ═══════════════════════════════════════════════════════════════════════════════

/// Pre-computed weekly analytics, aggregated from [DailyAnalytics] documents.
///
/// Stored in `analytics_weekly/{orgId}_{YYYY-WNN}` collection.
class WeeklyAnalytics {
  /// Composite ID: `{orgId}_{YYYY-WNN}` or `{orgId}_{campusId}_{YYYY-WNN}`.
  final String id;

  /// The organization this snapshot belongs to.
  final String organizationId;

  /// The tenant this snapshot belongs to.
  final String tenantId;

  /// The campus this snapshot belongs to (null for org-wide).
  final String? campusId;

  /// The first day of the week (Monday).
  final DateTime weekStart;

  /// The last day of the week (Sunday).
  final DateTime weekEnd;

  // ─── Aggregated averages ────────────────────────────────────────────────

  /// Average attendance rate across the 7 days (0-100).
  final double avgAttendanceRate;

  /// Average exam score across the week (0-100).
  final double avgExamScore;

  /// Average assignment completion rate across the week (0-100).
  final double avgAssignmentCompletionRate;

  /// Total exams created during the week.
  final int totalExamsCreated;

  /// Total exam submissions during the week.
  final int totalSubmissions;

  /// Total integrity violations during the week.
  final int totalViolations;

  /// Total messages sent during the week.
  final int totalMessages;

  /// Number of unique students who were active at least once during the week.
  final int uniqueActiveStudents;

  /// Number of unique teachers who were active at least once during the week.
  final int uniqueActiveTeachers;

  // ─── Week-over-week trends ──────────────────────────────────────────────

  /// Percentage change in attendance rate vs the previous week (can be negative).
  final double? attendanceTrend;

  /// Percentage change in average exam score vs the previous week.
  final double? scoreTrend;

  /// Percentage change in engagement (active users) vs the previous week.
  final double? engagementTrend;

  // ─── Metadata ───────────────────────────────────────────────────────────

  /// When this snapshot was computed.
  final DateTime computedAt;

  const WeeklyAnalytics({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    this.campusId,
    required this.weekStart,
    required this.weekEnd,
    this.avgAttendanceRate = 0.0,
    this.avgExamScore = 0.0,
    this.avgAssignmentCompletionRate = 0.0,
    this.totalExamsCreated = 0,
    this.totalSubmissions = 0,
    this.totalViolations = 0,
    this.totalMessages = 0,
    this.uniqueActiveStudents = 0,
    this.uniqueActiveTeachers = 0,
    this.attendanceTrend,
    this.scoreTrend,
    this.engagementTrend,
    required this.computedAt,
  });

  /// Construct from a Firestore document map.
  factory WeeklyAnalytics.fromMap(String id, Map<String, dynamic> map) {
    return WeeklyAnalytics(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      campusId: map['campusId'] as String?,
      weekStart: map['weekStart'] is DateTime
          ? map['weekStart'] as DateTime
          : DateTime.tryParse(map['weekStart'] as String? ?? '') ??
              DateTime.now(),
      weekEnd: map['weekEnd'] is DateTime
          ? map['weekEnd'] as DateTime
          : DateTime.tryParse(map['weekEnd'] as String? ?? '') ??
              DateTime.now(),
      avgAttendanceRate: (map['avgAttendanceRate'] as num?)?.toDouble() ?? 0.0,
      avgExamScore: (map['avgExamScore'] as num?)?.toDouble() ?? 0.0,
      avgAssignmentCompletionRate:
          (map['avgAssignmentCompletionRate'] as num?)?.toDouble() ?? 0.0,
      totalExamsCreated: map['totalExamsCreated'] as int? ?? 0,
      totalSubmissions: map['totalSubmissions'] as int? ?? 0,
      totalViolations: map['totalViolations'] as int? ?? 0,
      totalMessages: map['totalMessages'] as int? ?? 0,
      uniqueActiveStudents: map['uniqueActiveStudents'] as int? ?? 0,
      uniqueActiveTeachers: map['uniqueActiveTeachers'] as int? ?? 0,
      attendanceTrend: (map['attendanceTrend'] as num?)?.toDouble(),
      scoreTrend: (map['scoreTrend'] as num?)?.toDouble(),
      engagementTrend: (map['engagementTrend'] as num?)?.toDouble(),
      computedAt: map['computedAt'] is DateTime
          ? map['computedAt'] as DateTime
          : DateTime.now(),
    );
  }

  /// Serialize to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'tenantId': tenantId,
      'campusId': campusId,
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'avgAttendanceRate': avgAttendanceRate,
      'avgExamScore': avgExamScore,
      'avgAssignmentCompletionRate': avgAssignmentCompletionRate,
      'totalExamsCreated': totalExamsCreated,
      'totalSubmissions': totalSubmissions,
      'totalViolations': totalViolations,
      'totalMessages': totalMessages,
      'uniqueActiveStudents': uniqueActiveStudents,
      'uniqueActiveTeachers': uniqueActiveTeachers,
      'attendanceTrend': attendanceTrend,
      'scoreTrend': scoreTrend,
      'engagementTrend': engagementTrend,
      'computedAt': computedAt,
    };
  }

  WeeklyAnalytics copyWith({
    double? avgAttendanceRate,
    double? avgExamScore,
    double? avgAssignmentCompletionRate,
    int? totalExamsCreated,
    int? totalSubmissions,
    int? totalViolations,
    int? totalMessages,
    int? uniqueActiveStudents,
    int? uniqueActiveTeachers,
    double? attendanceTrend,
    double? scoreTrend,
    double? engagementTrend,
    DateTime? computedAt,
  }) {
    return WeeklyAnalytics(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      weekStart: weekStart,
      weekEnd: weekEnd,
      avgAttendanceRate: avgAttendanceRate ?? this.avgAttendanceRate,
      avgExamScore: avgExamScore ?? this.avgExamScore,
      avgAssignmentCompletionRate:
          avgAssignmentCompletionRate ?? this.avgAssignmentCompletionRate,
      totalExamsCreated: totalExamsCreated ?? this.totalExamsCreated,
      totalSubmissions: totalSubmissions ?? this.totalSubmissions,
      totalViolations: totalViolations ?? this.totalViolations,
      totalMessages: totalMessages ?? this.totalMessages,
      uniqueActiveStudents: uniqueActiveStudents ?? this.uniqueActiveStudents,
      uniqueActiveTeachers: uniqueActiveTeachers ?? this.uniqueActiveTeachers,
      attendanceTrend: attendanceTrend ?? this.attendanceTrend,
      scoreTrend: scoreTrend ?? this.scoreTrend,
      engagementTrend: engagementTrend ?? this.engagementTrend,
      computedAt: computedAt ?? this.computedAt,
    );
  }

  /// Generate the document ID for a given org/campus/week combination.
  static String generateId({
    required String organizationId,
    String? campusId,
    required DateTime weekStart,
  }) {
    // Calculate ISO week number
    final weekNumber = _weekNumber(weekStart);
    final weekStr =
        '${weekStart.year.toString().padLeft(4, '0')}-W${weekNumber.toString().padLeft(2, '0')}';
    if (campusId != null) {
      return '${organizationId}_${campusId}_$weekStr';
    }
    return '${organizationId}_$weekStr';
  }

  /// Calculate ISO 8601 week number from a date.
  static int _weekNumber(DateTime date) {
    // Add 10 days to ensure we're in the "right" year for week calculation
    final d = DateTime(date.year, date.month, date.day + 10 - date.weekday);
    // The first Thursday of the year is in week 1
    final firstThursday = DateTime(d.year, 1, 1);
    while (firstThursday.weekday != DateTime.thursday) {
      firstThursday.add(const Duration(days: 1));
    }
    return ((d.difference(firstThursday).inDays) / 7).floor() + 1;
  }

  /// Aggregate a list of [DailyAnalytics] into a [WeeklyAnalytics].
  ///
  /// This is the core aggregation logic used by the compute engine.
  static WeeklyAnalytics aggregateFromDaily({
    required String organizationId,
    required String tenantId,
    String? campusId,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DailyAnalytics> dailySnapshots,
    double? previousWeekAttendance,
    double? previousWeekScore,
    int? previousWeekActiveUsers,
  }) {
    if (dailySnapshots.isEmpty) {
      final id = generateId(
        organizationId: organizationId,
        campusId: campusId,
        weekStart: weekStart,
      );
      return WeeklyAnalytics(
        id: id,
        organizationId: organizationId,
        tenantId: tenantId,
        campusId: campusId,
        weekStart: weekStart,
        weekEnd: weekEnd,
        computedAt: DateTime.now(),
      );
    }

    final avgAttendance = dailySnapshots
            .map((d) => d.attendanceRate)
            .reduce((a, b) => a + b) /
        dailySnapshots.length;

    final avgScore = dailySnapshots
            .map((d) => d.averageScore)
            .reduce((a, b) => a + b) /
        dailySnapshots.length;

    final avgCompletion = dailySnapshots
            .map((d) => d.assignmentCompletionRate)
            .reduce((a, b) => a + b) /
        dailySnapshots.length;

    final totalExams = dailySnapshots
        .map((d) => d.examsCreated)
        .reduce((a, b) => a + b);

    final totalSubs = dailySnapshots
        .map((d) => d.submissionsCount)
        .reduce((a, b) => a + b);

    final totalViols = dailySnapshots
        .map((d) => d.violationsCount)
        .reduce((a, b) => a + b);

    final totalMsgs = dailySnapshots
        .map((d) => d.messagesSent)
        .reduce((a, b) => a + b);

    // For unique active users, take the max across days (conservative estimate)
    final uniqueStudents = dailySnapshots
        .map((d) => d.activeStudents)
        .reduce((a, b) => a > b ? a : b);

    final uniqueTeachers = dailySnapshots
        .map((d) => d.activeTeachers)
        .reduce((a, b) => a > b ? a : b);

    // Calculate trends
    double? attTrend;
    if (previousWeekAttendance != null && previousWeekAttendance != 0) {
      attTrend = ((avgAttendance - previousWeekAttendance) /
              previousWeekAttendance *
              100);
    }

    double? sTrend;
    if (previousWeekScore != null && previousWeekScore != 0) {
      sTrend =
          ((avgScore - previousWeekScore) / previousWeekScore * 100);
    }

    double? engTrend;
    if (previousWeekActiveUsers != null && previousWeekActiveUsers != 0) {
      final currentEngagement = uniqueStudents + uniqueTeachers;
      engTrend = ((currentEngagement - previousWeekActiveUsers) /
              previousWeekActiveUsers *
              100);
    }

    final id = generateId(
      organizationId: organizationId,
      campusId: campusId,
      weekStart: weekStart,
    );

    return WeeklyAnalytics(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      weekStart: weekStart,
      weekEnd: weekEnd,
      avgAttendanceRate: double.parse(avgAttendance.toStringAsFixed(2)),
      avgExamScore: double.parse(avgScore.toStringAsFixed(2)),
      avgAssignmentCompletionRate:
          double.parse(avgCompletion.toStringAsFixed(2)),
      totalExamsCreated: totalExams,
      totalSubmissions: totalSubs,
      totalViolations: totalViols,
      totalMessages: totalMsgs,
      uniqueActiveStudents: uniqueStudents,
      uniqueActiveTeachers: uniqueTeachers,
      attendanceTrend: attTrend != null
          ? double.parse(attTrend.toStringAsFixed(2))
          : null,
      scoreTrend:
          sTrend != null ? double.parse(sTrend.toStringAsFixed(2)) : null,
      engagementTrend:
          engTrend != null ? double.parse(engTrend.toStringAsFixed(2)) : null,
      computedAt: DateTime.now(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MONTHLY ANALYTICS — Aggregated from weekly snapshots
// ═══════════════════════════════════════════════════════════════════════════════

/// Pre-computed monthly analytics, aggregated from [WeeklyAnalytics] documents.
///
/// Stored in `analytics_monthly/{orgId}_{YYYY-MM}` collection.
class MonthlyAnalytics {
  /// Composite ID: `{orgId}_{YYYY-MM}` or `{orgId}_{campusId}_{YYYY-MM}`.
  final String id;

  /// The organization this snapshot belongs to.
  final String organizationId;

  /// The tenant this snapshot belongs to.
  final String tenantId;

  /// The campus this snapshot belongs to (null for org-wide).
  final String? campusId;

  /// The year (e.g., 2025).
  final int year;

  /// The month (1-12).
  final int month;

  // ─── Aggregated averages ────────────────────────────────────────────────

  /// Average attendance rate across the month (0-100).
  final double avgAttendanceRate;

  /// Average exam score across the month (0-100).
  final double avgExamScore;

  /// Average assignment completion rate across the month (0-100).
  final double avgAssignmentCompletionRate;

  /// Total exams created during the month.
  final int totalExamsCreated;

  /// Total exam submissions during the month.
  final int totalSubmissions;

  /// Total integrity violations during the month.
  final int totalViolations;

  /// Number of unique students who were active during the month.
  final int uniqueActiveStudents;

  /// Number of unique teachers who were active during the month.
  final int uniqueActiveTeachers;

  // ─── Month-over-month trends ────────────────────────────────────────────

  /// Percentage change in attendance rate vs the previous month.
  final double? attendanceTrend;

  /// Percentage change in average exam score vs the previous month.
  final double? scoreTrend;

  /// Percentage change in engagement vs the previous month.
  final double? engagementTrend;

  // ─── Top performers ─────────────────────────────────────────────────────

  /// Top-performing students for the month.
  final List<StudentPerformanceEntry> topStudents;

  /// Top-performing teachers for the month.
  final List<TeacherPerformanceEntry> topTeachers;

  /// Top-performing classes for the month.
  final List<ClassPerformanceEntry> topClasses;

  // ─── Metadata ───────────────────────────────────────────────────────────

  /// When this snapshot was computed.
  final DateTime computedAt;

  const MonthlyAnalytics({
    required this.id,
    required this.organizationId,
    required this.tenantId,
    this.campusId,
    required this.year,
    required this.month,
    this.avgAttendanceRate = 0.0,
    this.avgExamScore = 0.0,
    this.avgAssignmentCompletionRate = 0.0,
    this.totalExamsCreated = 0,
    this.totalSubmissions = 0,
    this.totalViolations = 0,
    this.uniqueActiveStudents = 0,
    this.uniqueActiveTeachers = 0,
    this.attendanceTrend,
    this.scoreTrend,
    this.engagementTrend,
    this.topStudents = const [],
    this.topTeachers = const [],
    this.topClasses = const [],
    required this.computedAt,
  });

  /// Construct from a Firestore document map.
  factory MonthlyAnalytics.fromMap(String id, Map<String, dynamic> map) {
    return MonthlyAnalytics(
      id: id,
      organizationId: map['organizationId'] as String? ?? '',
      tenantId: map['tenantId'] as String? ?? '',
      campusId: map['campusId'] as String?,
      year: map['year'] as int? ?? DateTime.now().year,
      month: map['month'] as int? ?? DateTime.now().month,
      avgAttendanceRate: (map['avgAttendanceRate'] as num?)?.toDouble() ?? 0.0,
      avgExamScore: (map['avgExamScore'] as num?)?.toDouble() ?? 0.0,
      avgAssignmentCompletionRate:
          (map['avgAssignmentCompletionRate'] as num?)?.toDouble() ?? 0.0,
      totalExamsCreated: map['totalExamsCreated'] as int? ?? 0,
      totalSubmissions: map['totalSubmissions'] as int? ?? 0,
      totalViolations: map['totalViolations'] as int? ?? 0,
      uniqueActiveStudents: map['uniqueActiveStudents'] as int? ?? 0,
      uniqueActiveTeachers: map['uniqueActiveTeachers'] as int? ?? 0,
      attendanceTrend: (map['attendanceTrend'] as num?)?.toDouble(),
      scoreTrend: (map['scoreTrend'] as num?)?.toDouble(),
      engagementTrend: (map['engagementTrend'] as num?)?.toDouble(),
      topStudents: (map['topStudents'] as List?)
              ?.map((e) => StudentPerformanceEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      topTeachers: (map['topTeachers'] as List?)
              ?.map((e) => TeacherPerformanceEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      topClasses: (map['topClasses'] as List?)
              ?.map((e) => ClassPerformanceEntry.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      computedAt: map['computedAt'] is DateTime
          ? map['computedAt'] as DateTime
          : DateTime.now(),
    );
  }

  /// Serialize to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'organizationId': organizationId,
      'tenantId': tenantId,
      'campusId': campusId,
      'year': year,
      'month': month,
      'avgAttendanceRate': avgAttendanceRate,
      'avgExamScore': avgExamScore,
      'avgAssignmentCompletionRate': avgAssignmentCompletionRate,
      'totalExamsCreated': totalExamsCreated,
      'totalSubmissions': totalSubmissions,
      'totalViolations': totalViolations,
      'uniqueActiveStudents': uniqueActiveStudents,
      'uniqueActiveTeachers': uniqueActiveTeachers,
      'attendanceTrend': attendanceTrend,
      'scoreTrend': scoreTrend,
      'engagementTrend': engagementTrend,
      'topStudents': topStudents.map((e) => e.toMap()).toList(),
      'topTeachers': topTeachers.map((e) => e.toMap()).toList(),
      'topClasses': topClasses.map((e) => e.toMap()).toList(),
      'computedAt': computedAt,
    };
  }

  MonthlyAnalytics copyWith({
    double? avgAttendanceRate,
    double? avgExamScore,
    double? avgAssignmentCompletionRate,
    int? totalExamsCreated,
    int? totalSubmissions,
    int? totalViolations,
    int? uniqueActiveStudents,
    int? uniqueActiveTeachers,
    double? attendanceTrend,
    double? scoreTrend,
    double? engagementTrend,
    List<StudentPerformanceEntry>? topStudents,
    List<TeacherPerformanceEntry>? topTeachers,
    List<ClassPerformanceEntry>? topClasses,
    DateTime? computedAt,
  }) {
    return MonthlyAnalytics(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      year: year,
      month: month,
      avgAttendanceRate: avgAttendanceRate ?? this.avgAttendanceRate,
      avgExamScore: avgExamScore ?? this.avgExamScore,
      avgAssignmentCompletionRate:
          avgAssignmentCompletionRate ?? this.avgAssignmentCompletionRate,
      totalExamsCreated: totalExamsCreated ?? this.totalExamsCreated,
      totalSubmissions: totalSubmissions ?? this.totalSubmissions,
      totalViolations: totalViolations ?? this.totalViolations,
      uniqueActiveStudents: uniqueActiveStudents ?? this.uniqueActiveStudents,
      uniqueActiveTeachers: uniqueActiveTeachers ?? this.uniqueActiveTeachers,
      attendanceTrend: attendanceTrend ?? this.attendanceTrend,
      scoreTrend: scoreTrend ?? this.scoreTrend,
      engagementTrend: engagementTrend ?? this.engagementTrend,
      topStudents: topStudents ?? this.topStudents,
      topTeachers: topTeachers ?? this.topTeachers,
      topClasses: topClasses ?? this.topClasses,
      computedAt: computedAt ?? this.computedAt,
    );
  }

  /// Generate the document ID for a given org/campus/month combination.
  static String generateId({
    required String organizationId,
    String? campusId,
    required int year,
    required int month,
  }) {
    final monthStr =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    if (campusId != null) {
      return '${organizationId}_${campusId}_$monthStr';
    }
    return '${organizationId}_$monthStr';
  }

  /// Aggregate a list of [WeeklyAnalytics] into a [MonthlyAnalytics].
  ///
  /// This is the core aggregation logic used by the compute engine.
  static MonthlyAnalytics aggregateFromWeekly({
    required String organizationId,
    required String tenantId,
    String? campusId,
    required int year,
    required int month,
    required List<WeeklyAnalytics> weeklySnapshots,
    double? previousMonthAttendance,
    double? previousMonthScore,
    int? previousMonthActiveUsers,
    List<StudentPerformanceEntry> topStudents = const [],
    List<TeacherPerformanceEntry> topTeachers = const [],
    List<ClassPerformanceEntry> topClasses = const [],
  }) {
    final id = generateId(
      organizationId: organizationId,
      campusId: campusId,
      year: year,
      month: month,
    );

    if (weeklySnapshots.isEmpty) {
      return MonthlyAnalytics(
        id: id,
        organizationId: organizationId,
        tenantId: tenantId,
        campusId: campusId,
        year: year,
        month: month,
        topStudents: topStudents,
        topTeachers: topTeachers,
        topClasses: topClasses,
        computedAt: DateTime.now(),
      );
    }

    final avgAttendance = weeklySnapshots
            .map((w) => w.avgAttendanceRate)
            .reduce((a, b) => a + b) /
        weeklySnapshots.length;

    final avgScore = weeklySnapshots
            .map((w) => w.avgExamScore)
            .reduce((a, b) => a + b) /
        weeklySnapshots.length;

    final avgCompletion = weeklySnapshots
            .map((w) => w.avgAssignmentCompletionRate)
            .reduce((a, b) => a + b) /
        weeklySnapshots.length;

    final totalExams = weeklySnapshots
        .map((w) => w.totalExamsCreated)
        .reduce((a, b) => a + b);

    final totalSubs = weeklySnapshots
        .map((w) => w.totalSubmissions)
        .reduce((a, b) => a + b);

    final totalViols = weeklySnapshots
        .map((w) => w.totalViolations)
        .reduce((a, b) => a + b);

    final uniqueStudents = weeklySnapshots
        .map((w) => w.uniqueActiveStudents)
        .reduce((a, b) => a > b ? a : b);

    final uniqueTeachers = weeklySnapshots
        .map((w) => w.uniqueActiveTeachers)
        .reduce((a, b) => a > b ? a : b);

    // Calculate trends
    double? attTrend;
    if (previousMonthAttendance != null && previousMonthAttendance != 0) {
      attTrend = ((avgAttendance - previousMonthAttendance) /
              previousMonthAttendance *
              100);
    }

    double? sTrend;
    if (previousMonthScore != null && previousMonthScore != 0) {
      sTrend =
          ((avgScore - previousMonthScore) / previousMonthScore * 100);
    }

    double? engTrend;
    if (previousMonthActiveUsers != null && previousMonthActiveUsers != 0) {
      final currentEngagement = uniqueStudents + uniqueTeachers;
      engTrend = ((currentEngagement - previousMonthActiveUsers) /
              previousMonthActiveUsers *
              100);
    }

    return MonthlyAnalytics(
      id: id,
      organizationId: organizationId,
      tenantId: tenantId,
      campusId: campusId,
      year: year,
      month: month,
      avgAttendanceRate: double.parse(avgAttendance.toStringAsFixed(2)),
      avgExamScore: double.parse(avgScore.toStringAsFixed(2)),
      avgAssignmentCompletionRate:
          double.parse(avgCompletion.toStringAsFixed(2)),
      totalExamsCreated: totalExams,
      totalSubmissions: totalSubs,
      totalViolations: totalViols,
      uniqueActiveStudents: uniqueStudents,
      uniqueActiveTeachers: uniqueTeachers,
      attendanceTrend: attTrend != null
          ? double.parse(attTrend.toStringAsFixed(2))
          : null,
      scoreTrend:
          sTrend != null ? double.parse(sTrend.toStringAsFixed(2)) : null,
      engagementTrend:
          engTrend != null ? double.parse(engTrend.toStringAsFixed(2)) : null,
      topStudents: topStudents,
      topTeachers: topTeachers,
      topClasses: topClasses,
      computedAt: DateTime.now(),
    );
  }
}
