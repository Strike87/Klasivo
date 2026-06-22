import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

      // D10 PATCH: Use deterministic doc ID `{generatedBy}_{studentId}` so the
      // firestore.rules parentHasAccessToStudent() helper can look up the link
      // by ID. Previous code used .add() (auto-ID) which made the helper always
      // return false → parents could not read submissions/attendance.
      // Note: this doc is created by a teacher/admin with parentId=null. When
      // a parent redeems the code, the doc is updated with parentId. At that
      // point we ALSO write a second doc with ID `{parentId}_{studentId}` OR
      // we rename the doc — but Firestore doesn't support rename. So we use
      // the studentId as part of the key, and the helper checks existence of
      // `{parentId}_{studentId}`. The redemption flow (linkParentToStudent)
      // must create a NEW doc with the deterministic ID.
      final linkDocId = '$generatedBy\_$studentId';
      await _firestore
          .collection(AppConstants.parentLinksCollection)
          .doc(linkDocId)
          .set({
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
  ///
  /// Delegates to the `linkParent` Cloud Function, which (server-side):
  ///   - validates the code, atomically flips the link to 'approved'
  ///   - writes the parent's organizationId + tenantId (the deadlock fix)
  ///   - re-mints the parent's custom claims with the real org
  ///   - writes the deterministic parent_links/{parentId}_{studentId} doc
  ///     that parentHasAccessToStudent() requires
  ///   - stamps parentId on the student doc
  ///
  /// The client cannot do any of the org/claims writes itself — they are all
  /// rules-blocked for a parent. See functions/src/functions/linkParent.ts.
  ///
  /// Returns the link data (studentId, studentName, organizationId).
  Future<Map<String, dynamic>> linkParentToStudent({
    required String code,
    required String parentId,
  }) async {
    try {
      KlasivoSentry.breadcrumb.registration('parent_link_started', data: {
        'parentId': parentId,
      });

      final result = await FirebaseFunctions.instance
          .httpsCallable('linkParent')
          .call<Map<String, dynamic>>({
        'code': code,
      });

      final data = result.data;
      if (data['success'] != true) {
        throw Exception(
          (data['error'] as String?) ?? 'Parent linking failed.',
        );
      }

      KlasivoSentry.breadcrumb.registration(
        'parent_link_success',
        data: {
          'parentId': parentId,
          'studentId': data['studentId'],
          'organizationId': data['organizationId'],
        },
      );

      return {
        'studentId': data['studentId'] as String,
        'studentName': data['studentName'] as String? ?? '',
        'organizationId': data['organizationId'] as String,
      };
    } on FirebaseFunctionsException catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Parent-student linking CF failed',
        tags: {
          'flow': 'parent_link',
          'parentId': parentId,
          'code': e.code,
        },
      );
      // Surface the CF's user-friendly message verbatim.
      throw Exception(e.message ?? 'Parent linking failed.');
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Parent-student linking failed (non-CF error)',
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
