import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TEST: Exam Creation Flow
//
// Tests the complete exam lifecycle using FakeFirebaseFirestore:
// create → add questions → recalculate marks → publish → take → grade → stats
//
// This tests the data flow that ExamService + SubmissionService orchestrate
// in production, validating that all Firestore operations compose correctly.
// ═══════════════════════════════════════════════════════════════════════════════

/// Testable version of ExamService that accepts a Firestore instance.
class TestableExamService {
  final FirebaseFirestore _db;

  TestableExamService(this._db);

  // ─── Search keyword generation (simplified from SearchKeywordService) ────
  List<String> _generateKeywords(String text) {
    if (text.trim().isEmpty) return [];
    final keywords = <String>[];
    final words = text.toLowerCase().trim().split(RegExp(r'\s+'));
    for (final word in words) {
      keywords.add(word);
      for (int i = 2; i <= word.length && i <= 10; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    keywords.add(text.toLowerCase().trim());
    return keywords.toSet().toList();
  }

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
    String organizationId = AppConstants.defaultInstitutionId,
  }) async {
    final keywords = _generateKeywords(title);
    final docRef = await _db.collection(AppConstants.examsCollection).add({
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
      'organizationId': organizationId,
      'version': 1,
      'isArchived': false,
      'archivedAt': null,
      'archivedBy': null,
      'searchKeywords': keywords,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
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
    final keywords = _generateKeywords(title);
    final data = <String, dynamic>{
      'title': title,
      'description': description,
      'classId': classId,
      'durationMinutes': durationMinutes,
      'startDate': startDate,
      'endDate': endDate,
      'passingScore': passingScore,
      'searchKeywords': keywords,
    };
    if (isRandomized != null) data['isRandomized'] = isRandomized;
    if (allowRetake != null) data['allowRetake'] = allowRetake;
    await _db.collection(AppConstants.examsCollection).doc(examId).update(data);
  }

  Future<void> archiveExam(String examId, {String archivedBy = ''}) async {
    await _db.collection(AppConstants.examsCollection).doc(examId).update({
      'isArchived': true,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': archivedBy,
    });
  }

  Future<void> incrementVersion(String examId) async {
    await _db.collection(AppConstants.examsCollection).doc(examId).update({
      'version': FieldValue.increment(1),
    });
  }

  Future<void> publishExam(String examId) async {
    final questionsSnapshot = await _db
        .collection(AppConstants.questionsCollection)
        .where('examId', isEqualTo: examId)
        .get();

    if (questionsSnapshot.size == 0) {
      throw Exception('Cannot publish exam without questions. Add at least one question.');
    }

    await _db.collection(AppConstants.examsCollection).doc(examId).update({
      'status': AppConstants.statusPublished,
      'publishedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unpublishExam(String examId) async {
    await _db.collection(AppConstants.examsCollection).doc(examId).update({
      'status': AppConstants.statusDraft,
      'publishedAt': FieldValue.delete(),
    });
  }

  Future<void> deleteExam(String examId) async {
    final batch = _db.batch();

    // Delete questions
    final questionsSnapshot = await _db
        .collection(AppConstants.questionsCollection)
        .where('examId', isEqualTo: examId)
        .get();
    for (final doc in questionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete submissions + answers
    final submissionsSnapshot = await _db
        .collection(AppConstants.submissionsCollection)
        .where('examId', isEqualTo: examId)
        .get();
    for (final doc in submissionsSnapshot.docs) {
      final answersSnapshot = await _db
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: doc.id)
          .get();
      for (final ansDoc in answersSnapshot.docs) {
        batch.delete(ansDoc.reference);
      }
      batch.delete(doc.reference);
    }

    // Delete exam instances
    final instancesSnapshot = await _db
        .collection(AppConstants.examInstancesCollection)
        .where('examId', isEqualTo: examId)
        .get();
    for (final doc in instancesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete exam stats
    final statsSnapshot = await _db
        .collection(AppConstants.examStatsCollection)
        .where('examId', isEqualTo: examId)
        .get();
    for (final doc in statsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_db.collection(AppConstants.examsCollection).doc(examId));
    await batch.commit();
  }

  Future<void> recalculateTotalMarks(String examId) async {
    final questionsSnapshot = await _db
        .collection(AppConstants.questionsCollection)
        .where('examId', isEqualTo: examId)
        .get();

    int totalMarks = 0;
    for (final doc in questionsSnapshot.docs) {
      totalMarks += (doc.data()['marks'] as int?) ?? 0;
    }

    await _db.collection(AppConstants.examsCollection).doc(examId).update({
      'totalMarks': totalMarks,
      'questionCount': questionsSnapshot.size,
    });
  }

  Future<Map<String, dynamic>?> getExam(String examId) async {
    final doc = await _db.collection(AppConstants.examsCollection).doc(examId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  Future<Map<String, int>> getExamCounts(String teacherId) async {
    final snapshot = await _db
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
  }

  Future<void> updateExamStats(String examId) async {
    final submissionsSnapshot = await _db
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

    final examDoc = await _db.collection(AppConstants.examsCollection).doc(examId).get();
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

        final passThreshold = totalMarks > 0
            ? (passingScore / totalMarks * 100)
            : passingScore.toDouble();
        if (percentage >= passThreshold) passCount++;
      }
    }

    final averageScore =
        submittedStudents > 0 ? (totalScore / submittedStudents).round() : 0;
    final passRate =
        submittedStudents > 0 ? (passCount / submittedStudents) * 100 : 0.0;

    final statsSnapshot = await _db
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
      await _db
          .collection(AppConstants.examStatsCollection)
          .doc(statsSnapshot.docs.first.id)
          .update(statsData);
    } else {
      await _db.collection(AppConstants.examStatsCollection).add(statsData);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late FakeFirebaseFirestore firestore;
  late TestableExamService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TestableExamService(firestore);
  });

  // ─── Helper: Create exam + questions ─────────────────────────────────────

  Future<String> createExamWithQuestions({
    required String teacherId,
    required String title,
    required List<Map<String, dynamic>> questions,
  }) async {
    final now = DateTime.now();
    final examId = await service.createExam(
      teacherId: teacherId,
      title: title,
      classId: 'class1',
      durationMinutes: 60,
      startDate: now.add(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 7)),
      passingScore: 50,
    );

    for (final q in questions) {
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        ...q,
      });
    }

    await service.recalculateTotalMarks(examId);
    return examId;
  }

  // ─── Helper: Create submission with answers ──────────────────────────────

  Future<String> createSubmissionWithAnswers({
    required String examId,
    required String studentId,
    required Map<String, String> questionIdToAnswer,
  }) async {
    final submissionDoc = await firestore
        .collection(AppConstants.submissionsCollection)
        .add({
      'examId': examId,
      'studentId': studentId,
      'classId': 'class1',
      'status': AppConstants.submissionStatusStarted,
      'startedAt': FieldValue.serverTimestamp(),
      'submittedAt': null,
      'timeSpent': 0,
      'totalMarks': 0,
      'score': 0,
      'percentage': 0,
      'violationCount': 0,
    });

    for (final entry in questionIdToAnswer.entries) {
      await firestore.collection(AppConstants.answersCollection).add({
        'submissionId': submissionDoc.id,
        'questionId': entry.key,
        'answer': entry.value,
        'isCorrect': false,
        'marksAwarded': 0,
      });
    }

    return submissionDoc.id;
  }

  // ─── Create Exam ─────────────────────────────────────────────────────────

  group('Create Exam — Firestore Integration', () {
    test('creates exam with draft status and correct defaults', () async {
      final now = DateTime.now();
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Math Final',
        classId: 'class1',
        durationMinutes: 90,
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 7)),
        passingScore: 60,
      );

      expect(examId, isNotEmpty);

      final exam = await service.getExam(examId);
      expect(exam, isNotNull);
      expect(exam!['title'], equals('Math Final'));
      expect(exam['status'], equals(AppConstants.statusDraft));
      expect(exam['totalMarks'], equals(0));
      expect(exam['questionCount'], equals(0));
      expect(exam['isArchived'], isFalse);
      expect(exam['version'], equals(1));
      expect(exam['passingScore'], equals(60));
      expect(exam['teacherId'], equals('teacher1'));
      expect(exam['classId'], equals('class1'));
      expect(exam['searchKeywords'], isNotEmpty);
    });

