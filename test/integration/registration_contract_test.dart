// ═══════════════════════════════════════════════════════════════════════════════
// REGRESSION TEST: Registration Flows — Client ⇄ Cloud Function Contract
//
// WHY THIS TEST EXISTS:
// Three security patches in a row (P1-4 tightening) each broke a different
// layer of registration in a different way:
//   1. firestore.rules: invite_codes reads required auth → unauthenticated
//      validateInviteCode() failed (fixed in 02e97c2)
//   2. firestore.rules: /users/{uid} create only allows student/parent/teacher
//      → owner self-create was blocked (fixed in ebfa4e1 by switching to CF)
//   3. registerOwner/registerParent CFs had enforceAppCheck:true → App Check
//      tokens can't be minted pre-auth → UNAUTHENTICATED (fixed in 3fbf855)
//
// Each fix took a manual end-to-end test to catch. This file encodes the
// contracts that were violated so future patches fail fast at `flutter test`
// time instead of requiring a manual sign-up attempt.
//
// WHAT THIS TEST VERIFIES (static contract — no live Firebase needed):
//   A. Client calls the right CF name with the right arg shape
//   B. CF declares enforceAppCheck: false (or omits it) — registration is
//      pre-auth by definition, so App Check enforcement is always wrong here
//   C. CF returns the shape the client expects
//   D. /users/{uid} create rule allows exactly {student, parent, teacher}
//      for self-create — owner/admin/super_admin must come from a CF
//   E. invite_codes allows unauthenticated reads of unused, non-expired codes
//      (validateInviteCode runs before the user exists)
//
// WHAT THIS TEST DOES NOT VERIFY:
//   - CF internal behavior (use functions/test/ with firebase-functions-test)
//   - Rules behavior under real Auth context (use Firebase emulator suite)
//   - UI flow / navigation (use widget tests with mocked AuthService)
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Reads a file relative to the project root.
String _readProjectFile(String relativePath) {
  final projectRoot = Directory.current.path;
  final file = File('$projectRoot/$relativePath');
  if (!file.existsSync()) {
    fail('Required file not found: $relativePath (cwd: $projectRoot)');
  }
  return file.readAsStringSync();
}

