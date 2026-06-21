import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TEST: Auth Flow
//
// Tests the full authentication lifecycle using FakeFirebaseFirestore.
// Since the real AuthService depends on FirebaseAuth (which can't be faked
// without firebase_auth_mocks or similar), we test the Firestore-side
// integration directly — the user document creation, organization creation,
// student code login, deactivation checks, and setup completion.
//
// These tests validate the data flow through Firestore that AuthService
// orchestrates in production.
// ═══════════════════════════════════════════════════════════════════════════════

/// Simulates the Firestore operations of AuthService without FirebaseAuth dependency.
/// This allows us to test the data integration layer that AuthService manages.
class TestableAuthFlowService {
  final FirebaseFirestore _db;

  TestableAuthFlowService(this._db);

  // ─── Simulate Owner Registration (Firestore side) ───────────────────────
  Future<Map<String, dynamic>> simulateOwnerRegistration({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    // Step 1: Create user document with placeholder orgId
    await _db.collection(AppConstants.usersCollection).doc(uid).set({
      'organizationId': '',
      'role': AppConstants.roleOwner,
      'authProvider': 'password',
      'fullName': fullName,
      'email': email,
      'photoUrl': null,
      'phoneNumber': null,
      'isActive': true,
      'isEmailVerified': false,
      'hasCompletedSetup': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Step 2: Create organization
    final orgDoc = await _db
        .collection(AppConstants.organizationsCollection)
        .add({
      'ownerId': uid,
      'name': "$fullName's Workspace",
      'slug': fullName.toLowerCase().replaceAll(' ', '-'),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Step 3: Patch user with real orgId
    await _db.collection(AppConstants.usersCollection).doc(uid).update({
      'organizationId': orgDoc.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return {
      'id': uid,
      'organizationId': orgDoc.id,
      'role': AppConstants.roleOwner,
      'fullName': fullName,
      'email': email,
      'hasCompletedSetup': false,
    };
  }

  // ─── Simulate Complete Owner Setup ──────────────────────────────────────
  Future<void> completeOwnerSetup({
    required String userId,
    required String organizationId,
    required String workspaceName,
  }) async {
    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .update({
      'name': workspaceName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'hasCompletedSetup': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Simulate Email Login (Firestore side — read user doc) ──────────────
  Future<Map<String, dynamic>> simulateEmailLogin({
    required String uid,
  }) async {
    final userDoc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!userDoc.exists) {
      throw Exception('User data not found. Please contact your administrator.');
    }

    final userData = userDoc.data()!;
    final role = userData['role'] as String?;
    final isActive = userData['isActive'] as bool? ?? true;

    if (!isActive) {
      throw Exception('Your account has been deactivated. Contact your administrator.');
    }

    if (role == AppConstants.roleStudent) {
      throw Exception('Students must login with their student code.');
    }

    return {
      'id': uid,
      'organizationId': userData['organizationId'] ?? '',
      'role': role ?? AppConstants.roleTeacher,
      'fullName': userData['fullName'] ?? 'User',
      'email': userData['email'] ?? '',
      'hasCompletedSetup': userData['hasCompletedSetup'] ?? true,
    };
  }

  // ─── Simulate Student Code Login ────────────────────────────────────────
  Future<Map<String, dynamic>> simulateStudentLogin({
    required String studentCode,
    required String password,
  }) async {
    final snapshot = await _db
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

    // Check password hash
    final storedPasswordHash = student['passwordHash'] as String?;
    final storedPlaintext = student['password'] as String?;

    bool passwordMatches = false;
    if (storedPasswordHash != null && storedPasswordHash.isNotEmpty) {
      // Compare hash
      final inputBytes = utf8.encode(password);
      final inputHash = sha256.convert(inputBytes).toString();
      passwordMatches = inputHash == storedPasswordHash;
    } else if (storedPlaintext != null) {
      passwordMatches = password == storedPlaintext;
      // Migrate to hash on successful login
      if (passwordMatches) {
        final inputBytes = utf8.encode(password);
        final inputHash = sha256.convert(inputBytes).toString();
        await _db
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
      'hasCompletedSetup': true,
    };
  }

  // ─── Simulate Teacher Invite Registration ───────────────────────────────
  Future<Map<String, dynamic>> simulateTeacherInviteRegistration({
    required String uid,
    required String email,
    required String fullName,
    required String inviteCode,
  }) async {
    // Validate invite code
    final codeSnapshot = await _db
        .collection(AppConstants.inviteCodesCollection)
        .where('code', isEqualTo: inviteCode)
        .where('type', isEqualTo: AppConstants.inviteTypeTeacher)
        .limit(1)
        .get();

    if (codeSnapshot.docs.isEmpty) {
      throw Exception('Invalid or expired invite code.');
    }

    final codeDoc = codeSnapshot.docs.first;
    final codeData = codeDoc.data();
    final organizationId = codeData['organizationId'] as String;

    // Create user document
    await _db.collection(AppConstants.usersCollection).doc(uid).set({
      'organizationId': organizationId,
      'role': AppConstants.roleTeacher,
      'authProvider': 'password',
      'fullName': fullName,
      'email': email,
      'photoUrl': null,
      'phoneNumber': null,
      'isActive': true,
      'isEmailVerified': false,
      'hasCompletedSetup': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mark invite code as used
    await _db
        .collection(AppConstants.inviteCodesCollection)
        .doc(codeDoc.id)
        .update({
      'isUsed': true,
      'usedBy': uid,
      'usedAt': FieldValue.serverTimestamp(),
      'useCount': FieldValue.increment(1),
    });

    return {
      'id': uid,
      'organizationId': organizationId,
      'role': AppConstants.roleTeacher,
      'fullName': fullName,
      'email': email,
      'hasCompletedSetup': true,
    };
  }

  // ─── Simulate Parent Registration ───────────────────────────────────────
  Future<Map<String, dynamic>> simulateParentRegistration({
    required String uid,
    required String email,
    required String fullName,
  }) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).set({
      'organizationId': null,
      'role': AppConstants.roleParent,
      'authProvider': 'password',
      'fullName': fullName,
      'email': email,
      'photoUrl': null,
      'phoneNumber': null,
      'isActive': true,
      'isEmailVerified': false,
      'hasCompletedSetup': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return {
      'id': uid,
      'organizationId': null,
      'role': AppConstants.roleParent,
      'fullName': fullName,
      'email': email,
      'hasCompletedSetup': false,
    };
  }

  // ─── Sync Email Verification ────────────────────────────────────────────
  Future<void> syncEmailVerification(String userId, bool isVerified) async {
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'isEmailVerified': isVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Needs Setup Check ──────────────────────────────────────────────────
  Future<bool> needsSetup(String uid) async {
    final userDoc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!userDoc.exists) return false;

    final data = userDoc.data()!;
    final role = data['role'] as String?;
    final hasCompletedSetup = data['hasCompletedSetup'] as bool? ?? true;

    if ((role == AppConstants.roleOwner || role == AppConstants.roleParent) &&
        !hasCompletedSetup) {
      return true;
    }

    return false;
  }
}

// SHA-256 implementation (same as production AuthService)

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late FakeFirebaseFirestore firestore;
  late TestableAuthFlowService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TestableAuthFlowService(firestore);
  });

  // ─── Owner Registration Flow ─────────────────────────────────────────────

  group('Owner Registration Flow — Full Integration', () {
    test('creates user doc + organization + patches orgId', () async {
      final result = await service.simulateOwnerRegistration(
        uid: 'owner_123',
        email: 'owner@school.com',
        fullName: 'Ahmed Mohamed',
      );

      // Verify return value
      expect(result['id'], equals('owner_123'));
      expect(result['role'], equals(AppConstants.roleOwner));
      expect(result['hasCompletedSetup'], isFalse);
      expect(result['organizationId'], isNotEmpty);

      // Verify user document in Firestore
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('owner_123')
          .get();

      expect(userDoc.exists, isTrue);
      final userData = userDoc.data()!;
      expect(userData['role'], equals(AppConstants.roleOwner));
      expect(userData['organizationId'], equals(result['organizationId']));
      expect(userData['fullName'], equals('Ahmed Mohamed'));
      expect(userData['email'], equals('owner@school.com'));
      expect(userData['isActive'], isTrue);
      expect(userData['hasCompletedSetup'], isFalse);

      // Verify organization document
      final orgDoc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(result['organizationId'])
          .get();

      expect(orgDoc.exists, isTrue);
      final orgData = orgDoc.data()!;
      expect(orgData['ownerId'], equals('owner_123'));
      expect(orgData['name'], equals("Ahmed Mohamed's Workspace"));
    });

    test('organizationId is patched from empty string to real ID', () async {
      // This verifies the critical two-step write:
      // 1. User doc created with organizationId: ''
      // 2. Org created → user doc patched with real orgId

      final result = await service.simulateOwnerRegistration(
        uid: 'owner_456',
        email: 'test@school.com',
        fullName: 'Sara Ali',
      );

      // The final user doc should have the real orgId, not the placeholder
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('owner_456')
          .get();

      expect(userDoc.data()!['organizationId'], isNotEmpty);
      expect(userDoc.data()!['organizationId'], equals(result['organizationId']));
    });
  });

  // ─── Complete Owner Setup Flow ───────────────────────────────────────────

  group('Complete Owner Setup — Workspace Naming', () {
    test('updates org name and marks setup complete', () async {
      final regResult = await service.simulateOwnerRegistration(
        uid: 'owner_789',
        email: 'owner@test.com',
        fullName: 'Test Owner',
      );

      await service.completeOwnerSetup(
        userId: 'owner_789',
        organizationId: regResult['organizationId'],
        workspaceName: 'My Academy',
      );

      // Verify org name updated
      final orgDoc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(regResult['organizationId'])
          .get();

      expect(orgDoc.data()!['name'], equals('My Academy'));

      // Verify user setup completed
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('owner_789')
          .get();

      expect(userDoc.data()!['hasCompletedSetup'], isTrue);
    });

    test('needsSetup returns true before completion, false after', () async {
      final regResult = await service.simulateOwnerRegistration(
        uid: 'owner_setup',
        email: 'setup@test.com',
        fullName: 'Setup Owner',
      );

      // Before completion
      expect(await service.needsSetup('owner_setup'), isTrue);

      await service.completeOwnerSetup(
        userId: 'owner_setup',
        organizationId: regResult['organizationId'],
        workspaceName: 'Setup Academy',
      );

      // After completion
      expect(await service.needsSetup('owner_setup'), isFalse);
    });
  });

  // ─── Email Login Flow ────────────────────────────────────────────────────

  group('Email Login Flow — Read User + Validation', () {
    test('returns user data for active teacher', () async {
      // Seed a teacher user
      await firestore.collection(AppConstants.usersCollection).doc('teacher_1').set({
        'organizationId': 'org1',
        'role': AppConstants.roleTeacher,
        'fullName': 'Teacher One',
        'email': 'teacher@school.com',
        'isActive': true,
        'hasCompletedSetup': true,
      });

      final result = await service.simulateEmailLogin(uid: 'teacher_1');

      expect(result['id'], equals('teacher_1'));
      expect(result['role'], equals(AppConstants.roleTeacher));
      expect(result['organizationId'], equals('org1'));
      expect(result['fullName'], equals('Teacher One'));
    });

    test('returns user data for active owner', () async {
      await firestore.collection(AppConstants.usersCollection).doc('owner_1').set({
        'organizationId': 'org1',
        'role': AppConstants.roleOwner,
        'fullName': 'Owner One',
        'email': 'owner@school.com',
        'isActive': true,
        'hasCompletedSetup': true,
      });

      final result = await service.simulateEmailLogin(uid: 'owner_1');

      expect(result['role'], equals(AppConstants.roleOwner));
    });

    test('throws for non-existent user', () async {
      expect(
        () => service.simulateEmailLogin(uid: 'nonexistent'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws for deactivated user', () async {
      await firestore.collection(AppConstants.usersCollection).doc('deactivated_1').set({
        'organizationId': 'org1',
        'role': AppConstants.roleTeacher,
        'fullName': 'Deactivated Teacher',
        'email': 'deactivated@school.com',
        'isActive': false,
        'hasCompletedSetup': true,
      });

      expect(
        () => service.simulateEmailLogin(uid: 'deactivated_1'),
        throwsA(isA<Exception>()),
      );
    });

    test('throws for student using email login', () async {
      await firestore.collection(AppConstants.usersCollection).doc('student_1').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Student One',
        'email': 'student@school.com',
        'isActive': true,
        'hasCompletedSetup': true,
      });

      expect(
        () => service.simulateEmailLogin(uid: 'student_1'),
        throwsA(isA<Exception>()),
      );
    });

    test('login flow: register → login → verify data consistency', () async {
      // Register owner
      final regResult = await service.simulateOwnerRegistration(
        uid: 'flow_user',
        email: 'flow@test.com',
        fullName: 'Flow User',
      );

      // Login with same UID
      final loginResult = await service.simulateEmailLogin(uid: 'flow_user');

      // Data should be consistent between registration and login
      expect(loginResult['id'], equals(regResult['id']));
      expect(loginResult['organizationId'], equals(regResult['organizationId']));
      expect(loginResult['role'], equals(regResult['role']));
      expect(loginResult['fullName'], equals(regResult['fullName']));
    });
  });

  // ─── Student Code Login Flow ─────────────────────────────────────────────

  group('Student Code Login Flow — Firestore Query + Validation', () {
    test('authenticates student with correct student code and password', () async {
      // Seed student with plaintext password
      await firestore.collection(AppConstants.usersCollection).doc('student_1').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Student One',
        'studentCode': 'STU001',
        'classId': 'class1',
        'password': '123456',
        'passwordHash': '',
        'isActive': true,
      });

      final result = await service.simulateStudentLogin(
        studentCode: 'STU001',
        password: '123456',
      );

      expect(result['id'], equals('student_1'));
      expect(result['role'], equals(AppConstants.roleStudent));
      expect(result['studentCode'], equals('STU001'));
      expect(result['classId'], equals('class1'));
    });

    test('migrates plaintext password to hash on successful login', () async {
      await firestore.collection(AppConstants.usersCollection).doc('student_2').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Student Two',
        'studentCode': 'STU002',
        'classId': 'class1',
        'password': '123456',
        'passwordHash': '',
        'isActive': true,
      });

      await service.simulateStudentLogin(
        studentCode: 'STU002',
        password: '123456',
      );

      // Verify passwordHash was written
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('student_2')
          .get();

      final hash = userDoc.data()!['passwordHash'] as String;
      expect(hash, isNotEmpty);

      // Verify hash matches expected SHA-256 of '123456'
      final expectedHash = sha256.convert(utf8.encode('123456')).toString();
      expect(hash, equals(expectedHash));
    });

    test('authenticates with hashed password', () async {
      final hash = sha256.convert(utf8.encode('123456')).toString();

      await firestore.collection(AppConstants.usersCollection).doc('student_3').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Student Three',
        'studentCode': 'STU003',
        'classId': 'class1',
        'passwordHash': hash,
        'isActive': true,
      });

      final result = await service.simulateStudentLogin(
        studentCode: 'STU003',
        password: '123456',
      );

      expect(result['id'], equals('student_3'));
    });

    test('rejects wrong password', () async {
      await firestore.collection(AppConstants.usersCollection).doc('student_4').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Student Four',
        'studentCode': 'STU004',
        'classId': 'class1',
        'password': '123456',
        'passwordHash': '',
        'isActive': true,
      });

      expect(
        () => service.simulateStudentLogin(studentCode: 'STU004', password: 'wrong'),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects unknown student code', () async {
      expect(
        () => service.simulateStudentLogin(studentCode: 'INVALID', password: '123456'),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects deactivated student', () async {
      await firestore.collection(AppConstants.usersCollection).doc('student_5').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Deactivated Student',
        'studentCode': 'STU005',
        'classId': 'class1',
        'password': '123456',
        'passwordHash': '',
        'isActive': false,
      });

      expect(
        () => service.simulateStudentLogin(studentCode: 'STU005', password: '123456'),
        throwsA(isA<Exception>()),
      );
    });

    test('does not match non-student users by student code', () async {
      // A teacher with a "studentCode" field should not match
      await firestore.collection(AppConstants.usersCollection).doc('teacher_fake').set({
        'organizationId': 'org1',
        'role': AppConstants.roleTeacher,
        'fullName': 'Fake Student',
        'studentCode': 'FAKE001',
        'password': '123456',
        'isActive': true,
      });

      expect(
        () => service.simulateStudentLogin(studentCode: 'FAKE001', password: '123456'),
        throwsA(isA<Exception>()),
        reason: 'Query filters by role=student, so teacher should not match',
      );
    });
  });

  // ─── Teacher Invite Registration Flow ────────────────────────────────────

  group('Teacher Invite Registration Flow', () {
    test('registers teacher with valid invite code', () async {
      // Seed invite code
      await firestore.collection(AppConstants.inviteCodesCollection).add({
        'code': 'TEACH2024',
        'type': AppConstants.inviteTypeTeacher,
        'organizationId': 'org1',
        'isUsed': false,
        'useCount': 0,
      });

      final result = await service.simulateTeacherInviteRegistration(
        uid: 'teacher_new',
        email: 'newteacher@school.com',
        fullName: 'New Teacher',
        inviteCode: 'TEACH2024',
      );

      expect(result['id'], equals('teacher_new'));
      expect(result['role'], equals(AppConstants.roleTeacher));
      expect(result['organizationId'], equals('org1'));
      expect(result['hasCompletedSetup'], isTrue);

      // Verify user document
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('teacher_new')
          .get();

      expect(userDoc.exists, isTrue);
      expect(userDoc.data()!['role'], equals(AppConstants.roleTeacher));
      expect(userDoc.data()!['organizationId'], equals('org1'));

      // Verify invite code marked as used
      final codesSnapshot = await firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('code', isEqualTo: 'TEACH2024')
          .get();

      expect(codesSnapshot.docs.first.data()!['isUsed'], isTrue);
      expect(codesSnapshot.docs.first.data()!['usedBy'], equals('teacher_new'));
    });

    test('rejects invalid invite code', () async {
      expect(
        () => service.simulateTeacherInviteRegistration(
          uid: 'teacher_bad',
          email: 'bad@school.com',
          fullName: 'Bad Teacher',
          inviteCode: 'INVALID',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects student-type invite code for teacher registration', () async {
      // Seed a student-type invite code
      await firestore.collection(AppConstants.inviteCodesCollection).add({
        'code': 'STU2024',
        'type': AppConstants.inviteTypeStudent,
        'organizationId': 'org1',
        'isUsed': false,
        'useCount': 0,
      });

      expect(
        () => service.simulateTeacherInviteRegistration(
          uid: 'teacher_wrong_type',
          email: 'wrong@school.com',
          fullName: 'Wrong Type',
          inviteCode: 'STU2024',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── Parent Registration Flow ────────────────────────────────────────────

  group('Parent Registration Flow', () {
    test('creates parent with null organizationId and incomplete setup', () async {
      final result = await service.simulateParentRegistration(
        uid: 'parent_1',
        email: 'parent@test.com',
        fullName: 'Parent One',
      );

      expect(result['id'], equals('parent_1'));
      expect(result['role'], equals(AppConstants.roleParent));
      expect(result['organizationId'], isNull);
      expect(result['hasCompletedSetup'], isFalse);

      // Verify Firestore
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('parent_1')
          .get();

      expect(userDoc.exists, isTrue);
      expect(userDoc.data()!['role'], equals(AppConstants.roleParent));
      expect(userDoc.data()!['hasCompletedSetup'], isFalse);
    });

    test('parent needs setup until child is linked', () async {
      await service.simulateParentRegistration(
        uid: 'parent_setup',
        email: 'parent_setup@test.com',
        fullName: 'Parent Setup',
      );

      expect(await service.needsSetup('parent_setup'), isTrue);

      // Simulate linking child by updating orgId and setup
      await firestore
          .collection(AppConstants.usersCollection)
          .doc('parent_setup')
          .update({
        'organizationId': 'org1',
        'hasCompletedSetup': true,
      });

      expect(await service.needsSetup('parent_setup'), isFalse);
    });
  });

  // ─── Email Verification Sync ─────────────────────────────────────────────

  group('Email Verification Sync', () {
    test('updates isEmailVerified field', () async {
      await service.simulateOwnerRegistration(
        uid: 'verify_user',
        email: 'verify@test.com',
        fullName: 'Verify User',
      );

      // Initially not verified
      var userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('verify_user')
          .get();
      expect(userDoc.data()!['isEmailVerified'], isFalse);

      // Sync verification
      await service.syncEmailVerification('verify_user', true);

      userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('verify_user')
          .get();
      expect(userDoc.data()!['isEmailVerified'], isTrue);
    });
  });

  // ─── Full Auth Lifecycle — End-to-End ────────────────────────────────────

  group('Full Auth Lifecycle — Owner End-to-End', () {
    test('register → needsSetup → completeSetup → login', () async {
      // 1. Register
      final regResult = await service.simulateOwnerRegistration(
        uid: 'e2e_owner',
        email: 'e2e@school.com',
        fullName: 'E2E Owner',
      );

      expect(regResult['role'], equals(AppConstants.roleOwner));
      expect(regResult['hasCompletedSetup'], isFalse);

      // 2. Check needsSetup
      expect(await service.needsSetup('e2e_owner'), isTrue);

      // 3. Complete setup
      await service.completeOwnerSetup(
        userId: 'e2e_owner',
        organizationId: regResult['organizationId'],
        workspaceName: 'E2E Academy',
      );

      expect(await service.needsSetup('e2e_owner'), isFalse);

      // 4. Login
      final loginResult = await service.simulateEmailLogin(uid: 'e2e_owner');
      expect(loginResult['role'], equals(AppConstants.roleOwner));
      expect(loginResult['hasCompletedSetup'], isTrue);

      // 5. Verify org name was updated
      final orgDoc = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(regResult['organizationId'])
          .get();

      expect(orgDoc.data()!['name'], equals('E2E Academy'));
    });
  });

  group('Full Auth Lifecycle — Teacher End-to-End', () {
    test('invite → register → login', () async {
      // 1. Create invite code
      await firestore.collection(AppConstants.inviteCodesCollection).add({
        'code': 'INVITE2024',
        'type': AppConstants.inviteTypeTeacher,
        'organizationId': 'org_teacher',
        'isUsed': false,
        'useCount': 0,
      });

      // 2. Register with invite
      final regResult = await service.simulateTeacherInviteRegistration(
        uid: 'e2e_teacher',
        email: 'teacher_e2e@school.com',
        fullName: 'E2E Teacher',
        inviteCode: 'INVITE2024',
      );

      expect(regResult['role'], equals(AppConstants.roleTeacher));
      expect(regResult['hasCompletedSetup'], isTrue);
      expect(regResult['organizationId'], equals('org_teacher'));

      // 3. Login
      final loginResult = await service.simulateEmailLogin(uid: 'e2e_teacher');
      expect(loginResult['role'], equals(AppConstants.roleTeacher));
      expect(loginResult['organizationId'], equals('org_teacher'));
    });
  });

  group('Full Auth Lifecycle — Student End-to-End', () {
    test('seed → login → password migration → re-login', () async {
      // 1. Seed student with plaintext password
      await firestore.collection(AppConstants.usersCollection).doc('e2e_student').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'E2E Student',
        'studentCode': 'E2ESTU',
        'classId': 'class1',
        'password': 'mypass123',
        'passwordHash': '',
        'isActive': true,
      });

      // 2. First login — plaintext password should work and get migrated to hash
      final login1 = await service.simulateStudentLogin(
        studentCode: 'E2ESTU',
        password: 'mypass123',
      );

      expect(login1['id'], equals('e2e_student'));
      expect(login1['role'], equals(AppConstants.roleStudent));

      // 3. Verify password was migrated
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc('e2e_student')
          .get();

      final hash = userDoc.data()!['passwordHash'] as String;
      expect(hash, isNotEmpty);

      // 4. Second login — should work with hash
      final login2 = await service.simulateStudentLogin(
        studentCode: 'E2ESTU',
        password: 'mypass123',
      );

      expect(login2['id'], equals('e2e_student'));

      // 5. Wrong password should fail
      expect(
        () => service.simulateStudentLogin(studentCode: 'E2ESTU', password: 'wrongpass'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── Multi-User Isolation ────────────────────────────────────────────────

  group('Multi-User Isolation', () {
    test('different users in same org have separate documents', () async {
      // Create org
      final ownerResult = await service.simulateOwnerRegistration(
        uid: 'org_owner',
        email: 'org_owner@school.com',
        fullName: 'Org Owner',
      );
      final orgId = ownerResult['organizationId'];

      // Create teacher in same org
      await firestore.collection(AppConstants.usersCollection).doc('org_teacher').set({
        'organizationId': orgId,
        'role': AppConstants.roleTeacher,
        'fullName': 'Org Teacher',
        'email': 'org_teacher@school.com',
        'isActive': true,
        'hasCompletedSetup': true,
      });

      // Create student in same org
      await firestore.collection(AppConstants.usersCollection).doc('org_student').set({
        'organizationId': orgId,
        'role': AppConstants.roleStudent,
        'fullName': 'Org Student',
        'studentCode': 'ORGSTU',
        'classId': 'class1',
        'password': '123456',
        'isActive': true,
        'hasCompletedSetup': true,
      });

      // Verify each user's data is separate
      final ownerLogin = await service.simulateEmailLogin(uid: 'org_owner');
      final teacherLogin = await service.simulateEmailLogin(uid: 'org_teacher');

      expect(ownerLogin['role'], equals(AppConstants.roleOwner));
      expect(teacherLogin['role'], equals(AppConstants.roleTeacher));
      expect(ownerLogin['organizationId'], equals(teacherLogin['organizationId']));

      // Student uses different login method
      final studentLogin = await service.simulateStudentLogin(
        studentCode: 'ORGSTU',
        password: '123456',
      );
      expect(studentLogin['role'], equals(AppConstants.roleStudent));
    });
  });

  // ─── Deactivation Security ───────────────────────────────────────────────

  group('Deactivation Security — Prevent Deactivated Access', () {
    test('deactivated owner cannot login via email', () async {
      await firestore.collection(AppConstants.usersCollection).doc('deact_owner').set({
        'organizationId': 'org1',
        'role': AppConstants.roleOwner,
        'fullName': 'Deactivated Owner',
        'email': 'deact@school.com',
        'isActive': false,
        'hasCompletedSetup': true,
      });

      expect(
        () => service.simulateEmailLogin(uid: 'deact_owner'),
        throwsA(isA<Exception>()),
      );
    });

    test('deactivated student cannot login via student code', () async {
      await firestore.collection(AppConstants.usersCollection).doc('deact_student').set({
        'organizationId': 'org1',
        'role': AppConstants.roleStudent,
        'fullName': 'Deactivated Student',
        'studentCode': 'DEACTSTU',
        'password': '123456',
        'isActive': false,
      });

      expect(
        () => service.simulateStudentLogin(studentCode: 'DEACTSTU', password: '123456'),
        throwsA(isA<Exception>()),
      );
    });

    test('active user can be deactivated after registration', () async {
      await service.simulateOwnerRegistration(
        uid: 'will_deactivate',
        email: 'willdeact@school.com',
        fullName: 'Will Deactivate',
      );

      // Can login initially
      final login1 = await service.simulateEmailLogin(uid: 'will_deactivate');
      expect(login1['role'], equals(AppConstants.roleOwner));

      // Deactivate
      await firestore
          .collection(AppConstants.usersCollection)
          .doc('will_deactivate')
          .update({'isActive': false});

      // Cannot login after deactivation
      expect(
        () => service.simulateEmailLogin(uid: 'will_deactivate'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
