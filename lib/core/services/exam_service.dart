import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';

class ExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Create a new exam (draft by default) ────────────────────────────────

  Future<String> createExam({
    required String teacherId,
    required String title,
    required String classId,
    String? description,
    required int durationMinutes,
    required DateTime startDate,
    required DateTime endDate,
    required int passingScore,
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
        'totalMarks': 0, // calculated when questions are added
        'passingScore': passingScore,
        'status': AppConstants.statusDraft,
        'questionCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update exam settings ────────────────────────────────────────────────

  Future<void> updateExam({
    required String examId,
    required String title,
    required String classId,
    String? description,
    required int durationMinutes,
    required DateTime startDate,
    required DateTime endDate,
    required int passingScore,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'title': title,
        'description': description,
        'classId': classId,
        'durationMinutes': durationMinutes,
        'startDate': startDate,
        'endDate': endDate,
        'passingScore': passingScore,
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Publish exam (draft → published) ────────────────────────────────────

  Future<void> publishExam(String examId) async {
    try {
      // Verify exam has at least 1 question before publishing
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

      // Schedule exam reminders for students
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

        // Notify students about new exam
        await NotificationService.notifyExamPublished(
          examTitle: title,
          className: classId, // We could look up class name but this is fine for now
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // ─── Unpublish exam (published → draft) ──────────────────────────────────

  Future<void> unpublishExam(String examId) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'status': AppConstants.statusDraft,
        'publishedAt': FieldValue.delete(),
      });

      // Cancel scheduled reminders
      await NotificationService.cancelExamReminders(examId);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Delete exam and its questions ───────────────────────────────────────

  Future<void> deleteExam(String examId) async {
    try {
      final batch = _firestore.batch();

      // Delete all questions for this exam
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      for (final doc in questionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all submissions for this exam
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      for (final doc in submissionsSnapshot.docs) {
        // Delete answers for each submission
        final answersSnapshot = await _firestore
            .collection(AppConstants.answersCollection)
            .where('submissionId', isEqualTo: doc.id)
            .get();
        for (final ansDoc in answersSnapshot.docs) {
          batch.delete(ansDoc.reference);
        }
        batch.delete(doc.reference);
      }

      // Delete the exam itself
      batch.delete(
        _firestore.collection(AppConstants.examsCollection).doc(examId),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Recalculate total marks from questions ──────────────────────────────

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

  // ─── Get stream of exams for a teacher ───────────────────────────────────

  Stream<QuerySnapshot> getExamsStream(String teacherId) {
    return _firestore
        .collection(AppConstants.examsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Get stream of published exams for a class ───────────────────────────

  Stream<QuerySnapshot> getClassExamsStream(String classId) {
    return _firestore
        .collection(AppConstants.examsCollection)
        .where('classId', isEqualTo: classId)
        .where('status', isEqualTo: AppConstants.statusPublished)
        .orderBy('startDate', descending: false)
        .snapshots();
  }

  // ─── Get a single exam ──────────────────────────────────────────────────

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

  // ─── Get exam counts by status ───────────────────────────────────────────

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
