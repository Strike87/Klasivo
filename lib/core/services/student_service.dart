import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_constants.dart';
import 'notification_service.dart';
import 'sentry_service.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  /// Add a student with Firebase Auth backing.
  /// UX: Student logs in with code + password.
  /// Backend: Firebase Auth account created for push notifications,
  /// security rules, multi-device, password reset, and analytics.
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
      });

      final studentCode = await generateStudentCode(organizationId);
      final passwordHash = hashPassword(password);
      final authEmail = _generateAuthEmail(studentCode);

      // ── Step 1: Try to create Firebase Auth account ──────────────────────
      KlasivoSentry.breadcrumb.registration('STEP_1_AUTH_ACCOUNT_CREATE_START', data: {
        'studentCode': studentCode,
      });

      String? authUid;
      try {
        final currentUser = _auth.currentUser;

        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        authUid = userCredential.user?.uid;

        KlasivoSentry.breadcrumb.registration('STEP_1_AUTH_ACCOUNT_CREATED', data: {
          'authUid': authUid,
          'studentCode': studentCode,
        });

        // Sign out the student account immediately
        await _auth.signOut();

        // Restore the original teacher/owner session
        if (currentUser?.email != null) {
          // Note: Cannot re-sign-in automatically — handled by auth state listener
          KlasivoCrashlytics.log('[student] Auth session changed after student creation — '
              'original user may need to re-authenticate');
        }
      } catch (authError, authStack) {
        // If Firebase Auth creation fails, student can still function without Auth
        KlasivoSentry.breadcrumb.registration('STEP_1_AUTH_ACCOUNT_FAILED', data: {
          'error': authError.toString().substring(0, (authError.toString().length).clamp(0, 100)),
        });
        await KlasivoObservability.reportError(
          authError,
          authStack,
          reason: 'Firebase Auth creation for student failed (non-fatal — student will use Firestore-only login)',
          tags: {
            'flow': 'student_creation',
            'step': 'STEP_1_AUTH_CREATE',
            'studentCode': studentCode,
          },
        );
      }

      // ── Step 2: Create student document in Firestore ──────────────────────
      final currentAuthUid = _auth.currentUser?.uid;
      KlasivoSentry.breadcrumb.registration('STEP_2_USER_DOC_CREATE_START', data: {
        'authUid': authUid ?? 'null',
        'docIdStrategy': authUid != null ? 'uid' : 'auto_id',
        'writePath': 'users/${authUid ?? "auto_id"}',
        'currentAuthUid': currentAuthUid ?? 'null',
        'authUidMatchesDocId': authUid == currentAuthUid,
        'organizationId': organizationId,
      });

      final docRef = authUid != null
          ? _firestore.collection(AppConstants.usersCollection).doc(authUid)
          : _firestore.collection(AppConstants.usersCollection).doc();

      final studentData = {
        'organizationId': organizationId,
        'role': AppConstants.roleStudent,
        'fullName': fullName,
        'studentCode': studentCode,
        'authEmail': authEmail,
        'email': email,
        'phone': phone,
        'passwordHash': passwordHash,
        'classId': classId,
        'photoUrl': null,
        'isActive': true,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Pre-write breadcrumb: captures exact path for permission-denied diagnosis
      await Sentry.addBreadcrumb(Breadcrumb(
        category: 'student_creation',
        message: 'Attempting Firestore write',
        data: {
          'collection': AppConstants.usersCollection,
          'docPath': docRef.path,
          'docId': docRef.id,
          'currentAuthUid': currentAuthUid ?? 'null',
          'docIdMatchesAuthUid': docRef.id == currentAuthUid,
          'dataRole': studentData['role'],
          'dataOrgId': studentData['organizationId'],
        },
      ));

      try {
        await SentryFirestoreHelper.docSet(
          collection: AppConstants.usersCollection,
          docId: docRef.id,
          data: studentData,
          flow: 'student_creation',
          step: 'STEP_2_USER_DOC_CREATE',
        );
      } catch (writeError, writeStack) {
        // Capture the exact write path + auth context for permission-denied diagnosis
        await Sentry.captureException(
          writeError,
          stackTrace: writeStack,
          withScope: (scope) {
            scope.setTag('firestore_write', 'permission_denied');
            scope.setTag('collection', AppConstants.usersCollection);
            scope.setTag('doc_path', docRef.path);
            scope.setExtra('doc_id', docRef.id);
            scope.setExtra('current_auth_uid', currentAuthUid ?? 'null');
            scope.setExtra('doc_id_matches_auth_uid', docRef.id == currentAuthUid);
            scope.setExtra('data_org_id', studentData['organizationId']);
            scope.setExtra('data_role', studentData['role']);
          },
        );
        rethrow;
      }

      // ── Read-back verification ──
      final verifyDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(docRef.id)
          .get();
      if (!verifyDoc.exists) {
        await KlasivoObservability.reportMessage(
          'STEP_2 STUDENT DOC SET SUCCEEDED BUT READ-BACK FAILED — '
          'doc users/${docRef.id} does not exist after .set()',
          level: SentryLevel.error,
          tags: {
            'flow': 'student_creation',
            'step': 'STEP_2_READBACK',
            'docId': docRef.id,
          },
        );
      } else {
        KlasivoSentry.breadcrumb.registration('STEP_2_USER_DOC_READBACK_VERIFIED', data: {
          'docId': docRef.id,
          'docExists': true,
        });
      }

      // Doc ID audit trail
      KlasivoSentry.docIdAudit.logUserCreation(
        flow: 'student_creation',
        collection: AppConstants.usersCollection,
        docIdStrategy: authUid != null ? 'uid' : 'auto_id',
        actualDocId: docRef.id,
        authUid: authUid,
      );

      // ── Step 3: Update student count in class ────────────────────────────
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();

      try {
        await _firestore
            .collection(AppConstants.classesCollection)
            .doc(classId)
            .update({'studentCount': countSnapshot.count ?? 0});
      } catch (classUpdateError, classUpdateStack) {
        await Sentry.captureException(
          classUpdateError,
          stackTrace: classUpdateStack,
          withScope: (scope) {
            scope.setTag('firestore_write', 'permission_denied');
            scope.setTag('collection', 'classes');
            scope.setTag('doc_path', 'classes/$classId');
            scope.setExtra('operation', 'update');
            scope.setExtra('field', 'studentCount');
            scope.setExtra('current_auth_uid', _auth.currentUser?.uid ?? 'null');
          },
        );
        rethrow;
      }

      // ── Step 4: Notify teachers ──────────────────────────────────────────
      _notifyStudentJoined(
        studentName: fullName,
        classId: classId,
        organizationId: organizationId,
        createdBy: createdBy,
      );

      KlasivoSentry.breadcrumb.registration('student_add_success', data: {
        'docId': docRef.id,
        'studentCode': studentCode,
        'authUid': authUid ?? 'null',
      });

      transaction.status = const SpanStatus.ok();

      return docRef.id;
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await KlasivoObservability.reportRegistrationError(
        e,
        st,
        flow: 'student_creation',
        step: 'addStudent',
        role: 'student',
        reason: 'Student creation failed',
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

  Future<void> deleteStudent(String studentId, String classId) async {
    try {
      final studentDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .get();
      final studentData = studentDoc.data();

      await SentryFirestoreHelper.docDelete(
        collection: AppConstants.usersCollection,
        docId: studentId,
        flow: 'student_deletion',
        step: 'deleteStudent',
      );

      // Update student count
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count ?? 0});
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

  Stream<QuerySnapshot> getStudentsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('classId', isEqualTo: classId)
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
      });

      final List<String> createdIds = [];

      // Bulk add creates Firestore documents only.
      // Firebase Auth accounts created lazily on first login.
      final batch = _firestore.batch();

      for (final student in students) {
        final studentCode = await generateStudentCode(organizationId);
        final password =
            student['password'] ?? AppConstants.defaultStudentPassword;
        final passwordHash = hashPassword(password);
        final authEmail = _generateAuthEmail(studentCode);

        // WARNING: Uses auto-ID — no auth UID available yet
        // Auth accounts are created lazily on first login
        final docRef =
            _firestore.collection(AppConstants.usersCollection).doc();

        batch.set(docRef, {
          'organizationId': organizationId,
          'role': AppConstants.roleStudent,
          'fullName': student['fullName']!,
          'studentCode': studentCode,
          'authEmail': authEmail,
          'email': student['email'],
          'phone': student['phone'],
          'passwordHash': passwordHash,
          'classId': classId,
          'photoUrl': null,
          'isActive': true,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        createdIds.add(docRef.id);

        // Doc ID audit — auto-ID used (Auth accounts created lazily)
        KlasivoSentry.docIdAudit.logUserCreation(
          flow: 'bulk_student_creation',
          collection: AppConstants.usersCollection,
          docIdStrategy: 'auto_id',
          actualDocId: docRef.id,
          authUid: null, // No auth UID yet — created lazily on first login
        );
      }

      await SentryFirestoreHelper.batchCommit(
        batch: batch,
        collection: AppConstants.usersCollection,
        operationCount: students.length,
        flow: 'bulk_student_creation',
        step: 'BATCH_COMMIT',
      );

      // Update student count
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count ?? 0});

      KlasivoSentry.breadcrumb.registration('bulk_student_add_success', data: {
        'createdCount': createdIds.length,
        'classId': classId,
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
