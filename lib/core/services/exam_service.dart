import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';

class ExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createExam({
    required String teacherId,
    required String title,
    required String classId,
    String? description,
    required int durationMinutes,
    required DateTime startDate,
    required DateTime endDate,
    required int passingScore,
    bool isRandomized = false,
    bool allowRetake = false,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef =
          await _firestore.collection(AppConstants.examsCollection).add({
        'teacherId': teacherId,
        'title': title,
        'description': description,
        'classId': classId,
        'durationMinutes': durationMinutes,
        'startDate': startDate,
        'endDate': endDate,
        'totalMarks': 0,
        'passingScore': passingScore,
        'status': AppConstants.statusDraft,
        'questionCount': 0,
        'isRandomized': isRandomized,
        'allowRetake': allowRetake,
        'institutionId': institutionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateExam({
    required String examId,
    required String title,
    required String classId,
    String? description,
    required int durationMinutes,
    required DateTime startDate,
    required DateTime endDate,
    required int passingScore,
    bool? isRandomized,
    bool? allowRetake,
  }) async {
    try {
      final data = <String, dynamic>{
        'title': title,
        'description': description,
        'classId': classId,
        'durationMinutes': durationMinutes,
        'startDate': startDate,
        'endDate': endDate,
        'passingScore': passingScore,
      };
      if (isRandomized != null) data['isRandomized'] = isRandomized;
      if (allowRetake != null) data['allowRetake'] = allowRetake;

      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> publishExam(String examId) async {
    try {
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .count()
          .get();

      if (questionsSnapshot.count == 0) {
        throw Exception('Cannot publish exam without questions. Add at least one question.');
      }

      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'status': AppConstants.statusPublished,
        'publishedAt': FieldValue.serverTimestamp(),
      });

      final examDoc = await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .get();
      if (examDoc.exists) {
        final data = examDoc.data()!;
        final startDate = (data['startDate'] as Timestamp?)?.toDate();
        final title = data['title'] as String? ?? 'Exam';
        final classId = data['classId'] as String? ?? '';

        if (startDate != null) {
          await NotificationService.scheduleExamReminders(
            examId: examId,
            examTitle: title,
            startDate: startDate,
          );
        }

        await NotificationService.notifyExamPublished(
          organizationId: data['organizationId'] as String? ?? '',
          classId: classId,
          examId: examId,
          examTitle: title,
          studentIds: [], // Will be populated by caller with actual student IDs
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unpublishExam(String examId) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'status': AppConstants.statusDraft,
        'publishedAt': FieldValue.delete(),
      });

      await NotificationService.cancelExamReminders(examId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteExam(String examId) async {
    try {
      await NotificationService.cancelExamReminders(examId);

      final batch = _firestore.batch();

      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      for (final doc in questionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      for (final doc in submissionsSnapshot.docs) {
        final answersSnapshot = await _firestore
            .collection(AppConstants.answersCollection)
            .where('submissionId', isEqualTo: doc.id)
            .get();
        for (final ansDoc in answersSnapshot.docs) {
          batch.delete(ansDoc.reference);
        }
        batch.delete(doc.reference);
      }

      // Delete exam instances
      final instancesSnapshot = await _firestore
          .collection(AppConstants.examInstancesCollection)
          .where('examId', isEqualTo: examId)
          .get();
      for (final doc in instancesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete exam stats
      final statsSnapshot = await _firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      for (final doc in statsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(
        _firestore.collection(AppConstants.examsCollection).doc(examId),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> recalculateTotalMarks(String examId) async {
    try {
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      int totalMarks = 0;
      for (final doc in questionsSnapshot.docs) {
        totalMarks += (doc.data()['marks'] as int?) ?? 0;
      }

      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'totalMarks': totalMarks,
        'questionCount': questionsSnapshot.size,
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Exam Instance (for randomization) ────────────────────────────────

  /// Create an exam instance with randomized question order when student starts
  Future<String> createExamInstance({
    required String examId,
    required String studentId,
    required List<Map<String, dynamic>> questions,
    bool randomizeQuestions = false,
    bool randomizeOptions = false,
  }) async {
    try {
      // Check if instance already exists for this student
      final existingSnapshot = await _firestore
          .collection(AppConstants.examInstancesCollection)
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        return existingSnapshot.docs.first.id;
      }

      // Randomize questions if needed
      List<Map<String, dynamic>> processedQuestions = List.from(questions);
      if (randomizeQuestions) {
        processedQuestions.shuffle(Random());
      }

      // Randomize options within each question if needed
      if (randomizeOptions) {
        for (final q in processedQuestions) {
          final options = List<String>.from(q['options'] ?? []);
          if (options.isNotEmpty) {
            options.shuffle(Random());
            q['options'] = options;
          }
        }
      }

      // Create submission
      final classId = questions.isNotEmpty ? (questions.first['examData']?['classId'] ?? '') : '';
      final submissionRef = await _firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': studentId,
        'classId': classId,
        'status': AppConstants.submissionStatusStarted,
        'startedAt': FieldValue.serverTimestamp(),
        'submittedAt': null,
        'timeSpent': 0,
        'totalMarks': 0,
        'score': 0,
        'percentage': 0,
        'violationCount': 0,
      });

      // Create exam instance (immutable snapshot)
      final docRef = await _firestore.collection(AppConstants.examInstancesCollection).add({
        'examId': examId,
        'studentId': studentId,
        'randomizedQuestions': processedQuestions,
        'startedAt': FieldValue.serverTimestamp(),
        'submissionId': submissionRef.id,
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam instance for a student
  Future<Map<String, dynamic>?> getExamInstance({
    required String examId,
    required String studentId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.examInstancesCollection)
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
    } catch (e) {
      rethrow;
    }
  }

  // ─── Exam Stats (precomputed) ────────────────────────────────────────

  /// Update exam stats after a submission
  Future<void> updateExamStats(String examId) async {
    try {
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      int totalStudents = submissionsSnapshot.docs.length;
      int submittedStudents = 0;
      int totalScore = 0;
      int highestScore = 0;
      int lowestScore = 0;
      bool firstScore = true;
      int passCount = 0;

      // Get passing score
      final examDoc = await _firestore.collection(AppConstants.examsCollection).doc(examId).get();
      final passingScore = (examDoc.data()?['passingScore'] as int?) ?? 0;
      final totalMarks = (examDoc.data()?['totalMarks'] as int?) ?? 0;

      for (final doc in submissionsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final score = data['score'] as int? ?? 0;
        final percentage = data['percentage'] as int? ?? 0;

        if (status == AppConstants.submissionStatusSubmitted ||
            status == AppConstants.submissionStatusFlagged) {
          submittedStudents++;
          totalScore += score;

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
      final passRate = submittedStudents > 0
          ? (passCount / submittedStudents) * 100
          : 0.0;

      // Upsert exam stats
      final statsSnapshot = await _firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .limit(1)
          .get();

      final statsData = {
        'examId': examId,
        'totalStudents': totalStudents,
        'submittedStudents': submittedStudents,
        'averageScore': averageScore,
        'highestScore': highestScore,
        'lowestScore': lowestScore,
        'passRate': passRate,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (statsSnapshot.docs.isNotEmpty) {
        await _firestore
            .collection(AppConstants.examStatsCollection)
            .doc(statsSnapshot.docs.first.id)
            .update(statsData);
      } else {
        await _firestore.collection(AppConstants.examStatsCollection).add(statsData);
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getExamsStream(String teacherId) {
    return _firestore
        .collection(AppConstants.examsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getClassExamsStream(String classId) {
    return _firestore
        .collection(AppConstants.examsCollection)
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: AppConstants.statusPublished)
        .orderBy('startDate', descending: false)
        .snapshots();
  }

  Future<Map<String, dynamic>?> getExam(String examId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> getExamCounts(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .get();

      int upcoming = 0;
      int completed = 0;
      int draft = 0;
      final now = DateTime.now();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final endDate = (data['endDate'] as Timestamp?)?.toDate();

        if (status == AppConstants.statusDraft) {
          draft++;
        } else if (endDate != null && endDate.isBefore(now)) {
          completed++;
        } else {
          upcoming++;
        }
      }

      return {
        'upcoming': upcoming,
        'completed': completed,
        'draft': draft,
        'total': snapshot.size,
      };
    } catch (e) {
      rethrow;
    }
  }
}
