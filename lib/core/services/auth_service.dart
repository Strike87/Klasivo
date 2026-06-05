import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      // Fetch user data from Firestore to get role and name
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
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Student Login ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    try {
      // Query students collection by student code
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

      if (student['password'] != password) {
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
