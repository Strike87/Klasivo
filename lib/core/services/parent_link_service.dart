import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_constants.dart';
import 'sentry_service.dart';

class ParentLinkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // ─── Linking Code Generation ─────────────────────────────────────────────

  /// Generate a random 8-character alphanumeric code (uppercase + digits).
  String _generateLinkingCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  /// Generate a linking code for a student that a parent can use to link.
  /// The code expires after 48 hours.
  Future<String> generateLinkingCode({
    required String organizationId,
    required String studentId,
    required String generatedBy,
  }) async {
    try {
      String code;
      bool exists;
      do {
        code = _generateLinkingCode();
        final snapshot = await _firestore
            .collection(AppConstants.parentLinksCollection)
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
        exists = snapshot.docs.isNotEmpty;
      } while (exists);

      final expiresAt = DateTime.now().add(const Duration(hours: 48));

      await _firestore.collection(AppConstants.parentLinksCollection).add({
        'code': code,
        'organizationId': organizationId,
        'studentId': studentId,
        'generatedBy': generatedBy,
        'parentId': null,
        'status': AppConstants.parentLinkPending,
        'expiresAt': expiresAt,
        'linkedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return code;
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to generate parent linking code',
        tags: {'flow': 'parent_link', 'step': 'generateLinkingCode'},
      );
      rethrow;
    }
  }

  // ─── Parent-Student Linking ──────────────────────────────────────────────

  /// Link a parent to a student using a linking code.
  /// Returns the link data (studentId, studentName, organizationId).
  Future<Map<String, dynamic>> linkParentToStudent({
    required String code,
    required String parentId,
  }) async {
    try {
      KlasivoSentry.breadcrumb.registration('parent_link_started', data: {
        'parentId': parentId,
      });
      // Look up the code in parentLinksCollection
      final snapshot = await _firestore
          .collection(AppConstants.parentLinksCollection)
          .where('code', isEqualTo: code)
          .where('status', isEqualTo: AppConstants.parentLinkPending)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Invalid or already used linking code.');
      }

      final linkDoc = snapshot.docs.first;
      final linkData = linkDoc.data();

      // Check if the code has expired
      final expiresAt = linkData['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception('This linking code has expired.');
      }

      final studentId = linkData['studentId'] as String;
      final organizationId = linkData['organizationId'] as String;

      // Update the link doc with parentId, status, linkedAt
      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.parentLinksCollection,
        docId: linkDoc.id,
        data: {
          'parentId': parentId,
          'status': AppConstants.parentLinkApproved,
          'linkedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'parent_link',
        step: 'UPDATE_LINK_DOC',
      );

      // Add parentId field to the student's doc in usersCollection
      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.usersCollection,
        docId: studentId,
        data: {
          'parentId': parentId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'parent_link',
        step: 'UPDATE_STUDENT_PARENT_ID',
      );

      // Fetch student name for the return value
      final studentDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .get();
      final studentName = studentDoc.data()?['fullName'] as String? ?? '';

      KlasivoSentry.breadcrumb.registration('parent_link_success', data: {
        'parentId': parentId,
        'studentId': studentId,
      });

      return {
        'studentId': studentId,
        'studentName': studentName,
        'organizationId': organizationId,
      };
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Parent-student linking failed',
        tags: {'flow': 'parent_link', 'parentId': parentId},
      );
      rethrow;
    }
  }

  // ─── Get Parent's Linked Students ────────────────────────────────────────

  /// Stream of approved parent links for a given parent, ordered by linkedAt descending.
  Stream<QuerySnapshot> getParentLinksStream(String parentId) {
    return _firestore
        .collection(AppConstants.parentLinksCollection)
        .where('parentId', isEqualTo: parentId)
        .where('status', isEqualTo: AppConstants.parentLinkApproved)
        .orderBy('linkedAt', descending: true)
        .snapshots();
  }

  // ─── Get Student's Parents ───────────────────────────────────────────────

  /// Stream of approved parent links for a given student (teacher/admin view).
  Stream<QuerySnapshot> getStudentParentsStream(String studentId) {
    return _firestore
        .collection(AppConstants.parentLinksCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: AppConstants.parentLinkApproved)
        .snapshots();
  }

  // ─── Revoke Parent Link ─────────────────────────────────────────────────

  /// Revoke a parent link (admin action).
  Future<void> revokeLink(String linkId) async {
    try {
      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.parentLinksCollection,
        docId: linkId,
        data: {
          'status': AppConstants.parentLinkRevoked,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'parent_link_revoke',
        step: 'revokeLink',
      );
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to revoke parent link',
        tags: {'flow': 'parent_link_revoke', 'linkId': linkId},
      );
      rethrow;
    }
  }

  // ─── Get Student Data for Parent ─────────────────────────────────────────

  /// Verify that a parent has an approved link to a student.
  Future<bool> _verifyParentLink({
    required String parentId,
    required String studentId,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.parentLinksCollection)
        .where('parentId', isEqualTo: parentId)
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: AppConstants.parentLinkApproved)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Stream of submitted results for a student, viewable by an approved parent.
  Stream<QuerySnapshot> getStudentResultsForParent({
    required String parentId,
    required String studentId,
  }) async* {
    final hasAccess = await _verifyParentLink(
      parentId: parentId,
      studentId: studentId,
    );
    if (!hasAccess) {
      throw Exception('You do not have access to this student\'s results.');
    }

    yield* _firestore
        .collection(AppConstants.submissionsCollection)
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: AppConstants.submissionStatusSubmitted)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  /// Stream of attendance records for a student, viewable by an approved parent.
  Stream<QuerySnapshot> getStudentAttendanceForParent({
    required String parentId,
    required String studentId,
  }) async* {
    final hasAccess = await _verifyParentLink(
      parentId: parentId,
      studentId: studentId,
    );
    if (!hasAccess) {
      throw Exception('You do not have access to this student\'s attendance.');
    }

    yield* _firestore
        .collection(AppConstants.attendanceCollection)
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // ─── Cleanup Expired Codes ──────────────────────────────────────────────

  /// Delete all parent_links where status is 'pending' and expiresAt < now.
  Future<void> cleanupExpiredCodes() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.parentLinksCollection)
          .where('status', isEqualTo: AppConstants.parentLinkPending)
          .where('expiresAt', isLessThan: DateTime.now())
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await SentryFirestoreHelper.batchCommit(
        batch: batch,
        collection: AppConstants.parentLinksCollection,
        operationCount: snapshot.docs.length,
        flow: 'cleanup_expired_codes',
        step: 'batchDelete',
      );
    } catch (e, st) {
      KlasivoCrashlytics.recordError(e, st, reason: 'Expired code cleanup failed');
      rethrow;
    }
  }
}
