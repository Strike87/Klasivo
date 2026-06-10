import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class ResourceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new resource
  Future<String> createResource({
    required String organizationId,
    String? subjectId,
    String? gradeId,
    required String title,
    String? description,
    required String type, // worksheet/template/past_exam/question_bank/document
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? category,
    List<String>? tags,
    String accessType = 'read_only', // read_only/editable
    String? createdBy,
    String? createdByName,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.resourcesCollection)
          .add({
        'organizationId': organizationId,
        'subjectId': subjectId,
        'gradeId': gradeId,
        'title': title,
        'description': description,
        'type': type,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'category': category,
        'tags': tags ?? <String>[],
        'accessType': accessType,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'version': 1,
        'downloadCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating resource: $e');
      rethrow;
    }
  }

  /// Update a resource
  Future<void> updateResource(String resourceId, {
    String? subjectId,
    String? gradeId,
    String? title,
    String? description,
    String? type,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? category,
    List<String>? tags,
    String? accessType,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (subjectId != null) data['subjectId'] = subjectId;
      if (gradeId != null) data['gradeId'] = gradeId;
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type;
      if (fileUrl != null) data['fileUrl'] = fileUrl;
      if (fileName != null) data['fileName'] = fileName;
      if (fileSize != null) data['fileSize'] = fileSize;
      if (category != null) data['category'] = category;
      if (tags != null) data['tags'] = tags;
      if (accessType != null) data['accessType'] = accessType;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.resourcesCollection)
          .doc(resourceId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating resource: $e');
      rethrow;
    }
  }

  /// Delete a resource
  Future<void> deleteResource(String resourceId) async {
    try {
      await _firestore
          .collection(AppConstants.resourcesCollection)
          .doc(resourceId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting resource: $e');
      rethrow;
    }
  }

  /// Get a single resource
  Future<Map<String, dynamic>?> getResource(String resourceId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.resourcesCollection)
          .doc(resourceId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('Error getting resource: $e');
      rethrow;
    }
  }

  /// Stream resources by organization
  Stream<QuerySnapshot> getResourcesByOrganizationStream(String orgId) {
    return _firestore
        .collection(AppConstants.resourcesCollection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream resources by type
  Stream<QuerySnapshot> getResourcesByTypeStream(String orgId, String type) {
    return _firestore
        .collection(AppConstants.resourcesCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('type', isEqualTo: type)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream resources by subject
  Stream<QuerySnapshot> getResourcesBySubjectStream(String orgId, String subjectId) {
    return _firestore
        .collection(AppConstants.resourcesCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Increment download count
  Future<void> incrementDownloadCount(String resourceId) async {
    try {
      await _firestore
          .collection(AppConstants.resourcesCollection)
          .doc(resourceId)
          .update({
        'downloadCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing download count: $e');
      rethrow;
    }
  }

  /// Increment version
  Future<void> incrementVersion(String resourceId) async {
    try {
      await _firestore
          .collection(AppConstants.resourcesCollection)
          .doc(resourceId)
          .update({
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing version: $e');
      rethrow;
    }
  }
}
