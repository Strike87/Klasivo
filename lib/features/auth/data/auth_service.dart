import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/app_constants.dart';
import 'firebase_service.dart';
import 'organization_service.dart';
import 'invite_code_service.dart';

// ─── Auth Provider Constants ─────────────────────────────────────────────────
// Tracks which authentication method a user registered with.

class AuthProviders {
  static const String password = 'password';
  static const String google = 'google';
  static const String studentCode = 'student_code';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Hash a password using SHA-256.
  ///
  /// C-02 PATCH (DEPRECATED): See lib/core/services/auth_service.dart
  /// for details. Server now uses scrypt. This helper is kept only for
  /// the legacy student-login-by-code flow at line ~233 of this file.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Owner Registration (Email + Password) ────────────────────────────────

  /// Register a new owner with email and password.
  /// Organization is auto-created with a temporary default name.
  /// After login, the owner is redirected to the Welcome/Org Naming screen.
  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      // Email verification: Firebase auto-sends verification for password sign-up
      // Google Sign-In emails are pre-verified by Google
      final isEmailVerified = user.emailVerified;

      // Create user document FIRST with a placeholder orgId.
      // This ensures isTeacherOrOwner() can resolve in Firestore rules
      // when the org document is created/updated immediately after.
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'organizationId': '', // Placeholder — updated below after org creation
        'role': AppConstants.roleOwner,
        'authProvider': AuthProviders.password,
        'fullName': fullName,
        'email': email,
        'photoUrl': null,
        'phoneNumber': null,
        'isActive': true,
        'isEmailVerified': isEmailVerified,
        'hasCompletedSetup': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Now create the organization — rules can verify the user is an owner
      final orgService = OrganizationService();
      final orgId = await orgService.createOrganization(
        ownerId: user.uid,
        name: "$fullName's Workspace",
      );

      // Patch the user doc with the real organizationId
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'organizationId': orgId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': user.uid,
        'organizationId': orgId,
        'role': AppConstants.roleOwner,
        'authProvider': AuthProviders.password,
        'fullName': fullName,
        'email': email,
        'isEmailVerified': isEmailVerified,
        'hasCompletedSetup': false,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Owner Registration (Google Sign-In) ──────────────────────────────────

  /// Register a new owner via Google Sign-In.
  /// If user already exists, logs them in instead.
  Future<Map<String, dynamic>> registerOwnerWithGoogle() async {
    return _signInWithGoogle(
      expectedRole: AppConstants.roleOwner,
      isNewUser: true,
    );
  }

