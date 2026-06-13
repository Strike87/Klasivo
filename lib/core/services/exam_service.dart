import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'notification_service.dart' as notif_service;
import 'search_keyword_service.dart';
import 'performance_trace_service.dart';
import 'interfaces/i_exam_service.dart';

/// Production exam service implementing [IExamService] for testability.
///
/// Call-sites that need to be testable should depend on [IExamService];
/// call-sites that need extra methods (createExamInstance, getExamCounts, etc.)
/// can import [ExamService] directly.
class ExamService implements IExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SearchKeywordService _searchKeywordService = SearchKeywordService();

  @override
  Future<String> createExam({required Map<String, dynamic> examData}) async {
    try {
      final title = examData['title'] as String? ?? '';
      final keywords = _searchKeywordService.generateKeywords(title);

      final data = <String, dynamic>{
        ...examData,
        'version': examData['version'] ?? 1,
        'isArchived': examData['isArchived'] ?? false,
        'archivedAt': null,
        'archivedBy': null,
        'searchKeywords': keywords,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef =
          await _firestore.collection(AppConstants.examsCollection).add(data);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateExam({
    required String examId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      if (updates.containsKey('title')) {
        updates['searchKeywords'] =
            _searchKeywordService.generateKeywords(updates['title'] as String);
      }
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Archive an exam (soft delete)
  @override
  Future<void> archiveExam({required String examId}) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Increment version when exam content changes significantly
  Future<void> incrementVersion(String examId) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'version': FieldValue.increment(1),
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> publishExam({required String examId}) async {
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
          await notif_service.NotificationService.scheduleExamReminders(
            examId: examId,
            examTitle: title,
            startDate: startDate,
          );
        }

        await notif_service.NotificationService.notifyExamCreated(
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

  @override
  Future<void> unpublishExam({required String examId}) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'status': AppConstants.statusDraft,
        'publishedAt': FieldValue.delete(),
      });

      await notif_service.NotificationService.cancelExamReminders(examId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteExam({required String examId}) async {
    await PerformanceTraceService.instance.traceOperation(
      PerformanceTraces.examDelete,
      () => _deleteExamImpl(examId),
      attributes: {'exam_id': examId},
    );
  }

  Future<void> _deleteExamImpl(String examId) async {
    try {
      await notif_service.NotificationService.cancelExamReminders(examId);

      // Fetch all related collections in parallel for better performance
      final results = await Future.wait([
        _firestore
            .collection(AppConstants.questionsCollection)
            .where('examId', isEqualTo: examId)
            .get(),
        _firestore
            .collection(AppConstants.submissionsCollection)
            .where('examId', isEqualTo: examId)
            .get(),
        _firestore
            .collection(AppConstants.examInstancesCollection)
            .where('examId', isEqualTo: examId)
            .get(),
        _firestore
            .collection(AppConstants.examStatsCollection)
            .where('examId', isEqualTo: examId)
            .get(),
      ]);

      final questionsSnapshot = results[0];
      final submissionsSnapshot = results[1];
      final instancesSnapshot = results[2];
      final statsSnapshot = results[3];

      // Batch fetch all answers for all submissions at once (instead of N+1)
      final submissionIds = submissionsSnapshot.docs.map((d) => d.id).toList();
      final List<QuerySnapshot> answerSnapshots = [];
      for (var i = 0; i < submissionIds.length; i += 30) {
        final chunk = submissionIds.sublist(
          i,
          i + 30 > submissionIds.length ? submissionIds.length : i + 30,
        );
        final snap = await _firestore
            .collection(AppConstants.answersCollection)
            .where('submissionId', whereIn: chunk)
            .get();
        answerSnapshots.add(snap);
      }

      final batch = _firestore.batch();

      // Delete questions
      for (final doc in questionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete submissions
      for (final doc in submissionsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete answers
      for (final snap in answerSnapshots) {
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
      }

      // Delete instances
      for (final doc in instancesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete stats
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

  @override
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
      // Get classId from the exam document
      final examDoc = await _firestore.collection(AppConstants.examsCollection).doc(examId).get();
      final classId = examDoc.data()?['classId'] as String? ?? '';
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
        'classId': classId,
        'isRandomized': randomizeQuestions,
        'randomizedQuestionIds': processedQuestions.map((q) => q['id'] ?? '').toList(),
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

          // Compare percentage (0-100) against passRate threshold
          final totalMarks = (examDoc.data()?['totalMarks'] as int?) ?? 0;
          final passThreshold = totalMarks > 0 ? (passingScore / totalMarks * 100) : passingScore.toDouble();
          if (percentage >= passThreshold) passCount++;
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

  Stream<QuerySnapshot> getExamsStream(String teacherId, {String? organizationId}) {
    var query = _firestore
        .collection(AppConstants.examsCollection)
        .where('teacherId', isEqualTo: teacherId);
    if (organizationId != null) {
      query = query.where('organizationId', isEqualTo: organizationId);
    }
    return query
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

  @override
  Future<Map<String, dynamic>?> getExam(String examId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
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

  @override
  Stream<QuerySnapshot> getExamsForClass(String classId) {
    return _firestore
        .collection(AppConstants.examsCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Stream<QuerySnapshot> getExamsForTeacher(String teacherId) {
    return getExamsStream(teacherId);
  }
}