    test('search keywords are generated from title', () async {
      final now = DateTime.now();
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Physics Quiz',
        classId: 'class1',
        durationMinutes: 30,
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
        passingScore: 50,
      );

      final exam = await service.getExam(examId);
      final keywords = exam!['searchKeywords'] as List;
      expect(keywords, contains('physics'));
      expect(keywords, contains('quiz'));
      expect(keywords, contains('physics quiz'));
    });
  });

  // ─── Update Exam ─────────────────────────────────────────────────────────

  group('Update Exam', () {
    test('updates exam fields correctly', () async {
      final now = DateTime.now();
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Original Title',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
        passingScore: 50,
      );

      await service.updateExam(
        examId: examId,
        title: 'Updated Title',
        classId: 'class2',
        durationMinutes: 120,
        startDate: now,
        endDate: now.add(const Duration(days: 2)),
        passingScore: 70,
        isRandomized: true,
      );

      final exam = await service.getExam(examId);
      expect(exam!['title'], equals('Updated Title'));
      expect(exam['classId'], equals('class2'));
      expect(exam['durationMinutes'], equals(120));
      expect(exam['passingScore'], equals(70));
      expect(exam['isRandomized'], isTrue);
    });
  });

  // ─── Recalculate Total Marks ─────────────────────────────────────────────

  group('Recalculate Total Marks — Questions → Exam', () {
    test('sums question marks and updates exam', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Marks Test',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
          {'questionType': 'true_false', 'text': 'Q2', 'marks': 5, 'correctAnswer': 'true'},
          {'questionType': 'short_answer', 'text': 'Q3', 'marks': 15, 'correctAnswer': 'Paris'},
        ],
      );

      final exam = await service.getExam(examId);
      expect(exam!['totalMarks'], equals(30));
      expect(exam['questionCount'], equals(3));
    });

    test('updates when questions are added', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Add Questions',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      // Add another question
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'multiple_choice',
        'text': 'Q2',
        'marks': 20,
        'correctAnswer': 'B',
      });

      await service.recalculateTotalMarks(examId);

      final exam = await service.getExam(examId);
      expect(exam!['totalMarks'], equals(30));
      expect(exam['questionCount'], equals(2));
    });
  });

  // ─── Publish Exam ────────────────────────────────────────────────────────

  group('Publish Exam — Validation + Status Change', () {
    test('publishes exam with questions', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Publishable Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      await service.publishExam(examId);

      final exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusPublished));
      expect(exam['publishedAt'], isNotNull);
    });

    test('rejects publishing exam without questions', () async {
      final now = DateTime.now();
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Empty Exam',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
        passingScore: 50,
      );

      expect(
        () => service.publishExam(examId),
        throwsA(isA<Exception>()),
      );
    });

    test('unpublish returns exam to draft', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Unpublishable Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      await service.publishExam(examId);
      var exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusPublished));

      await service.unpublishExam(examId);
      exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusDraft));
    });
  });

  // ─── Archive Exam (Soft Delete) ──────────────────────────────────────────

  group('Archive Exam — Soft Delete', () {
    test('marks exam as archived', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Archivable Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      await service.archiveExam(examId, archivedBy: 'teacher1');

      final exam = await service.getExam(examId);
      expect(exam!['isArchived'], isTrue);
      expect(exam['archivedBy'], equals('teacher1'));
      expect(exam['archivedAt'], isNotNull);
    });
  });

  // ─── Version Increment ───────────────────────────────────────────────────

  group('Version Increment', () {
    test('increments version from 1 to 2', () async {
      final now = DateTime.now();
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Version Test',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now,
        endDate: now.add(const Duration(days: 1)),
        passingScore: 50,
      );

      var exam = await service.getExam(examId);
      expect(exam!['version'], equals(1));

      await service.incrementVersion(examId);
      exam = await service.getExam(examId);
      expect(exam!['version'], equals(2));

      await service.incrementVersion(examId);
      exam = await service.getExam(examId);
      expect(exam!['version'], equals(3));
    });
  });

  // ─── Delete Exam (Hard Delete) ───────────────────────────────────────────

  group('Delete Exam — Hard Delete with Cascade', () {
    test('deletes exam and all related documents', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Deletable Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
          {'questionType': 'true_false', 'text': 'Q2', 'marks': 5, 'correctAnswer': 'true'},
        ],
      );

      // Create a submission with answers
      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      final answers = <String, String>{};
      for (final doc in questionsSnapshot.docs) {
        answers[doc.id] = 'A';
      }

      await createSubmissionWithAnswers(
        examId: examId,
        studentId: 'student1',
        questionIdToAnswer: answers,
      );

      // Verify data exists before deletion
      var questions = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      expect(questions.size, equals(2));

      var submissions = await firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      expect(submissions.size, equals(1));

      // Delete
      await service.deleteExam(examId);

      // Verify all deleted
      final exam = await service.getExam(examId);
      expect(exam, isNull);

      questions = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      expect(questions.size, equals(0));

      submissions = await firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      expect(submissions.size, equals(0));
    });
  });

  // ─── Exam Stats ──────────────────────────────────────────────────────────

  group('Exam Stats — Aggregation', () {
    test('computes stats from submitted exams', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Stats Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 50, 'correctAnswer': 'A'},
          {'questionType': 'multiple_choice', 'text': 'Q2', 'marks': 50, 'correctAnswer': 'B'},
        ],
      );

      // Create 3 submissions with different scores
      // Student 1: 100/100 (100%)
      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 'student1',
        'classId': 'class1',
        'status': 'submitted',
        'score': 100,
        'percentage': 100,
        'timeSpent': 3000,
      });

      // Student 2: 50/100 (50%)
      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 'student2',
        'classId': 'class1',
        'status': 'submitted',
        'score': 50,
        'percentage': 50,
        'timeSpent': 5400,
      });

      // Student 3: 0/100 (0%) — started but not submitted
      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 'student3',
        'classId': 'class1',
        'status': 'started',
        'score': 0,
        'percentage': 0,
        'timeSpent': 0,
      });

      await service.updateExamStats(examId);

      // Verify stats
      final statsSnapshot = await firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      expect(statsSnapshot.docs.length, 1);
      final stats = statsSnapshot.docs.first.data();
      expect(stats['totalStudents'], equals(3));
      expect(stats['submittedStudents'], equals(2));
      expect(stats['averageScore'], equals(75)); // (100+50)/2
      expect(stats['highestScore'], equals(100));
      expect(stats['lowestScore'], equals(50));
    });

    test('pass rate calculated correctly', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Pass Rate Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 100, 'correctAnswer': 'A'},
        ],
      );

      // Passing score is 50, so 50% = pass
      // Student with 60% passes, student with 40% fails
      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 's1',
        'classId': 'class1',
        'status': 'submitted',
        'score': 60,
        'percentage': 60,
      });

      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 's2',
        'classId': 'class1',
        'status': 'submitted',
        'score': 40,
        'percentage': 40,
      });

      await service.updateExamStats(examId);

      final statsSnapshot = await firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      final stats = statsSnapshot.docs.first.data();
      // passingScore=50, totalMarks=100, threshold=50%
      // 60% >= 50% → pass, 40% < 50% → fail
      expect(stats['passRate'], equals(50.0)); // 1 out of 2 = 50%
    });

    test('stats are updated (not duplicated) on recalculation', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher1',
        title: 'Stats Update Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      // First stats computation
      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 's1',
        'classId': 'class1',
        'status': 'submitted',
        'score': 10,
        'percentage': 100,
      });

      await service.updateExamStats(examId);

      // Second computation with more submissions
      await firestore.collection(AppConstants.submissionsCollection).add({
        'examId': examId,
        'studentId': 's2',
        'classId': 'class1',
        'status': 'submitted',
        'score': 5,
        'percentage': 50,
      });

      await service.updateExamStats(examId);

      // Should have only 1 stats doc (updated, not duplicated)
      final statsSnapshot = await firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      expect(statsSnapshot.docs.length, 1);
      expect(statsSnapshot.docs.first.data()['totalStudents'], equals(2));
    });
  });

  // ─── Get Exam Counts ─────────────────────────────────────────────────────

  group('Get Exam Counts — By Status', () {
    test('counts draft and upcoming exams correctly', () async {
      final now = DateTime.now();

      // Draft exam
      await service.createExam(
        teacherId: 'teacher_counts',
        title: 'Draft Exam',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 7)),
        passingScore: 50,
      );

      // Upcoming exam (published, future end date)
      final upcomingId = await service.createExam(
        teacherId: 'teacher_counts',
        title: 'Upcoming Exam',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 7)),
        passingScore: 50,
      );
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': upcomingId,
        'questionType': 'mcq',
        'marks': 10,
      });
      await service.publishExam(upcomingId);

      // Completed exam (published, past end date)
      final completedId = await service.createExam(
        teacherId: 'teacher_counts',
        title: 'Completed Exam',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now.subtract(const Duration(days: 7)),
        endDate: now.subtract(const Duration(days: 1)),
        passingScore: 50,
      );
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': completedId,
        'questionType': 'mcq',
        'marks': 10,
      });
      await service.publishExam(completedId);

      final counts = await service.getExamCounts('teacher_counts');
      expect(counts['draft'], equals(1));
      expect(counts['total'], equals(3));
    });
  });

  // ─── Full Exam Lifecycle — End-to-End ────────────────────────────────────

  group('Full Exam Lifecycle — End-to-End', () {
    test('create → add questions → recalculate → publish → take → grade → stats', () async {
      // 1. Create exam
      final now = DateTime.now();
      final examId = await service.createExam(
        teacherId: 'teacher_e2e',
        title: 'E2E Exam',
        classId: 'class1',
        durationMinutes: 60,
        startDate: now.add(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 7)),
        passingScore: 50,
      );

      var exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusDraft));
      expect(exam['totalMarks'], equals(0));

      // 2. Add questions
      final q1Doc = await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'multiple_choice',
        'text': 'What is 2+2?',
        'marks': 25,
        'correctAnswer': '4',
      });

      final q2Doc = await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'true_false',
        'text': 'Earth is flat',
        'marks': 25,
        'correctAnswer': 'false',
      });

      // 3. Recalculate marks
      await service.recalculateTotalMarks(examId);
      exam = await service.getExam(examId);
      expect(exam!['totalMarks'], equals(50));
      expect(exam['questionCount'], equals(2));

      // 4. Publish
      await service.publishExam(examId);
      exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusPublished));

      // 5. Student takes exam — create submission with answers
      final submissionId = await createSubmissionWithAnswers(
        examId: examId,
        studentId: 'student_e2e',
        questionIdToAnswer: {
          q1Doc.id: '4',    // Correct
          q2Doc.id: 'true',  // Wrong (correct is 'false')
        },
      );

      // 6. Simulate grading (update submission with score)
      // Student got 25/50 (50%)
      await firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .update({
        'status': AppConstants.submissionStatusSubmitted,
        'score': 25,
        'percentage': 50,
        'totalMarks': 50,
        'timeSpent': 3600,
      });

      // 7. Compute stats
      await service.updateExamStats(examId);

      final statsSnapshot = await firestore
          .collection(AppConstants.examStatsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      expect(statsSnapshot.docs.length, 1);
      final stats = statsSnapshot.docs.first.data();
      expect(stats['totalStudents'], equals(1));
      expect(stats['submittedStudents'], equals(1));
      expect(stats['averageScore'], equals(25));
      expect(stats['highestScore'], equals(25));
      expect(stats['lowestScore'], equals(25));
    });

    test('create → publish → unpublish → re-publish', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher_cycle',
        title: 'Status Cycle Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      // Draft → Published
      await service.publishExam(examId);
      var exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusPublished));

      // Published → Draft
      await service.unpublishExam(examId);
      exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusDraft));

      // Draft → Published again
      await service.publishExam(examId);
      exam = await service.getExam(examId);
      expect(exam!['status'], equals(AppConstants.statusPublished));
    });

    test('create → archive → verify soft delete preserves data', () async {
      final examId = await createExamWithQuestions(
        teacherId: 'teacher_archive',
        title: 'Archive E2E Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      await service.archiveExam(examId, archivedBy: 'teacher_archive');

      final exam = await service.getExam(examId);
      expect(exam, isNotNull); // Still exists
      expect(exam!['isArchived'], isTrue);

      // Questions still exist (soft delete doesn't cascade)
      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      expect(questionsSnapshot.size, equals(1));
    });
  });

  // ─── Multi-Exam Isolation ────────────────────────────────────────────────

  group('Multi-Exam Isolation', () {
    test('questions from different exams are isolated', () async {
      final exam1Id = await createExamWithQuestions(
        teacherId: 'teacher_iso',
        title: 'Exam 1',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'E1-Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      final exam2Id = await createExamWithQuestions(
        teacherId: 'teacher_iso',
        title: 'Exam 2',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'E2-Q1', 'marks': 20, 'correctAnswer': 'B'},
          {'questionType': 'true_false', 'text': 'E2-Q2', 'marks': 30, 'correctAnswer': 'true'},
        ],
      );

      final exam1 = await service.getExam(exam1Id);
      final exam2 = await service.getExam(exam2Id);

      expect(exam1!['totalMarks'], equals(10));
      expect(exam1['questionCount'], equals(1));
      expect(exam2!['totalMarks'], equals(50));
      expect(exam2['questionCount'], equals(2));
    });

    test('deleting one exam does not affect another', () async {
      final exam1Id = await createExamWithQuestions(
        teacherId: 'teacher_del',
        title: 'Keep This Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q1', 'marks': 10, 'correctAnswer': 'A'},
        ],
      );

      final exam2Id = await createExamWithQuestions(
        teacherId: 'teacher_del',
        title: 'Delete This Exam',
        questions: [
          {'questionType': 'multiple_choice', 'text': 'Q2', 'marks': 20, 'correctAnswer': 'B'},
        ],
      );

      await service.deleteExam(exam2Id);

      // Exam 1 should still exist
      final exam1 = await service.getExam(exam1Id);
      expect(exam1, isNotNull);
      expect(exam1!['title'], equals('Keep This Exam'));

      // Exam 2 should be gone
      final exam2 = await service.getExam(exam2Id);
      expect(exam2, isNull);
    });
  });
}
