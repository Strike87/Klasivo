import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class TeacherAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Assign a teacher to a class + subject
  Future<String> assignTeacher({
    required String organizationId,
    required String teacherId,
    required String classId,
    required String subjectId,
    String createdBy = '',
  }) async {
    try {
      // Check if assignment already exists
      final existing = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .where('classId', isEqualTo: classId)
          .where('subjectId', isEqualTo: subjectId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id; // Already assigned
      }

      final docRef = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .add({
        'organizationId': organizationId,
        'teacherId': teacherId,
        'classId': classId,
        'subjectId': subjectId,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also update the subject's teacherId if not set
      final subjectDoc = await _firestore
          .collection(AppConstants.subjectsCollection)
          .doc(subjectId)
          .get();
      if (subjectDoc.exists && subjectDoc.data()?['teacherId'] == null) {
        await _firestore
            .collection(AppConstants.subjectsCollection)
            .doc(subjectId)
            .update({'teacherId': teacherId});
      }

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a teacher assignment
  Future<void> removeAssignment(String assignmentId) async {
    try {
      await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .doc(assignmentId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all assignments for a teacher
  Stream<QuerySnapshot> getAssignmentsByTeacherStream(String teacherId) {
    return _firestore
        .collection(AppConstants.teacherAssignmentsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all assignments for a class
  Stream<QuerySnapshot> getAssignmentsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.teacherAssignmentsCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all assignments for a subject
  Stream<QuerySnapshot> getAssignmentsBySubjectStream(String subjectId) {
    return _firestore
        .collection(AppConstants.teacherAssignmentsCollection)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get all assignments for an organization
  Stream<QuerySnapshot> getAssignmentsByOrganizationStream(
      String organizationId) {
    return _firestore
        .collection(AppConstants.teacherAssignmentsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get teacher assignments as a list
  Future<List<Map<String, dynamic>>> getAssignmentsByTeacher(
      String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
