import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'firebase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Teacher registration
  Future<void> registerTeacher({
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
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Teacher login
  Future<void> loginTeacher({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseService.loginWithEmail(email, password);
    } catch (e) {
      rethrow;
    }
  }

  // Student login
  Future<void> loginStudent({
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
        throw Exception('Student not found');
      }

      final student = snapshot.docs.first.data();
      if (student['password'] != password) {
        throw Exception('Invalid password');
      }

      // Store student info locally or in session
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await FirebaseService.logout();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user
  User? get currentUser => FirebaseService.currentUser;
}
