import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class OrganizationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new organization. Called automatically when a user registers.
  Future<String> createOrganization({
    required String ownerId,
    required String name,
    String? description,
    String? logoUrl,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.organizationsCollection)
          .add({
        'ownerId': ownerId,
        'name': name,
        'description': description,
        'logoUrl': logoUrl,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update organization details
  Future<void> updateOrganization({
    required String organizationId,
    String? name,
    String? description,
    String? logoUrl,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (logoUrl != null) data['logoUrl'] = logoUrl;
      if (isActive != null) data['isActive'] = isActive;

      await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Get organization by ID
  Future<Map<String, dynamic>?> getOrganization(String organizationId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId)
          .get();
      return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get organization by owner ID
  Future<Map<String, dynamic>?> getOrganizationByOwner(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.organizationsCollection)
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return {'id': snapshot.docs.first.id, ...snapshot.docs.first.data()};
    } catch (e) {
      rethrow;
    }
  }

  /// Stream organization data in real-time
  Stream<DocumentSnapshot> getOrganizationStream(String organizationId) {
    return _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .snapshots();
  }

  /// Get all members (users) in an organization
  Stream<QuerySnapshot> getOrganizationMembersStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get teachers in an organization
  Stream<QuerySnapshot> getOrganizationTeachersStream(String organizationId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('role', isEqualTo: AppConstants.roleTeacher)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get member count by role
  Future<Map<String, int>> getMemberCounts(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();

      int owners = 0;
      int teachers = 0;
      int students = 0;

      for (final doc in snapshot.docs) {
        final role = doc.data()['role'] as String? ?? '';
        switch (role) {
          case 'owner':
            owners++;
            break;
          case 'teacher':
            teachers++;
            break;
          case 'student':
            students++;
            break;
        }
      }

      return {
        'owners': owners,
        'teachers': teachers,
        'students': students,
        'total': snapshot.docs.length,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Delete organization and all its data (use with caution!)
  Future<void> deleteOrganization(String organizationId) async {
    try {
      final batch = _firestore.batch();

      // Delete all users in this organization
      final usersSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in usersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all stages
      final stagesSnapshot = await _firestore
          .collection(AppConstants.stagesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in stagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all classes
      final classesSnapshot = await _firestore
          .collection(AppConstants.classesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in classesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all subjects
      final subjectsSnapshot = await _firestore
          .collection(AppConstants.subjectsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in subjectsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all groups
      final groupsSnapshot = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in groupsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all teacher assignments
      final assignmentsSnapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in assignmentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all exams
      final examsSnapshot = await _firestore
          .collection(AppConstants.examsCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in examsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all question banks
      final qbSnapshot = await _firestore
          .collection(AppConstants.questionBankCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in qbSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all invite codes
      final codesSnapshot = await _firestore
          .collection(AppConstants.inviteCodesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .get();
      for (final doc in codesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the organization document itself
      batch.delete(_firestore
          .collection(AppConstants.organizationsCollection)
          .doc(organizationId));

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
