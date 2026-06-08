import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_constants.dart';
import '../core/services/analytics_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService());

// ─── Student Analytics ──────────────────────────────────────────────────────

final studentAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) {
    return {
      'averageScore': 0.0,
      'highestScore': 0.0,
      'lowestScore': 0.0,
      'examCount': 0,
      'examTrend': <Map<String, dynamic>>[],
      'attendanceRate': 0.0,
      'attendanceTotal': 0,
      'absentCount': 0,
      'lateCount': 0,
      'assignmentCompletionRate': 0.0,
      'totalAssignments': 0,
      'completedAssignments': 0,
    };
  }

  return ref.read(analyticsServiceProvider).getStudentAnalyticsCached(
        organizationId: orgId,
        studentId: studentId,
      );
});

// ─── Student Analytics with Class Filter ─────────────────────────────────────

final studentClassAnalyticsProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, StudentClassParams>((ref, params) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) {
    return {
      'averageScore': 0.0,
      'highestScore': 0.0,
      'lowestScore': 0.0,
      'examCount': 0,
      'examTrend': <Map<String, dynamic>>[],
      'attendanceRate': 0.0,
      'attendanceTotal': 0,
      'absentCount': 0,
      'lateCount': 0,
      'assignmentCompletionRate': 0.0,
      'totalAssignments': 0,
      'completedAssignments': 0,
    };
  }

  return ref.read(analyticsServiceProvider).getStudentAnalyticsCached(
        organizationId: orgId,
        studentId: params.studentId,
        classId: params.classId,
      );
});

// ─── Class Analytics ────────────────────────────────────────────────────────

final classAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) {
    return {
      'studentCount': 0,
      'classAverage': 0.0,
      'highestScore': 0.0,
      'lowestScore': 0.0,
      'passRate': 0.0,
      'attendanceRate': 0.0,
      'examCount': 0,
      'totalSubmissions': 0,
    };
  }

  return ref.read(analyticsServiceProvider).getClassAnalyticsCached(
        organizationId: orgId,
        classId: classId,
      );
});

// ─── Teacher Analytics ──────────────────────────────────────────────────────

final teacherAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, teacherId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) {
    return {
      'examsCreated': 0,
      'assignmentsCreated': 0,
      'studentsManaged': 0,
      'classesAssigned': 0,
      'questionBanksCreated': 0,
      'teacherAssignmentsCount': 0,
    };
  }

  return ref.read(analyticsServiceProvider).getTeacherAnalyticsCached(
        organizationId: orgId,
        teacherId: teacherId,
      );
});

// ─── Current User Analytics (role-based) ────────────────────────────────────

final currentUserAnalyticsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  final role = ref.watch(userRoleProvider);

  if (orgId == null || userId == null) {
    return {};
  }

  switch (role) {
    case AppConstants.roleStudent:
      return ref.read(analyticsServiceProvider).getStudentAnalyticsCached(
            organizationId: orgId,
            studentId: userId,
          );
    case AppConstants.roleTeacher:
      return ref.read(analyticsServiceProvider).getTeacherAnalyticsCached(
            organizationId: orgId,
            teacherId: userId,
          );
    case AppConstants.roleOwner:
      // Owner sees organization-wide stats
      return ref.read(analyticsServiceProvider).getTeacherAnalyticsCached(
            organizationId: orgId,
            teacherId: userId,
          );
    default:
      return {};
  }
});

// ─── Parameter Classes ──────────────────────────────────────────────────────

class StudentClassParams {
  final String studentId;
  final String? classId;

  const StudentClassParams({
    required this.studentId,
    this.classId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentClassParams &&
          runtimeType == other.runtimeType &&
          studentId == other.studentId &&
          classId == other.classId;

  @override
  int get hashCode => studentId.hashCode ^ classId.hashCode;
}
