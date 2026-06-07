import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import '../config/app_constants.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Hash a password using SHA-256
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> generateStudentCode(String organizationId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    bool exists;

    do {
      code = 'STU-';
      for (int i = 0; i < 6; i++) {
        code += chars[_random.nextInt(chars.length)];
      }
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();
      exists = snapshot.docs.isNotEmpty;
    } while (exists);

    return code;
  }

  /// Add a student to the users collection
  Future<String> addStudent({
    required String organizationId,
    required String classId,
    required String fullName,
    required String password,
    String? email,
    String? phone,
    String createdBy = '',
  }) async {
    try {
      final studentCode = await generateStudentCode(organizationId);
      final passwordHash = hashPassword(password);

      final docRef = await _firestore
          .collection(AppConstants.usersCollection)
          .add({
        'organizationId': organizationId,
        'role': AppConstants.roleStudent,
        'fullName': fullName,
        'studentCode': studentCode,
        'password': password,
        'passwordHash': passwordHash,
        'classId': classId,
        'email': email,
        'phone': phone,
        'photoUrl': null,
        'isActive': true,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update student count in class
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count});

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStudent({
    required String studentId,
    String? fullName,
    String? classId,
    String? email,
    String? phone,
    String? password,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (fullName != null) data['fullName'] = fullName;
      if (classId != null) data['classId'] = classId;
      if (email != null) data['email'] = email;
      if (phone != null) data['phone'] = phone;
      if (isActive != null) data['isActive'] = isActive;
      if (password != null && password.isNotEmpty) {
        data['password'] = password;
        data['passwordHash'] = hashPassword(password);
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStudent(String studentId, String classId) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(studentId)
          .delete();

      // Update student count
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count});
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getStudentsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('classId', isEqualTo: classId)
        .where('role', isEqualTo: AppConstants.roleStudent)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getStudentsByOrganizationStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('role', isEqualTo: AppConstants.roleStudent)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<int> getTotalStudentCount(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> bulkAddStudents({
    required String organizationId,
    required String classId,
    required List<Map<String, String>> students,
    String createdBy = '',
  }) async {
    try {
      final List<String> createdIds = [];
      final batch = _firestore.batch();

      for (final student in students) {
        final studentCode = await generateStudentCode(organizationId);
        final password =
            student['password'] ?? AppConstants.defaultStudentPassword;
        final passwordHash = hashPassword(password);
        final docRef =
            _firestore.collection(AppConstants.usersCollection).doc();

        batch.set(docRef, {
          'organizationId': organizationId,
          'role': AppConstants.roleStudent,
          'fullName': student['fullName']!,
          'studentCode': studentCode,
          'password': password,
          'passwordHash': passwordHash,
          'classId': classId,
          'email': student['email'],
          'phone': student['phone'],
          'photoUrl': null,
          'isActive': true,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        createdIds.add(docRef.id);
      }

      await batch.commit();

      // Update student count
      final countSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count});

      return createdIds;
    } catch (e) {
      rethrow;
    }
  }
}
