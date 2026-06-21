import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGrade({
    required String stageId,
    required String name,
    required String organizationId,
  }) async {
    try {
      final docRef = await _firestore.collection(AppConstants.classesCollection).add({
        'stageId': stageId,
        'name': name,
        'organizationId': organizationId,
        'studentCount': 0,
        'isArchived': false,
        'createdBy': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGrade(String gradeId) async {
    try {
      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(gradeId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getGradesByStageStream(String stageId, {required String organizationId}) {
    return _firestore
        .collection(AppConstants.classesCollection)
        .where('stageId', isEqualTo: stageId)
        // REQUIRED by firestore.rules: isInSameOrg() checks
        // resource.data.organizationId == getUserOrgId().
        // Without this filter, the query is rejected with
        // permission-denied (rules are not filters).
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('name')
        .snapshots();
  }
}
