import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';
import 'sentry_service.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final Random _random = Random();

  /// Hash a password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> generateStudentCode(String organizationId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    bool exists;

    do {
      code = 'STU-';
      for (int i = 0; i < 6; i++) {
        code += chars[_random.nextInt(chars.length)];
      }
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: code)
          .where('organizationId', isEqualTo: organizationId)  // AUDIT FIX #3
          .limit(1)
          .get();
      exists = snapshot.docs.isNotEmpty;
    } while (exists);

    return code;
  }

  /// Generate an internal email for Firebase Auth.
  /// Students never see this email — they log in with their studentCode.
  /// Format: student_{code}@students.klasivo.app
  String _generateAuthEmail(String studentCode) {
    final cleanCode = studentCode.replaceAll('-', '').toLowerCase();
    return 'student_$cleanCode@students.klasivo.app';
  }

  /// Create a student account via Cloud Function (Admin SDK).
  ///
  /// This is the ONLY authorized way to create student accounts.
  /// The client must never write directly to users/{studentUid} —
  /// Firestore rules block that (`allow create: if request.auth.uid == userId`).
  ///
  /// The Cloud Function uses Admin SDK which bypasses Firestore rules,
  /// creates the Firebase Auth account, writes the user document, and
  /// handles rollback on failure.
  Future<String> addStudent({
    required String organizationId,
    required String classId,
    required String fullName,
    required String password,
    String? email,
    String? phone,
    String createdBy = '',
  }) async {
    final transaction = KlasivoSentry.transactions.studentEnrollment();

    try {
      KlasivoSentry.breadcrumb.registration('student_add_started', data: {
        'organizationId': organizationId,
        'classId': classId,
        'fullName': fullName,
        'createdBy': createdBy,
        'method': 'cloud_function',
      });

      // ── Auth state diagnostic before callable ──────────────────────────
      // Verify the teacher/owner is authenticated before calling the function.
      // If uid is null, the callable will reject with 'unauthenticated'.
      final currentUser = _auth.currentUser;
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'student_creation',
        message: 'before_createStudent_callable',
        data: {
          'uid': currentUser?.uid ?? 'null',
          'email': currentUser?.email ?? 'null',
          'isAuthenticated': currentUser != null,
          'createdBy_param': createdBy,
        },
        level: SentryLevel.info,
      ));

      // ── Call createStudent Cloud Function ──────────────────────────────
      // All Auth + Firestore + class count + audit + notifications
      // are handled server-side via Admin SDK. No client-side writes.
      final callable = _functions.httpsCallable('createStudent');
      final result = await callable.call<Map<String, dynamic>>({
        'organizationId': organizationId,
        'classId': classId,
        'fullName': fullName,
        'password': password,
        'email': email,
        'phone': phone,
      });

      final data = result.data;
      final studentUid = data['uid'] as String;
      final studentCode = data['studentCode'] as String;

      KlasivoSentry.breadcrumb.registration('student_add_success', data: {
        'studentUid': studentUid,
        'studentCode': studentCode,
        'method': 'cloud_function',
      });

      transaction.status = const SpanStatus.ok();

      return studentUid;
    } on FirebaseFunctionsException catch (e, st) {
      transaction.status = const SpanStatus.internalError();

      KlasivoSentry.breadcrumb.registration('student_add_failed', data: {
        'code': e.code,
        'message': e.message,
        'details': e.details?.toString(),
      });

      await KlasivoObservability.reportRegistrationError(
        e,
        st,
        flow: 'student_creation',
        step: 'addStudent',
        role: 'student',
        reason: 'Cloud Function createStudent failed: ${e.code} — ${e.message}',
      );
      rethrow;
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await KlasivoObservability.reportRegistrationError(
        e,
        st,
        flow: 'student_creation',
        step: 'addStudent',
        role: 'student',
        reason: 'Student creation failed (unexpected error)',
      );
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  Future<void> updateStudent({
    required String studentId,
    String? fullName,
    String? classId,
    String? email,
    String? phone,
    String? grade,
    String? password,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (fullName != null) data['fullName'] = fullName;
      if (classId != null) data['classId'] = classId;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (grade != null) data['grade'] = grade;
      if (isActive != null) data['isActive'] = isActive;
      if (password != null && password.isNotEmpty) {
        data['passwordHash'] = hashPassword(password);

        try {
          final studentDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(studentId)
              .get();
          final authEmail = studentDoc.data()?['authEmail'] as String?;
          if (authEmail != null) {
            // Firebase Admin SDK would be needed for server-side password update
          }
        } catch (_) {}
      }

      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.usersCollection,
        docId: studentId,
        data: data,
        flow: 'student_update',
        step: 'updateStudent',
      );
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Student update failed',
        tags: {'flow': 'student_update', 'studentId': studentId},
      );
      rethrow;
    }
  }

  /// A6 PATCH: Delete a student via the deleteStudent Cloud Function.
  /// Previous implementation called SentryFirestoreHelper.docDelete →
  /// CLIENT-SIDE Firestore delete → blocked by firestore.rules:109
  /// `allow delete: if false`. No callable existed → student deletion
  /// was structurally impossible.
  ///
  /// Now routes through the deleteStudent callable (Phase 2 TRACK-5)
  /// which soft-deletes (isArchived=true) + disables the Auth account +
  /// updates class studentCount + writes audit log. Hard-delete is
  /// available via the `hardDelete: true` parameter (owner-only).
  Future<void> deleteStudent(String studentId, String classId, {bool hardDelete = false}) async {
    try {
      // Fetch the student's organizationId first (needed by the callable).
      final studentDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .get();
      if (!studentDoc.exists) {
        throw Exception('Student $studentId not found.');
      }
      final organizationId = studentDoc.data()?['organizationId'] as String? ?? '';
      if (organizationId.isEmpty) {
        throw Exception('Student has no organizationId — cannot delete.');
      }

      // Call the deleteStudent Cloud Function.
      final result = await _functions.httpsCallable('deleteStudent').call({
        'targetUserId': studentId,
        'organizationId': organizationId,
        'hardDelete': hardDelete,
        'reason': 'deleted_by_client',
      });

      if (result.data['success'] != true) {
        throw Exception('deleteStudent callable returned failure: ${result.data}');
      }
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Student deletion failed',
        tags: {'flow': 'student_deletion', 'studentId': studentId, 'classId': classId},
      );
      rethrow;
    }
  }

  Stream<QuerySnapshot> getStudentsByClassStream(String classId, {required String organizationId}) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('classId', isEqualTo: classId)
        .where('organizationId', isEqualTo: organizationId)  // AUDIT FIX #2
        .where('role', isEqualTo: AppConstants.roleStudent)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getStudentsByOrganizationStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('role', isEqualTo: AppConstants.roleStudent)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<int> getTotalStudentCount(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e, st) {
      KlasivoCrashlytics.recordError(e, st, reason: 'getTotalStudentCount failed');
      rethrow;
    }
  }

  /// Create multiple student accounts via Cloud Function (Admin SDK).
  ///
  /// Each student is created individually via the createStudent callable.
  /// This ensures every student gets a Firebase Auth account, a proper
  /// user document at users/{uid}, and full audit trail — no more
  /// auto-ID docs with lazy Auth account creation.
  ///
  /// If any individual student creation fails, the error is recorded
  /// but remaining students continue to be processed. The method
  /// returns the IDs of all successfully created students.
  Future<List<String>> bulkAddStudents({
    required String organizationId,
    required String classId,
    required List<Map<String, String>> students,
    String createdBy = '',
  }) async {
    final transaction = KlasivoSentry.transactions.studentEnrollment();

    try {
      KlasivoSentry.breadcrumb.registration('bulk_student_add_started', data: {
        'organizationId': organizationId,
        'classId': classId,
        'studentCount': students.length,
        'createdBy': createdBy,
        'method': 'cloud_function',
      });

      // ── Auth state diagnostic before bulk callable ─────────────────────
      final bulkUser = _auth.currentUser;
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'student_creation',
        message: 'before_bulk_createStudent_callable',
        data: {
          'uid': bulkUser?.uid ?? 'null',
          'email': bulkUser?.email ?? 'null',
          'isAuthenticated': bulkUser != null,
          'createdBy_param': createdBy,
          'studentCount': students.length,
        },
        level: SentryLevel.info,
      ));

      final List<String> createdIds = [];
      final callable = _functions.httpsCallable('createStudent');

      for (final student in students) {
        try {
          final result = await callable.call<Map<String, dynamic>>({
            'organizationId': organizationId,
            'classId': classId,
            'fullName': student['fullName']!,
            'password': student['password'] ?? AppConstants.defaultStudentPassword,
            'email': student['email'],
            'phone': student['phone'],
          });

          final uid = result.data['uid'] as String;
          createdIds.add(uid);
        } catch (e, st) {
          // Record failure but continue with remaining students
          KlasivoCrashlytics.recordError(
            e, st,
            reason: 'Bulk add: failed to create student "${student['fullName']}" — skipping',
          );
        }
      }

      KlasivoSentry.breadcrumb.registration('bulk_student_add_completed', data: {
        'requestedCount': students.length,
        'createdCount': createdIds.length,
        'failedCount': students.length - createdIds.length,
        'classId': classId,
        'method': 'cloud_function',
      });

      transaction.status = const SpanStatus.ok();

      return createdIds;
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await KlasivoObservability.reportRegistrationError(
        e,
        st,
        flow: 'bulk_student_creation',
        step: 'bulkAddStudents',
        role: 'student',
        reason: 'Bulk student creation failed',
      );
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  /// Create a Firebase Auth account for a student who was created before
  /// the Firebase Auth migration. Called lazily on first student login.
  Future<bool> ensureFirebaseAuthAccount({
    required String studentId,
    required String studentCode,
    required String password,
  }) async {
    try {
      final authEmail = _generateAuthEmail(studentCode);

      // Check if Firebase Auth account already exists
      try {
        await _auth.signInWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        await _auth.signOut();
        return true;
      } catch (_) {
        // Account doesn't exist — create it
      }

      // Create the Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final newUid = userCredential.user?.uid;

      // Update the Firestore document with the auth email
      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.usersCollection,
        docId: studentId,
        data: {'authEmail': authEmail},
        flow: 'student_auth_ensure',
        step: 'ensureFirebaseAuthAccount',
      );

      KlasivoCrashlytics.log('[student] FirebaseAuth account ensured for studentId=$studentId, authUid=$newUid');

      await _auth.signOut();

      return true;
    } catch (e, st) {
      await KlasivoObservability.reportError(
        e,
        st,
        reason: 'Failed to ensure Firebase Auth account for student',
        tags: {'flow': 'student_auth_ensure', 'studentId': studentId},
      );
      return false;
    }
  }

  /// Notify teachers that a new student joined their class.
  Future<void> _notifyStudentJoined({
    required String studentName,
    required String classId,
    required String organizationId,
    String createdBy = '',
  }) async {
    try {
      final classDoc = await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .get();
      final className = classDoc.data()?['name'] as String? ?? 'class';

      final teachersSnapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('classId', isEqualTo: classId)
          .where('organizationId', isEqualTo: organizationId)  // AUDIT FIX #17
          .get();
      final teacherIds = teachersSnapshot.docs
          .map((d) => d.data()['teacherId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (createdBy.isNotEmpty && !teacherIds.contains(createdBy)) {
        teacherIds.add(createdBy);
      }

      for (final teacherId in teacherIds) {
        await NotificationService.notifyStudentJoined(
          teacherId: teacherId,
          studentName: studentName,
          className: className,
          organizationId: organizationId,
        );
      }
    } catch (e, st) {
      // Non-critical: notification failure shouldn't block student creation
      KlasivoCrashlytics.recordError(e, st, reason: 'Student join notification failed (non-critical)');
    }
  }
}
