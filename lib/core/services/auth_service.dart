import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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

  // P0-12 PATCH: static hashPassword() removed. It was dead code — its own
  // doc comment claimed it existed for backward compatibility with
  // lib/features/auth/data/auth_service.dart:233, but that file no longer
  // exists in the codebase. loginStudent() (below) already authenticates
  // via FirebaseAuth.signInWithEmailAndPassword() directly, never comparing
  // a client-computed hash against a stored passwordHash field. Server-side
  // password hashing lives in functions/src/utils/passwordHash.ts (scrypt).
  /// A9 PATCH: Best-effort rollback of an orphaned Firebase Auth account.
  ///
  /// Called from the catch block of every registration method that creates
  /// an Auth account BEFORE writing the Firestore user doc. If the Firestore
  /// write (or any subsequent step) fails, the Auth account would be orphaned
  /// — it would fire onUserCreated with no user doc, send a welcome email to
  /// a non-existent user, and linger in Firebase Auth indefinitely.
  ///
  /// This method:
  ///   1. Signs in the user (if not already) using email+password.
  ///   2. Deletes the current user's Auth account.
  ///   3. Logs the rollback to Sentry.
  ///
  /// If the rollback itself fails (network, permissions, account already
  /// deleted), logs a CRITICAL Sentry message for manual cleanup.
  ///
  /// [flow] is the registration flow name (e.g., 'registerOwner') for audit.
  /// [originalError] is the error that triggered the rollback.
  /// [email]/[password] are the credentials of the orphaned account.
  Future<void> _rollbackOrphanedAuthAccount({
    required String flow,
    required Object originalError,
    required String email,
    required String password,
  }) async {
    try {
      // Sign in to get a currentUser we can delete. The registration flow
      // may have created the account but not signed in, or may have signed
      // in and then failed on a subsequent step. Either way, we need to be
      // signed in as the orphaned user to call .delete().
      try {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } on FirebaseAuthException catch (signInErr) {
        // If sign-in fails (e.g., account already deleted, or network error),
        // we can't delete via the client SDK. Log for manual cleanup.
        await Sentry.captureMessage(
          'A9 CRITICAL: Cannot rollback orphaned Auth account in $flow. '
          'Sign-in failed: ${signInErr.code}. '
          'Manual cleanup required in Firebase Console → Authentication → Users '
          'for email=$email. Original error: $originalError',
          level: SentryLevel.error,
        );
        return;
      }

      final orphanedUid = _auth.currentUser?.uid;
      if (orphanedUid == null) {
        await Sentry.captureMessage(
          'A9: No currentUser to rollback in $flow. Account may already be clean. '
          'Original error: $originalError',
          level: SentryLevel.info,
        );
        return;
      }

      await _auth.currentUser?.delete();
      await Sentry.captureMessage(
        'A9: Rolled back orphaned Auth account $orphanedUid (email=$email) in $flow. '
        'Original error: $originalError',
        level: SentryLevel.info,
      );
    } catch (rollbackError) {
      await Sentry.captureMessage(
        'A9 CRITICAL: Failed to rollback orphaned Auth account in $flow. '
        'Manual cleanup required in Firebase Console → Authentication → Users '
        'for email=$email. Original error: $originalError. Rollback error: $rollbackError',
        level: SentryLevel.error,
      );
    }
  }

  // ─── Owner Registration (Email + Password) ────────────────────────────────

  /// P0-1 FIX (Day 4): Register owner via Cloud Function.
  ///
  /// Replaces the old `registerOwner` which wrote role:'owner' from the client
  /// — blocked by Firestore rules (only student/parent/teacher are allowed on
  /// self-create; owner must come from a CF writing via Admin SDK).
  ///
  /// The CF (functions/src/functions/registerOwner.ts) atomically:
  ///   1. Creates the Firebase Auth account
  ///   2. Creates the organization doc
  ///   3. Creates the user doc with role:'owner' + real organizationId
  ///   4. Sets custom claims (role, organizationId, roleVersion)
  ///   5. Writes an audit log
  ///   6. Returns { uid, organizationId }
  ///
  /// After the CF succeeds, this method signs the user in with the provided
  /// email + password so subsequent Firestore reads are authenticated.
  Future<Map<String, dynamic>> registerOwnerViaCF({
    required String email,
    required String password,
    required String fullName,
    required String organizationName,
    String? phone,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('registerOwner')
          .call({
        'email': email,
        'password': password,
        'fullName': fullName,
        'organizationName': organizationName,
        'phone': phone,
      });

      final data = result.data as Map<String, dynamic>;
      final uid = data['uid'] as String;
      final orgId = data['organizationId'] as String;

      // Sign in the newly created user so subsequent Firestore reads are
      // authenticated (the CF uses Admin SDK which bypasses rules; the client
      // now needs its own Auth session to read its own user doc).
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      return {
        'success': true,
        'uid': uid,
        'organizationId': orgId,
        'role': 'owner',
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Registration failed',
        'code': e.code,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// DEPRECATED: Use registerOwnerViaCF instead.
  /// This method attempts to write role:'owner' from the client, which is
  /// blocked by Firestore rules. Kept for backward compatibility only.
  Future<Map<String, dynamic>> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final transaction = Sentry.startTransaction(
      'owner_registration',
      'registration',
    );

    // ── Forensic bookend: registration start ───────────────────────────
    Sentry.addBreadcrumb(Breadcrumb(
      category: 'registration',
      message: 'REGISTER_START',
      data: {'method': 'email', 'email': email, 'fullName': fullName},
    ));
    await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'REGISTER_START_email');
    await FirebaseCrashlytics.instance.setCustomKey('registration_email', email);

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
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'STEP_1_AUTH_USER_CREATED');
      await FirebaseCrashlytics.instance.setCustomKey('uid', user.uid);

      // Set Sentry user context immediately after auth account creation
      await Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: user.uid, email: email));
      });

      final isEmailVerified = user.emailVerified;

      // ── Step 2: Create user document in Firestore ──────────────────────
      Sentry.addBreadcrumb(Breadcrumb(
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
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'STEP_2_USER_DOC_CREATE_SUCCESS');

      // ── Step 3: Create organization ────────────────────────────────────
      Sentry.addBreadcrumb(Breadcrumb(
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
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'STEP_3_ORG_CREATE_SUCCESS');
      await FirebaseCrashlytics.instance.setCustomKey('orgId', orgId);

      // ── Step 4: Patch user doc with real organizationId ────────────────
      Sentry.addBreadcrumb(Breadcrumb(
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
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'STEP_4_USER_PATCH_SUCCESS');

      // ── Step 4b: Final read-back verification of COMPLETE user doc ─────
      // After the patch, the user doc should have organizationId set.
      // Read it back to confirm the full document is consistent.
      final finalCheck = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();
      if (!finalCheck.exists) {
        await Sentry.captureMessage(
          'STEP_4b FINAL READ-BACK FAILED — users/${user.uid} does NOT exist after patch',
          level: SentryLevel.error,
        );
        FirebaseCrashlytics.instance.recordError(
          'FINAL_READBACK_FAILED: users/${user.uid} missing after Step 4 patch',
          StackTrace.current,
          reason: 'owner_registration final verification',
        );
      } else {
        final finalOrgId = finalCheck.data()?['organizationId'] as String? ?? '';
        final finalRole = finalCheck.data()?['role'] as String? ?? '';
        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'STEP_4b_FINAL_READBACK_VERIFIED',
          data: {
            'uid': user.uid,
            'docExists': true,
            'organizationId': finalOrgId,
            'organizationIdMatches': finalOrgId == orgId,
            'role': finalRole,
          },
        ));
        if (finalOrgId != orgId) {
          await Sentry.captureMessage(
            'STEP_4b ORG_ID_MISMATCH — expected=$orgId actual=$finalOrgId for users/${user.uid}',
            level: SentryLevel.error,
          );
        }
      }

      // Set Sentry org context after creation
      await Sentry.configureScope((scope) {
        scope.setTag('organizationId', orgId);
        scope.setTag('role', 'owner');
      });

      transaction.status = const SpanStatus.ok();

      // ── Forensic bookend: registration complete ────────────────────────
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'REGISTER_COMPLETE',
        data: {'uid': user.uid, 'orgId': orgId, 'method': 'email'},
      ));
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'REGISTER_COMPLETE');

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
      // A9 PATCH: Rollback orphaned Auth account on any failure.
      // Previous code caught the error and rethrew but did NOT delete the
      // Auth account created at Step 1. This left orphaned Auth accounts
      // that fired onUserCreated with no Firestore user doc → welcome email
      // to a non-existent user, and the account existed indefinitely in
      // Firebase Auth with no way for the user to know.
      await _rollbackOrphanedAuthAccount(
        flow: 'registerOwner',
        originalError: e,
        email: email,
        password: password,
      );
      transaction.status = const SpanStatus.internalError();
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'REGISTER_FAILED');
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

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

      Sentry.addBreadcrumb(Breadcrumb(
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
  /// A1 PATCH: Derive the synthetic authEmail from a student code.
  /// Mirrors functions/src/functions/createStudent.ts:generateAuthEmail().
  /// Pattern: `student_${code.toLowerCase().replaceAll('-', '')}@students.klasivo.app`.
  /// This eliminates the chicken-and-egg where loginStudent needed to read
  /// the user doc BEFORE signing in, but Firestore rules require auth to read.
  /// By deriving the authEmail client-side, we can sign in FIRST, then read.
  static String _deriveStudentAuthEmail(String studentCode) {
    final cleanCode = studentCode.toLowerCase().replaceAll('-', '');
    return 'student_$cleanCode@students.klasivo.app';
  }

  /// Login a student using student code + password.
  ///
  /// A1+A2 PATCH (Phase 2): Previous flow did an UNAUTHENTICATED Firestore
  /// `.get()` against `users.where('studentCode', isEqualTo: code)` BEFORE
  /// `signInWithEmailAndPassword` → permission-denied (chicken-and-egg).
  /// A try/catch then swallowed ALL Auth errors and returned success even on
  /// wrong password → wrong-password student flagged isLoggedIn=true.
  ///
  /// New flow:
  ///   1. Derive synthetic authEmail from studentCode (no Firestore read).
  ///   2. Call signInWithEmailAndPassword(authEmail, password) FIRST.
  ///      - Wrong code → user-not-found (authEmail doesn't exist)
  ///      - Wrong password → wrong-password
  ///      - Disabled account → user-disabled
  ///   3. After successful Auth sign-in, fetch the user doc (now allowed).
  ///   4. Verify the doc's studentCode matches what the user entered (defense
  ///      in depth — catches any authEmail-pattern collision).
  ///   5. Return user map on success; throw on any failure.
  Future<Map<String, dynamic>> loginStudent({
    required String studentCode,
    required String password,
  }) async {
    final transaction = KlasivoSentry.transactions.loginFlow('student');

    try {
      KlasivoSentry.breadcrumb.auth('login_started', data: {
        'method': 'student_code',
      });

      // ── A1: Derive authEmail client-side (no Firestore read needed) ──
      final authEmail = _deriveStudentAuthEmail(studentCode);

      // ── Step 1: Sign in via Firebase Auth FIRST ────────────────────────
      // This replaces the previous unauthenticated Firestore lookup.
      // If the student code is wrong, the derived authEmail won't exist →
      // user-not-found. If the password is wrong → wrong-password. Both
      // are clean Auth errors that surface to the user.
      final signInSpan = transaction.startChild('auth_signin');
      try {
        await _auth.signInWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        KlasivoSentry.breadcrumb.auth('student_auth_signed_in', data: {
          'authEmail': authEmail,
        });
      } on FirebaseAuthException catch (authError) {
        // A2 PATCH: Do NOT swallow Auth errors. Previous code had a
        // try/catch here that swallowed ALL errors and returned success,
        // causing wrong-password students to be flagged isLoggedIn=true.
        // Now we translate Auth error codes to user-friendly messages and
        // rethrow — login FAILS on any Auth error.
        signInSpan.status = const SpanStatus.internalError();
        KlasivoSentry.breadcrumb.auth('login_failed_auth_error', data: {
          'method': 'student_code',
          'code': authError.code,
        });
        String userMessage;
        switch (authError.code) {
          case 'user-not-found':
            userMessage = 'Student not found. Please check your student code.';
            break;
          case 'wrong-password':
          case 'invalid-credential':
            userMessage = 'Invalid student code or password. Please try again.';
            break;
          case 'user-disabled':
            userMessage = 'Your account has been deactivated.';
            break;
          case 'too-many-requests':
            userMessage = 'Too many login attempts. Please try again later.';
            break;
          case 'network-request-failed':
            userMessage = 'Network error. Please check your connection and try again.';
            break;
          default:
            userMessage = 'Login failed: ${authError.message ?? authError.code}';
        }
        throw Exception(userMessage);
      }
      await signInSpan.finish();

      // ── Step 2: Fetch the user doc by UID (single-doc read — bypasses list-query orgId requirement) ──
      // AUDIT FIX #1 (CRITICAL): Previously queried users.where('studentCode', isEqualTo: code)
      // which is a LIST query. Firestore rules require isInSameOrg() for list queries on
      // org-scoped collections — but at this point we don't yet know the user's orgId (it's
      // stored IN the doc we're trying to fetch). Result: every student login was denied.
      // Fix: read the doc directly by the authenticated UID. Single-doc reads can be
      // authorized via `request.auth.uid == userId` (no orgId filter needed).
      final findUserSpan = transaction.startChild('find_user_by_code');
      final uid = _auth.currentUser!.uid;
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      await findUserSpan.finish();

      if (!userDoc.exists) {
        // Auth succeeded but Firestore doc missing — sign out and fail.
        // This is an inconsistent state (Auth account exists, user doc doesn't).
        // Log to Sentry for manual investigation.
        await _auth.signOut();
        await Sentry.captureMessage(
          'A1: Auth sign-in succeeded for $authEmail (uid=$uid) but no Firestore user doc exists at users/$uid. '
          'Possible data inconsistency (Auth account exists without Firestore doc).',
          level: SentryLevel.error,
        );
        throw Exception('Account data not found. Please contact your administrator.');
      }

      final student = userDoc.data()!;

      // ── Step 2.5: Defense-in-depth — verify role is student ───────────
      // AUDIT FIX #1 (CRITICAL): Single-doc read bypasses the role filter that
      // the old list query had (.where('role', isEqualTo: 'student')). Re-add
      // it explicitly here to prevent a non-student Auth account from using
      // the student login flow.
      final docRole = student['role'] as String?;
      if (docRole != AppConstants.roleStudent) {
        await _auth.signOut();
        await Sentry.captureMessage(
          'A1: Role mismatch in student login flow. uid=$uid, docRole=$docRole, '
          'authEmail=$authEmail. Non-student attempted student login.',
          level: SentryLevel.warning,
        );
        throw Exception('This account is not a student account.');
      }

      // ── Step 3: Defense-in-depth — verify studentCode matches ──────────
      // Catches the (extremely unlikely) case where two student codes
      // derive to the same authEmail pattern.
      final docStudentCode = student['studentCode'] as String?;
      if (docStudentCode != studentCode) {
        await _auth.signOut();
        await Sentry.captureMessage(
          'A1: studentCode mismatch after sign-in. Entered=$studentCode, '
          'doc=$docStudentCode, authEmail=$authEmail. Possible collision.',
          level: SentryLevel.error,
        );
        throw Exception('Account data mismatch. Please contact your administrator.');
      }

      // ── Step 4: Verify account is active ────────────────────────────────
      final isActive = student['isActive'] as bool? ?? true;
      if (!isActive) {
        await _auth.signOut();
        KlasivoSentry.breadcrumb.auth('login_failed_account_deactivated', data: {
          'userId': userDoc.id,
          'role': 'student',
        });
        throw Exception('Your account has been deactivated.');
      }

      // ── Step 5: Check isArchived (D21 alignment) ────────────────────────
      final isArchived = student['isArchived'] as bool? ?? false;
      if (isArchived) {
        await _auth.signOut();
        throw Exception('Your account has been archived. Please contact your administrator.');
      }

      // Set Sentry user context
      await KlasivoSentry.userContext.setUser(
        uid: userDoc.id,
        email: authEmail,
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
      Sentry.addBreadcrumb(Breadcrumb(
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

        // Read-back verification for teacher registration
        final verifyTeacherDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        if (!verifyTeacherDoc.exists) {
          await KlasivoObservability.reportMessage(
            'STEP_2 TEACHER DOC SET SUCCEEDED BUT READ-BACK FAILED — '
            'doc users/${user.uid} does not exist after .set()',
            level: SentryLevel.error,
            tags: {'flow': 'teacher_registration', 'step': 'STEP_2_READBACK'},
          );
        } else {
          Sentry.addBreadcrumb(Breadcrumb(
            category: 'registration',
            message: 'STEP_2_USER_DOC_READBACK_VERIFIED',
            data: {'uid': user.uid, 'docExists': true},
          ));
        }

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
      // A9 PATCH: Rollback orphaned Auth account on any failure.
      // registerTeacherWithInvite creates the Auth account at registerWithEmail
      // (line ~758) BEFORE writing the Firestore user doc. If the doc write or
      // invite-code update fails, the Auth account is orphaned.
      await _rollbackOrphanedAuthAccount(
        flow: 'registerTeacherWithInvite',
        originalError: e,
        email: email,
        password: password,
      );
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

      Sentry.addBreadcrumb(Breadcrumb(
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

  /// P0-2 FIX (Day 4): Register parent via Cloud Function.
  ///
  /// Replaces the old `registerParent` which wrote organizationId:null from
  /// the client — blocked by Firestore rules (is string check fails on null).
  ///
  /// The CF (functions/src/functions/registerParent.ts) atomically:
  ///   1. Creates the Firebase Auth account
  ///   2. Creates the user doc with role:'parent' + organizationId:'' (empty
  ///      string, not null — passes the is-string rule)
  ///   3. Sets custom claims
  ///   4. If studentCode is provided, links parent to student + updates
  ///      organizationId to match the student's org + creates a parent_link
  ///   5. Returns { uid }
  ///
  /// After the CF succeeds, this method signs the user in.
  Future<Map<String, dynamic>> registerParentViaCF({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? studentCode,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('registerParent')
          .call({
        'email': email,
        'password': password,
        'fullName': fullName,
        'phone': phone,
        'studentCode': studentCode,
      });

      final data = result.data as Map<String, dynamic>;
      final uid = data['uid'] as String;

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      return {
        'success': true,
        'uid': uid,
        'role': 'parent',
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Registration failed',
        'code': e.code,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// DEPRECATED: Use registerParentViaCF instead.
  /// This method writes organizationId:null from the client, which fails the
  /// Firestore rules `is string` check. Kept for backward compatibility only.
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

      Sentry.addBreadcrumb(Breadcrumb(
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

        // Read-back verification for parent email registration
        final verifyParentDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        if (!verifyParentDoc.exists) {
          await KlasivoObservability.reportMessage(
            'STEP_2 PARENT DOC SET SUCCEEDED BUT READ-BACK FAILED — '
            'doc users/${user.uid} does not exist after .set()',
            level: SentryLevel.error,
            tags: {'flow': 'parent_registration', 'step': 'STEP_2_READBACK'},
          );
        } else {
          Sentry.addBreadcrumb(Breadcrumb(
            category: 'registration',
            message: 'STEP_2_USER_DOC_READBACK_VERIFIED',
            data: {'uid': user.uid, 'docExists': true},
          ));
        }

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
      // A9 PATCH: Rollback orphaned Auth account on any failure.
      // registerParent creates the Auth account at registerWithEmail (line ~1112)
      // BEFORE writing the Firestore user doc. If the doc write fails, the
      // Auth account is orphaned.
      await _rollbackOrphanedAuthAccount(
        flow: 'registerParent',
        originalError: e,
        email: email,
        password: password,
      );
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

    // ── Forensic bookend: registration start (Google) ───────────────────
    if (isNewUser) {
      Sentry.addBreadcrumb(Breadcrumb(
        category: 'registration',
        message: 'REGISTER_START',
        data: {'method': 'google', 'expectedRole': expectedRole ?? 'unknown'},
      ));
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'REGISTER_START_google');
    }

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
      await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'STEP_1_AUTH_USER_CREATED_google');
      await FirebaseCrashlytics.instance.setCustomKey('uid', user.uid);

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
        Sentry.addBreadcrumb(Breadcrumb(
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
        Sentry.addBreadcrumb(Breadcrumb(
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
        Sentry.addBreadcrumb(Breadcrumb(
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
        await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'STEP_4_USER_PATCH_SUCCESS_google');
        await FirebaseCrashlytics.instance.setCustomKey('orgId', organizationId ?? '');

        // ── Step 4b: Final read-back verification of COMPLETE user doc ────
        final finalCheck = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        if (!finalCheck.exists) {
          await Sentry.captureMessage(
            'STEP_4b FINAL READ-BACK FAILED (Google) — users/${user.uid} does NOT exist after patch',
            level: SentryLevel.error,
          );
          FirebaseCrashlytics.instance.recordError(
            'FINAL_READBACK_FAILED: users/${user.uid} missing after Step 4 patch (Google)',
            StackTrace.current,
            reason: 'google_owner_registration final verification',
          );
        } else {
          final finalOrgId = finalCheck.data()?['organizationId'] as String? ?? '';
          Sentry.addBreadcrumb(Breadcrumb(
            category: 'registration',
            message: 'STEP_4b_FINAL_READBACK_VERIFIED',
            data: {
              'uid': user.uid,
              'docExists': true,
              'organizationId': finalOrgId,
              'organizationIdMatches': finalOrgId == organizationId,
            },
          ));
          if (finalOrgId != organizationId) {
            await Sentry.captureMessage(
              'STEP_4b ORG_ID_MISMATCH (Google) — expected=$organizationId actual=$finalOrgId',
              level: SentryLevel.error,
            );
          }
        }

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

      // ── Forensic bookend: registration complete (Google) ────────────────
      if (isNewUser) {
        Sentry.addBreadcrumb(Breadcrumb(
          category: 'registration',
          message: 'REGISTER_COMPLETE',
          data: {'uid': user.uid, 'orgId': organizationId, 'method': 'google', 'role': role},
        ));
        await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'REGISTER_COMPLETE_google');
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
      transaction.status = const SpanStatus.internalError();
      if (isNewUser) {
        await FirebaseCrashlytics.instance.setCustomKey('registration_state', 'REGISTER_FAILED_google');
      }
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
    final role = await _getCurrentRole();
    final transaction = KlasivoSentry.transactions.logoutFlow(role);
    try {
      KlasivoSentry.breadcrumb.auth('logout_started');

      await GoogleSignIn().signOut();
      await FirebaseService.logout();

      // Clear Sentry + Crashlytics user context
      await KlasivoSentry.userContext.clearUser();

      KlasivoSentry.breadcrumb.auth('logout_success');
      transaction.status = const SpanStatus.ok();
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'logout');
        },
      );
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  /// Get the current user's role from Firestore or Hive cache.
  String _getCurrentRole() {
    try {
      final box = Hive.box(AppConstants.authBox);
      return box.get('userRole', defaultValue: 'unknown') as String;
    } catch (_) {
      return 'unknown';
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
