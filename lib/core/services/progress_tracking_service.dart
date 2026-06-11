import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

/// Service for student progress tracking.
/// Aggregates data from exams, attendance, and assignments to compute
/// overall progress per student per class.
class ProgressTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create or update a progress tracking record for a student.
  Future<void> updateStudentProgress({
    required String organizationId,
    required String studentId,
    required String classId,
    required String stageId,
  }) async {
    try {
      // 1. Get exam results for the student
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'submitted')
          .get();

      double totalScore = 0;
      double totalMarks = 0;
      int examsCompleted = submissionsSnapshot.docs.length;

      for (final doc in submissionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalScore += (data['score'] as num?)?.toDouble() ?? 0;
        totalMarks += (data['totalMarks'] as num?)?.toDouble() ?? 0;
      }

      final examAverage = totalMarks > 0 ? (totalScore / totalMarks) * 100 : 0.0;

      // 2. Get attendance rate
      final attendanceSnapshot = await _firestore
          .collection(AppConstants.attendanceCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      int presentCount = 0;
      for (final doc in attendanceSnapshot.docs) {
        final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? '';
        if (status == AppConstants.attendanceStatusPresent ||
            status == AppConstants.attendanceStatusLate) {
          presentCount++;
        }
      }
      final attendanceRate = attendanceSnapshot.docs.isNotEmpty
          ? (presentCount / attendanceSnapshot.docs.length) * 100
          : 0.0;

      // 3. Get assignment completion rate
      final assignmentsSnapshot = await _firestore
          .collection(AppConstants.assignmentsCollection)
          .where('classId', isEqualTo: classId)
          .where('isArchived', isEqualTo: false)
          .get();

      int totalAssignments = assignmentsSnapshot.docs.length;
      int completedAssignments = 0;

      if (totalAssignments > 0) {
        for (final assignDoc in assignmentsSnapshot.docs) {
          final subSnapshot = await _firestore
              .collection(AppConstants.assignmentSubmissionsCollection)
              .where('assignmentId', isEqualTo: assignDoc.id)
              .where('studentId', isEqualTo: studentId)
              .limit(1)
              .get();
          if (subSnapshot.docs.isNotEmpty) {
            completedAssignments++;
          }
        }
      }

      final assignmentRate = totalAssignments > 0
          ? (completedAssignments / totalAssignments) * 100
          : 0.0;

      // 4. Compute overall progress (weighted: exams 50%, attendance 25%, assignments 25%)
      final overallProgress = (examAverage * 0.5) +
          (attendanceRate * 0.25) +
          (assignmentRate * 0.25);

      // 5. Determine grade level
      String gradeLevel;
      if (overallProgress >= 90) {
        gradeLevel = 'excellent';
      } else if (overallProgress >= 75) {
        gradeLevel = 'good';
      } else if (overallProgress >= 60) {
        gradeLevel = 'average';
      } else if (overallProgress >= 40) {
        gradeLevel = 'below_average';
      } else {
        gradeLevel = 'at_risk';
      }

      // 6. Upsert the progress document
      final existingQuery = await _firestore
          .collection(AppConstants.progressTrackingCollection)
          .where('studentId', isEqualTo: studentId)
          .where('classId', isEqualTo: classId)
          .limit(1)
          .get();

      final progressData = {
        'organizationId': organizationId,
        'studentId': studentId,
        'classId': classId,
        'stageId': stageId,
        'examAverage': examAverage,
        'examsCompleted': examsCompleted,
        'attendanceRate': attendanceRate,
        'totalAttendanceRecords': attendanceSnapshot.docs.length,
        'presentCount': presentCount,
        'assignmentRate': assignmentRate,
        'totalAssignments': totalAssignments,
        'completedAssignments': completedAssignments,
        'overallProgress': overallProgress,
        'gradeLevel': gradeLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingQuery.docs.isNotEmpty) {
        await existingQuery.docs.first.reference.update(progressData);
      } else {
        await _firestore
            .collection(AppConstants.progressTrackingCollection)
            .add({
          ...progressData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get progress for a specific student in a class.
  Stream<QuerySnapshot> getStudentProgressStream({
    required String studentId,
    required String classId,
  }) {
    return _firestore
        .collection(AppConstants.progressTrackingCollection)
        .where('studentId', isEqualTo: studentId)
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  /// Get progress for all students in a class.
  Stream<QuerySnapshot> getClassProgressStream(String classId) {
    return _firestore
        .collection(AppConstants.progressTrackingCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('overallProgress', descending: true)
        .snapshots();
  }

  /// Get progress for all students in a stage.
  Stream<QuerySnapshot> getStageProgressStream(String stageId) {
    return _firestore
        .collection(AppConstants.progressTrackingCollection)
        .where('stageId', isEqualTo: stageId)
        .orderBy('overallProgress', descending: true)
        .snapshots();
  }

  /// Get students at risk (overallProgress < 40) in a class.
  Stream<QuerySnapshot> getAtRiskStudentsStream(String classId) {
    return _firestore
        .collection(AppConstants.progressTrackingCollection)
        .where('classId', isEqualTo: classId)
        .where('gradeLevel', isEqualTo: 'at_risk')
        .snapshots();
  }

  /// Get progress summary stats for a class.
  Future<Map<String, dynamic>> getClassSummary(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.progressTrackingCollection)
          .where('classId', isEqualTo: classId)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'totalStudents': 0,
          'averageProgress': 0.0,
          'excellent': 0,
          'good': 0,
          'average': 0,
          'belowAverage': 0,
          'atRisk': 0,
        };
      }

      double totalProgress = 0;
      int excellent = 0, good = 0, average = 0, belowAverage = 0, atRisk = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final progress = (data['overallProgress'] as num?)?.toDouble() ?? 0;
        totalProgress += progress;

        switch (data['gradeLevel'] as String? ?? '') {
          case 'excellent': excellent++; break;
          case 'good': good++; break;
          case 'average': average++; break;
          case 'below_average': belowAverage++; break;
          case 'at_risk': atRisk++; break;
        }
      }

      return {
        'totalStudents': snapshot.docs.length,
        'averageProgress': totalProgress / snapshot.docs.length,
        'excellent': excellent,
        'good': good,
        'average': average,
        'belowAverage': belowAverage,
        'atRisk': atRisk,
      };
    } catch (e) {
      rethrow;
    }
  }
}
