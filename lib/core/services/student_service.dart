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

  Future<String> generateStudentCode(String teacherId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    bool exists;

    do {
      code = 'STU-';
      for (int i = 0; i < 6; i++) {
        code += chars[_random.nextInt(chars.length)];
      }
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();
      exists = snapshot.docs.isNotEmpty;
    } while (exists);

    return code;
  }

  Future<String> addStudent({
    required String teacherId,
    required String classId,
    required String className,
    required String fullName,
    required String password,
    String? grade,
    String? stageId,
    String? gradeId,
    String? groupId,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final studentCode = await generateStudentCode(teacherId);
      final passwordHash = hashPassword(password);

      final docRef = await _firestore
          .collection(AppConstants.studentsCollection)
          .add({
        'teacherId': teacherId,
        'classId': classId,
        'className': className,
        'fullName': fullName,
        'studentCode': studentCode,
        'password': password,
        'passwordHash': passwordHash,
        'grade': grade,
        'stageId': stageId,
        'gradeId': gradeId,
        'groupId': groupId,
        'institutionId': institutionId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update student count in class
      final countSnapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
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
    required String fullName,
    String? grade,
    String? password,
    String? stageId,
    String? gradeId,
    String? groupId,
  }) async {
    try {
      final data = <String, dynamic>{
        'fullName': fullName,
        'grade': grade,
      };
      if (stageId != null) data['stageId'] = stageId;
      if (gradeId != null) data['gradeId'] = gradeId;
      if (groupId != null) data['groupId'] = groupId;
      if (password != null && password.isNotEmpty) {
        data['password'] = password;
        data['passwordHash'] = hashPassword(password);
      }
      await _firestore
          .collection(AppConstants.studentsCollection)
          .doc(studentId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStudent(String studentId, String classId) async {
    try {
      await _firestore
          .collection(AppConstants.studentsCollection)
          .doc(studentId)
          .delete();

      final countSnapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
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
        .collection(AppConstants.studentsCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getStudentsByTeacherStream(String teacherId) {
    return _firestore
        .collection(AppConstants.studentsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<int> getTotalStudentCount(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> bulkAddStudents({
    required String teacherId,
    required String classId,
    required String className,
    required List<Map<String, String>> students,
    String? stageId,
    String? gradeId,
    String? groupId,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final List<String> createdIds = [];
      final batch = _firestore.batch();

      for (final student in students) {
        final studentCode = await generateStudentCode(teacherId);
        final password = student['password'] ?? AppConstants.defaultStudentPassword;
        final passwordHash = hashPassword(password);
        final docRef =
            _firestore.collection(AppConstants.studentsCollection).doc();

        batch.set(docRef, {
          'teacherId': teacherId,
          'classId': classId,
          'className': className,
          'fullName': student['fullName']!,
          'studentCode': studentCode,
          'password': password,
          'passwordHash': passwordHash,
          'grade': student['grade'],
          'stageId': stageId,
          'gradeId': gradeId,
          'groupId': groupId,
          'institutionId': institutionId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        createdIds.add(docRef.id);
      }

      await batch.commit();

      final countSnapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
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
