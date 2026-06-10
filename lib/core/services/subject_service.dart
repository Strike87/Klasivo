import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class SubjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createSubject({
    required String organizationId,
    required String classId,
    required String name,
    String color = '#2196F3',
    String? teacherId,
    String createdBy = '',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.subjectsCollection)
          .add({
        'organizationId': organizationId,
        'classId': classId,
        'name': name,
        'color': color,
        'teacherId': teacherId,
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

  Future<void> updateSubject({
    required String subjectId,
    String? name,
    String? color,
    String? teacherId,
    bool? isArchived,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (color != null) data['color'] = color;
      if (teacherId != null) data['teacherId'] = teacherId;
      if (isArchived != null) {
        data['isArchived'] = isArchived;
        if (isArchived) {
          data['archivedAt'] = FieldValue.serverTimestamp();
          data['archivedBy'] = ''; // Caller should use archiveSubject() for tracking
        }
      }

      await _firestore
          .collection(AppConstants.subjectsCollection)
          .doc(subjectId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archiveSubject(String subjectId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.subjectsCollection)
          .doc(subjectId)
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

  Future<void> deleteSubject(String subjectId) async {
    try {
      // Delete teacher assignments for this subject
      final taSnapshot = await _firestore
          .collection(AppConstants.teacherAssignmentsCollection)
          .where('subjectId', isEqualTo: subjectId)
          .get();

      final batch = _firestore.batch();
      for (final doc in taSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
          _firestore.collection(AppConstants.subjectsCollection).doc(subjectId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getSubjectsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.subjectsCollection)
        .where('classId', isEqualTo: classId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<List<Map<String, dynamic>>> getSubjectsByClass(String classId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.subjectsCollection)
          .where('classId', isEqualTo: classId)
          .where('isArchived', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get subjects assigned to a specific teacher
  Stream<QuerySnapshot> getSubjectsByTeacherStream(String teacherId) {
    return _firestore
        .collection(AppConstants.subjectsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
