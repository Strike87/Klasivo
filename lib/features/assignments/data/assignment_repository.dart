import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_constants.dart';
import '../domain/assignment_model.dart';

/// Repository layer that wraps FirebaseFirestore and returns [AssignmentModel]
/// domain objects for the assignments feature.
class AssignmentRepository {
  final FirebaseFirestore _firestore;

  AssignmentRepository(this._firestore);

  // ─── Read Operations ──────────────────────────────────────────────────────

  /// Fetch all assignments for a given class.
  Future<List<AssignmentModel>> getAssignmentsForClass(String classId) async {
    final snapshot = await _firestore
        .collection(AppConstants.assignmentsCollection)
        .where('classId', isEqualTo: classId)
        .get();

    return snapshot.docs
        .map((doc) => AssignmentModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// Fetch all assignments for a given student.
  ///
  /// Looks up assignments via the classes the student belongs to.
  Future<List<AssignmentModel>> getAssignmentsForStudent(
      String studentId) async {
    // First find the student's classes
    final classSnapshot = await _firestore
        .collection(AppConstants.classesCollection)
        .where('studentIds', arrayContains: studentId)
        .get();

    if (classSnapshot.docs.isEmpty) return [];

    final classIds = classSnapshot.docs.map((doc) => doc.id).toList();

    // Then fetch assignments for each class
    final assignments = <AssignmentModel>[];
    for (final classId in classIds) {
      final snapshot = await _firestore
          .collection(AppConstants.assignmentsCollection)
          .where('classId', isEqualTo: classId)
          .get();

      assignments.addAll(snapshot.docs
          .map((doc) => AssignmentModel.fromFirestore(doc.data(), doc.id)));
    }

    return assignments;
  }

  // ─── Write Operations ─────────────────────────────────────────────────────

  /// Create a new assignment document and return the created model.
  Future<AssignmentModel> createAssignment(
      Map<String, dynamic> data) async {
    final docRef = await _firestore
        .collection(AppConstants.assignmentsCollection)
        .add(data);

    final doc = await docRef.get();
    return AssignmentModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Update an existing assignment and return the updated model.
  Future<AssignmentModel> updateAssignment(
      String id, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.assignmentsCollection)
        .doc(id)
        .update(data);

    final doc = await _firestore
        .collection(AppConstants.assignmentsCollection)
        .doc(id)
        .get();

    return AssignmentModel.fromFirestore(doc.data()!, doc.id);
  }

  /// Archive an assignment by setting its status to 'archived'.
  Future<void> archiveAssignment(String id) async {
    await _firestore
        .collection(AppConstants.assignmentsCollection)
        .doc(id)
        .update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }
}
