import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/app_constants.dart';
import 'sentry_service.dart';
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

  /// Hash a password using SHA-256
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
    final transaction = Sentry.startTransaction(
      'owner_registration',
      'registration',
    );

    try {
      // ── Step 1: Create Firebase Auth account ──────────────────────────
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_1_AUTH_USER_CREATED',
        data: {'uid': user.uid, 'email': email},
      ));
      transaction.setData('uid', user.uid);

      // Set Sentry user context immediately after auth account creation
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: user.uid, email: email));
      });

      final isEmailVerified = user.emailVerified;

      // ── Step 2: Create user document in Firestore ──────────────────────
      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_START',
      ));

      final createUserDocSpan = transaction.startChild('create_user_doc');

      try {
        await SentryFirestoreHelper.docSet(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: {
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
          },
          flow: 'owner_registration',
          step: 'STEP_2_USER_DOC_CREATE',
        );

        // Read-back verification: confirm the document actually exists in Firestore.
        // This detects silent write failures caused by network partitions,
        // Firestore eventual consistency issues, or security rule misconfigurations
        // that allow the SDK to resolve the Future without error but never persist.
        final verifyDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        if (!verifyDoc.exists) {
          await Sentry.captureMessage(
            'STEP_2 USER DOC SET SUCCEEDED BUT READ-BACK FAILED — doc users/${user.uid} does not exist after .set()',
            level: SentryLevel.error,
          );
        } else {
          Sentry.addBreadcrumb(Breadcrumb(
            category: 'registration',
            message: 'STEP_2_USER_DOC_READBACK_VERIFIED',
            data: {'uid': user.uid, 'docExists': true},
          ));
        }

        // Doc ID audit trail
        KlasivoSentry.docIdAudit.logUserCreation(
          flow: 'owner_registration',
          collection: AppConstants.usersCollection,
          docIdStrategy: 'uid',
          actualDocId: user.uid,
          authUid: user.uid,
        );

        createUserDocSpan.status = const SpanStatus.ok();
      } catch (e, st) {
        createUserDocSpan.status = const SpanStatus.internalError();
        rethrow;
      } finally {
        await createUserDocSpan.finish();
      }

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_SUCCESS',
        data: {'uid': user.uid},
      ));

      // ── Step 3: Create organization ────────────────────────────────────
      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_3_ORG_CREATE_START',
      ));

      final createOrgSpan = transaction.startChild('create_organization');
      final orgService = OrganizationService();

      String orgId;
      try {
        orgId = await orgService.createOrganization(
          ownerId: user.uid,
          name: "$fullName's Workspace",
        );
        createOrgSpan.status = const SpanStatus.ok();
      } catch (e, st) {
        createOrgSpan.status = const SpanStatus.internalError();
        await Sentry.captureException(
          e,
          stackTrace: st,
          withScope: (scope) {
            scope.setTag('collection', 'organizations');
            scope.setTag('operation', 'create');
            scope.setTag('ownerId', user.uid);
            scope.setTag('flow', 'owner_registration');
            scope.setTag('step', 'STEP_3_ORG_CREATE');
          },
        );
        rethrow;
      } finally {
        await createOrgSpan.finish();
      }

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_3_ORG_CREATE_SUCCESS',
        data: {'orgId': orgId},
      ));

      // ── Step 4: Patch user doc with real organizationId ────────────────
      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_4_USER_PATCH_START',
      ));

      final patchUserSpan = transaction.startChild('update_user_doc');

      try {
        await SentryFirestoreHelper.docUpdate(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: {
            'organizationId': orgId,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          flow: 'owner_registration',
          step: 'STEP_4_USER_PATCH',
        );
        patchUserSpan.status = const SpanStatus.ok();
      } catch (e, st) {
        patchUserSpan.status = const SpanStatus.internalError();
        rethrow;
      } finally {
        await patchUserSpan.finish();
      }

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_4_USER_PATCH_SUCCESS',
        data: {'uid': user.uid, 'organizationId': orgId},
      ));

      // Set Sentry org context after creation
      await Sentry.configureScope((scope) {
        scope.setTag('organizationId', orgId);
        scope.setTag('role', 'owner');
      });

      transaction.status = const SpanStatus.ok();

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
      transaction.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await transaction.finish();
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
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_WORKSPACE_SETUP_START',
        data: {'userId': userId, 'organizationId': organizationId, 'workspaceName': workspaceName},
      ));

      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.organizationsCollection,
        docId: organizationId,
        data: {
          'name': workspaceName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'owner_registration',
        step: 'STEP_WORKSPACE_SETUP_ORG',
      );

      await SentryFirestoreHelper.docUpdate(
        collection: AppConstants.usersCollection,
        docId: userId,
        data: {
          'hasCompletedSetup': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        flow: 'owner_registration',
        step: 'STEP_WORKSPACE_SETUP_USER',
      );

      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_WORKSPACE_SETUP_SUCCESS',
      ));
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'owner_registration');
          scope.setTag('step', 'WORKSPACE_SETUP');
          scope.setTag('userId', userId);
          scope.setTag('organizationId', organizationId);
        },
      );
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
    final transaction = KlasivoSentry.transactions.loginFlow('email');

    try {
      KlasivoSentry.breadcrumb.auth('login_started', data: {
        'method': 'email',
        'email': email,
      });

      final userCredential =
          await FirebaseService.loginWithEmail(email, password);
      final user = userCredential.user!;

      KlasivoSentry.breadcrumb.auth('auth_user_authenticated', data: {
        'uid': user.uid,
        'method': 'email',
      });

      // Set Sentry user context immediately after auth
      await KlasivoSentry.userContext.setUser(
        uid: user.uid,
        email: email,
      );

      final readUserSpan = transaction.startChild('read_user_doc');
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();
      await readUserSpan.finish();

      if (!userDoc.exists) {
        KlasivoSentry.breadcrumb.auth('login_failed_user_doc_missing', data: {
          'uid': user.uid,
        });
        await Sentry.captureMessage(
          'Login failed: users/${user.uid} document does not exist',
          level: SentryLevel.error,
        );
        throw Exception('User data not found. Please contact your administrator.');
      }

      final userData = userDoc.data()!;
      final role = userData['role'] as String?;
      final isActive = userData['isActive'] as bool? ?? true;

      // Update Sentry context with role and org
      await KlasivoSentry.userContext.setRole(role ?? 'unknown');
      final orgId = userData['organizationId'] as String?;
      if (orgId != null && orgId.isNotEmpty) {
        await KlasivoSentry.userContext.setOrganizationId(orgId);
      }

      if (!isActive) {
        await _auth.signOut();
        KlasivoSentry.breadcrumb.auth('login_failed_account_deactivated', data: {
          'uid': user.uid,
          'role': role,
        });
        throw Exception('Your account has been deactivated. Contact your administrator.');
      }

      // Students should NOT use email login — they use student code login
      if (role == AppConstants.roleStudent) {
        await _auth.signOut();
        KlasivoSentry.breadcrumb.auth('login_failed_student_email_login', data: {
          'uid': user.uid,
        });
        throw Exception('Students must login with their student code.');
      }

      KlasivoSentry.breadcrumb.auth('login_success', data: {
        'uid': user.uid,
        'role': role ?? 'unknown',
        'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
      });

      transaction.status = const SpanStatus.ok();

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
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'email_login');
          scope.setTag('step', 'login_with_email');
        },
      );
      rethrow;
    } finally {
      await transaction.finish();
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
    final transaction = KlasivoSentry.transactions.loginFlow('student');

    try {
      KlasivoSentry.breadcrumb.auth('login_started', data: {
        'method': 'student_code',
      });

      // Step 1: Find user by studentCode
      final findUserSpan = transaction.startChild('find_user_by_code');
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: studentCode)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .limit(1)
          .get();
      await findUserSpan.finish();

      if (snapshot.docs.isEmpty) {
        KlasivoSentry.breadcrumb.auth('login_failed_student_not_found', data: {
          'method': 'student_code',
        });
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
        KlasivoSentry.breadcrumb.auth('login_failed_invalid_password', data: {
          'method': 'student_code',
          'userId': userDoc.id,
        });
        throw Exception('Invalid password. Please try again.');
      }

      final isActive = student['isActive'] as bool? ?? true;
      if (!isActive) {
        KlasivoSentry.breadcrumb.auth('login_failed_account_deactivated', data: {
          'userId': userDoc.id,
          'role': 'student',
        });
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
          KlasivoSentry.breadcrumb.auth('student_auth_signed_in', data: {
            'userId': userDoc.id,
          });
        } catch (authError) {
          // Graceful fallback — still allow login even if Firebase Auth fails
          KlasivoSentry.breadcrumb.auth('student_auth_signin_failed_fallback', data: {
            'userId': userDoc.id,
            'error': authError.toString().substring(0, (authError.toString().length).clamp(0, 100)),
          });
        }
      }

      // Set Sentry user context
      await KlasivoSentry.userContext.setUser(
        uid: userDoc.id,
        email: internalEmail ?? '',
        role: AppConstants.roleStudent,
        organizationId: student['organizationId'] as String?,
      );

      KlasivoSentry.breadcrumb.auth('login_success', data: {
        'uid': userDoc.id,
        'role': 'student',
        'method': 'student_code',
      });

      // Log doc ID audit — student uses Firestore doc ID (not auth UID)
      KlasivoSentry.docIdAudit.logUserCreation(
        flow: 'student_code_login',
        collection: AppConstants.usersCollection,
        docIdStrategy: userDoc.id.length > 28 ? 'auto_id' : 'uid',
        actualDocId: userDoc.id,
        authUid: _auth.currentUser?.uid,
      );

      transaction.status = const SpanStatus.ok();

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
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'student_login');
          scope.setTag('step', 'login_student');
          scope.setTag('method', 'student_code');
        },
      );
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  // ─── Teacher Registration via Invite Code ──────────────────────────────────

  Future<Map<String, dynamic>> registerTeacherWithInvite({
    required String email,
    required String password,
    required String fullName,
    required String inviteCode,
  }) async {
    final transaction = Sentry.startTransaction(
      'teacher_registration',
      'registration',
    );

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

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_1_AUTH_USER_CREATED',
        data: {'uid': user.uid, 'email': email, 'role': 'teacher'},
      ));

      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: user.uid, email: email));
        scope.setTag('role', 'teacher');
        scope.setTag('organizationId', organizationId);
      });

      final isEmailVerified = user.emailVerified;

      // Create user document with teacher role
      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_START',
      ));

      final createUserDocSpan = transaction.startChild('create_user_doc');

      try {
        await SentryFirestoreHelper.docSet(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: {
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
          },
          flow: 'teacher_registration',
          step: 'STEP_2_USER_DOC_CREATE',
        );

        KlasivoSentry.docIdAudit.logUserCreation(
          flow: 'teacher_registration',
          collection: AppConstants.usersCollection,
          docIdStrategy: 'uid',
          actualDocId: user.uid,
          authUid: user.uid,
        );

        createUserDocSpan.status = const SpanStatus.ok();
      } catch (e, st) {
        createUserDocSpan.status = const SpanStatus.internalError();
        rethrow;
      } finally {
        await createUserDocSpan.finish();
      }

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_SUCCESS',
        data: {'uid': user.uid},
      ));

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

      transaction.status = const SpanStatus.ok();

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
      transaction.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await transaction.finish();
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

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_1_AUTH_USER_CREATED',
        data: {'uid': user.uid, 'email': user.email ?? '', 'role': 'teacher', 'authProvider': 'google'},
      ));

      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: user.uid, email: user.email));
        scope.setTag('role', 'teacher');
        scope.setTag('organizationId', organizationId);
      });

      // Check if user document already exists
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'USER_DOC_ALREADY_EXISTS',
          data: {'uid': user.uid, 'flow': 'teacher_google'},
        ));
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

      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_START',
      ));

      try {
        await SentryFirestoreHelper.docSet(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: {
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
          },
          flow: 'teacher_google_registration',
          step: 'STEP_2_USER_DOC_CREATE',
        );

        KlasivoSentry.docIdAudit.logUserCreation(
          flow: 'teacher_google_registration',
          collection: AppConstants.usersCollection,
          docIdStrategy: 'uid',
          actualDocId: user.uid,
          authUid: user.uid,
        );
      } catch (e, st) {
        // SentryFirestoreHelper already captured — just rethrow
        rethrow;
      }

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_SUCCESS',
        data: {'uid': user.uid},
      ));

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
    final transaction = Sentry.startTransaction(
      'parent_registration',
      'registration',
    );

    try {
      final userCredential =
          await FirebaseService.registerWithEmail(email, password);
      final user = userCredential.user!;

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_1_AUTH_USER_CREATED',
        data: {'uid': user.uid, 'email': email, 'role': 'parent'},
      ));

      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: user.uid, email: email));
        scope.setTag('role', 'parent');
      });

      // Create user document with parent role
      // Parents need to link a child after registration
      final isEmailVerified = user.emailVerified;

      Sentry.addBreadcrumb(const Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_START',
      ));

      final createUserDocSpan = transaction.startChild('create_user_doc');

      try {
        await SentryFirestoreHelper.docSet(
          collection: AppConstants.usersCollection,
          docId: user.uid,
          data: {
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
          },
          flow: 'parent_registration',
          step: 'STEP_2_USER_DOC_CREATE',
        );

        KlasivoSentry.docIdAudit.logUserCreation(
          flow: 'parent_registration',
          collection: AppConstants.usersCollection,
          docIdStrategy: 'uid',
          actualDocId: user.uid,
          authUid: user.uid,
        );

        createUserDocSpan.status = const SpanStatus.ok();
      } catch (e, st) {
        createUserDocSpan.status = const SpanStatus.internalError();
        rethrow;
      } finally {
        await createUserDocSpan.finish();
      }

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_2_USER_DOC_CREATE_SUCCESS',
        data: {'uid': user.uid},
      ));

      transaction.status = const SpanStatus.ok();

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
      transaction.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await transaction.finish();
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
    final flowName = isNewUser ? '${expectedRole ?? 'owner'}_google_registration' : 'google_login';
    final transaction = Sentry.startTransaction(flowName, 'registration');

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

      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'STEP_1_AUTH_USER_CREATED',
        data: {'uid': user.uid, 'email': user.email ?? '', 'role': expectedRole ?? 'unknown', 'authProvider': 'google'},
      ));

      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: user.uid, email: user.email));
      });

      // Check if user document already exists
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'USER_DOC_ALREADY_EXISTS',
          data: {'uid': user.uid, 'flow': flowName},
        ));
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

        transaction.status = const SpanStatus.ok();
        await transaction.finish();

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
        Sentry.addBreadcrumb(const Breadcrumb(
          category: 'registration',
          message: 'STEP_2_USER_DOC_CREATE_START',
        ));

        final createUserDocSpan = transaction.startChild('create_user_doc');

        try {
          await SentryFirestoreHelper.docSet(
            collection: AppConstants.usersCollection,
            docId: user.uid,
            data: {
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
            },
            flow: flowName,
            step: 'STEP_2_USER_DOC_CREATE',
          );

          // Read-back verification: confirm the document actually exists
          final verifyDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .get();
          if (!verifyDoc.exists) {
            await Sentry.captureMessage(
              'STEP_2 USER DOC SET SUCCEEDED BUT READ-BACK FAILED — doc users/${user.uid} does not exist',
              level: SentryLevel.error,
            );
          }

          KlasivoSentry.docIdAudit.logUserCreation(
            flow: flowName,
            collection: AppConstants.usersCollection,
            docIdStrategy: 'uid',
            actualDocId: user.uid,
            authUid: user.uid,
          );

          createUserDocSpan.status = const SpanStatus.ok();
        } catch (e, st) {
          createUserDocSpan.status = const SpanStatus.internalError();
          rethrow;
        } finally {
          await createUserDocSpan.finish();
        }

        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'STEP_2_USER_DOC_CREATE_SUCCESS',
          data: {'uid': user.uid},
        ));

        // Now create the organization — rules can verify user is an owner
        Sentry.addBreadcrumb(const Breadcrumb(
          category: 'registration',
          message: 'STEP_3_ORG_CREATE_START',
        ));

        final createOrgSpan = transaction.startChild('create_organization');
        final orgService = OrganizationService();

        try {
          organizationId = await orgService.createOrganization(
            ownerId: user.uid,
            name: "$fullName's Workspace",
          );
          createOrgSpan.status = const SpanStatus.ok();
        } catch (e, st) {
          createOrgSpan.status = const SpanStatus.internalError();
          await Sentry.captureException(
            e,
            stackTrace: st,
            withScope: (scope) {
              scope.setTag('collection', 'organizations');
              scope.setTag('operation', 'create');
              scope.setTag('ownerId', user.uid);
              scope.setTag('flow', flowName);
              scope.setTag('step', 'STEP_3_ORG_CREATE');
            },
          );
          rethrow;
        } finally {
          await createOrgSpan.finish();
        }

        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'STEP_3_ORG_CREATE_SUCCESS',
          data: {'orgId': organizationId},
        ));

        // Patch the user doc with the real organizationId
        Sentry.addBreadcrumb(const Breadcrumb(
          category: 'registration',
          message: 'STEP_4_USER_PATCH_START',
        ));

        final patchSpan = transaction.startChild('update_user_doc');
        try {
          await SentryFirestoreHelper.docUpdate(
            collection: AppConstants.usersCollection,
            docId: user.uid,
            data: {
              'organizationId': organizationId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            flow: flowName,
            step: 'STEP_4_USER_PATCH',
          );
          patchSpan.status = const SpanStatus.ok();
        } catch (e, st) {
          patchSpan.status = const SpanStatus.internalError();
          rethrow;
        } finally {
          await patchSpan.finish();
        }

        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'STEP_4_USER_PATCH_SUCCESS',
          data: {'uid': user.uid, 'organizationId': organizationId},
        ));

        hasCompletedSetup = false; // Needs to name workspace
      } else if (role == AppConstants.roleParent) {
        organizationId = null; // Set when parent links a child
        hasCompletedSetup = false; // Needs to link child
      }

      // For non-owner roles, write the user doc normally (owner doc already created above)
      if (role != AppConstants.roleOwner) {
        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'STEP_2_USER_DOC_CREATE_START',
          data: {'role': role},
        ));

        try {
          await SentryFirestoreHelper.docSet(
            collection: AppConstants.usersCollection,
            docId: user.uid,
            data: {
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
            },
            flow: flowName,
            step: 'STEP_2_USER_DOC_CREATE',
          );

          // Read-back verification: confirm the document actually exists
          final verifyDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .get();
          if (!verifyDoc.exists) {
            await Sentry.captureMessage(
              'STEP_2 USER DOC SET SUCCEEDED BUT READ-BACK FAILED — doc users/${user.uid} does not exist (role=$role)',
              level: SentryLevel.error,
            );
          }

          KlasivoSentry.docIdAudit.logUserCreation(
            flow: flowName,
            collection: AppConstants.usersCollection,
            docIdStrategy: 'uid',
            actualDocId: user.uid,
            authUid: user.uid,
          );
        } catch (e, st) {
          rethrow;
        }
      }

      // Set Sentry org/role context after all writes
      await Sentry.configureScope((scope) {
        scope.setTag('role', role);
        if (organizationId != null) {
          scope.setTag('organizationId', organizationId);
        }
      });

      transaction.status = const SpanStatus.ok();

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
      transaction.status = const SpanStatus.internalError();
      rethrow;
    } finally {
      await transaction.finish();
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
      KlasivoSentry.breadcrumb.auth('logout_started');

      await GoogleSignIn().signOut();
      await FirebaseService.logout();

      // Clear Sentry user context
      await KlasivoSentry.userContext.clearUser();

      KlasivoSentry.breadcrumb.auth('logout_success');
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'logout');
        },
      );
      rethrow;
    }
  }

  // ─── Get Current User ──────────────────────────────────────────────────────

  User? get currentUser => FirebaseService.currentUser;

  // ─── Check if user is logged in ────────────────────────────────────────────

  bool get isLoggedIn => _auth.currentUser != null;

  // ─── Password Reset ────────────────────────────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    final transaction = KlasivoSentry.transactions.passwordReset();

    try {
      KlasivoSentry.breadcrumb.auth('password_reset_started', data: {
        'email': email,
      });

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

      KlasivoSentry.breadcrumb.auth('password_reset_email_sent', data: {
        'email': email,
      });

      transaction.status = const SpanStatus.ok();
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'password_reset');
          scope.setTag('step', 'send_reset_email');
        },
      );
      rethrow;
    } finally {
      await transaction.finish();
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
