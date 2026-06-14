import 'package:cloud_firestore/cloud_firestore.dart';

/// Abstract interface for exam CRUD and lifecycle operations.
///
/// Implementations typically wrap Firestore; mock implementations
/// can use in-memory stores for testing.
abstract class IExamService {
  /// Create a new exam and return its document ID.
  Future<String> createExam({required Map<String, dynamic> examData});

  /// Update an existing exam.
  Future<void> updateExam({
    required String examId,
    required Map<String, dynamic> updates,
  });

  /// Publish a draft exam (makes it visible to students).
  Future<void> publishExam({required String examId});

  /// Un-publish an exam (revert to draft).
  Future<void> unpublishExam({required String examId});

  /// Soft-delete (archive) an exam.
  Future<void> archiveExam({required String examId});

  /// Hard-delete an exam and all related data.
  Future<void> deleteExam({required String examId});

  /// Get a single exam by ID; returns null if not found.
  Future<Map<String, dynamic>?> getExam(String examId);

  /// Real-time stream of exams for a given class.
  Stream<QuerySnapshot> getExamsForClass(String classId);

  /// Real-time stream of exams for a given teacher.
  Stream<QuerySnapshot> getExamsForTeacher(String teacherId);

  /// Recalculate total marks and question count for an exam.
  Future<void> recalculateTotalMarks(String examId);
}
