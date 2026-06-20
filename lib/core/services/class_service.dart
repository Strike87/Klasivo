import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
import 'search_keyword_service.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createClass({
    required String organizationId,
    required String stageId,
    required String name,
    String code = '',
    int capacity = 0,
    String? homeroomTeacherId,
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
        'code': code,
        'capacity': capacity,
        'homeroomTeacherId': homeroomTeacherId,
        'academicYear': academicYear,
        'studentCount': 0,
        'createdBy': createdBy,
        'isArchived': false,
        'archivedAt': null,
        'archivedBy': null,
        'searchKeywords': SearchKeywordService().generateKeywords('$name ${code ?? ""}'),
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
    String? code,
    int? capacity,
    String? homeroomTeacherId,
    String? academicYear,
    String? grade,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) {
        data['name'] = name;
        data['searchKeywords'] = SearchKeywordService().generateKeywords('$name ${code ?? ""}');
      }
      if (stageId != null) data['stageId'] = stageId;
      if (code != null) data['code'] = code;
      if (capacity != null) data['capacity'] = capacity;
      if (homeroomTeacherId != null) data['homeroomTeacherId'] = homeroomTeacherId;
      if (academicYear != null) data['academicYear'] = academicYear;
      if (grade != null) data['grade'] = grade;

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Soft-delete: archive the class instead of removing it.
  /// Archived classes are filtered out of live queries via `isArchived == false`.
  Future<void> archiveClass(String classId, {String archivedBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
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

  /// Hard-delete: removes the class and all its related data.
  /// Use only for cleanup / admin purposes. Prefer [archiveClass] for normal flow.
  ///
  /// SAFETY PATCH (Phase 2): Previous implementation cascade-deleted student
  /// Firestore docs but NOT Auth accounts, skipped 10+ related collections,
  /// had no audit log, and had zero UI callers — yet was still callable.
  /// This is now DEFANGED to archive-only. True hard-delete should go through
  /// a Cloud Function that can cascade Auth account deletion + audit log.
  /// The original cascade logic is preserved below (commented) for reference
  /// when the Cloud Function is built in a future phase.
  Future<void> deleteClass(String classId) async {
    // SAFETY: Redirect to archiveClass. Hard-delete is too dangerous to leave
    // as a client-side operation — it leaves orphaned Auth accounts and
    // breaks referential integrity for submissions, answers, exam_instances,
    // attendance, gradebook, parent_links, and more.
    await archiveClass(classId);
    // ignore: avoid_print
    print('[class_service] deleteClass redirected to archiveClass for safety. '
        'Hard-delete is disabled — use the deleteClass Cloud Function (future phase) '
        'for true cascade deletion.');

    /* Original cascade — DISABLED for safety. Too many collections missed,
       no Auth account cleanup, no audit log. Preserve for reference when
       building the Cloud Function equivalent.

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
    */
  }

  /// Restore: unarchive the class (A8 hygiene — archive was previously a one-way door).
  Future<void> restoreClass(String classId, {String restoredBy = ''}) async {
    try {
      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
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

  Stream<QuerySnapshot> getClassesByStageStream(String stageId, {required String organizationId}) {
    return _firestore
        .collection(AppConstants.classesCollection)
        .where('stageId', isEqualTo: stageId)
        .where('organizationId', isEqualTo: organizationId)  // AUDIT FIX #10
        .where('isArchived', isEqualTo: false)
        .orderBy('name')
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

  /// Batch-create classes under a stage.
  /// Used by the Smart Setup Wizard.
  /// A10 PATCH: Now writes the same fields as createClass (searchKeywords +
  /// academicYear) to eliminate schema drift between wizard and manual paths.
  Future<void> createClassesBatch({
    required String organizationId,
    required String stageId,
    required List<Map<String, dynamic>> classes,
    String createdBy = '',
    String? academicYear, // A10: now accepted and written
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
      for (final classData in classes) {
        final docRef = _firestore.collection(AppConstants.classesCollection).doc();
        final className = classData['name'] as String? ?? '';
        final classCode = classData['code'] as String? ?? '';
        batch.set(docRef, {
          'organizationId': organizationId,
          'stageId': stageId,
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
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
