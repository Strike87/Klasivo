import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createClass({
    required String organizationId,
    required String stageId,
    required String name,
    String? academicYear,
    String createdBy = '',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.classesCollection)
          .add({
        'organizationId': organizationId,
        'stageId': stageId,
        'name': name,
        'academicYear': academicYear,
        'studentCount': 0,
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

  Future<void> updateClass({
    required String classId,
    String? name,
    String? stageId,
    String? academicYear,
    bool? isArchived,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (stageId != null) data['stageId'] = stageId;
      if (academicYear != null) data['academicYear'] = academicYear;
      if (isArchived != null) data['isArchived'] = isArchived;

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
      // Delete students in this class
      final studentsSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
          .get();

      // Delete subjects in this class
      final subjectsSnapshot = await _firestore
          .collection(AppConstants.subjectsCollection)
          .where('classId', isEqualTo: classId)
          .get();

      // Delete groups in this class
      final groupsSnapshot = await _firestore
          .collection(AppConstants.groupsCollection)
          .where('classId', isEqualTo: classId)
          .get();

      // Delete teacher assignments for this class
      final taSnapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('classId', isEqualTo: classId)
          .get();

      final batch = _firestore.batch();
      for (final doc in studentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in subjectsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in groupsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in taSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
          _firestore.collection(AppConstants.classesCollection).doc(classId));
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
      return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getClassesByStageStream(String stageId) {
    return _firestore
        .collection(AppConstants.classesCollection)
        .where('stageId', isEqualTo: stageId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getClassesByOrganizationStream(String organizationId) {
    return _firestore
        .collection(AppConstants.classesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<int> getStudentCount(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('classId', isEqualTo: classId)
          .where('role', isEqualTo: AppConstants.roleStudent)
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
