import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';
import 'search_keyword_service.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SearchKeywordService _searchKeywordService = SearchKeywordService();

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
      final keywords = _searchKeywordService.generateKeywords(title);

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
        'version': 1,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'searchKeywords': keywords,
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
      if (title != null) {
        data['title'] = title;
        data['searchKeywords'] = _searchKeywordService.generateKeywords(title);
      }
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

  /// Increment version when assignment content changes significantly
  Future<void> incrementVersion(String assignmentId) async {
    try {
      await _firestore
          .collection(AppConstants.assignmentsCollection)
          .doc(assignmentId)
          .update({
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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

      // Notify all students in the class
      final assignmentDoc = await _firestore
          .collection(AppConstants.assignmentsCollection)
          .doc(assignmentId)
          .get();
      if (assignmentDoc.exists) {
        final data = assignmentDoc.data()!;
        final classId = data['classId'] as String? ?? '';
        final orgId = data['organizationId'] as String?;
        final title = data['title'] as String? ?? '';

        if (classId.isNotEmpty) {
          final studentsSnapshot = await _firestore
              .collection(AppConstants.usersCollection)
              .where('classId', isEqualTo: classId)
              .where('role', isEqualTo: AppConstants.roleStudent)
              .get();
          final studentIds = studentsSnapshot.docs.map((d) => d.id).toList();

          if (studentIds.isNotEmpty && orgId != null && orgId.isNotEmpty) {
            await NotificationService.notifyAssignmentPublished(
              organizationId: orgId,
              assignmentId: assignmentId,
              assignmentTitle: title,
              studentIds: studentIds,
            );
          } else if (orgId == null || orgId.isEmpty) {
            // Assignment was created with empty organizationId (should not happen
            // after the fail-fast fix in assignment_form_screen.dart, but guard
            // against legacy data). Skip notification — sending one with empty
            // org would fail org-boundary rules on delivery.
            print('[AssignmentService] Skipping notification for ${assignmentId}: '
                'assignment has no organizationId.');
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archiveAssignment(String assignmentId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.assignmentsCollection)
          .doc(assignmentId)
          .update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': archivedBy,
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
      // Get submission details before updating
      final submissionDoc = await _firestore
          .collection(AppConstants.assignmentSubmissionsCollection)
          .doc(submissionId)
          .get();

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

      // Notify the student about the grade
      if (submissionDoc.exists) {
        final subData = submissionDoc.data()!;
        final studentId = subData['studentId'] as String?;
        final assignmentId = subData['assignmentId'] as String?;

        if (studentId != null && assignmentId != null) {
          // Get assignment title
          final assignmentDoc = await _firestore
              .collection(AppConstants.assignmentsCollection)
              .doc(assignmentId)
              .get();
          final assignmentTitle =
              assignmentDoc.data()?['title'] as String? ?? 'Assignment';
          final orgId = assignmentDoc.data()?['organizationId'] as String?;

          await NotificationService.notifyAssignmentGraded(
            studentId: studentId,
            assignmentTitle: assignmentTitle,
            score: grade,
            organizationId: orgId,
            assignmentId: assignmentId,
          );
        }
      }
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
