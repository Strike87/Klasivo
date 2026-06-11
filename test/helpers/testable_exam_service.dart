import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';
import 'package:klasivo/core/services/search_keyword_service.dart';

/// Testable version of ExamService that accepts a Firestore instance.
/// This allows us to inject FakeFirebaseFirestore for unit testing
/// without modifying the production service constructor.
class TestableExamService {
  final FirebaseFirestore _firestore;
  final SearchKeywordService _searchKeywordService = SearchKeywordService();

  TestableExamService(this._firestore);

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
    try {
      final keywords = _searchKeywordService.generateKeywords(title);

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
        'organizationId': organizationId,
        'version': 1,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'searchKeywords': keywords,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
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
        throw Exception(
            'Cannot publish exam without questions. Add at least one question.');
      }

      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'status': AppConstants.statusPublished,
        'publishedAt': FieldValue.serverTimestamp(),
      });
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
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archiveExam(String examId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': archivedBy,
      });
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

  Future<void> deleteExam(String examId) async {
    try {
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

      batch.delete(
        _firestore.collection(AppConstants.examsCollection).doc(examId),
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

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

  // ─── createExam ────────────────────────────────────────────────────────────

  group('createExam', () {
    test('creates exam with draft status', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Math Final',
        classId: 'class1',
        durationMinutes: 60,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      expect(examId, isNotEmpty);

      final exam = await service.getExam(examId);
      expect(exam, isNotNull);
      expect(exam!['status'], equals('draft'));
      expect(exam['title'], equals('Math Final'));
      expect(exam['teacherId'], equals('teacher1'));
      expect(exam['classId'], equals('class1'));
      expect(exam['durationMinutes'], equals(60));
      expect(exam['passingScore'], equals(50));
      expect(exam['totalMarks'], equals(0));
      expect(exam['questionCount'], equals(0));
      expect(exam['version'], equals(1));
      expect(exam['isArchived'], equals(false));
    });

    test('creates exam with default organizationId', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Science Quiz',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 60,
      );

      final exam = await service.getExam(examId);
      expect(exam!['organizationId'], equals('default'));
    });

    test('creates exam with custom organizationId', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'History Test',
        classId: 'class1',
        durationMinutes: 45,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 40,
        organizationId: 'org123',
      );

      final exam = await service.getExam(examId);
      expect(exam!['organizationId'], equals('org123'));
    });

    test('creates exam with randomized and retake flags', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Randomized Exam',
        classId: 'class1',
        durationMinutes: 60,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
        isRandomized: true,
        allowRetake: true,
      );

      final exam = await service.getExam(examId);
      expect(exam!['isRandomized'], equals(true));
      expect(exam['allowRetake'], equals(true));
    });

    test('includes search keywords from title', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Biology Chapter 5',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      final exam = await service.getExam(examId);
      final keywords = exam!['searchKeywords'] as List;
      expect(keywords, isNotEmpty);
      expect(keywords, contains('biology'));
      expect(keywords, contains('bi'));
    });

    test('creates multiple exams for same teacher', () async {
      final id1 = await service.createExam(
        teacherId: 'teacher1',
        title: 'Exam 1',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );
      final id2 = await service.createExam(
        teacherId: 'teacher1',
        title: 'Exam 2',
        classId: 'class1',
        durationMinutes: 60,
        startDate: DateTime(2025, 2, 1),
        endDate: DateTime(2025, 2, 2),
        passingScore: 60,
      );

      expect(id1, isNot(equals(id2)));

      final counts = await service.getExamCounts('teacher1');
      expect(counts['total'], equals(2));
      expect(counts['draft'], equals(2));
    });
  });

  // ─── publishExam ───────────────────────────────────────────────────────────

  group('publishExam', () {
    test('throws if exam has no questions', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Empty Exam',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      expect(
        () => service.publishExam(examId),
        throwsA(isA<Exception>()),
      );
    });

    test('publishes exam when it has questions', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Exam With Questions',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      // Add a question
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'multiple_choice',
        'text': 'What is 2+2?',
        'marks': 10,
        'correctAnswer': '4',
      });

      await service.publishExam(examId);

      final exam = await service.getExam(examId);
      expect(exam!['status'], equals('published'));
    });
  });

  // ─── unpublishExam ─────────────────────────────────────────────────────────

  group('unpublishExam', () {
    test('reverts published exam back to draft', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Unpublish Test',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      // Add question and publish
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'multiple_choice',
        'text': 'Question',
        'marks': 10,
        'correctAnswer': 'A',
      });
      await service.publishExam(examId);

      // Unpublish
      await service.unpublishExam(examId);

      final exam = await service.getExam(examId);
      expect(exam!['status'], equals('draft'));
    });
  });

  // ─── archiveExam ───────────────────────────────────────────────────────────

  group('archiveExam', () {
    test('marks exam as archived', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Archive Test',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      await service.archiveExam(examId, archivedBy: 'teacher1');

      final exam = await service.getExam(examId);
      expect(exam!['isArchived'], equals(true));
      expect(exam['archivedBy'], equals('teacher1'));
    });
  });

  // ─── recalculateTotalMarks ─────────────────────────────────────────────────

  group('recalculateTotalMarks', () {
    test('sums marks from all questions', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Marks Test',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      // Add 3 questions with marks: 10, 20, 15
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'multiple_choice',
        'text': 'Q1',
        'marks': 10,
      });
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'true_false',
        'text': 'Q2',
        'marks': 20,
      });
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'short_answer',
        'text': 'Q3',
        'marks': 15,
      });

      await service.recalculateTotalMarks(examId);

      final exam = await service.getExam(examId);
      expect(exam!['totalMarks'], equals(45));
      expect(exam['questionCount'], equals(3));
    });

    test('handles exam with no questions', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'No Questions',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      await service.recalculateTotalMarks(examId);

      final exam = await service.getExam(examId);
      expect(exam!['totalMarks'], equals(0));
      expect(exam['questionCount'], equals(0));
    });
  });

  // ─── getExamCounts ─────────────────────────────────────────────────────────

  group('getExamCounts', () {
    test('counts draft exams correctly', () async {
      await service.createExam(
        teacherId: 'teacher1',
        title: 'Draft 1',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );
      await service.createExam(
        teacherId: 'teacher1',
        title: 'Draft 2',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      final counts = await service.getExamCounts('teacher1');
      expect(counts['draft'], equals(2));
      expect(counts['total'], equals(2));
      expect(counts['upcoming'], equals(0));
      expect(counts['completed'], equals(0));
    });

    test('counts completed exams (past end date)', () async {
      // Create an exam with a published status and past end date
      await firestore.collection(AppConstants.examsCollection).add({
        'teacherId': 'teacher1',
        'title': 'Completed Exam',
        'classId': 'class1',
        'status': 'published',
        'endDate': DateTime(2020, 1, 1), // Past
        'durationMinutes': 30,
        'passingScore': 50,
      });

      final counts = await service.getExamCounts('teacher1');
      expect(counts['completed'], equals(1));
      expect(counts['total'], equals(1));
    });

    test('only counts exams for the specified teacher', () async {
      await service.createExam(
        teacherId: 'teacher1',
        title: 'T1 Exam',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );
      await service.createExam(
        teacherId: 'teacher2',
        title: 'T2 Exam',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      final counts = await service.getExamCounts('teacher1');
      expect(counts['total'], equals(1));
    });
  });

  // ─── deleteExam ────────────────────────────────────────────────────────────

  group('deleteExam', () {
    test('removes exam document', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Delete Me',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      await service.deleteExam(examId);

      final exam = await service.getExam(examId);
      expect(exam, isNull);
    });

    test('removes associated questions', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Delete With Questions',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': 'multiple_choice',
        'text': 'Q1',
        'marks': 10,
      });

      await service.deleteExam(examId);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      expect(questionsSnapshot.docs, isEmpty);
    });
  });

  // ─── incrementVersion ──────────────────────────────────────────────────────

  group('incrementVersion', () {
    test('increments exam version by 1', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Version Test',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      // Initial version should be 1
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

  // ─── getExam ───────────────────────────────────────────────────────────────

  group('getExam', () {
    test('returns null for non-existent exam', () async {
      final exam = await service.getExam('nonexistent-id');
      expect(exam, isNull);
    });

    test('returns exam data with id included', () async {
      final examId = await service.createExam(
        teacherId: 'teacher1',
        title: 'Fetch Test',
        classId: 'class1',
        durationMinutes: 30,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 1, 2),
        passingScore: 50,
      );

      final exam = await service.getExam(examId);
      expect(exam, isNotNull);
      expect(exam!['id'], equals(examId));
      expect(exam['title'], equals('Fetch Test'));
    });
  });
}
