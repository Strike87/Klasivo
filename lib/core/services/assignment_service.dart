import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createAssignment({
    required String organizationId,
    required String classId,
    required String title,
    String? description,
    String? subjectId,
    String? groupId,
    required DateTime dueDate,
    List<String>? attachments,
    String createdBy = '',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.assignmentsCollection)
          .add({
        'organizationId': organizationId,
        'classId': classId,
        'title': title,
        'description': description,
        'subjectId': subjectId,
        'groupId': groupId,
        'dueDate': dueDate,
        'status': AppConstants.assignmentStatusDraft,
        'attachments': attachments ?? [],
        'createdBy': createdBy,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateAssignment({
    required String assignmentId,
    String? title,
    String? description,
    String? subjectId,
    String? groupId,
    DateTime? dueDate,
    List<String>? attachments,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (subjectId != null) data['subjectId'] = subjectId;
      if (groupId != null) data['groupId'] = groupId;
      if (dueDate != null) data['dueDate'] = dueDate;
      if (attachments != null) data['attachments'] = attachments;

      await _firestore
          .collection(AppConstants.assignmentsCollection)
          .doc(assignmentId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> publishAssignment(String assignmentId) async {
    try {
      await _firestore
          .collection(AppConstants.assignmentsCollection)
          .doc(assignmentId)
          .update({
        'status': AppConstants.assignmentStatusPublished,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAssignment(String assignmentId) async {
    try {
      // Delete all submissions for this assignment
      final submissionsSnapshot = await _firestore
          .collection(AppConstants.assignmentSubmissionsCollection)
          .where('assignmentId', isEqualTo: assignmentId)
          .get();

      final batch = _firestore.batch();
      for (final doc in submissionsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore
          .collection(AppConstants.assignmentsCollection)
          .doc(assignmentId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getAssignmentsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.assignmentsCollection)
        .where('classId', isEqualTo: classId)
        .where('isArchived', isEqualTo: false)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getAssignmentsByGroupStream(String groupId) {
    return _firestore
        .collection(AppConstants.assignmentsCollection)
        .where('groupId', isEqualTo: groupId)
        .where('isArchived', isEqualTo: false)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getAssignmentsByOrganizationStream(
      String organizationId) {
    return _firestore
        .collection(AppConstants.assignmentsCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Assignment Submissions ──────────────────────────────────────────────

  Future<String> submitAssignment({
    required String assignmentId,
    required String studentId,
    String? textSubmission,
    List<String>? fileUrls,
  }) async {
    try {
      // Check if already submitted
      final existing = await _firestore
          .collection(AppConstants.assignmentSubmissionsCollection)
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing submission
        await existing.docs.first.reference.update({
          'textSubmission': textSubmission,
          'fileUrls': fileUrls ?? [],
          'status': AppConstants.assignmentStatusSubmitted,
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return existing.docs.first.id;
      }

      final docRef = await _firestore
          .collection(AppConstants.assignmentSubmissionsCollection)
          .add({
        'assignmentId': assignmentId,
        'studentId': studentId,
        'textSubmission': textSubmission,
        'fileUrls': fileUrls ?? [],
        'status': AppConstants.assignmentStatusSubmitted,
        'grade': null,
        'feedback': null,
        'submittedAt': FieldValue.serverTimestamp(),
        'gradedAt': null,
        'gradedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double grade,
    String? feedback,
    required String gradedBy,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.assignmentSubmissionsCollection)
          .doc(submissionId)
          .update({
        'status': AppConstants.assignmentStatusGraded,
        'grade': grade,
        'feedback': feedback,
        'gradedBy': gradedBy,
        'gradedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getSubmissionsByAssignmentStream(String assignmentId) {
    return _firestore
        .collection(AppConstants.assignmentSubmissionsCollection)
        .where('assignmentId', isEqualTo: assignmentId)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getSubmissionsByStudentStream(String studentId) {
    return _firestore
        .collection(AppConstants.assignmentSubmissionsCollection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }
}
