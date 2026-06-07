import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGrade({
    required String stageId,
    required String name,
    required String teacherId,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef = await _firestore.collection(AppConstants.gradesCollection).add({
        'stageId': stageId,
        'name': name,
        'teacherId': teacherId,
        'institutionId': institutionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateGrade({required String gradeId, required String name}) async {
    try {
      await _firestore.collection(AppConstants.gradesCollection).doc(gradeId).update({'name': name});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGrade(String gradeId) async {
    try {
      await _firestore.collection(AppConstants.gradesCollection).doc(gradeId).delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getGradesByStageStream(String stageId) {
    return _firestore
        .collection(AppConstants.gradesCollection)
        .where('stageId', isEqualTo: stageId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getGradesByTeacherStream(String teacherId) {
    return _firestore
        .collection(AppConstants.gradesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getGradesByStage(String stageId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.gradesCollection)
          .where('stageId', isEqualTo: stageId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }
}
