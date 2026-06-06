import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createClass({
    required String teacherId,
    required String name,
    String? grade,
    String? gradeId,
    String? stageId,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.classesCollection)
          .add({
        'teacherId': teacherId,
        'name': name,
        'grade': grade,
        'gradeId': gradeId,
        'stageId': stageId,
        'studentCount': 0,
        'institutionId': institutionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateClass({
    required String classId,
    required String name,
    String? grade,
    String? gradeId,
    String? stageId,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'grade': grade,
      };
      if (gradeId != null) data['gradeId'] = gradeId;
      if (stageId != null) data['stageId'] = stageId;

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClass(String classId) async {
    try {
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

  Stream<QuerySnapshot> getClassesStream(String teacherId) {
    return _firestore
        .collection(AppConstants.classesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot> getClasses(String teacherId) async {
    return await _firestore
        .collection(AppConstants.classesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .get();
  }

  Future<int> getStudentCount(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

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