  // ─── Complete Owner Setup — Name the workspace ────────────────────────────

  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .update({
        'name': workspaceName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

  // ─── Generate workspace name auto-suggest ─────────────────────────────────

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

  // ─── Teacher/Owner/Parent Login (Email + Password) ────────────────────────

  /// Unified email+password login for owners, teachers, and parents.
  Future<Map<String, dynamic>> loginWithEmail({
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

      // Students should NOT use email login — they use student code login
      if (role == AppConstants.roleStudent) {
        await _auth.signOut();
        throw Exception('Students must login with their student code.');
      }

      return {
        'id': user.uid,
        'organizationId': userData['organizationId'] ?? '',
        'role': role ?? AppConstants.roleTeacher,
        'authProvider': AuthProviders.password,
        'fullName': userData['fullName'] ?? 'User',
        'email': userData['email'] ?? email,
        'isEmailVerified': user.emailVerified,
        'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Student Login (Student Code + Password) ──────────────────────────────

  /// Student login using student code + password.
  /// Internally maps to Firebase Auth for push notifications,
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
      final internalEmail = student['authEmail'] as String?;
      if (internalEmail != null && internalEmail.isNotEmpty) {
        try {
          await _auth.signInWithEmailAndPassword(
            email: internalEmail,
            password: password,
          );
        } catch (authError) {
          // Graceful fallback — still allow login even if Firebase Auth fails
        }
      }

      return {
        'id': userDoc.id,
        'organizationId': student['organizationId'] ?? '',
        'role': AppConstants.roleStudent,
        'authProvider': AuthProviders.studentCode,
        'fullName': student['fullName'] ?? 'Student',
        'studentCode': student['studentCode'],
        'classId': student['classId'],
        'hasCompletedSetup': true,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Teacher Registration via Invite Code ──────────────────────────────────

  Future<Map<String, dynamic>> registerTeacherWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    try {
      // Validate invite code
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

      final isEmailVerified = user.emailVerified;

      // Create user document with teacher role
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'organizationId': organizationId,
        'role': AppConstants.roleTeacher,
        'authProvider': AuthProviders.password,
        'fullName': fullName,
        'email': email,
        'photoUrl': null,
        'phoneNumber': null,
        'isActive': true,
        'isEmailVerified': isEmailVerified,
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
        'authProvider': AuthProviders.password,
        'fullName': fullName,
        'email': email,
        'isEmailVerified': isEmailVerified,
        'hasCompletedSetup': true,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Teacher Registration via Google Sign-In ───────────────────────────────

  /// Register a teacher via Google Sign-In with an invite code.
  Future<Map<String, dynamic>> registerTeacherWithGoogle({
    required String inviteCode,
  }) async {
    try {
      // Validate invite code first
      final inviteService = InviteCodeService();
      final codeData = await inviteService.validateInviteCode(inviteCode);

      if (codeData == null) {
        throw Exception('Invalid or expired invite code.');
      }

      if (codeData['type'] != AppConstants.inviteTypeTeacher) {
        throw Exception('This invite code is not for teachers.');
      }

      final organizationId = codeData['organizationId'] as String;

      // Trigger Google Sign-In
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

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
        final isActive = userData['isActive'] as bool? ?? true;
        if (!isActive) {
          await _auth.signOut();
          throw Exception('Your account has been deactivated.');
        }
        return {
          'id': user.uid,
          'organizationId': userData['organizationId'] ?? organizationId,
          'role': userData['role'] ?? AppConstants.roleTeacher,
          'authProvider': AuthProviders.google,
          'fullName': userData['fullName'] ?? user.displayName ?? 'Teacher',
          'email': userData['email'] ?? user.email ?? '',
          'isEmailVerified': user.emailVerified,
          'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
        };
      }

      // New user — create teacher document
      final fullName = user.displayName ?? 'Teacher';
      final email = user.email ?? '';
      final isEmailVerified = user.emailVerified; // Google emails are pre-verified

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'organizationId': organizationId,
        'role': AppConstants.roleTeacher,
        'authProvider': AuthProviders.google,
        'fullName': fullName,
        'email': email,
        'photoUrl': user.photoURL,
        'phoneNumber': null,
        'isActive': true,
        'isEmailVerified': isEmailVerified,
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
        'authProvider': AuthProviders.google,
        'fullName': fullName,
        'email': email,
        'hasCompletedSetup': true,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Parent Registration (Email + Password) ───────────────────────────────

  /// Register a parent with email, password, and an invite code to link child.
  Future<Map<String, dynamic>> registerParent({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      // Create user document with parent role
      // Parents need to link a child after registration
      final isEmailVerified = user.emailVerified;

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        'organizationId': null, // Set when parent links a child
        'role': AppConstants.roleParent,
        'authProvider': AuthProviders.password,
        'fullName': fullName,
        'email': email,
        'photoUrl': null,
        'phoneNumber': null,
        'isActive': true,
        'isEmailVerified': isEmailVerified,
        'hasCompletedSetup': false, // Needs to link child
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'id': user.uid,
        'organizationId': null,
        'role': AppConstants.roleParent,
        'authProvider': AuthProviders.password,
        'fullName': fullName,
        'email': email,
        'isEmailVerified': isEmailVerified,
        'hasCompletedSetup': false,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Parent Registration (Google Sign-In) ─────────────────────────────────

  /// Register a parent via Google Sign-In.
  Future<Map<String, dynamic>> registerParentWithGoogle() async {
    return _signInWithGoogle(
      expectedRole: AppConstants.roleParent,
      isNewUser: true,
    );
  }

  // ─── Google Sign-In (Unified — Owner / Teacher / Parent) ──────────────────

  /// Sign in with Google. Works for owners, teachers, and parents.
  /// If the user already exists, logs them in.
  /// If the user is new, creates an account based on [expectedRole]:
  ///   - owner: auto-creates organization (hasCompletedSetup=false)
  ///   - teacher: needs invite code (handled separately via registerTeacherWithGoogle)
  ///   - parent: creates parent account (hasCompletedSetup=false, needs to link child)
  Future<Map<String, dynamic>> loginWithGoogle({
    String? expectedRole,
  }) async {
    return _signInWithGoogle(
      expectedRole: expectedRole,
      isNewUser: false,
    );
  }

  Future<Map<String, dynamic>> _signInWithGoogle({
    String? expectedRole,
    bool isNewUser = false,
  }) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

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

        // Students cannot use Google Sign-In
        if (role == AppConstants.roleStudent) {
          await _auth.signOut();
          throw Exception('Students must login with their student code.');
        }

        return {
          'id': user.uid,
          'organizationId': userData['organizationId'] ?? '',
          'role': role ?? expectedRole ?? AppConstants.roleOwner,
          'authProvider': AuthProviders.google,
          'fullName': userData['fullName'] ?? user.displayName ?? 'User',
          'email': userData['email'] ?? user.email ?? '',
          'isEmailVerified': user.emailVerified,
          'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
        };
      }

      // New user — create account based on expected role
      final fullName = user.displayName ?? 'User';
      final email = user.email ?? '';
      final role = expectedRole ?? AppConstants.roleOwner;
      final isEmailVerified = user.emailVerified; // Google emails are pre-verified

      String? organizationId;
      bool hasCompletedSetup = true;

      if (role == AppConstants.roleOwner) {
        // Create user doc FIRST with placeholder orgId so isTeacherOrOwner() resolves
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
          'organizationId': '', // Placeholder — updated below
          'role': AppConstants.roleOwner,
          'authProvider': AuthProviders.google,
          'fullName': fullName,
          'email': email,
          'photoUrl': user.photoURL,
          'phoneNumber': null,
          'isActive': true,
          'isEmailVerified': isEmailVerified,
          'hasCompletedSetup': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Now create the organization — rules can verify user is an owner
        final orgService = OrganizationService();
        organizationId = await orgService.createOrganization(
          ownerId: user.uid,
          name: "$fullName's Workspace",
        );

        // Patch the user doc with the real organizationId
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .update({
          'organizationId': organizationId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        hasCompletedSetup = false; // Needs to name workspace
      } else if (role == AppConstants.roleParent) {
        organizationId = null; // Set when parent links a child
        hasCompletedSetup = false; // Needs to link child
      }

      // For non-owner roles, write the user doc normally (owner doc already created above)
      if (role != AppConstants.roleOwner) {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
          'organizationId': organizationId,
          'role': role,
          'authProvider': AuthProviders.google,
          'fullName': fullName,
          'email': email,
          'photoUrl': user.photoURL,
          'phoneNumber': null,
          'isActive': true,
          'isEmailVerified': isEmailVerified,
          'hasCompletedSetup': hasCompletedSetup,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return {
        'id': user.uid,
        'organizationId': organizationId,
        'role': role,
        'authProvider': AuthProviders.google,
        'fullName': fullName,
        'email': email,
        'isEmailVerified': isEmailVerified,
        'hasCompletedSetup': hasCompletedSetup,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ─── Sync Email Verification Status ────────────────────────────────────────

  /// Updates the isEmailVerified field in Firestore if it has changed.
  /// Called after every successful login to keep the field accurate.
  /// Google Sign-In users are always verified. Password users may verify later.
  Future<void> syncEmailVerification(String userId, bool isVerified) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'isEmailVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical — don't block login if this fails
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseService.logout();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get Current User ──────────────────────────────────────────────────────

  User? get currentUser => FirebaseService.currentUser;

  // ─── Check if user is logged in ────────────────────────────────────────────

  bool get isLoggedIn => _auth.currentUser != null;

  // ─── Password Reset ────────────────────────────────────────────────────────

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

  // ─── Check if current user needs setup ─────────────────────────────────────

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

      // Owners need workspace naming, parents need child linking
      if ((role == AppConstants.roleOwner || role == AppConstants.roleParent) &&
          !hasCompletedSetup) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
