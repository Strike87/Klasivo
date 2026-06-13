import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../rbac/rbac.dart';
import '../rbac/roles.dart';

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
    try {
      final studentCode = await generateStudentCode(organizationId);
      final passwordHash = hashPassword(password);
      final authEmail = _generateAuthEmail(studentCode);

      // Try to create Firebase Auth account for this student
      // This enables push notifications, security rules, etc.
      String? authUid;
      try {
        // Save the current user so we can restore after student creation
        final currentUser = _auth.currentUser;
        final currentUserEmail = currentUser?.email;
        final currentUserPassword = ''; // Cannot retrieve password - will use re-auth

        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        authUid = userCredential.user?.uid;

        // Sign out the student account immediately
        await _auth.signOut();

        // Restore the original teacher/owner session
        if (currentUserEmail != null) {
          // Note: We cannot re-sign-in the teacher automatically because
          // we don't have their password. The teacher will need to sign in again.
          // This is handled gracefully by the auth state listener.
        }
      } catch (authError) {
        // If Firebase Auth creation fails (e.g., email already exists),
        // the student can still function without Firebase Auth initially.
        debugPrint('Firebase Auth creation for student failed: $authError');
      }

      // If Firebase Auth account was created, use its UID as the document ID
      // This links the Firestore user doc directly to the Firebase Auth UID
      final docRef = authUid != null
          ? _firestore.collection(AppConstants.usersCollection).doc(authUid)
          : _firestore.collection(AppConstants.usersCollection).doc();

      await docRef.set({
        'organizationId': organizationId,
        'role': KlasivoRole.student,
        'fullName': fullName,
        'studentCode': studentCode,
        'authEmail': authEmail, // Internal email for Firebase Auth
        'email': email,         // User's real email (optional)
        'phone': phone,
        'passwordHash': passwordHash,
        'mustChangePassword': true,
        'classId': classId,
        'photoUrl': null,
        'isActive': true,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update student count in class
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: KlasivoRole.student)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count ?? 0});

      // Re-sign in the creator (owner/teacher) since we signed out above
      // This is handled by the calling code — the auth state will be restored

      return docRef.id;
    } catch (e) {
      rethrow;
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

        // Also update Firebase Auth password if the student has an auth account
        try {
          final studentDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(studentId)
              .get();
          final authEmail = studentDoc.data()?['authEmail'] as String?;
          if (authEmail != null) {
            // Firebase Admin SDK would be needed to update password server-side
            // For now, the password is stored in Firestore for client-side login
          }
        } catch (_) {}
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStudent(String studentId, String classId) async {
    try {
      // Get student data before deleting
      final studentDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .get();
      final studentData = studentDoc.data();

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .delete();

      // Try to delete Firebase Auth account
      // Note: This requires Cloud Functions (Admin SDK) for proper cleanup
      // The onUserDelete cloud function handles this

      // Update student count
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: KlasivoRole.student)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count ?? 0});
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getStudentsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('classId', isEqualTo: classId)
        .where('role', isEqualTo: KlasivoRole.student)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getStudentsByOrganizationStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('role', isEqualTo: KlasivoRole.student)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<int> getTotalStudentCount(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('role', isEqualTo: KlasivoRole.student)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> bulkAddStudents({
    required String organizationId,
    required String classId,
    required List<Map<String, String>> students,
    String createdBy = '',
  }) async {
    try {
      final List<String> createdIds = [];

      // Note: Bulk add creates Firestore documents only.
      // Firebase Auth accounts will be created lazily on first login
      // to avoid signing out the current user during bulk operations.
      final batch = _firestore.batch();

      for (final student in students) {
        final studentCode = await generateStudentCode(organizationId);
        final password =
            student['password']?.isNotEmpty == true
                ? student['password']!
                : PasswordGenerator.generateTempPassword();
        final passwordHash = hashPassword(password);
        final authEmail = _generateAuthEmail(studentCode);
        final docRef =
            _firestore.collection(AppConstants.usersCollection).doc();

        batch.set(docRef, {
          'organizationId': organizationId,
          'role': KlasivoRole.student,
          'fullName': student['fullName']!,
          'studentCode': studentCode,
          'authEmail': authEmail,
          'email': student['email'],
          'phone': student['phone'],
          'passwordHash': passwordHash,
          'mustChangePassword': true,
          'classId': classId,
          'photoUrl': null,
          'isActive': true,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        createdIds.add(docRef.id);
      }

      await batch.commit();

      // Update student count
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: KlasivoRole.student)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count ?? 0});

      return createdIds;
    } catch (e) {
      rethrow;
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
        // Account exists — sign back out
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
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .update({
        'authEmail': authEmail,
      });

      // Sign out — student isn't the one creating this
      await _auth.signOut();

      return true;
    } catch (e) {
      debugPrint('Failed to create Firebase Auth account for student: $e');
      return false;
    }
  }
}
