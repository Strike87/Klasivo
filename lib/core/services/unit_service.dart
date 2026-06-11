import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'search_keyword_service.dart';

/// Service for managing Units (chapters) within the LMS.
/// Units organize Lessons and Materials under a Subject.
/// Hierarchy: Subject → Unit → Lesson → Material
class UnitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SearchKeywordService _searchKeywordService = SearchKeywordService();

  /// Create a new unit (chapter) within a subject
  Future<String> createUnit({
    required String organizationId,
    required String subjectId,
    required String classId,
    String? stageId,
    required String title,
    String? description,
    int order = 0,
    String? createdBy,
  }) async {
    try {
      // Get current max order if not specified
      if (order == 0) {
        final existingUnits = await _firestore
            .collection(AppConstants.unitsCollection)
            .where('subjectId', isEqualTo: subjectId)
            .get();
        order = existingUnits.docs.length;
      }

      final keywords = _searchKeywordService.generateKeywords(title);

      final docRef = await _firestore
          .collection(AppConstants.unitsCollection)
          .add({
        'organizationId': organizationId,
        'subjectId': subjectId,
        'classId': classId,
        'stageId': stageId,
        'title': title,
        'description': description,
        'order': order,
        'createdBy': createdBy,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'searchKeywords': keywords,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Update a unit
  Future<void> updateUnit(String unitId, {
    String? title,
    String? description,
    int? order,
    bool? isArchived,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (title != null) {
        data['title'] = title;
        data['searchKeywords'] = _searchKeywordService.generateKeywords(title);
      }
      if (description != null) data['description'] = description;
      if (order != null) data['order'] = order;
      if (isArchived != null) {
        data['isArchived'] = isArchived;
        if (isArchived) {
          data['archivedAt'] = FieldValue.serverTimestamp();
        }
      }

      await _firestore
          .collection(AppConstants.unitsCollection)
          .doc(unitId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Archive a unit (soft delete)
  Future<void> archiveUnit(String unitId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.unitsCollection)
          .doc(unitId)
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

  /// Delete a unit permanently (also archives lessons/materials inside)
  Future<void> deleteUnit(String unitId) async {
    try {
      final batch = _firestore.batch();

      // Archive lessons in this unit
      final lessonsSnapshot = await _firestore
          .collection(AppConstants.lessonsCollection)
          .where('chapterId', isEqualTo: unitId)
          .get();
      for (final doc in lessonsSnapshot.docs) {
        batch.update(doc.reference, {
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Archive materials in this unit
      final materialsSnapshot = await _firestore
          .collection(AppConstants.materialsCollection)
          .where('chapterId', isEqualTo: unitId)
          .get();
      for (final doc in materialsSnapshot.docs) {
        batch.update(doc.reference, {
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      batch.delete(
          _firestore.collection(AppConstants.unitsCollection).doc(unitId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Get a single unit
  Future<Map<String, dynamic>?> getUnit(String unitId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.unitsCollection)
          .doc(unitId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      rethrow;
    }
  }

  /// Stream units by subject (ordered by order field)
  Stream<QuerySnapshot> getUnitsBySubjectStream(String subjectId) {
    return _firestore
        .collection(AppConstants.unitsCollection)
        .where('subjectId', isEqualTo: subjectId)
        .where('isArchived', isEqualTo: false)
        .orderBy('order', descending: false)
        .snapshots();
  }

  /// Stream units by class
  Stream<QuerySnapshot> getUnitsByClassStream(String classId) {
    return _firestore
        .collection(AppConstants.unitsCollection)
        .where('classId', isEqualTo: classId)
        .where('isArchived', isEqualTo: false)
        .orderBy('order', descending: false)
        .snapshots();
  }

  /// Stream all units for an organization
  Stream<QuerySnapshot> getUnitsByOrganizationStream(String orgId) {
    return _firestore
        .collection(AppConstants.unitsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Reorder units within a subject
  Future<void> reorderUnits(String subjectId, List<String> unitIds) async {
    try {
      final batch = _firestore.batch();
      for (int i = 0; i < unitIds.length; i++) {
        batch.update(
          _firestore.collection(AppConstants.unitsCollection).doc(unitIds[i]),
          {'order': i, 'updatedAt': FieldValue.serverTimestamp()},
        );
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of lessons in a unit
  Future<int> getLessonCount(String unitId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.lessonsCollection)
          .where('chapterId', isEqualTo: unitId)
          .where('isArchived', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get count of materials in a unit
  Future<int> getMaterialCount(String unitId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.materialsCollection)
          .where('chapterId', isEqualTo: unitId)
          .where('isArchived', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
