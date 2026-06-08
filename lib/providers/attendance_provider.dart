import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/attendance_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final attendanceServiceProvider =
    Provider<AttendanceService>((ref) => AttendanceService());

// ─── Selected Date Provider ──────────────────────────────────────────────────

final selectedAttendanceDateProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
});

// ─── Selected Class/Group/Subject for Attendance ────────────────────────────

final attendanceClassIdProvider = StateProvider<String?>((ref) => null);
final attendanceGroupIdProvider = StateProvider<String?>((ref) => null);
final attendanceSubjectIdProvider = StateProvider<String?>((ref) => null);

// ─── Class Attendance Stream ────────────────────────────────────────────────

final classAttendanceProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final classId = ref.watch(attendanceClassIdProvider);
  final date = ref.watch(selectedAttendanceDateProvider);
  final subjectId = ref.watch(attendanceSubjectIdProvider);

  if (orgId == null || classId == null) return const Stream.empty();

  return ref.read(attendanceServiceProvider).getClassAttendanceByDateStream(
        organizationId: orgId,
        classId: classId,
        date: date,
        subjectId: subjectId,
      );
});

// ─── Group Attendance Stream ────────────────────────────────────────────────

final groupAttendanceProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final groupId = ref.watch(attendanceGroupIdProvider);
  final date = ref.watch(selectedAttendanceDateProvider);

  if (orgId == null || groupId == null) return const Stream.empty();

  return ref.read(attendanceServiceProvider).getGroupAttendanceByDateStream(
        organizationId: orgId,
        groupId: groupId,
        date: date,
      );
});

// ─── Student Attendance Stream ──────────────────────────────────────────────

final studentAttendanceProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  final role = ref.watch(userRoleProvider);

  if (orgId == null || userId == null || role != AppConstants.roleStudent) {
    return const Stream.empty();
  }

  return ref.read(attendanceServiceProvider).getStudentAttendanceStream(
        organizationId: orgId,
        studentId: userId,
      );
});

// ─── Student Attendance Stats ───────────────────────────────────────────────

final studentAttendanceStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final userId = ref.watch(currentUserIdProvider);
  final role = ref.watch(userRoleProvider);

  if (orgId == null || userId == null || role != AppConstants.roleStudent) {
    return {
      'total': 0,
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
      'attendanceRate': 0.0,
    };
  }

  return ref.read(attendanceServiceProvider).getStudentAttendanceStats(
        organizationId: orgId,
        studentId: userId,
      );
});

// ─── Class Attendance Stats ─────────────────────────────────────────────────

final classAttendanceStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) {
    return {
      'total': 0,
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
      'attendanceRate': 0.0,
    };
  }

  return ref.read(attendanceServiceProvider).getClassAttendanceStats(
        organizationId: orgId,
        classId: classId,
      );
});

// ─── Attendance Data Model ──────────────────────────────────────────────────

class AttendanceData {
  final String id;
  final String organizationId;
  final String classId;
  final String studentId;
  final String? subjectId;
  final String? groupId;
  final String date;
  final String status;
  final String? markedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AttendanceData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.studentId,
    this.subjectId,
    this.groupId,
    required this.date,
    required this.status,
    this.markedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      studentId: data['studentId'] ?? '',
      subjectId: data['subjectId'],
      groupId: data['groupId'],
      date: data['date'] ?? '',
      status: data['status'] ?? AppConstants.attendanceStatusPresent,
      markedBy: data['markedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory AttendanceData.fromMap(Map<String, dynamic> map) {
    return AttendanceData(
      id: map['id'] ?? '',
      organizationId: map['organizationId'] ?? '',
      classId: map['classId'] ?? '',
      studentId: map['studentId'] ?? '',
      subjectId: map['subjectId'],
      groupId: map['groupId'],
      date: map['date'] ?? '',
      status: map['status'] ?? AppConstants.attendanceStatusPresent,
      markedBy: map['markedBy'],
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'classId': classId,
      'studentId': studentId,
      'subjectId': subjectId,
      'groupId': groupId,
      'date': date,
      'status': status,
      'markedBy': markedBy,
    };
  }
}
