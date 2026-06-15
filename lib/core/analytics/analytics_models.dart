/// Klasivo v2.0 - Analytics data models
/// 
/// Structured models for precomputed analytics data
/// at daily, weekly, and monthly granularity levels.
library;

/// Daily analytics snapshot.
class DailyAnalytics {
  final DateTime date;
  final String organizationId;
  final String? campusId;
  final int totalExams;
  final int totalSubmissions;
  final int totalAttendanceRecords;
  final double averageScore;
  final int activeUsers;
  final Map<String, dynamic> breakdown;

  const DailyAnalytics({
    required this.date,
    required this.organizationId,
    this.campusId,
    this.totalExams = 0,
    this.totalSubmissions = 0,
    this.totalAttendanceRecords = 0,
    this.averageScore = 0,
    this.activeUsers = 0,
    this.breakdown = const {},
  });
}

/// Weekly analytics snapshot with trend data.
class WeeklyAnalytics {
  final DateTime weekStart;
  final String organizationId;
  final String? campusId;
  final int totalExams;
  final int totalSubmissions;
  final double averageScore;
  final double scoreTrend;
  final int activeUsers;
  final List<DailyAnalytics> dailyBreakdown;

  const WeeklyAnalytics({
    required this.weekStart,
    required this.organizationId,
    this.campusId,
    this.totalExams = 0,
    this.totalSubmissions = 0,
    this.averageScore = 0,
    this.scoreTrend = 0,
    this.activeUsers = 0,
    this.dailyBreakdown = const [],
  });
}

/// Monthly analytics snapshot with comparison data.
class MonthlyAnalytics {
  final DateTime month;
  final String organizationId;
  final String? campusId;
  final int totalExams;
  final int totalSubmissions;
  final double averageScore;
  final double scoreTrend;
  final int activeUsers;
  final int totalAssignments;
  final double assignmentCompletionRate;
  final double attendanceRate;
  final List<WeeklyAnalytics> weeklyBreakdown;

  const MonthlyAnalytics({
    required this.month,
    required this.organizationId,
    this.campusId,
    this.totalExams = 0,
    this.totalSubmissions = 0,
    this.averageScore = 0,
    this.scoreTrend = 0,
    this.activeUsers = 0,
    this.totalAssignments = 0,
    this.assignmentCompletionRate = 0,
    this.attendanceRate = 0,
    this.weeklyBreakdown = const [],
  });
}
