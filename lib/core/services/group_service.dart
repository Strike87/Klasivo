import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createGroup({
    required String organizationId,
    required String classId,
    required String name,
    String stageId = '',
    String createdBy = '',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.groupsCollection)
          .add({
        'organizationId': organizationId,
        'classId': classId,
        'stageId': stageId,
        'name': name,
        'createdBy': createdBy,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    bool? isArchived,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (isArchived != null) {
        data['isArchived'] = isArchived;
        if (isArchived) {
          data['archivedAt'] = FieldValue.serverTimestamp();
        }
      }

      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Soft-delete: archive the group instead of removing it.
  Future<void> archiveGroup(String groupId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.groupsCollection)
          .doc(groupId)
          .update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': archivedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Hard-delete: removes the group and all its members.
  /// Prefer [archiveGroup] for normal flow.
  Future<void> deleteGroup(String groupId) async {
    try {
      // Delete all group members
      final membersSnapshot = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('groupId', isEqualTo: groupId)
          .get();

      final batch = _firestore.batch();
      for (final doc in membersSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
          _firestore.collection(AppConstants.groupsCollection).doc(groupId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getGroupsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .where('classId', isEqualTo: classId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getGroupsByStageStream(String stageId) {
    return _firestore
        .collection(AppConstants.groupsCollection)
        .where('stageId', isEqualTo: stageId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getGroupsByClass(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('classId', isEqualTo: classId)
          .where('isArchived', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }
}
