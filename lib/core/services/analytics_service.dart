import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Student Analytics ───────────────────────────────────────────────────

  /// Get comprehensive analytics for a student.
  /// Returns average exam score, attendance %, assignment completion rate,
  /// and exam trend data.
  Future<Map<String, dynamic>> getStudentAnalytics({
    required String organizationId,
    required String studentId,
    String? classId,
  }) async {
    try {
      // 1. Exam performance
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      double totalScore = 0;
      int examCount = 0;
      double highestScore = 0;
      double lowestScore = double.infinity;
      List<Map<String, dynamic>> examTrend = [];

      for (final doc in submissionsSnapshot.docs) {
        final data = doc.data();
        final score = (data['score'] as num?)?.toDouble() ?? 0;
        final examId = data['examId'] as String? ?? '';

        // Filter by organization if classId is specified
        if (classId != null) {
          final examDoc = await _firestore
              .collection(AppConstants.examsCollection)
              .doc(examId)
              .get();
          if (examDoc.exists &&
              examDoc.data()?['classId'] != classId) {
            continue;
          }
        }

        totalScore += score;
        examCount++;
        if (score > highestScore) highestScore = score;
        if (score < lowestScore) lowestScore = score;

        // Get exam title for trend
        final examDoc = await _firestore
            .collection(AppConstants.examsCollection)
            .doc(examId)
            .get();
        if (examDoc.exists) {
          examTrend.add({
            'examId': examId,
            'examTitle': examDoc.data()?['title'] ?? 'Unknown',
            'score': score,
            'date': examDoc.data()?['startDate'],
          });
        }
      }

      final averageScore = examCount > 0 ? totalScore / examCount : 0.0;
      if (lowestScore == double.infinity) lowestScore = 0;

      // 2. Attendance stats
      Map<String, dynamic> attendanceStats = {'attendanceRate': 0.0, 'total': 0, 'absent': 0, 'late': 0};
      try {
        Query<Map<String, dynamic>> attendanceQuery = _firestore
            .collection(AppConstants.attendanceCollection)
            .where('organizationId', isEqualTo: organizationId)
            .where('studentId', isEqualTo: studentId);

        if (classId != null) {
          attendanceQuery =
              attendanceQuery.where('classId', isEqualTo: classId);
        }

        final attendanceSnapshot = await attendanceQuery.get();
        int total = attendanceSnapshot.docs.length;
        int present = 0;
        int absent = 0;
        int late = 0;

        for (final doc in attendanceSnapshot.docs) {
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
          }
        }

        final rate = total > 0
            ? (present + late) / total * 100
            : 0.0;
        attendanceStats = {
          'attendanceRate': double.parse(rate.toStringAsFixed(1)),
          'total': total,
          'present': present,
          'absent': absent,
          'late': late,
        };
      } catch (e) {
        // Attendance might not exist yet
      }

      // 3. Assignment completion
      int totalAssignments = 0;
      int completedAssignments = 0;
      try {
        Query assignmentsQuery = _firestore
            .collection(AppConstants.assignmentsCollection)
            .where('organizationId', isEqualTo: organizationId)
            .where('isArchived', isEqualTo: false);

        if (classId != null) {
          assignmentsQuery =
              assignmentsQuery.where('classId', isEqualTo: classId);
        }

        final assignmentsSnapshot = await assignmentsQuery.get();
        totalAssignments = assignmentsSnapshot.docs.length;

        // Check submissions for each assignment
        for (final doc in assignmentsSnapshot.docs) {
          final submissionSnapshot = await _firestore
              .collection(AppConstants.assignmentSubmissionsCollection)
              .where('assignmentId', isEqualTo: doc.id)
              .where('studentId', isEqualTo: studentId)
              .limit(1)
              .get();

          if (submissionSnapshot.docs.isNotEmpty) {
            completedAssignments++;
          }
        }
      } catch (e) {
        // Assignments might not exist yet
      }

      final completionRate = totalAssignments > 0
          ? completedAssignments / totalAssignments * 100
          : 0.0;

      return {
        'averageScore': double.parse(averageScore.toStringAsFixed(1)),
        'highestScore': highestScore,
        'lowestScore': lowestScore,
        'examCount': examCount,
        'examTrend': examTrend,
        'attendanceRate': attendanceStats['attendanceRate'],
        'attendanceTotal': attendanceStats['total'],
        'absentCount': attendanceStats['absent'],
        'lateCount': attendanceStats['late'],
        'assignmentCompletionRate': double.parse(completionRate.toStringAsFixed(1)),
        'totalAssignments': totalAssignments,
        'completedAssignments': completedAssignments,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Class Analytics ─────────────────────────────────────────────────────

  /// Get analytics for a class: average score, pass rate, attendance rate,
  /// highest/lowest scores.
  Future<Map<String, dynamic>> getClassAnalytics({
    required String organizationId,
    required String classId,
  }) async {
    try {
      // 1. Get all students in this class
      final studentsSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .where('isActive', isEqualTo: true)
          .get();

      final studentCount = studentsSnapshot.docs.length;

      if (studentCount == 0) {
        return {
          'studentCount': 0,
          'classAverage': 0.0,
          'highestScore': 0.0,
          'lowestScore': 0.0,
          'passRate': 0.0,
          'attendanceRate': 0.0,
        };
      }

      // 2. Get all exams for this class
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId)
          .get();

      double totalScore = 0;
      int totalSubmissions = 0;
      double highestScore = 0;
      double lowestScore = double.infinity;
      int passedCount = 0;
      final passingGrade = 50.0; // 50% is passing

      for (final examDoc in examsSnapshot.docs) {
        final examId = examDoc.id;
        final submissionsSnapshot = await _firestore
            .collection(AppConstants.submissionsCollection)
            .where('examId', isEqualTo: examId)
            .get();

        for (final subDoc in submissionsSnapshot.docs) {
          final score = (subDoc.data()['score'] as num?)?.toDouble() ?? 0;
          totalScore += score;
          totalSubmissions++;
          if (score > highestScore) highestScore = score;
          if (score < lowestScore) lowestScore = score;
          if (score >= passingGrade) passedCount++;
        }
      }

      if (lowestScore == double.infinity) lowestScore = 0;
      final classAverage = totalSubmissions > 0 ? totalScore / totalSubmissions : 0.0;
      final passRate = totalSubmissions > 0 ? passedCount / totalSubmissions * 100 : 0.0;

      // 3. Class attendance rate
      final attendanceSnapshot = await _firestore
          .collection(AppConstants.attendanceCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId)
          .get();

      int totalAttendance = attendanceSnapshot.docs.length;
      int presentCount = 0;
      for (final doc in attendanceSnapshot.docs) {
        final status = doc.data()['status'] as String? ?? '';
        if (status == 'present' || status == 'late') {
          presentCount++;
        }
      }

      final attendanceRate = totalAttendance > 0
          ? presentCount / totalAttendance * 100
          : 0.0;

      return {
        'studentCount': studentCount,
        'classAverage': double.parse(classAverage.toStringAsFixed(1)),
        'highestScore': highestScore,
        'lowestScore': lowestScore,
        'passRate': double.parse(passRate.toStringAsFixed(1)),
        'attendanceRate': double.parse(attendanceRate.toStringAsFixed(1)),
        'examCount': examsSnapshot.docs.length,
        'totalSubmissions': totalSubmissions,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Teacher Analytics ───────────────────────────────────────────────────

  /// Get analytics for a teacher: exams created, assignments created,
  /// students managed.
  Future<Map<String, dynamic>> getTeacherAnalytics({
    required String organizationId,
    required String teacherId,
  }) async {
    try {
      // 1. Exams created
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('createdBy', isEqualTo: teacherId)
          .get();

      final examsCreated = examsSnapshot.docs.length;

      // 2. Assignments created
      final assignmentsSnapshot = await _firestore
          .collection(AppConstants.assignmentsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('createdBy', isEqualTo: teacherId)
          .get();

      final assignmentsCreated = assignmentsSnapshot.docs.length;

      // 3. Students managed (through teacher assignments)
      final teacherAssignmentsSnapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final managedClassIds = <String>{};
      for (final doc in teacherAssignmentsSnapshot.docs) {
        final classId = doc.data()['classId'] as String?;
        if (classId != null) managedClassIds.add(classId);
      }

      int studentsManaged = 0;
      for (final classId in managedClassIds) {
        final studentsSnapshot = await _firestore
            .collection(AppConstants.usersCollection)
            .where('organizationId', isEqualTo: organizationId)
            .where('classId', isEqualTo: classId)
            .where('role', isEqualTo: AppConstants.roleStudent)
            .where('isActive', isEqualTo: true)
            .get();
        studentsManaged += studentsSnapshot.docs.length;
      }

      // 4. Question banks created
      final qbSnapshot = await _firestore
          .collection(AppConstants.questionBankCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('createdBy', isEqualTo: teacherId)
          .get();

      final questionBanksCreated = qbSnapshot.docs.length;

      return {
        'examsCreated': examsCreated,
        'assignmentsCreated': assignmentsCreated,
        'studentsManaged': studentsManaged,
        'classesAssigned': managedClassIds.length,
        'questionBanksCreated': questionBanksCreated,
        'teacherAssignmentsCount': teacherAssignmentsSnapshot.docs.length,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Analytics Cache ─────────────────────────────────────────────────────

  /// Cache computed analytics for quick retrieval.
  /// Analytics are expensive to compute, so we cache them with a TTL.
  Future<void> cacheAnalytics({
    required String organizationId,
    required String type, // 'student', 'class', 'teacher'
    required String entityId, // studentId, classId, or teacherId
    required Map<String, dynamic> data,
  }) async {
    try {
      final docId = '${type}_${entityId}';

      await _firestore
          .collection(AppConstants.analyticsCacheCollection)
          .doc(docId)
          .set({
        'organizationId': organizationId,
        'type': type,
        'entityId': entityId,
        'data': data,
        'computedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(
            Duration(hours: AppConstants.analyticsCacheDurationHours),
          ),
        ),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get cached analytics if they haven't expired.
  Future<Map<String, dynamic>?> getCachedAnalytics({
    required String type,
    required String entityId,
  }) async {
    try {
      final docId = '${type}_${entityId}';
      final doc = await _firestore
          .collection(AppConstants.analyticsCacheCollection)
          .doc(docId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      // Check if cache has expired
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        return null; // Cache expired
      }

      return data['data'] as Map<String, dynamic>?;
    } catch (e) {
      rethrow;
    }
  }

  /// Get student analytics with caching.
  Future<Map<String, dynamic>> getStudentAnalyticsCached({
    required String organizationId,
    required String studentId,
    String? classId,
  }) async {
    try {
      // Try cache first
      final cached = await getCachedAnalytics(
        type: AppConstants.analyticsTypeStudent,
        entityId: classId != null ? '${studentId}_$classId' : studentId,
      );

      if (cached != null) return cached;

      // Compute and cache
      final analytics = await getStudentAnalytics(
        organizationId: organizationId,
        studentId: studentId,
        classId: classId,
      );

      await cacheAnalytics(
        organizationId: organizationId,
        type: AppConstants.analyticsTypeStudent,
        entityId: classId != null ? '${studentId}_$classId' : studentId,
        data: analytics,
      );

      return analytics;
    } catch (e) {
      rethrow;
    }
  }

  /// Get class analytics with caching.
  Future<Map<String, dynamic>> getClassAnalyticsCached({
    required String organizationId,
    required String classId,
  }) async {
    try {
      final cached = await getCachedAnalytics(
        type: AppConstants.analyticsTypeClass,
        entityId: classId,
      );

      if (cached != null) return cached;

      final analytics = await getClassAnalytics(
        organizationId: organizationId,
        classId: classId,
      );

      await cacheAnalytics(
        organizationId: organizationId,
        type: AppConstants.analyticsTypeClass,
        entityId: classId,
        data: analytics,
      );

      return analytics;
    } catch (e) {
      rethrow;
    }
  }

  /// Get teacher analytics with caching.
  Future<Map<String, dynamic>> getTeacherAnalyticsCached({
    required String organizationId,
    required String teacherId,
  }) async {
    try {
      final cached = await getCachedAnalytics(
        type: AppConstants.analyticsTypeTeacher,
        entityId: teacherId,
      );

      if (cached != null) return cached;

      final analytics = await getTeacherAnalytics(
        organizationId: organizationId,
        teacherId: teacherId,
      );

      await cacheAnalytics(
        organizationId: organizationId,
        type: AppConstants.analyticsTypeTeacher,
        entityId: teacherId,
        data: analytics,
      );

      return analytics;
    } catch (e) {
      rethrow;
    }
  }

  /// Invalidate (delete) cached analytics for an entity.
  Future<void> invalidateCache({
    required String type,
    required String entityId,
  }) async {
    try {
      final docId = '${type}_${entityId}';
      await _firestore
          .collection(AppConstants.analyticsCacheCollection)
          .doc(docId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }
}
