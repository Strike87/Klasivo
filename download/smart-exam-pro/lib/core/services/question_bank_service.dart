import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing the Question Bank - a reusable library of questions
/// that can be imported into any exam. Tracks usageCount per question.
class QuestionBankService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== CRUD ====================

  /// Add a question to the question bank
  Future<String> addQuestion({
    required String teacherId,
    String? stageId,
    String? gradeId,
    String? classId,
    required String subject,
    required String type, // 'mcq', 'true_false', 'short_answer'
    required String difficulty, // 'easy', 'medium', 'hard'
    required String text,
    List<String>? options,
    required String correctAnswer,
    List<String>? tags,
    int marks = 1,
  }) async {
    final docRef = _firestore.collection('question_bank').doc();
    await docRef.set({
      'id': docRef.id,
      'institutionId': 'default',
      'teacherId': teacherId,
      'stageId': stageId,
      'gradeId': gradeId,
      'classId': classId,
      'subject': subject,
      'type': type,
      'difficulty': difficulty,
      'text': text,
      'options': options ?? [],
      'correctAnswer': correctAnswer,
      'tags': tags ?? [],
      'marks': marks,
      'usageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Update a question in the bank
  Future<void> updateQuestion({
    required String questionId,
    String? subject,
    String? type,
    String? difficulty,
    String? text,
    List<String>? options,
    String? correctAnswer,
    List<String>? tags,
    int? marks,
  }) async {
    final updates = <String, dynamic>{};

    if (subject != null) updates['subject'] = subject;
    if (type != null) updates['type'] = type;
    if (difficulty != null) updates['difficulty'] = difficulty;
    if (text != null) updates['text'] = text;
    if (options != null) updates['options'] = options;
    if (correctAnswer != null) updates['correctAnswer'] = correctAnswer;
    if (tags != null) updates['tags'] = tags;
    if (marks != null) updates['marks'] = marks;

    if (updates.isNotEmpty) {
      await _firestore.collection('question_bank').doc(questionId).update(updates);
    }
  }

  /// Delete a question from the bank
  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('question_bank').doc(questionId).delete();
  }

  /// Get a single question from the bank
  Future<Map<String, dynamic>?> getQuestion(String questionId) async {
    final doc = await _firestore.collection('question_bank').doc(questionId).get();
    return doc.exists ? doc.data() : null;
  }

  // ==================== STREAMS ====================

  /// Stream all bank questions for a teacher
  Stream<QuerySnapshot> getQuestionsStream(String teacherId) {
    return _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream bank questions filtered by subject
  Stream<QuerySnapshot> getQuestionsBySubject(String teacherId, String subject) {
    return _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .where('subject', isEqualTo: subject)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream bank questions filtered by difficulty
  Stream<QuerySnapshot> getQuestionsByDifficulty(String teacherId, String difficulty) {
    return _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .where('difficulty', isEqualTo: difficulty)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream bank questions filtered by type
  Stream<QuerySnapshot> getQuestionsByType(String teacherId, String type) {
    return _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream bank questions filtered by subject and difficulty
  Stream<QuerySnapshot> getQuestionsBySubjectAndDifficulty(
    String teacherId,
    String subject,
    String difficulty,
  ) {
    return _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .where('subject', isEqualTo: subject)
        .where('difficulty', isEqualTo: difficulty)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ==================== SEARCH ====================

  /// Search bank questions by text (client-side filtering)
  /// Firestore doesn't support full-text search, so we fetch all and filter
  Future<List<Map<String, dynamic>>> searchQuestions({
    required String teacherId,
    required String query,
    String? subject,
    String? difficulty,
    String? type,
  }) async {
    Query queryRef = _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId);

    if (subject != null && subject.isNotEmpty) {
      queryRef = queryRef.where('subject', isEqualTo: subject);
    }
    if (difficulty != null && difficulty.isNotEmpty) {
      queryRef = queryRef.where('difficulty', isEqualTo: difficulty);
    }
    if (type != null && type.isNotEmpty) {
      queryRef = queryRef.where('type', isEqualTo: type);
    }

    final snapshot = await queryRef.get();

    if (query.trim().isEmpty) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }

    // Client-side text search
    final lowerQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .where((data) {
      final text = (data['text'] as String? ?? '').toLowerCase();
      final tags = (data['tags'] as List<dynamic>? ?? [])
          .map((t) => t.toString().toLowerCase())
          .toList();
      final subjectStr = (data['subject'] as String? ?? '').toLowerCase();

      return text.contains(lowerQuery) ||
          tags.any((t) => t.contains(lowerQuery)) ||
          subjectStr.contains(lowerQuery);
    }).toList();
  }

  // ==================== IMPORT TO EXAM ====================

  /// Import a single question from the bank into an exam
  /// Increments usageCount on the bank question
  Future<String> importToExam({
    required String bankQuestionId,
    required String examId,
    int? order,
  }) async {
    // Fetch the bank question
    final bankDoc = await _firestore.collection('question_bank').doc(bankQuestionId).get();
    if (!bankDoc.exists) throw Exception('Question not found in bank');

    final bankData = bankDoc.data()!;

    // Get next order if not provided
    int nextOrder = order ?? 0;
    if (order == null) {
      final existing = await _firestore
          .collection('questions')
          .where('examId', isEqualTo: examId)
          .orderBy('order', descending: true)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        nextOrder = (existing.docs.first.data()['order'] as int? ?? 0) + 1;
      }
    }

    // Create a copy in the exam's questions collection
    final docRef = _firestore.collection('questions').doc();
    await docRef.set({
      'id': docRef.id,
      'examId': examId,
      'institutionId': bankData['institutionId'] ?? 'default',
      'questionType': bankData['type'] ?? 'mcq',
      'questionText': bankData['text'] ?? '',
      'options': bankData['options'] ?? [],
      'correctAnswer': bankData['correctAnswer'] ?? '',
      'marks': bankData['marks'] ?? 1,
      'order': nextOrder,
      'difficulty': bankData['difficulty'] ?? 'medium',
      'tags': bankData['tags'] ?? [],
      'imageUrl': null,
      'bankQuestionId': bankQuestionId, // Reference back to bank
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment usageCount on bank question
    await _firestore.collection('question_bank').doc(bankQuestionId).update({
      'usageCount': FieldValue.increment(1),
    });

    // Recalculate exam total marks
    await _recalculateExamTotals(examId);

    return docRef.id;
  }

  /// Import multiple questions from bank into an exam at once
  /// Returns list of created question IDs
  Future<List<String>> importMultipleToExam({
    required List<String> bankQuestionIds,
    required String examId,
  }) async {
    final List<String> createdIds = [];

    // Get current max order
    int nextOrder = 0;
    final existing = await _firestore
        .collection('questions')
        .where('examId', isEqualTo: examId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      nextOrder = (existing.docs.first.data()['order'] as int? ?? 0) + 1;
    }

    // Fetch all bank questions
    for (int i = 0; i < bankQuestionIds.length; i++) {
      final bankDoc = await _firestore.collection('question_bank').doc(bankQuestionIds[i]).get();
      if (!bankDoc.exists) continue;

      final bankData = bankDoc.data()!;

      final docRef = _firestore.collection('questions').doc();
      await docRef.set({
        'id': docRef.id,
        'examId': examId,
        'institutionId': bankData['institutionId'] ?? 'default',
        'questionType': bankData['type'] ?? 'mcq',
        'questionText': bankData['text'] ?? '',
        'options': bankData['options'] ?? [],
        'correctAnswer': bankData['correctAnswer'] ?? '',
        'marks': bankData['marks'] ?? 1,
        'order': nextOrder + i,
        'difficulty': bankData['difficulty'] ?? 'medium',
        'tags': bankData['tags'] ?? [],
        'imageUrl': null,
        'bankQuestionId': bankQuestionIds[i],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment usageCount
      await _firestore.collection('question_bank').doc(bankQuestionIds[i]).update({
        'usageCount': FieldValue.increment(1),
      });

      createdIds.add(docRef.id);
    }

    if (createdIds.isNotEmpty) {
      await _recalculateExamTotals(examId);
    }

    return createdIds;
  }

  /// Import random questions from bank into an exam (for randomized exams)
  /// Filters by subject/difficulty and picks [count] random questions
  Future<List<String>> importRandomToExam({
    required String teacherId,
    required String examId,
    required int count,
    String? subject,
    String? difficulty,
  }) async {
    // Build query
    Query queryRef = _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId);

    if (subject != null) {
      queryRef = queryRef.where('subject', isEqualTo: subject);
    }
    if (difficulty != null) {
      queryRef = queryRef.where('difficulty', isEqualTo: difficulty);
    }

    final snapshot = await queryRef.get();
    final allQuestions = snapshot.docs.toList();

    if (allQuestions.length < count) {
      throw Exception('Not enough questions in bank. Found ${allQuestions.length}, need $count');
    }

    // Shuffle and pick
    final random = Random();
    final shuffled = List.of(allQuestions)..shuffle(random);
    final selected = shuffled.take(count).toList();

    // Get current max order
    int nextOrder = 0;
    final existing = await _firestore
        .collection('questions')
        .where('examId', isEqualTo: examId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      nextOrder = (existing.docs.first.data()['order'] as int? ?? 0) + 1;
    }

    final batch = _firestore.batch();
    final List<String> createdIds = [];

    for (int i = 0; i < selected.length; i++) {
      final bankData = selected[i].data() as Map<String, dynamic>;
      final bankId = selected[i].id;

      final docRef = _firestore.collection('questions').doc();
      batch.set(docRef, {
        'id': docRef.id,
        'examId': examId,
        'institutionId': bankData['institutionId'] ?? 'default',
        'questionType': bankData['type'] ?? 'mcq',
        'questionText': bankData['text'] ?? '',
        'options': bankData['options'] ?? [],
        'correctAnswer': bankData['correctAnswer'] ?? '',
        'marks': bankData['marks'] ?? 1,
        'order': nextOrder + i,
        'difficulty': bankData['difficulty'] ?? 'medium',
        'tags': bankData['tags'] ?? [],
        'imageUrl': null,
        'bankQuestionId': bankId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Increment usageCount
      batch.update(
        _firestore.collection('question_bank').doc(bankId),
        {'usageCount': FieldValue.increment(1)},
      );

      createdIds.add(docRef.id);
    }

    await batch.commit();

    if (createdIds.isNotEmpty) {
      await _recalculateExamTotals(examId);
    }

    return createdIds;
  }

  // ==================== UTILITIES ====================

  /// Get unique subjects for a teacher (for filter dropdown)
  Future<List<String>> getSubjects(String teacherId) async {
    final snapshot = await _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final subjects = <String>{};
    for (final doc in snapshot.docs) {
      final subject = doc.data()['subject'] as String?;
      if (subject != null && subject.isNotEmpty) {
        subjects.add(subject);
      }
    }
    return subjects.toList()..sort();
  }

  /// Get total question count for a teacher
  Future<int> getTotalCount(String teacherId) async {
    final snapshot = await _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .get();
    return snapshot.docs.length;
  }

  /// Get count by subject
  Future<Map<String, int>> getCountBySubject(String teacherId) async {
    final snapshot = await _firestore
        .collection('question_bank')
        .where('teacherId', isEqualTo: teacherId)
        .get();

    final Map<String, int> counts = {};
    for (final doc in snapshot.docs) {
      final subject = doc.data()['subject'] as String? ?? 'General';
      counts[subject] = (counts[subject] ?? 0) + 1;
    }
    return counts;
  }

  /// Recalculate exam total marks and question count
  Future<void> _recalculateExamTotals(String examId) async {
    final questions = await _firestore
        .collection('questions')
        .where('examId', isEqualTo: examId)
        .get();

    int totalMarks = 0;
    for (final doc in questions.docs) {
      totalMarks += (doc.data()['marks'] as int? ?? 1);
    }

    await _firestore.collection('exams').doc(examId).update({
      'totalMarks': totalMarks,
      'questionCount': questions.docs.length,
    });
  }
}
