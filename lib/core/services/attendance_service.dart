import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Mark Attendance ─────────────────────────────────────────────────────

  /// Mark attendance for a single student on a specific date.
  /// If a record already exists for this student+date+class+subject, it will be updated.
  Future<String> markAttendance({
    required String organizationId,
    required String classId,
    required String studentId,
    required String date, // Format: 'yyyy-MM-dd'
    required String status,
    String? subjectId,
    String? groupId,
    String? markedBy,
  }) async {
    try {
      // Check if an attendance record already exists for this student+date+class+subject
      QuerySnapshot existing;
      if (subjectId != null) {
        existing = await _firestore
            .collection(AppConstants.attendanceCollection)
            .where('organizationId', isEqualTo: organizationId)
            .where('classId', isEqualTo: classId)
            .where('studentId', isEqualTo: studentId)
            .where('date', isEqualTo: date)
            .where('subjectId', isEqualTo: subjectId)
            .limit(1)
            .get();
      } else {
        existing = await _firestore
            .collection(AppConstants.attendanceCollection)
            .where('organizationId', isEqualTo: organizationId)
            .where('classId', isEqualTo: classId)
            .where('studentId', isEqualTo: studentId)
            .where('date', isEqualTo: date)
            .where('subjectId', isNull: true)
            .limit(1)
            .get();
      }

      if (existing.docs.isNotEmpty) {
        // Update existing record
        await existing.docs.first.reference.update({
          'status': status,
          'groupId': groupId,
          'markedBy': markedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return existing.docs.first.id;
      }

      // Create new record
      final docRef = await _firestore
          .collection(AppConstants.attendanceCollection)
          .add({
        'organizationId': organizationId,
        'classId': classId,
        'studentId': studentId,
        'subjectId': subjectId,
        'groupId': groupId,
        'date': date,
        'status': status,
        'markedBy': markedBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Mark attendance for multiple students in a batch (class or group attendance).
  /// This is the primary method for taking attendance in a classroom.
  Future<void> markBatchAttendance({
    required String organizationId,
    required String classId,
    required String date,
    required Map<String, String> studentStatuses, // {studentId: status}
    String? subjectId,
    String? groupId,
    String? markedBy,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final entry in studentStatuses.entries) {
        final studentId = entry.key;
        final status = entry.value;

        // Check for existing record
        QuerySnapshot existing;
        if (subjectId != null) {
          existing = await _firestore
              .collection(AppConstants.attendanceCollection)
              .where('organizationId', isEqualTo: organizationId)
              .where('classId', isEqualTo: classId)
              .where('studentId', isEqualTo: studentId)
              .where('date', isEqualTo: date)
              .where('subjectId', isEqualTo: subjectId)
              .limit(1)
              .get();
        } else {
          existing = await _firestore
              .collection(AppConstants.attendanceCollection)
              .where('organizationId', isEqualTo: organizationId)
              .where('classId', isEqualTo: classId)
              .where('studentId', isEqualTo: studentId)
              .where('date', isEqualTo: date)
              .where('subjectId', isNull: true)
              .limit(1)
              .get();
        }

        if (existing.docs.isNotEmpty) {
          // Update existing
          batch.update(existing.docs.first.reference, {
            'status': status,
            'groupId': groupId,
            'markedBy': markedBy,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new
          final docRef =
              _firestore.collection(AppConstants.attendanceCollection).doc();
          batch.set(docRef, {
            'organizationId': organizationId,
            'classId': classId,
            'studentId': studentId,
            'subjectId': subjectId,
            'groupId': groupId,
            'date': date,
            'status': status,
            'markedBy': markedBy,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update Single Record ────────────────────────────────────────────────

  Future<void> updateAttendanceStatus({
    required String attendanceId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.attendanceCollection)
          .doc(attendanceId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Delete Attendance Record ────────────────────────────────────────────

  Future<void> deleteAttendance(String attendanceId) async {
    try {
      await _firestore
          .collection(AppConstants.attendanceCollection)
          .doc(attendanceId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get Attendance Streams ──────────────────────────────────────────────

  /// Stream attendance records for a class on a specific date.
  Stream<QuerySnapshot> getClassAttendanceByDateStream({
    required String organizationId,
    required String classId,
    required String date,
    String? subjectId,
  }) {
    Query query = _firestore
        .collection(AppConstants.attendanceCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .where('date', isEqualTo: date);

    if (subjectId != null) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }

    return query.snapshots();
  }

  /// Stream attendance records for a group on a specific date.
  Stream<QuerySnapshot> getGroupAttendanceByDateStream({
    required String organizationId,
    required String groupId,
    required String date,
  }) {
    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('groupId', isEqualTo: groupId)
        .where('date', isEqualTo: date)
        .snapshots();
  }

  /// Stream attendance records for a specific student (all dates).
  Stream<QuerySnapshot> getStudentAttendanceStream({
    required String organizationId,
    required String studentId,
  }) {
    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Stream attendance records for a student within a date range.
  Stream<QuerySnapshot> getStudentAttendanceByDateRangeStream({
    required String organizationId,
    required String studentId,
    required String startDate,
    required String endDate,
  }) {
    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('studentId', isEqualTo: studentId)
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .orderBy('date', descending: true)
        .snapshots();
  }

  /// Stream all attendance records for a class (for subject attendance view).
  Stream<QuerySnapshot> getSubjectAttendanceStream({
    required String organizationId,
    required String classId,
    required String subjectId,
  }) {
    return _firestore
        .collection(AppConstants.attendanceCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // ─── Attendance Statistics ───────────────────────────────────────────────

  /// Calculate attendance statistics for a student.
  Future<Map<String, dynamic>> getStudentAttendanceStats({
    required String organizationId,
    required String studentId,
    String? classId,
    String? subjectId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.attendanceCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('studentId', isEqualTo: studentId);

      if (classId != null) {
        query = query.where('classId', isEqualTo: classId);
      }
      if (subjectId != null) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }

      final snapshot = await query.get();

      int total = snapshot.docs.length;
      int present = 0;
      int absent = 0;
      int late = 0;
      int excused = 0;

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? '';
        switch (status) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'late':
            late++;
            break;
          case 'excused':
            excused++;
            break;
        }
      }

      final attendanceRate = total > 0 ? (present + late + excused) / total * 100 : 0.0;

      return {
        'total': total,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'attendanceRate': double.parse(attendanceRate.toStringAsFixed(1)),
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate attendance statistics for a class.
  Future<Map<String, dynamic>> getClassAttendanceStats({
    required String organizationId,
    required String classId,
    String? subjectId,
    String? date,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.attendanceCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId);

      if (subjectId != null) {
        query = query.where('subjectId', isEqualTo: subjectId);
      }
      if (date != null) {
        query = query.where('date', isEqualTo: date);
      }

      final snapshot = await query.get();

      int total = snapshot.docs.length;
      int present = 0;
      int absent = 0;
      int late = 0;
      int excused = 0;

      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String? ?? '';
        switch (status) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'late':
            late++;
            break;
          case 'excused':
            excused++;
            break;
        }
      }

      final attendanceRate = total > 0 ? (present + late + excused) / total * 100 : 0.0;

      return {
        'total': total,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'attendanceRate': double.parse(attendanceRate.toStringAsFixed(1)),
      };
    } catch (e) {
      rethrow;
    }
  }
}
