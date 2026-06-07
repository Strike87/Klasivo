import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'firebase_service.dart';
import 'organization_service.dart';
import 'invite_code_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hash a password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Owner Registration (auto-creates workspace) ────────────────────────

  /// Register a new owner. Organization is auto-created with a default name.
  /// The owner will be prompted to name their workspace after first login.
  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      // Auto-create organization with default name
      // Owner will rename it in the post-registration onboarding screen
      final orgService = OrganizationService();
      final orgId = await orgService.createOrganization(
        ownerId: user.uid,
        name: "$fullName's Workspace",
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
        'hasCompletedSetup': false, // Will be true after naming workspace
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': user.uid,
        'organizationId': orgId,
        'role': AppConstants.roleOwner,
        'fullName': fullName,
        'email': email,
        'hasCompletedSetup': false,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Teacher/Owner Login ────────────────────────────────────────────────

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
        'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Student Login (Firebase Auth backed, code-based UX) ───────────────

  /// Student login using student code + password.
  /// UX: Student enters code + password (simple).
  /// Backend: Internally maps to Firebase Auth for push notifications,
  /// multi-device, password reset, security rules, and analytics.
  Future<Map<String, dynamic>> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    try {
      // Step 1: Find user by studentCode
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

      // Step 2: Verify password
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

      // Step 3: Sign in via Firebase Auth using the student's internal email
      // This gives students push notifications, multi-device, security rules, etc.
      final internalEmail = student['authEmail'] as String?;
      if (internalEmail != null) {
        try {
          // Try Firebase Auth sign-in with the internal email
          await _auth.signInWithEmailAndPassword(
            email: internalEmail,
            password: password,
          );
        } catch (authError) {
          // If Firebase Auth fails, still allow login via Hive (graceful fallback)
          // This handles cases where Firebase Auth account wasn't created yet
          // (e.g., students created before this update)
        }
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

  // ─── Register Teacher via Invite Code ────────────────────────────────────

  Future<Map<String, dynamic>> registerTeacherWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    try {
      // Validate invite code (supports both T-XXXXXXXX and URL code format)
      final inviteService = InviteCodeService();
      final codeData = await inviteService.validateInviteCode(inviteCode);

      if (codeData == null) {
        throw Exception('Invalid or expired invite code.');
      }

      if (codeData['type'] != AppConstants.inviteTypeTeacher) {
        throw Exception('This invite code is not for teachers.');
      }

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
        'hasCompletedSetup': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark invite code as used
      await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .doc(codeData['id'])
          .update({
        'isUsed': true,
        'usedBy': user.uid,
        'usedAt': FieldValue.serverTimestamp(),
        'useCount': FieldValue.increment(1),
      });

      return {
        'id': user.uid,
        'organizationId': organizationId,
        'role': AppConstants.roleTeacher,
        'fullName': fullName,
        'email': email,
        'hasCompletedSetup': true,
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

  // ─── Password Reset with custom domain ──────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: AppConstants.appBaseUrl,
        handleCodeInApp: true,
        iOSBundleId: AppConstants.iosBundleId,
        androidPackageName: AppConstants.androidPackageName,
        androidInstallApp: true,
        androidMinimumVersion: '21',
        dynamicLinkDomain: AppConstants.dynamicLinkDomain,
      );

      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );
    } catch (e) {
      rethrow;
    }
  }
}
