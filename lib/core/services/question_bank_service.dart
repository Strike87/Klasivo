import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class QuestionBankService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> addQuestionToBank({
    required String teacherId,
    String? stageId,
    String? gradeId,
    String? classId,
    required String subject,
    required String type,
    required String difficulty,
    required String text,
    List<String>? options,
    String? correctAnswer,
    int marks = 1,
    List<String>? tags,
    String? imageUrl,
    String organizationId = 'default',
  }) async {
    try {
      final docRef = await _firestore.collection(AppConstants.questionBankCollection).add({
        'teacherId': teacherId,
        'stageId': stageId,
        'gradeId': gradeId,
        'classId': classId,
        'subject': subject,
        'type': type,
        'difficulty': difficulty,
        'text': text,
        'options': options ?? [],
        'correctAnswer': correctAnswer ?? '',
        'marks': marks,
        'tags': tags ?? [],
        'imageUrl': imageUrl,
        'usageCount': 0,
        'organizationId': organizationId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateQuestionInBank({
    required String questionId,
    String? subject,
    String? type,
    String? difficulty,
    String? text,
    List<String>? options,
    String? correctAnswer,
    int? marks,
    List<String>? tags,
    String? imageUrl,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (subject != null) data['subject'] = subject;
      if (type != null) data['type'] = type;
      if (difficulty != null) data['difficulty'] = difficulty;
      if (text != null) data['text'] = text;
      if (options != null) data['options'] = options;
      if (correctAnswer != null) data['correctAnswer'] = correctAnswer;
      if (marks != null) data['marks'] = marks;
      if (tags != null) data['tags'] = tags;
      if (imageUrl != null) data['imageUrl'] = imageUrl;

      await _firestore.collection(AppConstants.questionBankCollection).doc(questionId).update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> incrementUsageCount(String questionId) async {
    try {
      await _firestore.collection(AppConstants.questionBankCollection).doc(questionId).update({
        'usageCount': FieldValue.increment(1),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteQuestionFromBank(String questionId) async {
    try {
      await _firestore.collection(AppConstants.questionBankCollection).doc(questionId).delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getQuestionBankStream(String teacherId) {
    return _firestore
        .collection(AppConstants.questionBankCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot> searchQuestions({
    required String teacherId,
    String? subject,
    String? difficulty,
    String? type,
    String? gradeId,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.questionBankCollection)
          .where('teacherId', isEqualTo: teacherId);

      if (subject != null && subject.isNotEmpty) {
        query = query.where('subject', isEqualTo: subject);
      }
      if (difficulty != null && difficulty.isNotEmpty) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }
      if (type != null && type.isNotEmpty) {
        query = query.where('type', isEqualTo: type);
      }
      if (gradeId != null && gradeId.isNotEmpty) {
        query = query.where('gradeId', isEqualTo: gradeId);
      }

      return await query.get();
    } catch (e) {
      rethrow;
    }
  }

  /// Import a question from the bank into an exam (creates a copy in questions collection)
  Future<String> importQuestionToExam({
    required String bankQuestionId,
    required String examId,
    required int order,
  }) async {
    try {
      // Fetch the bank question
      final bankDoc = await _firestore
          .collection(AppConstants.questionBankCollection)
          .doc(bankQuestionId)
          .get();

      if (!bankDoc.exists) {
        throw Exception('Question not found in bank');
      }

      final bankData = bankDoc.data()!;

      // Create a copy in the questions collection
      final docRef = await _firestore.collection(AppConstants.questionsCollection).add({
        'examId': examId,
        'questionType': bankData['type'] ?? AppConstants.questionTypeMultipleChoice,
        'questionText': bankData['text'] ?? '',
        'options': bankData['options'] ?? [],
        'correctAnswer': bankData['correctAnswer'] ?? '',
        'marks': bankData['marks'] ?? 1,
        'order': order,
        'imageUrl': bankData['imageUrl'],
        'difficulty': bankData['difficulty'],
        'bankQuestionId': bankQuestionId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment usage count
      await incrementUsageCount(bankQuestionId);

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }
}
