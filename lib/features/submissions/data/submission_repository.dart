import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';
import '../domain/submission_model.dart';

/// Repository layer that wraps FirebaseFirestore and returns [SubmissionModel]
/// domain objects for the submissions feature.
class SubmissionRepository {
  final FirebaseFirestore _firestore;

  SubmissionRepository(this._firestore);

  // ─── Read Operations ──────────────────────────────────────────────────────

  /// Fetch all submissions for a given exam.
  Future<List<SubmissionModel>> getSubmissionsForExam(String examId) async {
    final snapshot = await _firestore
        .collection(AppConstants.submissionsCollection)
        .where('examId', isEqualTo: examId)
        .get();

    return snapshot.docs
        .map((doc) => SubmissionModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Fetch all submissions for a given student.
  Future<List<SubmissionModel>> getSubmissionsForStudent(
      String studentId) async {
    final snapshot = await _firestore
        .collection(AppConstants.submissionsCollection)
        .where('studentId', isEqualTo: studentId)
        .get();

    return snapshot.docs
        .map((doc) => SubmissionModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Fetch a single submission by its document ID.
  Future<SubmissionModel?> getSubmission(String id) async {
    final doc = await _firestore
        .collection(AppConstants.submissionsCollection)
        .doc(id)
        .get();

    if (!doc.exists) return null;
    return SubmissionModel.fromFirestore(doc.data()!, doc.id);
  }

  // ─── Write Operations ─────────────────────────────────────────────────────

  /// Create a new submission document and return the created model.
  Future<SubmissionModel> createSubmission(
      Map<String, dynamic> data) async {
    final docRef = await _firestore
        .collection(AppConstants.submissionsCollection)
        .add(data);

    final doc = await docRef.get();
    return SubmissionModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Update an existing submission and return the updated model.
  Future<SubmissionModel> updateSubmission(
      String id, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.submissionsCollection)
        .doc(id)
        .update(data);

    final doc = await _firestore
        .collection(AppConstants.submissionsCollection)
        .doc(id)
        .get();

    return SubmissionModel.fromFirestore(doc.data()!, doc.id);
  }

  // ─── Stream Operations ────────────────────────────────────────────────────

  /// Stream submissions for a given exam in real-time.
  Stream<List<SubmissionModel>> streamSubmissionsForExam(String examId) {
    return _firestore
        .collection(AppConstants.submissionsCollection)
        .where('examId', isEqualTo: examId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubmissionModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}
