import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing exam instances - per-student snapshots of exams
/// with randomized question order for anti-cheating.
class ExamInstanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create an exam instance for a student
  /// If isRandomized, questions are shuffled into a random order
  /// Returns the exam instance document ID
  Future<String> createExamInstance({
    required String examId,
    required String studentId,
    required String classId,
    required String teacherId,
    bool isRandomized = false,
  }) async {
    // Check if instance already exists for this student+exam
    final existing = await _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id; // Return existing instance
    }

    // Fetch all questions for this exam
    final questionsSnapshot = await _firestore
        .collection('questions')
        .where('examId', isEqualTo: examId)
        .orderBy('order')
        .get();

    final List<String> questionIds = questionsSnapshot.docs
        .map((doc) => doc.id)
        .toList();

    // Shuffle if randomized
    List<String> orderedQuestions;
    if (isRandomized && questionIds.length > 1) {
      orderedQuestions = List<String>.from(questionIds);
      // Fisher-Yates shuffle
      final random = Random();
      for (int i = orderedQuestions.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = orderedQuestions[i];
        orderedQuestions[i] = orderedQuestions[j];
        orderedQuestions[j] = temp;
      }
    } else {
      orderedQuestions = questionIds;
    }

    // Create the exam instance
    final docRef = _firestore.collection('exam_instances').doc();
    await docRef.set({
      'id': docRef.id,
      'institutionId': 'default',
      'examId': examId,
      'studentId': studentId,
      'classId': classId,
      'teacherId': teacherId,
      'randomizedQuestions': orderedQuestions,
      'isRandomized': isRandomized,
      'startedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'submissionId': null,
    });

    return docRef.id;
  }

  /// Get an exam instance for a specific student+exam
  Future<Map<String, dynamic>?> getExamInstance({
    required String examId,
    required String studentId,
  }) async {
    final snapshot = await _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  /// Get questions in the randomized order for a specific exam instance
  /// Returns list of question data maps in the order the student should see them
  Future<List<Map<String, dynamic>>> getInstanceQuestions(String instanceId) async {
    // Fetch the instance
    final instanceDoc = await _firestore.collection('exam_instances').doc(instanceId).get();
    if (!instanceDoc.exists) return [];

    final instanceData = instanceDoc.data()!;
    final List<dynamic> questionOrder = instanceData['randomizedQuestions'] ?? [];

    if (questionOrder.isEmpty) {
      // Fallback: fetch all questions in original order
      final questions = await _firestore
          .collection('questions')
          .where('examId', isEqualTo: instanceData['examId'])
          .orderBy('order')
          .get();
      return questions.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }

    // Fetch questions in the randomized order
    final List<Map<String, dynamic>> orderedQuestions = [];
    for (final questionId in questionOrder) {
      final doc = await _firestore.collection('questions').doc(questionId as String).get();
      if (doc.exists) {
        orderedQuestions.add(doc.data()!);
      }
    }

    return orderedQuestions;
  }

  /// Get questions in randomized order as a stream (for real-time updates)
  /// Fetches all questions first, then reorders them
  Stream<List<Map<String, dynamic>>> getInstanceQuestionsStream(String instanceId) {
    // First get the instance to know the order
    return _firestore.collection('exam_instances').doc(instanceId).snapshots().asyncMap(
      (instanceDoc) async {
        if (!instanceDoc.exists) return [];

        final instanceData = instanceDoc.data()!;
        final List<dynamic> questionOrder = instanceData['randomizedQuestions'] ?? [];

        // Fetch all questions for the exam
        final questionsSnapshot = await _firestore
            .collection('questions')
            .where('examId', isEqualTo: instanceData['examId'])
            .get();

        final questionsMap = <String, Map<String, dynamic>>{};
        for (final doc in questionsSnapshot.docs) {
          questionsMap[doc.id] = doc.data();
        }

        // Reorder according to instance order
        if (questionOrder.isNotEmpty) {
          return questionOrder
              .where((id) => questionsMap.containsKey(id))
              .map((id) => questionsMap[id as String]!)
              .toList();
        }

        // Fallback: return in original order
        return questionsMap.values.toList()
          ..sort((a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0));
      },
    );
  }

  /// Mark an exam instance as completed
  Future<void> completeInstance({
    required String instanceId,
    required String submissionId,
  }) async {
    await _firestore.collection('exam_instances').doc(instanceId).update({
      'completedAt': FieldValue.serverTimestamp(),
      'submissionId': submissionId,
    });
  }

  /// Get all instances for an exam (teacher view)
  Stream<QuerySnapshot> getExamInstancesStream(String examId) {
    return _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .orderBy('startedAt', descending: true)
        .snapshots();
  }

  /// Get all instances for a student
  Stream<QuerySnapshot> getStudentInstancesStream(String studentId) {
    return _firestore
        .collection('exam_instances')
        .where('studentId', isEqualTo: studentId)
        .orderBy('startedAt', descending: true)
        .snapshots();
  }

  /// Delete all instances for an exam (used when deleting an exam)
  Future<void> deleteExamInstances(String examId) async {
    final snapshot = await _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Get count of instances for an exam
  Future<int> getInstanceCount(String examId) async {
    final snapshot = await _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .get();
    return snapshot.docs.length;
  }
}
