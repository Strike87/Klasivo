import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class StageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createStage({
    required String organizationId,
    required String name,
    required int order,
    String description = '',
    String createdBy = '',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.stagesCollection)
          .add({
        'organizationId': organizationId,
        'name': name,
        'description': description,
        'order': order,
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

  Future<void> updateStage({
    required String stageId,
    String? name,
    String? description,
    int? order,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      if (order != null) data['order'] = order;

      await _firestore
          .collection(AppConstants.stagesCollection)
          .doc(stageId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Soft-delete: archive the stage instead of removing it.
  /// Archived stages are filtered out of live queries via `isArchived == false`.
  Future<void> archiveStage(String stageId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.stagesCollection)
          .doc(stageId)
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

  /// Hard-delete: removes the stage and all its classes.
  /// Use only for cleanup / admin purposes. Prefer [archiveStage] for normal flow.
  Future<void> deleteStage(String stageId) async {
    try {
      // Soft-delete all classes in this stage first
      final classesSnapshot = await _firestore
          .collection(AppConstants.classesCollection)
          .where('stageId', isEqualTo: stageId)
          .get();

      final batch = _firestore.batch();
      for (final doc in classesSnapshot.docs) {
        batch.update(doc.reference, {
          'isArchived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
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

  /// Get class count for a stage
  Future<int> getClassCount(String stageId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.classesCollection)
          .where('stageId', isEqualTo: stageId)
          .where('isArchived', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  /// Batch-create stages with predefined templates.
  /// Used by the Smart Setup Wizard.
  Future<void> createStagesBatch({
    required String organizationId,
    required List<Map<String, dynamic>> stages,
    String createdBy = '',
  }) async {
    try {
      final batch = _firestore.batch();
      for (final stage in stages) {
        final docRef = _firestore.collection(AppConstants.stagesCollection).doc();
        batch.set(docRef, {
          'organizationId': organizationId,
          'name': stage['name'],
          'description': stage['description'] ?? '',
          'order': stage['order'] ?? 0,
          'createdBy': createdBy,
          'isArchived': false,
          'archivedAt': null,
          'archivedBy': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If the stage template includes classes, create them too
        if (stage['classes'] != null) {
          final classes = stage['classes'] as List<Map<String, dynamic>>;
          for (final classData in classes) {
            final classRef = _firestore.collection(AppConstants.classesCollection).doc();
            batch.set(classRef, {
              'organizationId': organizationId,
              'stageId': docRef.id,
              'name': classData['name'],
              'code': classData['code'] ?? '',
              'capacity': classData['capacity'] ?? 0,
              'homeroomTeacherId': null,
              'studentCount': 0,
              'createdBy': createdBy,
              'isArchived': false,
              'archivedAt': null,
              'archivedBy': null,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
