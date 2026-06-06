import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGroup({
    required String classId,
    required String name,
    required String teacherId,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      final docRef = await _firestore.collection(AppConstants.groupsCollection).add({
        'classId': classId,
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

  Future<void> updateGroup({required String groupId, required String name}) async {
    try {
      await _firestore.collection(AppConstants.groupsCollection).doc(groupId).update({'name': name});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGroup(String groupId) async {
    try {
      await _firestore.collection(AppConstants.groupsCollection).doc(groupId).delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getGroupsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getGroupsByClass(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }
}
