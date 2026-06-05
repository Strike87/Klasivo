import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // ─── Generate a unique student code ──────────────────────────────────────

  Future<String> generateStudentCode(String teacherId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    bool exists;

    do {
      code = 'STU-';
      for (int i = 0; i < 6; i++) {
        code += chars[_random.nextInt(chars.length)];
      }
      // Check if code already exists
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();
      exists = snapshot.docs.isNotEmpty;
    } while (exists);

    return code;
  }

  // ─── Add a new student ───────────────────────────────────────────────────

  Future<String> addStudent({
    required String teacherId,
    required String classId,
    required String className,
    required String fullName,
    required String password,
    String? grade,
  }) async {
    try {
      final studentCode = await generateStudentCode(teacherId);

      final docRef = await _firestore
          .collection(AppConstants.studentsCollection)
          .add({
        'teacherId': teacherId,
        'classId': classId,
        'className': className,
        'fullName': fullName,
        'studentCode': studentCode,
        'password': password,
        'grade': grade,
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

  // ─── Update an existing student ──────────────────────────────────────────

  Future<void> updateStudent({
    required String studentId,
    required String fullName,
    String? grade,
    String? password,
  }) async {
    try {
      final data = <String, dynamic>{
        'fullName': fullName,
        'grade': grade,
      };
      if (password != null && password.isNotEmpty) {
        data['password'] = password;
      }
      await _firestore
          .collection(AppConstants.studentsCollection)
          .doc(studentId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  // ─── Delete a student ────────────────────────────────────────────────────

  Future<void> deleteStudent(String studentId, String classId) async {
    try {
      await _firestore
          .collection(AppConstants.studentsCollection)
          .doc(studentId)
          .delete();

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
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get stream of students for a class ──────────────────────────────────

  Stream<QuerySnapshot> getStudentsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.studentsCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Get all students for a teacher ──────────────────────────────────────

  Stream<QuerySnapshot> getStudentsByTeacherStream(String teacherId) {
    return _firestore
        .collection(AppConstants.studentsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Get total student count for a teacher ───────────────────────────────

  Future<int> getTotalStudentCount(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('teacherId', isEqualTo: teacherId)
          .count()
          .get();
      return snapshot.count;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Bulk add students to a class ────────────────────────────────────────

  Future<List<String>> bulkAddStudents({
    required String teacherId,
    required String classId,
    required String className,
    required List<Map<String, String>> students,
  }) async {
    try {
      final List<String> createdIds = [];
      final batch = _firestore.batch();

      for (final student in students) {
        final studentCode = await generateStudentCode(teacherId);
        final docRef =
            _firestore.collection(AppConstants.studentsCollection).doc();

        batch.set(docRef, {
          'teacherId': teacherId,
          'classId': classId,
          'className': className,
          'fullName': student['fullName']!,
          'studentCode': studentCode,
          'password': student['password'] ?? '123456',
          'grade': student['grade'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        createdIds.add(docRef.id);
      }

      await batch.commit();

      // Update student count
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
