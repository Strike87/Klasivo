import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class MaterialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new material
  Future<String> createMaterial({
    required String organizationId,
    required String subjectId,
    String? chapterId,
    String? lessonId,
    required String title,
    String? description,
    required String type, // pdf/word/powerpoint/image/video/link
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? thumbnailUrl,
    String accessType = 'all', // all/class/group
    String? targetId,
    String? createdBy,
    String? createdByName,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.materialsCollection)
          .add({
        'organizationId': organizationId,
        'subjectId': subjectId,
        'chapterId': chapterId,
        'lessonId': lessonId,
        'title': title,
        'description': description,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'thumbnailUrl': thumbnailUrl,
        'accessType': accessType,
        'targetId': targetId,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'downloadCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating material: $e');
      rethrow;
    }
  }

  /// Update a material
  Future<void> updateMaterial(String materialId, {
    String? subjectId,
    String? chapterId,
    String? lessonId,
    String? title,
    String? description,
    String? type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? thumbnailUrl,
    String? accessType,
    String? targetId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (subjectId != null) data['subjectId'] = subjectId;
      if (chapterId != null) data['chapterId'] = chapterId;
      if (lessonId != null) data['lessonId'] = lessonId;
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type;
      if (fileUrl != null) data['fileUrl'] = fileUrl;
      if (fileName != null) data['fileName'] = fileName;
      if (fileSize != null) data['fileSize'] = fileSize;
      if (thumbnailUrl != null) data['thumbnailUrl'] = thumbnailUrl;
      if (accessType != null) data['accessType'] = accessType;
      if (targetId != null) data['targetId'] = targetId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.materialsCollection)
          .doc(materialId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating material: $e');
      rethrow;
    }
  }

  /// Delete a material
  Future<void> deleteMaterial(String materialId) async {
    try {
      await _firestore
          .collection(AppConstants.materialsCollection)
          .doc(materialId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting material: $e');
      rethrow;
    }
  }

  /// Get a single material
  Future<Map<String, dynamic>?> getMaterial(String materialId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.materialsCollection)
          .doc(materialId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('Error getting material: $e');
      rethrow;
    }
  }

  /// Stream materials by organization
  Stream<QuerySnapshot> getMaterialsByOrganizationStream(String orgId) {
    return _firestore
        .collection(AppConstants.materialsCollection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream materials by subject
  Stream<QuerySnapshot> getMaterialsBySubjectStream(String orgId, String subjectId) {
    return _firestore
        .collection(AppConstants.materialsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream materials by chapter
  Stream<QuerySnapshot> getMaterialsByChapterStream(String orgId, String chapterId) {
    return _firestore
        .collection(AppConstants.materialsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('chapterId', isEqualTo: chapterId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream materials by lesson
  Stream<QuerySnapshot> getMaterialsByLessonStream(String orgId, String lessonId) {
    return _firestore
        .collection(AppConstants.materialsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('lessonId', isEqualTo: lessonId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Increment download count
  Future<void> incrementDownloadCount(String materialId) async {
    try {
      await _firestore
          .collection(AppConstants.materialsCollection)
          .doc(materialId)
          .update({
        'downloadCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing download count: $e');
      rethrow;
    }
  }
}
