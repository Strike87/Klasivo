import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // ─── Owner Registration (NO org name — post-login naming) ──────────────

  /// Register a new owner. No organization name is asked here.
  /// Organization is auto-created with a temporary default name.
  /// After login, the owner is redirected to the Welcome/Org Naming screen
  /// where they choose their workspace name (with auto-suggest).
  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      // Auto-create organization with a temporary default name
      // The owner will rename it in the post-login onboarding screen
      final orgService = OrganizationService();
      final orgId = await orgService.createOrganization(
        ownerId: user.uid,
        name: "$fullName's Workspace",
      );

      // Create user document with owner role
      // hasCompletedSetup = false → triggers Welcome screen redirect
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

  // ─── Complete Owner Setup — Name the workspace ─────────────────────────

  /// Called after first login when owner has NOT completed setup.
  /// The Welcome screen shows auto-suggest based on the owner's name.
  /// The owner picks or types a workspace name, then this method saves it.
  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  }) async {
    try {
      // Update the organization name
      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .update({
        'name': workspaceName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark user setup as complete
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'hasCompletedSetup': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Generate workspace name auto-suggest ───────────────────────────────

  /// Returns a list of suggested workspace names based on the owner's name.
  /// Example: "Mohamed" → ["Mohamed Academy", "Mohamed's Classroom", "Mohamed Learning Center"]
  List<String> generateWorkspaceSuggestions(String fullName) {
    final firstName = fullName.split(' ').first;
    return [
      '$firstName Academy',
      '$firstName\'s Classroom',
      '$firstName Learning Center',
      '$firstName Education',
      '$firstName Institute',
    ];
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
  /// UX: Student enters code + password (simple, familiar).
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
      if (internalEmail != null && internalEmail.isNotEmpty) {
        try {
          await _auth.signInWithEmailAndPassword(
            email: internalEmail,
            password: password,
          );
        } catch (authError) {
          // If Firebase Auth fails, still allow login (graceful fallback)
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
        'hasCompletedSetup': true, // Students don't need workspace naming
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
      // Teachers always have hasCompletedSetup = true (they join an existing org)
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

  // ─── Google Sign-In (for Teachers/Owners) ───────────────────────────────

  /// Sign in with Google. Used by teachers and owners.
  /// If the user already exists, logs them in.
  /// If the user is new, creates an owner account (with hasCompletedSetup=false).
  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      // Obtain the auth details from the request
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Check if user document already exists
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        // Existing user — log them in
        final userData = userDoc.data()!;
        final role = userData['role'] as String?;
        final isActive = userData['isActive'] as bool? ?? true;

        if (!isActive) {
          await _auth.signOut();
          throw Exception('Your account has been deactivated.');
        }

        if (role != AppConstants.roleOwner && role != AppConstants.roleTeacher) {
          await _auth.signOut();
          throw Exception('This account does not have teacher access.');
        }

        return {
          'id': user.uid,
          'organizationId': userData['organizationId'] ?? '',
          'role': role ?? AppConstants.roleOwner,
          'fullName': userData['fullName'] ?? user.displayName ?? 'User',
          'email': userData['email'] ?? user.email ?? '',
          'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
        };
      } else {
        // New user — auto-create as owner
        final fullName = user.displayName ?? 'User';
        final email = user.email ?? '';

        // Auto-create organization with temporary default name
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
          'photoUrl': user.photoURL,
          'phoneNumber': null,
          'isActive': true,
          'hasCompletedSetup': false, // Needs to name workspace
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
      }
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

  // ─── Check if current user needs setup ───────────────────────────────────

  /// Returns true if the logged-in user has NOT completed setup
  /// (i.e., needs to name their workspace)
  Future<bool> needsSetup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final data = userDoc.data()!;
      final role = data['role'] as String?;
      final hasCompletedSetup = data['hasCompletedSetup'] as bool? ?? true;

      // Only owners need setup (workspace naming)
      if (role == AppConstants.roleOwner && !hasCompletedSetup) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
