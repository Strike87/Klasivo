import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'exam_stats_service.dart';
import 'notification_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SubmissionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Start a new submission (when student begins an exam) ───────────────

  Future<String> startSubmission({
    required String examId,
    required String studentId,
    required String classId,
  }) async {
    try {
      // Check if student already has a submission for this exam
      final existingSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // Return existing submission ID
        return existingSnapshot.docs.first.id;
      }

      final docRef =
          await _firestore.collection(AppConstants.submissionsCollection).add({
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

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Save / update an answer ─────────────────────────────────────────────

  Future<void> saveAnswer({
    required String submissionId,
    required String questionId,
    required String answer,
    required String studentId,  // P1-2: required by rules
    required String organizationId,  // P1-2: required by isIncomingSameOrg()
  }) async {
    try {
      // Check if answer already exists
      final existingSnapshot = await _firestore
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: submissionId)
          .where('questionId', isEqualTo: questionId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        // Update existing answer
        await _firestore
            .collection(AppConstants.answersCollection)
            .doc(existingSnapshot.docs.first.id)
            .update({
          'answer': answer,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new answer
        await _firestore.collection(AppConstants.answersCollection).add({
          'submissionId': submissionId,
          'questionId': questionId,
          'answer': answer,
          'studentId': studentId,  // P1-2: required by rules
          'organizationId': organizationId,  // P1-2: required by isIncomingSameOrg()
          'isCorrect': false,
          'marksAwarded': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // ─── Bulk save answers (for auto-save) ──────────────────────────────────

  Future<void> bulkSaveAnswers({
    required String submissionId,
    required List<Map<String, String>> answers,
    required String studentId,  // P1-2: required by rules
    required String organizationId,  // P1-2: required by isIncomingSameOrg()
  }) async {
    try {
      final batch = _firestore.batch();

      for (final answerData in answers) {
        final questionId = answerData['questionId']!;
        final answer = answerData['answer']!;

        // Check if answer already exists
        final existingSnapshot = await _firestore
            .collection(AppConstants.answersCollection)
            .where('submissionId', isEqualTo: submissionId)
            .where('questionId', isEqualTo: questionId)
            .limit(1)
            .get();

        if (existingSnapshot.docs.isNotEmpty) {
          batch.update(
            existingSnapshot.docs.first.reference,
            {
              'answer': answer,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        } else {
          final newDocRef =
              _firestore.collection(AppConstants.answersCollection).doc();
          batch.set(newDocRef, {
            'submissionId': submissionId,
            'questionId': questionId,
            'answer': answer,
            'studentId': studentId,  // P1-2: required by rules
            'organizationId': organizationId,  // P1-2: required by isIncomingSameOrg()
            'isCorrect': false,
            'marksAwarded': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Submit exam (auto-grade) ────────────────────────────────────────────

  Future<void> submitExam({
    required String submissionId,
    required String examId,
    required int timeSpent,
  }) async {
    try {
      // Fetch all questions for this exam
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // Fetch all answers for this submission
      final answersSnapshot = await _firestore
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: submissionId)
          .get();

      final answersMap = <String, String>{};
      for (final doc in answersSnapshot.docs) {
        final data = doc.data();
        answersMap[data['questionId'] as String] =
            data['answer'] as String? ?? '';
      }

      // Grade each question
      final batch = _firestore.batch();
      int totalMarks = 0;
      int score = 0;

      for (final qDoc in questionsSnapshot.docs) {
        final qData = qDoc.data();
        final questionId = qDoc.id;
        final marks = qData['marks'] as int? ?? 0;
        final questionType = qData['questionType'] as String? ?? '';
        final correctAnswer = qData['correctAnswer'] as String? ?? '';
        final studentAnswer = answersMap[questionId] ?? '';

        totalMarks += marks;

        bool isCorrect = false;

        if (studentAnswer.isNotEmpty) {
          if (questionType == AppConstants.questionTypeMultipleChoice) {
            // MCQ: exact match
            isCorrect = studentAnswer == correctAnswer;
          } else if (questionType == AppConstants.questionTypeTrueFalse) {
            // T/F: exact match
            isCorrect = studentAnswer == correctAnswer;
          } else if (questionType == AppConstants.questionTypeShortAnswer) {
            // Short Answer: case-insensitive match
            isCorrect = studentAnswer.trim().toLowerCase() ==
                correctAnswer.trim().toLowerCase();
          }
        }

        final marksAwarded = isCorrect ? marks : 0;
        score += marksAwarded;

        // Update the answer document
        final answerDoc = answersSnapshot.docs.where(
          (doc) => doc.data()['questionId'] == questionId,
        ).firstOrNull;

        if (answerDoc != null) {
          batch.update(answerDoc.reference, {
            'isCorrect': isCorrect,
            'marksAwarded': marksAwarded,
          });
        }
      }

      // Calculate percentage
      final percentage =
          totalMarks > 0 ? ((score / totalMarks) * 100).round() : 0;

      // Update submission
      // P1-3: Only write fields the student is allowed to update.
      // Grading fields (score, percentage, status, totalMarks) are set by
      // the gradeSubmission Cloud Function — not the client.
      batch.update(
        _firestore
            .collection(AppConstants.submissionsCollection)
            .doc(submissionId),
        {
          'submittedAt': FieldValue.serverTimestamp(),
          'timeSpent': timeSpent,
        },
      );

      await batch.commit();

      // P1-3: Call gradeSubmission Cloud Function to do the grading
      try {
        await _functions.httpsCallable('gradeSubmission').call({
          'submissionId': submissionId,
          'examId': examId,
        });
      } catch (e) {
        // Grading failed — submission is marked as submitted but ungraded
        // The teacher can grade manually later
        print('Auto-grading failed: $e');
      }

      // Update precomputed exam stats (Phase D: uses ExamStatsService)
      try {
        final statsService = ExamStatsService();
        await statsService.recalculateExamStats(examId);
      } catch (_) {}

      // Notify student about result
      try {
        // Get the submission to find the studentId
        final submissionDoc = await _firestore
            .collection(AppConstants.submissionsCollection)
            .doc(submissionId)
            .get();
        final studentId = submissionDoc.data()?['studentId'] as String? ?? '';
        final classId = submissionDoc.data()?['classId'] as String? ?? '';

        final examDoc = await _firestore
            .collection(AppConstants.examsCollection)
            .doc(examId)
            .get();
        final examTitle = examDoc.data()?['title'] as String? ?? 'Exam';
        final orgId = examDoc.data()?['organizationId'] as String?;

        if (studentId.isNotEmpty) {
          await NotificationService.notifyResultPublished(
            studentId: studentId,
            examTitle: examTitle,
            score: percentage.toDouble(),
            organizationId: orgId,
            examId: examId,
          );
        }
      } catch (_) {
        // Don't fail the submission if notification fails
      }
    } catch (e) {
      rethrow;
    }
  }

  // ─── Increment violation count ───────────────────────────────────────────

  Future<void> incrementViolationCount(String submissionId) async {
    try {
      await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .update({
        'violationCount': FieldValue.increment(1),
      });

      // Check if threshold exceeded
      final doc = await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .get();

      final data = doc.data();
      if (data != null &&
          (data['violationCount'] as int? ?? 0) >=
              AppConstants.violationThreshold) {
        await _firestore
            .collection(AppConstants.submissionsCollection)
            .doc(submissionId)
            .update({
          'status': AppConstants.submissionStatusFlagged,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update time spent ───────────────────────────────────────────────────

  Future<void> updateTimeSpent(String submissionId, int seconds) async {
    try {
      await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .update({
        'timeSpent': seconds,
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get a single submission ─────────────────────────────────────────────

  Future<Map<String, dynamic>?> getSubmission(String submissionId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get submission for a student and exam ───────────────────────────────

  Future<Map<String, dynamic>?> getStudentSubmission({
    required String examId,
    required String studentId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
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

  // ─── Get stream of submissions for a student ─────────────────────────────

  Stream<QuerySnapshot> getStudentSubmissionsStream(String studentId) {
    return _firestore
        .collection(AppConstants.submissionsCollection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('startedAt', descending: true)
        .snapshots();
  }

  // ─── Get stream of submissions for an exam (teacher view) ────────────────

  Stream<QuerySnapshot> getExamSubmissionsStream(String examId) {
    return _firestore
        .collection(AppConstants.submissionsCollection)
        .where('examId', isEqualTo: examId)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  // ─── Get answers for a submission ────────────────────────────────────────

  Stream<QuerySnapshot> getAnswersStream(String submissionId) {
    return _firestore
        .collection(AppConstants.answersCollection)
        .where('submissionId', isEqualTo: submissionId)
        .snapshots();
  }

  // ─── Get all answers for a submission (one-time fetch) ───────────────────

  Future<List<Map<String, dynamic>>> getAnswers(String submissionId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: submissionId)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get submission stats for an exam ────────────────────────────────────

  Future<Map<String, dynamic>> getExamSubmissionStats(String examId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      int total = snapshot.docs.length;
      int submitted = 0;
      int flagged = 0;
      int totalScore = 0;
      int highScore = 0;
      int lowScore = 0;
      bool firstScore = true;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final score = data['score'] as int? ?? 0;

        if (status == AppConstants.submissionStatusSubmitted) {
          submitted++;
          totalScore += score;
          if (firstScore) {
            highScore = score;
            lowScore = score;
            firstScore = false;
          } else {
            if (score > highScore) highScore = score;
            if (score < lowScore) lowScore = score;
          }
        } else if (status == AppConstants.submissionStatusFlagged) {
          flagged++;
        }
      }

      return {
        'total': total,
        'submitted': submitted,
        'flagged': flagged,
        'absent': 0, // will be calculated with class student count
        'average': submitted > 0 ? (totalScore / submitted).round() : 0,
        'highScore': highScore,
        'lowScore': lowScore,
      };
    } catch (e) {
      rethrow;
    }
  }
}
