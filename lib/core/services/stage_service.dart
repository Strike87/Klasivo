import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class StageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createStage({
    required String organizationId,
    required String name,
    required int order,
    String createdBy = '',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.stagesCollection)
          .add({
        'organizationId': organizationId,
        'name': name,
        'order': order,
        'createdBy': createdBy,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateStage({
    required String stageId,
    String? name,
    int? order,
    bool? isArchived,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (order != null) data['order'] = order;
      if (isArchived != null) data['isArchived'] = isArchived;

      await _firestore
          .collection(AppConstants.stagesCollection)
          .doc(stageId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStage(String stageId) async {
    try {
      // Delete all classes in this stage
      final classesSnapshot = await _firestore
          .collection(AppConstants.classesCollection)
          .where('stageId', isEqualTo: stageId)
          .get();

      final batch = _firestore.batch();
      for (final doc in classesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
          _firestore.collection(AppConstants.stagesCollection).doc(stageId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getStagesStream(String organizationId) {
    return _firestore
        .collection(AppConstants.stagesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('isArchived', isEqualTo: false)
        .orderBy('order')
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getStages(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.stagesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('isArchived', isEqualTo: false)
          .orderBy('order')
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }
}
