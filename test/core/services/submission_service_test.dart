import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';

/// Testable version of SubmissionService that accepts a Firestore instance.
/// Tests the auto-grading engine which is the core business logic of the app.
class TestableSubmissionService {
  final FirebaseFirestore _firestore;

  TestableSubmissionService(this._firestore);

  Future<String> startSubmission({
    required String examId,
    required String studentId,
    required String classId,
  }) async {
    try {
      final existingSnapshot = await _firestore
          .collection(AppConstants.submissionsCollection)
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
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

  Future<void> saveAnswer({
    required String submissionId,
    required String questionId,
    required String answer,
  }) async {
    try {
      final existingSnapshot = await _firestore
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: submissionId)
          .where('questionId', isEqualTo: questionId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        await _firestore
            .collection(AppConstants.answersCollection)
            .doc(existingSnapshot.docs.first.id)
            .update({
          'answer': answer,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection(AppConstants.answersCollection).add({
          'submissionId': submissionId,
          'questionId': questionId,
          'answer': answer,
          'isCorrect': false,
          'marksAwarded': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Core grading engine — this is the most critical business logic in the app.
  Future<Map<String, dynamic>> submitExam({
    required String submissionId,
    required String examId,
    required int timeSpent,
  }) async {
    try {
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

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
            isCorrect = studentAnswer == correctAnswer;
          } else if (questionType == AppConstants.questionTypeTrueFalse) {
            isCorrect = studentAnswer == correctAnswer;
          } else if (questionType == AppConstants.questionTypeShortAnswer) {
            isCorrect = studentAnswer.trim().toLowerCase() ==
                correctAnswer.trim().toLowerCase();
          }
        }

        final marksAwarded = isCorrect ? marks : 0;
        score += marksAwarded;

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

      final percentage =
          totalMarks > 0 ? ((score / totalMarks) * 100).round() : 0;

      batch.update(
        _firestore
            .collection(AppConstants.submissionsCollection)
            .doc(submissionId),
        {
          'status': AppConstants.submissionStatusSubmitted,
          'submittedAt': FieldValue.serverTimestamp(),
          'timeSpent': timeSpent,
          'totalMarks': totalMarks,
          'score': score,
          'percentage': percentage,
        },
      );

      await batch.commit();

      return {
        'totalMarks': totalMarks,
        'score': score,
        'percentage': percentage,
      };
    } catch (e) {
      rethrow;
    }
  }

  Future<void> incrementViolationCount(String submissionId) async {
    try {
      await _firestore
          .collection(AppConstants.submissionsCollection)
          .doc(submissionId)
          .update({
        'violationCount': FieldValue.increment(1),
      });

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
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late FakeFirebaseFirestore firestore;
  late TestableSubmissionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TestableSubmissionService(firestore);
  });

  // ─── Helper: Create exam + questions + submission + answers ────────────────

  Future<String> setupExamWithQuestions(List<Map<String, dynamic>> questions) async {
    final examDoc = await firestore.collection(AppConstants.examsCollection).add({
      'title': 'Test Exam',
      'teacherId': 'teacher1',
      'classId': 'class1',
      'status': 'published',
      'totalMarks': questions.fold<int>(0, (sum, q) => sum + ((q['marks'] ?? 0) as int)),
      'passingScore': 50,
    });

    for (final q in questions) {
      await firestore.collection(AppConstants.questionsCollection).add({
        'examId': examDoc.id,
        ...q,
      });
    }

    return examDoc.id;
  }

  Future<String> setupSubmissionWithAnswers(
    String examId,
    String studentId,
    Map<String, String> questionIdToAnswer,
  ) async {
    final submissionId = await service.startSubmission(
      examId: examId,
      studentId: studentId,
      classId: 'class1',
    );

    for (final entry in questionIdToAnswer.entries) {
      await service.saveAnswer(
        submissionId: submissionId,
        questionId: entry.key,
        answer: entry.value,
      );
    }

    return submissionId;
  }

  // ─── startSubmission ───────────────────────────────────────────────────────

  group('startSubmission', () {
    test('creates submission with started status', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      expect(submissionId, isNotEmpty);

      final submission = await service.getSubmission(submissionId);
      expect(submission, isNotNull);
      expect(submission!['examId'], equals('exam1'));
      expect(submission['studentId'], equals('student1'));
      expect(submission['classId'], equals('class1'));
      expect(submission['status'], equals('started'));
      expect(submission['score'], equals(0));
      expect(submission['percentage'], equals(0));
      expect(submission['violationCount'], equals(0));
    });

    test('returns existing submission if one already exists', () async {
      final id1 = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );
      final id2 = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      expect(id1, equals(id2), reason: 'Should return same submission ID');
    });

    test('allows different students to have separate submissions', () async {
      final id1 = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );
      final id2 = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student2',
        classId: 'class1',
      );

      expect(id1, isNot(equals(id2)));
    });
  });

  // ─── saveAnswer ────────────────────────────────────────────────────────────

  group('saveAnswer', () {
    test('creates a new answer document', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      await service.saveAnswer(
        submissionId: submissionId,
        questionId: 'q1',
        answer: 'A',
      );

      final answersSnapshot = await firestore
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: submissionId)
          .where('questionId', isEqualTo: 'q1')
          .get();

      expect(answersSnapshot.docs.length, 1);
      expect(answersSnapshot.docs.first.data()['answer'], equals('A'));
    });

    test('updates existing answer for same question', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      await service.saveAnswer(
        submissionId: submissionId,
        questionId: 'q1',
        answer: 'A',
      );
      await service.saveAnswer(
        submissionId: submissionId,
        questionId: 'q1',
        answer: 'B',
      );

      final answersSnapshot = await firestore
          .collection(AppConstants.answersCollection)
          .where('submissionId', isEqualTo: submissionId)
          .where('questionId', isEqualTo: 'q1')
          .get();

      // Should still be 1 answer (updated, not duplicated)
      expect(answersSnapshot.docs.length, 1);
      expect(answersSnapshot.docs.first.data()['answer'], equals('B'));
    });
  });

  // ─── Grading Engine: MCQ ───────────────────────────────────────────────────

  group('Grading Engine — Multiple Choice', () {
    test('awards full marks for correct MCQ answer', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'What is 2+2?',
          'marks': 10,
          'correctAnswer': '4',
        },
      ]);

      // Get the question ID
      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: '4'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 300,
      );

      expect(result['score'], equals(10));
      expect(result['totalMarks'], equals(10));
      expect(result['percentage'], equals(100));
    });

    test('awards zero for wrong MCQ answer', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Capital of France?',
          'marks': 10,
          'correctAnswer': 'Paris',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'London'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 300,
      );

      expect(result['score'], equals(0));
      expect(result['percentage'], equals(0));
    });

    test('MCQ grading is case-sensitive', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Which option?',
          'marks': 10,
          'correctAnswer': 'Option A',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'option a'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 300,
      );

      // MCQ is exact match — case matters
      expect(result['score'], equals(0));
    });
  });

  // ─── Grading Engine: True/False ────────────────────────────────────────────

  group('Grading Engine — True/False', () {
    test('awards marks for correct True answer', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'true_false',
          'text': 'The Earth is round',
          'marks': 5,
          'correctAnswer': 'true',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'true'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 60,
      );

      expect(result['score'], equals(5));
      expect(result['percentage'], equals(100));
    });

    test('awards zero for wrong False answer', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'true_false',
          'text': 'Water boils at 100°C',
          'marks': 5,
          'correctAnswer': 'true',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'false'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 60,
      );

      expect(result['score'], equals(0));
    });
  });

  // ─── Grading Engine: Short Answer ──────────────────────────────────────────

  group('Grading Engine — Short Answer', () {
    test('awards marks for case-insensitive match', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'short_answer',
          'text': 'What is the capital of Egypt?',
          'marks': 10,
          'correctAnswer': 'Cairo',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'cairo'}, // lowercase
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 120,
      );

      expect(result['score'], equals(10));
      expect(result['percentage'], equals(100));
    });

    test('awards marks for answer with extra whitespace', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'short_answer',
          'text': 'Name the largest planet',
          'marks': 10,
          'correctAnswer': 'Jupiter',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: '  jupiter  '}, // leading/trailing spaces
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 120,
      );

      expect(result['score'], equals(10));
    });

    test('awards zero for wrong short answer', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'short_answer',
          'text': 'What is H2O?',
          'marks': 10,
          'correctAnswer': 'Water',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'Salt'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 120,
      );

      expect(result['score'], equals(0));
    });
  });

  // ─── Grading Engine: Mixed Questions ───────────────────────────────────────

  group('Grading Engine — Mixed Exam', () {
    test('correctly grades a mixed question exam', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': '2+2?',
          'marks': 10,
          'correctAnswer': '4',
        },
        {
          'questionType': 'true_false',
          'text': 'Earth is flat',
          'marks': 5,
          'correctAnswer': 'false',
        },
        {
          'questionType': 'short_answer',
          'text': 'Capital of France?',
          'marks': 15,
          'correctAnswer': 'Paris',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // Answer MCQ correctly, T/F correctly, short answer wrong
      final answers = <String, String>{};
      for (final doc in questionsSnapshot.docs) {
        final type = doc.data()['questionType'] as String;
        if (type == 'multiple_choice') {
          answers[doc.id] = '4'; // Correct
        } else if (type == 'true_false') {
          answers[doc.id] = 'false'; // Correct
        } else {
          answers[doc.id] = 'London'; // Wrong
        }
      }

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        answers,
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 600,
      );

      // MCQ: 10/10, T/F: 5/5, Short: 0/15 = 15/30 = 50%
      expect(result['score'], equals(15));
      expect(result['totalMarks'], equals(30));
      expect(result['percentage'], equals(50));
    });

    test('unanswered questions score zero', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Q1',
          'marks': 10,
          'correctAnswer': 'A',
        },
        {
          'questionType': 'multiple_choice',
          'text': 'Q2',
          'marks': 10,
          'correctAnswer': 'B',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // Only answer Q1, skip Q2
      final firstQuestionId = questionsSnapshot.docs.first.id;
      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {firstQuestionId: 'A'}, // Only Q1 answered
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 300,
      );

      expect(result['score'], equals(10));
      expect(result['totalMarks'], equals(20));
      expect(result['percentage'], equals(50));
    });

    test('perfect score gives 100%', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Q1',
          'marks': 25,
          'correctAnswer': 'A',
        },
        {
          'questionType': 'true_false',
          'text': 'Q2',
          'marks': 25,
          'correctAnswer': 'true',
        },
        {
          'questionType': 'short_answer',
          'text': 'Q3',
          'marks': 25,
          'correctAnswer': 'Answer',
        },
        {
          'questionType': 'multiple_choice',
          'text': 'Q4',
          'marks': 25,
          'correctAnswer': 'D',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      final answers = <String, String>{};
      for (final doc in questionsSnapshot.docs) {
        final type = doc.data()['questionType'] as String;
        final correctAnswer = doc.data()['correctAnswer'] as String;
        answers[doc.id] = correctAnswer;
      }

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        answers,
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 1800,
      );

      expect(result['score'], equals(100));
      expect(result['totalMarks'], equals(100));
      expect(result['percentage'], equals(100));
    });

    test('zero score gives 0%', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Q1',
          'marks': 10,
          'correctAnswer': 'A',
        },
        {
          'questionType': 'true_false',
          'text': 'Q2',
          'marks': 10,
          'correctAnswer': 'true',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // All wrong
      final answers = <String, String>{};
      for (final doc in questionsSnapshot.docs) {
        answers[doc.id] = 'WRONG';
      }

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        answers,
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 60,
      );

      expect(result['score'], equals(0));
      expect(result['percentage'], equals(0));
    });

    test('percentage rounds correctly for non-divisible scores', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Q1',
          'marks': 7,
          'correctAnswer': 'A',
        },
        {
          'questionType': 'multiple_choice',
          'text': 'Q2',
          'marks': 3,
          'correctAnswer': 'B',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();

      // Answer Q1 correctly (7/10 = 70%)
      final firstQuestionId = questionsSnapshot.docs.first.id;
      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {firstQuestionId: 'A'},
      );

      final result = await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 300,
      );

      expect(result['score'], equals(7));
      expect(result['totalMarks'], equals(10));
      expect(result['percentage'], equals(70));
    });
  });

  // ─── Violation Threshold ───────────────────────────────────────────────────

  group('Violation Threshold', () {
    test('flags submission after 3 violations (threshold)', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      // Increment 3 times (violationThreshold = 3)
      await service.incrementViolationCount(submissionId);
      await service.incrementViolationCount(submissionId);
      await service.incrementViolationCount(submissionId);

      final submission = await service.getSubmission(submissionId);
      expect(submission!['violationCount'], equals(3));
      expect(submission['status'], equals('flagged'));
    });

    test('does not flag submission before threshold', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      // Increment 2 times (below threshold of 3)
      await service.incrementViolationCount(submissionId);
      await service.incrementViolationCount(submissionId);

      final submission = await service.getSubmission(submissionId);
      expect(submission!['violationCount'], equals(2));
      expect(submission['status'], equals('started'));
    });

    test('violation count increments from zero', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      await service.incrementViolationCount(submissionId);

      final submission = await service.getSubmission(submissionId);
      expect(submission!['violationCount'], equals(1));
    });
  });

  // ─── Submission Status Updates ─────────────────────────────────────────────

  group('Submission Status', () {
    test('submission starts with "started" status', () async {
      final submissionId = await service.startSubmission(
        examId: 'exam1',
        studentId: 'student1',
        classId: 'class1',
      );

      final submission = await service.getSubmission(submissionId);
      expect(submission!['status'], equals('started'));
    });

    test('submission status changes to "submitted" after submitExam', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Q1',
          'marks': 10,
          'correctAnswer': 'A',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'A'},
      );

      await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 300,
      );

      final submission = await service.getSubmission(submissionId);
      expect(submission!['status'], equals('submitted'));
    });

    test('submission records time spent', () async {
      final examId = await setupExamWithQuestions([
        {
          'questionType': 'multiple_choice',
          'text': 'Q1',
          'marks': 10,
          'correctAnswer': 'A',
        },
      ]);

      final questionsSnapshot = await firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .get();
      final questionId = questionsSnapshot.docs.first.id;

      final submissionId = await setupSubmissionWithAnswers(
        examId,
        'student1',
        {questionId: 'A'},
      );

      await service.submitExam(
        submissionId: submissionId,
        examId: examId,
        timeSpent: 540, // 9 minutes
      );

      final submission = await service.getSubmission(submissionId);
      expect(submission!['timeSpent'], equals(540));
    });
  });
}
