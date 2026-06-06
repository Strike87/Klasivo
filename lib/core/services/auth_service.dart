import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hash a password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Teacher Registration ────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerTeacher({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      await _firestore.collection(AppConstants.usersCollection).doc(user.uid).set({
        'id': user.uid,
        'role': AppConstants.roleTeacher,
        'fullName': fullName,
        'email': email,
        'institutionId': AppConstants.defaultInstitutionId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': user.uid,
        'role': AppConstants.roleTeacher,
        'fullName': fullName,
        'email': email,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Teacher Login ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loginTeacher({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential =
          await FirebaseService.loginWithEmail(email, password);
      final user = userCredential.user!;

      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found. Please register again.');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;

      if (role != AppConstants.roleTeacher) {
        await _auth.signOut();
        throw Exception('This account is not a teacher account.');
      }

      return {
        'id': user.uid,
        'role': role ?? AppConstants.roleTeacher,
        'fullName': userData['fullName'] ?? 'Teacher',
        'email': userData['email'] ?? email,
        'institutionId': userData['institutionId'] ?? AppConstants.defaultInstitutionId,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Student Login (with hashed password support) ──────────────────────

  Future<Map<String, dynamic>> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('studentCode', isEqualTo: studentCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Student not found. Please check your student code.');
      }

      final studentDoc = snapshot.docs.first;
      final student = studentDoc.data();

      // Support both hashed and plaintext passwords for migration period
      final storedPasswordHash = student['passwordHash'] as String?;
      final storedPlaintext = student['password'] as String?;
      final inputHash = hashPassword(password);

      bool passwordMatches = false;
      if (storedPasswordHash != null && storedPasswordHash.isNotEmpty) {
        // New system: compare hashes
        passwordMatches = inputHash == storedPasswordHash;
      } else if (storedPlaintext != null) {
        // Legacy: compare plaintext
        passwordMatches = password == storedPlaintext;
        // Migrate to hash on successful login
        if (passwordMatches) {
          await _firestore
              .collection(AppConstants.studentsCollection)
              .doc(studentDoc.id)
              .update({'passwordHash': inputHash});
        }
      }

      if (!passwordMatches) {
        throw Exception('Invalid password. Please try again.');
      }

      return {
        'id': studentDoc.id,
        'role': AppConstants.roleStudent,
        'fullName': student['fullName'] ?? 'Student',
        'studentCode': student['studentCode'],
        'className': student['className'],
        'classId': student['classId'],
        'teacherId': student['teacherId'],
        'stageId': student['stageId'],
        'gradeId': student['gradeId'],
        'groupId': student['groupId'],
        'institutionId': student['institutionId'] ?? AppConstants.defaultInstitutionId,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Logout ──────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await FirebaseService.logout();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get Current User ────────────────────────────────────────────────────

  User? get currentUser => FirebaseService.currentUser;

  // ─── Check if user is logged in ──────────────────────────────────────────

  bool get isLoggedIn => _auth.currentUser != null;
}
