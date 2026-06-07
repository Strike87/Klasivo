import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class StageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createStage({
    required String teacherId,
    required String name,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef = await _firestore.collection(AppConstants.stagesCollection).add({
        'teacherId': teacherId,
        'name': name,
        'institutionId': institutionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStage({required String stageId, required String name}) async {
    try {
      await _firestore.collection(AppConstants.stagesCollection).doc(stageId).update({'name': name});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStage(String stageId) async {
    try {
      // Delete all grades in this stage
      final gradesSnapshot = await _firestore
          .collection(AppConstants.gradesCollection)
          .where('stageId', isEqualTo: stageId)
          .get();
      final batch = _firestore.batch();
      for (final doc in gradesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection(AppConstants.stagesCollection).doc(stageId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getStagesStream(String teacherId) {
    return _firestore
        .collection(AppConstants.stagesCollection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getStages(String teacherId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.stagesCollection)
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }
}
