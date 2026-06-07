import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'firebase_service.dart';
import 'organization_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hash a password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Owner Registration (auto-creates organization) ─────────────────────

  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
    required String organizationName,
  }) async {
    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      // Create organization
      final orgService = OrganizationService();
      final orgId = await orgService.createOrganization(
        ownerId: user.uid,
        name: organizationName,
      );

      // Create user document with owner role
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'organizationId': orgId,
        'role': AppConstants.roleOwner,
        'fullName': fullName,
        'email': email,
        'photoUrl': null,
        'phoneNumber': null,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': user.uid,
        'organizationId': orgId,
        'role': AppConstants.roleOwner,
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
        throw Exception('User data not found. Please contact your administrator.');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      final isActive = userData['isActive'] as bool? ?? true;

      if (!isActive) {
        await _auth.signOut();
        throw Exception('Your account has been deactivated. Contact your administrator.');
      }

      if (role != AppConstants.roleOwner && role != AppConstants.roleTeacher) {
        await _auth.signOut();
        throw Exception('This account does not have teacher access.');
      }

      return {
        'id': user.uid,
        'organizationId': userData['organizationId'] ?? '',
        'role': role ?? AppConstants.roleTeacher,
        'fullName': userData['fullName'] ?? 'Teacher',
        'email': userData['email'] ?? email,
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
      // Find user by studentCode
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: studentCode)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Student not found. Please check your student code.');
      }

      final userDoc = snapshot.docs.first;
      final student = userDoc.data();

      // Support both hashed and plaintext passwords for migration period
      final storedPasswordHash = student['passwordHash'] as String?;
      final storedPlaintext = student['password'] as String?;
      final inputHash = hashPassword(password);

      bool passwordMatches = false;
      if (storedPasswordHash != null && storedPasswordHash.isNotEmpty) {
        passwordMatches = inputHash == storedPasswordHash;
      } else if (storedPlaintext != null) {
        passwordMatches = password == storedPlaintext;
        // Migrate to hash on successful login
        if (passwordMatches) {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(userDoc.id)
              .update({'passwordHash': inputHash});
        }
      }

      if (!passwordMatches) {
        throw Exception('Invalid password. Please try again.');
      }

      final isActive = student['isActive'] as bool? ?? true;
      if (!isActive) {
        throw Exception('Your account has been deactivated.');
      }

      return {
        'id': userDoc.id,
        'organizationId': student['organizationId'] ?? '',
        'role': AppConstants.roleStudent,
        'fullName': student['fullName'] ?? 'Student',
        'studentCode': student['studentCode'],
        'classId': student['classId'],
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Register Teacher via Invite Code ─────────────────────────────────────

  Future<Map<String, dynamic>> registerTeacherWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    try {
      // Validate invite code
      final codeSnapshot = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('code', isEqualTo: inviteCode)
          .where('type', isEqualTo: AppConstants.inviteTypeTeacher)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

      if (codeSnapshot.docs.isEmpty) {
        throw Exception('Invalid or expired invite code.');
      }

      final codeDoc = codeSnapshot.docs.first;
      final codeData = codeDoc.data();
      final organizationId = codeData['organizationId'] as String;

      // Create Firebase Auth account
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      // Create user document with teacher role
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'organizationId': organizationId,
        'role': AppConstants.roleTeacher,
        'fullName': fullName,
        'email': email,
        'photoUrl': null,
        'phoneNumber': null,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark invite code as used
      await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .doc(codeDoc.id)
          .update({
        'isUsed': true,
        'usedBy': user.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': user.uid,
        'organizationId': organizationId,
        'role': AppConstants.roleTeacher,
        'fullName': fullName,
        'email': email,
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
