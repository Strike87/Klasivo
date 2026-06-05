import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Create a new class ──────────────────────────────────────────────────

  Future<String> createClass({
    required String teacherId,
    required String name,
    String? grade,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.classesCollection)
          .add({
        'teacherId': teacherId,
        'name': name,
        'grade': grade,
        'studentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update an existing class ────────────────────────────────────────────

  Future<void> updateClass({
    required String classId,
    required String name,
    String? grade,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({
        'name': name,
        'grade': grade,
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Delete a class and its students ─────────────────────────────────────

  Future<void> deleteClass(String classId) async {
    try {
      // Delete all students in this class
      final studentsSnapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
          .get();

      final batch = _firestore.batch();
      for (final doc in studentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
        _firestore.collection(AppConstants.classesCollection).doc(classId),
      );
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get a single class ──────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getClass(String classId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .get();
      return doc.data();
    } catch (e) {
      rethrow;
    }
  }

  // ─── Get stream of classes for a teacher ─────────────────────────────────

  Stream<QuerySnapshot> getClassesStream(String teacherId) {
    return _firestore
        .collection(AppConstants.classesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Get all classes for a teacher (one-time fetch) ──────────────────────

  Future<QuerySnapshot> getClasses(String teacherId) async {
    return await _firestore
        .collection(AppConstants.classesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .get();
  }

  // ─── Get student count for a class ───────────────────────────────────────

  Future<int> getStudentCount(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
          .count()
          .get();
      return snapshot.count;
    } catch (e) {
      rethrow;
    }
  }

  // ─── Update student count in class ───────────────────────────────────────

  Future<void> updateStudentCount(String classId, int count) async {
    try {
      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': count});
    } catch (e) {
      rethrow;
    }
  }
}
