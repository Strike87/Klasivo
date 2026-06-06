import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'exam_service.dart';

class QuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> addMultipleChoiceQuestion({
    required String examId,
    required String questionText,
    required List<String> options,
    required String correctAnswer,
    required int marks,
    required int order,
    String? imageUrl,
    String? difficulty,
    String? bankQuestionId,
  }) async {
    try {
      final data = <String, dynamic>{
        'examId': examId,
        'questionType': AppConstants.questionTypeMultipleChoice,
        'questionText': questionText,
        'options': options,
        'correctAnswer': correctAnswer,
        'marks': marks,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (imageUrl != null) data['imageUrl'] = imageUrl;
      if (difficulty != null) data['difficulty'] = difficulty;
      if (bankQuestionId != null) data['bankQuestionId'] = bankQuestionId;

      final docRef = await _firestore.collection(AppConstants.questionsCollection).add(data);
      await ExamService().recalculateTotalMarks(examId);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> addTrueFalseQuestion({
    required String examId,
    required String questionText,
    required bool correctAnswer,
    required int marks,
    required int order,
    String? imageUrl,
    String? difficulty,
    String? bankQuestionId,
  }) async {
    try {
      final data = <String, dynamic>{
        'examId': examId,
        'questionType': AppConstants.questionTypeTrueFalse,
        'questionText': questionText,
        'options': ['True', 'False'],
        'correctAnswer': correctAnswer ? 'True' : 'False',
        'marks': marks,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (imageUrl != null) data['imageUrl'] = imageUrl;
      if (difficulty != null) data['difficulty'] = difficulty;
      if (bankQuestionId != null) data['bankQuestionId'] = bankQuestionId;

      final docRef = await _firestore.collection(AppConstants.questionsCollection).add(data);
      await ExamService().recalculateTotalMarks(examId);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> addShortAnswerQuestion({
    required String examId,
    required String questionText,
    required String correctAnswer,
    required int marks,
    required int order,
    String? imageUrl,
    String? difficulty,
    String? bankQuestionId,
  }) async {
    try {
      final data = <String, dynamic>{
        'examId': examId,
        'questionType': AppConstants.questionTypeShortAnswer,
        'questionText': questionText,
        'options': [],
        'correctAnswer': correctAnswer,
        'marks': marks,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (imageUrl != null) data['imageUrl'] = imageUrl;
      if (difficulty != null) data['difficulty'] = difficulty;
      if (bankQuestionId != null) data['bankQuestionId'] = bankQuestionId;

      final docRef = await _firestore.collection(AppConstants.questionsCollection).add(data);
      await ExamService().recalculateTotalMarks(examId);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateQuestion({
    required String questionId,
    required String examId,
    required String questionText,
    String? questionType,
    List<String>? options,
    String? correctAnswer,
    int? marks,
    int? order,
    String? imageUrl,
    String? difficulty,
  }) async {
    try {
      final data = <String, dynamic>{
        'questionText': questionText,
      };
      if (questionType != null) data['questionType'] = questionType;
      if (options != null) data['options'] = options;
      if (correctAnswer != null) data['correctAnswer'] = correctAnswer;
      if (marks != null) data['marks'] = marks;
      if (order != null) data['order'] = order;
      if (imageUrl != null) data['imageUrl'] = imageUrl;
      if (difficulty != null) data['difficulty'] = difficulty;

      await _firestore
          .collection(AppConstants.questionsCollection)
          .doc(questionId)
          .update(data);

      await ExamService().recalculateTotalMarks(examId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteQuestion(String questionId, String examId) async {
    try {
      await _firestore
          .collection(AppConstants.questionsCollection)
          .doc(questionId)
          .delete();

      await _reorderQuestions(examId);
      await ExamService().recalculateTotalMarks(examId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _reorderQuestions(String examId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .orderBy('order')
          .get();

      final batch = _firestore.batch();
      for (int i = 0; i < snapshot.docs.length; i++) {
        batch.update(snapshot.docs[i].reference, {'order': i});
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> swapQuestionOrder({
    required String examId,
    required String questionId1,
    required int order1,
    required String questionId2,
    required int order2,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.update(
        _firestore.collection(AppConstants.questionsCollection).doc(questionId1),
        {'order': order2},
      );
      batch.update(
        _firestore.collection(AppConstants.questionsCollection).doc(questionId2),
        {'order': order1},
      );
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getQuestionsStream(String examId) {
    return _firestore
        .collection(AppConstants.questionsCollection)
        .where('examId', isEqualTo: examId)
        .orderBy('order')
        .snapshots();
  }

  Future<int> getNextOrder(String examId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where('examId', isEqualTo: examId)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;
      return ((snapshot.docs.first.data()['order'] as int?) ?? 0) + 1;
    } catch (e) {
      return 0;
    }
  }
}
