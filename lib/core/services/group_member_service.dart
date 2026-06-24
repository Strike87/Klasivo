import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class GroupMemberService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a single student to a group
  ///
  /// [organizationId] is REQUIRED — Firestore rules enforce
  /// `isIncomingSameOrg()` on create, which needs `organizationId` on the
  /// incoming document. Without it the write is silently denied.
  Future<void> addMemberToGroup({
    required String organizationId,
    required String groupId,
    required String studentId,
  }) async {
    try {
      // Check if already a member
      final existing = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('groupId', isEqualTo: groupId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return; // Already a member

      await _firestore
          .collection(AppConstants.groupMembersCollection)
          .add({
        'organizationId': organizationId,
        'groupId': groupId,
        'studentId': studentId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a student from a group
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('groupId', isEqualTo: groupId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Set all members for a group (replaces existing members)
  ///
  /// [organizationId] is REQUIRED — Firestore rules enforce
  /// `isIncomingSameOrg()` on each batched set, which needs `organizationId`
  /// on every incoming document.
  Future<void> setGroupMembers({
    required String organizationId,
    required String groupId,
    required List<String> studentIds,
  }) async {
    try {
      // Delete existing members
      final existing = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('groupId', isEqualTo: groupId)
          .get();

      final batch = _firestore.batch();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Add new members
      for (final studentId in studentIds) {
        final docRef = _firestore
            .collection(AppConstants.groupMembersCollection)
            .doc();
        batch.set(docRef, {
          'organizationId': organizationId,
          'groupId': groupId,
          'studentId': studentId,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all members of a group as a stream
  Stream<QuerySnapshot> getGroupMembersStream(String groupId) {
    return _firestore
        .collection(AppConstants.groupMembersCollection)
        .where('groupId', isEqualTo: groupId)
        .orderBy('addedAt', descending: false)
        .snapshots();
  }

  /// Get member student IDs for a group
  Future<List<String>> getGroupMemberIds(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('groupId', isEqualTo: groupId)
          .get();
      return snapshot.docs
          .map((doc) => doc.data()['studentId'] as String)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get all group IDs a student belongs to
  Future<List<String>> getStudentGroupIds(String studentId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('studentId', isEqualTo: studentId)
          .get();
      return snapshot.docs
          .map((doc) => doc.data()['groupId'] as String)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of members in a group
  Future<int> getGroupMemberCount(String groupId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.groupMembersCollection)
          .where('groupId', isEqualTo: groupId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }
}
