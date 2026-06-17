import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'search_keyword_service.dart';

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
        'searchKeywords': SearchKeywordService().generateKeywords(name),
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
      if (name != null) {
        data['name'] = name;
        data['searchKeywords'] = SearchKeywordService().generateKeywords(name);
      }
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

  /// Restore: unarchive the stage (Phase 2 hygiene — archive was previously a one-way door).
  Future<void> restoreStage(String stageId, {String restoredBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.stagesCollection)
          .doc(stageId)
          .update({
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'restoredAt': FieldValue.serverTimestamp(),
        'restoredBy': restoredBy,
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
  /// A10 PATCH: Now writes the same fields as createStage (searchKeywords)
  /// and createClass (searchKeywords + academicYear) to eliminate schema drift.
  Future<void> createStagesBatch({
    required String organizationId,
    required List<Map<String, dynamic>> stages,
    String createdBy = '',
    String? academicYear, // A10: classes now get academicYear
  }) async {
    try {
      // A4 part 2: Guard against empty organizationId at the service layer too.
      if (organizationId.isEmpty) {
        throw ArgumentError(
          'organizationId cannot be empty — Hive box may not be hydrated yet.',
        );
      }

      final keywordService = SearchKeywordService();
      final batch = _firestore.batch();
      for (final stage in stages) {
        final docRef = _firestore.collection(AppConstants.stagesCollection).doc();
        final stageName = stage['name'] as String? ?? '';
        batch.set(docRef, {
          'organizationId': organizationId,
          'name': stageName,
          'description': stage['description'] ?? '',
          'order': stage['order'] ?? 0,
          'createdBy': createdBy,
          'isArchived': false,
          'archivedAt': null,
          'archivedBy': null,
          // A10: searchKeywords now written in batch path too (was missing).
          'searchKeywords': keywordService.generateKeywords(stageName),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If the stage template includes classes, create them too
        if (stage['classes'] != null) {
          final classes = stage['classes'] as List<Map<String, dynamic>>;
          for (final classData in classes) {
            final classRef = _firestore.collection(AppConstants.classesCollection).doc();
            final className = classData['name'] as String? ?? '';
            final classCode = classData['code'] as String? ?? '';
            batch.set(classRef, {
              'organizationId': organizationId,
              'stageId': docRef.id,
              'name': className,
              'code': classCode,
              'capacity': classData['capacity'] ?? 0,
              'homeroomTeacherId': null,
              // A10: academicYear now written in batch path (was missing).
              'academicYear': academicYear,
              'studentCount': 0,
              'createdBy': createdBy,
              'isArchived': false,
              'archivedAt': null,
              'archivedBy': null,
              // A10: searchKeywords now written in batch path (was missing).
              'searchKeywords': keywordService.generateKeywords('$className $classCode'),
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