/// Extracts the first block matching `marker(` ... `)` from [source].
/// Used to pull out the options object passed to `onCall({...}, async ...)`.
String? _extractOptionsBlock(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  if (markerIndex < 0) return null;
  final openBrace = source.indexOf('{', markerIndex);
  if (openBrace < 0) return null;
  var depth = 0;
  final buf = StringBuffer();
  for (var i = openBrace; i < source.length; i++) {
    final ch = source[i];
    buf.write(ch);
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return buf.toString();
    }
  }
  return null;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // A1. registerOwner contract (client ⇄ registerOwner CF)
  // ═══════════════════════════════════════════════════════════════════════════
  group('A1. registerOwnerViaCF → registerOwner CF', () {
    late String authServiceSrc;
    late String cfSrc;

    setUpAll(() {
      authServiceSrc = _readProjectFile('lib/core/services/auth_service.dart');
      cfSrc = _readProjectFile('functions/src/functions/registerOwner.ts');
    });

    test('client calls CF named "registerOwner"', () {
      // Regression for ebfa4e1: the original bug was that the client called
      // the deprecated registerOwner() method (direct Firestore write) instead
      // of the CF. This test ensures the CF call site exists.
      expect(
        authServiceSrc,
        contains("httpsCallable('registerOwner')"),
        reason: 'Client must call the registerOwner Cloud Function, not do a '
            'direct Firestore write. See commit ebfa4e1.',
      );
    });

    test('client sends {email, password, fullName, organizationName, phone?}', () {
      final callIdx = authServiceSrc.indexOf("httpsCallable('registerOwner')");
      expect(callIdx, greaterThanOrEqualTo(0));
      final callBlock = authServiceSrc.substring(callIdx, callIdx + 600);

      expect(callBlock, contains("'email'"));
      expect(callBlock, contains("'password'"));
      expect(callBlock, contains("'fullName'"));
      expect(callBlock, contains("'organizationName'"));
      expect(callBlock, contains("'phone'"),
          reason: 'phone must be passed (even if null) — the CF accepts it as '
              'optional and writes null to Firestore');
    });

    test('CF accepts {email, password, fullName, organizationName, phone?}', () {
      expect(cfSrc, contains('email: string'));
      expect(cfSrc, contains('password: string'));
      expect(cfSrc, contains('fullName: string'));
      expect(cfSrc, contains('organizationName: string'));
      expect(cfSrc, contains('phone?'));
    });

    test('CF returns {success, uid, organizationId}', () {
      // Client reads data['uid'] and data['organizationId'] — CF MUST return them.
      expect(cfSrc, contains('uid: authUser.uid'));
      expect(cfSrc, contains('organizationId: orgId'));
    });

    test('CF writes role:owner via Admin SDK (not client)', () {
      // Regression for ebfa4e1: owner docs must come from a CF because
      // firestore.rules only allows student/parent/teacher on self-create.
      expect(cfSrc, contains("role: 'owner'"));
      expect(cfSrc, contains('auth.createUser'),
          reason: 'CF must create the Auth account server-side');
      expect(cfSrc, contains('auth.setCustomUserClaims'),
          reason: 'CF must set custom claims server-side');
    });

    test('CF has rollback on failure', () {
      // If the CF creates the Auth account but then fails, it MUST roll back
      // or we leak orphaned Auth accounts (the A9 patch was added for this
      // exact scenario on the client side; the CF must do the same).
      expect(cfSrc, contains('deleteUser'),
          reason: 'CF must delete Auth account on failure');
    });

    test('CF has email-duplicate guard', () {
      // P2-2 abuse control — prevents Firebase Auth's raw 'email-already-exists'
      // from leaking to the client.
      expect(cfSrc, contains('getUserByEmail'),
          reason: 'CF must check for existing email before createUser');
      expect(cfSrc, contains('already-exists'),
          reason: 'CF must throw already-exists on duplicate email');
    });

    test('CF does NOT enforce App Check (pre-auth public endpoint)', () {
      // Regression for 3fbf855: enforceAppCheck:true on a pre-auth endpoint
      // returns UNAUTHENTICATED to legitimate sign-ups because App Check
      // tokens can't be reliably minted before Firebase Auth sign-in.
      final optionsBlock =
          _extractOptionsBlock(cfSrc, 'export const registerOwner = onCall(');
      expect(optionsBlock, isNotNull,
          reason: 'Could not find onCall options block — verify CF structure');
      expect(optionsBlock!, isNot(contains('enforceAppCheck: true')),
          reason: 'enforceAppCheck:true is forbidden on registration endpoints. '
              'See commit 3fbf855.');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // A2. registerParent contract
  // ═══════════════════════════════════════════════════════════════════════════
  group('A2. registerParentViaCF → registerParent CF', () {
    late String authServiceSrc;
    late String cfSrc;

    setUpAll(() {
      authServiceSrc = _readProjectFile('lib/core/services/auth_service.dart');
      cfSrc = _readProjectFile('functions/src/functions/registerParent.ts');
    });

    test('client calls CF named "registerParent"', () {
      expect(
        authServiceSrc,
        contains("httpsCallable('registerParent')"),
        reason: 'Client must call the registerParent Cloud Function, not do a '
            'direct Firestore write.',
      );
    });

    test('client sends {email, password, fullName, phone?, studentCode?}', () {
      final callIdx = authServiceSrc.indexOf("httpsCallable('registerParent')");
      expect(callIdx, greaterThanOrEqualTo(0));
      final callBlock = authServiceSrc.substring(callIdx, callIdx + 600);

      expect(callBlock, contains("'email'"));
      expect(callBlock, contains("'password'"));
      expect(callBlock, contains("'fullName'"));
      expect(callBlock, contains("'phone'"));
      expect(callBlock, contains("'studentCode'"));
    });

    test('CF accepts {email, password, fullName, phone?, studentCode?}', () {
      expect(cfSrc, contains('email: string'));
      expect(cfSrc, contains('password: string'));
      expect(cfSrc, contains('fullName: string'));
      expect(cfSrc, contains('phone?'));
      expect(cfSrc, contains('studentCode?'));
    });

    test('CF returns {success, uid}', () {
      // Client reads data['uid'] — CF MUST return it.
      expect(cfSrc, contains('uid: authUser.uid'));
      expect(cfSrc, contains('success: true'));
    });

    test('CF writes role:parent with organizationId as empty string (not null)', () {
      // Regression for the original P0-2 bug: client wrote organizationId:null
      // which failed the firestore.rules `is string` check. CF MUST write ''.
      expect(cfSrc, contains("role: 'parent'"));
      expect(cfSrc, contains("organizationId: ''"),
          reason: 'CF must write empty string, not null — firestore.rules '
              'requires organizationId is string. See P0-2 fix.');
    });

    test('CF has email-duplicate guard', () {
      // P2-2 abuse control — added in 3fbf855.
      expect(cfSrc, contains('getUserByEmail'),
          reason: 'CF must check for existing email before createUser');
      expect(cfSrc, contains('already-exists'),
          reason: 'CF must throw already-exists on duplicate email');
    });

    test('CF has rollback on failure', () {
      expect(cfSrc, contains('deleteUser'),
          reason: 'CF must delete Auth account on failure');
    });

    test('CF does NOT enforce App Check (pre-auth public endpoint)', () {
      // Regression for 3fbf855: this was the actual bug that caused parent
      // registration to fail with 'unauthenticated'.
      final optionsBlock =
          _extractOptionsBlock(cfSrc, 'export const registerParent = onCall(');
      expect(optionsBlock, isNotNull,
          reason: 'Could not find onCall options block — verify CF structure');
      expect(optionsBlock!, isNot(contains('enforceAppCheck: true')),
          reason: 'enforceAppCheck:true is forbidden on registration endpoints. '
              'This was the root cause of the "unauthenticated" error on '
              'parent registration. See commit 3fbf855.');
    });

    test('CF links parent to student when studentCode is provided', () {
      // This is the parent→student linking feature. If a future refactor
      // drops it, parents will register but never link to their child.
      expect(cfSrc, contains('studentCode'),
          reason: 'CF must accept studentCode');
      expect(cfSrc, contains('parent_links'),
          reason: 'CF must create a parent_links document when studentCode is provided');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // A3. Teacher email/password + invite (client-side flow)
  // ═══════════════════════════════════════════════════════════════════════════
  group('A3. registerTeacherWithInvite (CF-based flow)', () {
    late String authServiceSrc;
    late String cfSrc;

    setUpAll(() {
      authServiceSrc = _readProjectFile('lib/core/services/auth_service.dart');
      cfSrc = _readProjectFile('functions/src/functions/registerTeacher.ts');
    });

    test('client calls CF named "registerTeacher"', () {
      // P0-3 FIX: Teacher registration moved to a Cloud Function because the
      // old client-side flow tried to flip invite_codes.isUsed before the
      // teacher's custom claims were synced → cloud_firestore/permission-denied.
      final methodIdx = authServiceSrc
          .indexOf('Future<Map<String, dynamic>> registerTeacherWithInvite');
      expect(methodIdx, greaterThanOrEqualTo(0));
      final methodBlock =
          authServiceSrc.substring(methodIdx, methodIdx + 5000);

      expect(methodBlock, contains("httpsCallable('registerTeacher')"),
          reason: 'Teacher registration must go through the registerTeacher CF');
    });

    test('client does NOT directly write to invite_codes collection', () {
      // The CF handles invite-code flipping server-side (Admin SDK bypasses
      // rules). If the client ever writes to invite_codes directly again,
      // we'll reintroduce the permission-denied bug.
      final methodIdx = authServiceSrc
          .indexOf('Future<Map<String, dynamic>> registerTeacherWithInvite');
      expect(methodIdx, greaterThanOrEqualTo(0));
      final methodBlock =
          authServiceSrc.substring(methodIdx, methodIdx + 5000);

      expect(methodBlock, isNot(contains('inviteCodesCollection')),
          reason: 'Client must not directly touch invite_codes — CF does it');
      expect(methodBlock, isNot(contains("'isUsed': true")),
          reason: 'Client must not flip isUsed — CF does it');
    });

    test('client signs in the user after CF success', () {
      // The CF creates the Auth account server-side (Admin SDK). The client
      // must then sign in with email+password so subsequent Firestore reads
      // are authenticated.
      final methodIdx = authServiceSrc
          .indexOf('Future<Map<String, dynamic>> registerTeacherWithInvite');
      expect(methodIdx, greaterThanOrEqualTo(0));
      final methodBlock =
          authServiceSrc.substring(methodIdx, methodIdx + 5000);

      expect(methodBlock, contains('FirebaseService.loginWithEmail'),
          reason: 'Client must sign in the user after the CF creates the account');
    });

    test('CF writes role:teacher (NOT owner/admin)', () {
      expect(cfSrc, contains("role: 'teacher'"),
          reason: 'registerTeacher CF must write role:teacher to the user doc');
      expect(cfSrc, isNot(contains("role: 'owner'")),
          reason: 'Owner role must never be granted by registerTeacher CF');
    });

    test('CF has rollback for orphaned Auth account', () {
      // A9 PATCH: if the doc write fails after Auth account creation, the
      // Auth account must be rolled back server-side.
      expect(cfSrc, contains('auth.deleteUser'),
          reason: 'registerTeacher CF must roll back orphaned Auth accounts');
    });

    test('CF marks invite code as used via transaction', () {
      // The invite flip must be atomic (transaction) to prevent race
      // conditions where two teachers redeem the same single-use code.
      expect(cfSrc, contains('runTransaction'),
          reason: 'registerTeacher CF must flip invite atomically');
      expect(cfSrc, contains('isUsed'),
          reason: 'CF must flip isUsed on the invite code');
      expect(cfSrc, contains('usedBy'),
          reason: 'CF must record who used the invite code');
    });

    test('CF does NOT enforce App Check (pre-auth public endpoint)', () {
      // Same pattern as registerOwner/registerParent (commit 3fbf855):
      // enforceAppCheck:true returns UNAUTHENTICATED to legitimate sign-ups
      // because App Check tokens can't be reliably minted before sign-in.
      expect(cfSrc, isNot(contains('enforceAppCheck: true')),
          reason: 'registerTeacher CF must not enforce App Check (pre-auth endpoint)');
    });

    test('CF validates invite type is teacher', () {
      expect(cfSrc, contains("'teacher'"),
          reason: 'CF must validate that the invite code type is teacher');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // A4. Student creation (owner/teacher creates student)
  // ═══════════════════════════════════════════════════════════════════════════
  group('A4. Student creation → createStudent CF', () {
    late String studentServiceSrc;
    late String cfSrc;

    setUpAll(() {
      studentServiceSrc = _readProjectFile('lib/core/services/student_service.dart');
      cfSrc = _readProjectFile('functions/src/functions/createStudent.ts');
    });

    test('client calls CF named "createStudent"', () {
      expect(
        studentServiceSrc,
        contains("httpsCallable('createStudent')"),
        reason: 'Student creation must go through the createStudent Cloud Function. '
            'Direct Firestore writes would bypass the passwordHash + studentCode '
            'generation logic.',
      );
    });

    test('CF writes role:student via Admin SDK', () {
      expect(cfSrc, contains("'student'"),
          reason: 'CF must write role:student');
    });

    test('CF has rollback on failure', () {
      // Same pattern as registerOwner/registerParent.
      expect(cfSrc, contains('deleteUser'),
          reason: 'CF must delete Auth account on failure');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // B. Firestore rules contract
  // ═══════════════════════════════════════════════════════════════════════════
  group('B. firestore.rules contract', () {
    late String rulesSrc;

    setUpAll(() {
      rulesSrc = _readProjectFile('firestore.rules');
    });

    test('B1. /users/{uid} self-create allows exactly {student, parent, teacher}', () {
      // Regression for ebfa4e1: rules were tightened to forbid owner/admin
      // self-create. If someone widens this list, owner registration could
      // silently start working via direct client write again — undoing the
      // security design that requires owners to come from a CF.
      expect(
        rulesSrc,
        contains("['student', 'parent', 'teacher']"),
        reason: '/users/{uid} create must only allow student/parent/teacher. '
            'owner/admin/super_admin must come from a Cloud Function. '
            'See commit ebfa4e1.',
      );
    });

    test('B2. /users/{uid} create requires request.auth.uid == userId', () {
      // Self-create only — prevents a user from creating docs under another uid.
      expect(
        rulesSrc,
        contains('request.auth.uid == userId'),
        reason: 'Self-create only — a user must not be able to create user docs '
            'for other uids.',
      );
    });

    test('B3. /users/{uid} create requires organizationId is string', () {
      // Regression for P0-2: client used to write organizationId:null which
      // failed this check. The check MUST stay so a future client bug doesn't
      // silently write null again.
      expect(
        rulesSrc,
        contains('organizationId is string'),
        reason: 'organizationId must be a string (not null). See P0-2 fix.',
      );
    });

    test('B4. invite_codes allows unauthenticated reads of unused, non-expired codes', () {
      // Regression for 02e97c2: validateInviteCode() runs BEFORE the user
      // exists, so the read must be allowed for unauthenticated users under
      // strict conditions (unused + not expired).
      expect(
        rulesSrc,
        contains('!isAuth()'),
        reason: 'invite_codes must allow unauthenticated reads for the '
            'validateInviteCode flow. See commit 02e97c2.',
      );
      expect(
        rulesSrc,
        contains('resource.data.isUsed == false'),
        reason: 'Unauthenticated reads must be restricted to UNUSED codes only.',
      );
    });

    test('B5. /users/{uid} client delete is forbidden', () {
      // C-08: NEVER allow client deletes on users — would orphan orgs/classes.
      expect(
        rulesSrc,
        contains('allow delete: if false'),
        reason: 'Client deletes on /users must be forbidden. See C-08.',
      );
    });

    test('B6. /users/{uid} self-update blocks privilege escalation fields', () {
      // D1: Block self-mutation of role, organizationId, tenantId, etc.
      // If a future patch removes these guards, a compromised client could
      // self-promote to owner/admin.
      expect(
        rulesSrc,
        contains("'role', 'organizationId', 'tenantId'"),
        reason: 'Self-update must block role/organizationId/tenantId mutation. See D1.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // C. AppConstants contract — roles referenced by both client and tests must
  //    stay in sync with firestore.rules and the CF TypeScript types.
  // ═══════════════════════════════════════════════════════════════════════════
  group('C. AppConstants role values', () {
    test('role values match firestore.rules + CFs', () {
      // If someone changes AppConstants.roleOwner from 'owner' to 'OWNER',
      // the client would write 'OWNER' which firestore.rules would reject.
      // This test enforces the literal string values.
      expect(AppConstants.roleOwner, equals('owner'));
      expect(AppConstants.roleTeacher, equals('teacher'));
      expect(AppConstants.roleStudent, equals('student'));
      expect(AppConstants.roleParent, equals('parent'));
    });

    test('inviteTypeTeacher matches firestore.rules', () {
      expect(AppConstants.inviteTypeTeacher, equals('teacher'));
    });

    test('collection names match firestore.rules', () {
      expect(AppConstants.usersCollection, equals('users'));
      expect(AppConstants.inviteCodesCollection, equals('invite_codes'));
    });
  });
}
