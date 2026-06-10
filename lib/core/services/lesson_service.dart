import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class LessonService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new lesson
  Future<String> createLesson({
    required String organizationId,
    required String subjectId,
    String? chapterId,
    required String title,
    String? description,
    required String type, // recorded/youtube/zoom/google_drive
    String? videoUrl,
    String? thumbnailUrl,
    int? duration, // seconds
    String accessType = 'all', // all/class/group
    String? targetId,
    String? createdBy,
    String? createdByName,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.lessonsCollection)
          .add({
        'organizationId': organizationId,
        'subjectId': subjectId,
        'chapterId': chapterId,
        'title': title,
        'description': description,
        'type': type,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'duration': duration,
        'accessType': accessType,
        'targetId': targetId,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'viewCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating lesson: $e');
      rethrow;
    }
  }

  /// Update a lesson
  Future<void> updateLesson(String lessonId, {
    String? subjectId,
    String? chapterId,
    String? title,
    String? description,
    String? type,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    String? accessType,
    String? targetId,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (subjectId != null) data['subjectId'] = subjectId;
      if (chapterId != null) data['chapterId'] = chapterId;
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type;
      if (videoUrl != null) data['videoUrl'] = videoUrl;
      if (thumbnailUrl != null) data['thumbnailUrl'] = thumbnailUrl;
      if (duration != null) data['duration'] = duration;
      if (accessType != null) data['accessType'] = accessType;
      if (targetId != null) data['targetId'] = targetId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.lessonsCollection)
          .doc(lessonId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating lesson: $e');
      rethrow;
    }
  }

  /// Delete a lesson
  Future<void> deleteLesson(String lessonId) async {
    try {
      await _firestore
          .collection(AppConstants.lessonsCollection)
          .doc(lessonId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting lesson: $e');
      rethrow;
    }
  }

  /// Get a single lesson
  Future<Map<String, dynamic>?> getLesson(String lessonId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.lessonsCollection)
          .doc(lessonId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('Error getting lesson: $e');
      rethrow;
    }
  }

  /// Stream lessons by organization
  Stream<QuerySnapshot> getLessonsByOrganizationStream(String orgId) {
    return _firestore
        .collection(AppConstants.lessonsCollection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream lessons by subject
  Stream<QuerySnapshot> getLessonsBySubjectStream(String orgId, String subjectId) {
    return _firestore
        .collection(AppConstants.lessonsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Increment view count
  Future<void> incrementViewCount(String lessonId) async {
    try {
      await _firestore
          .collection(AppConstants.lessonsCollection)
          .doc(lessonId)
          .update({
        'viewCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
      rethrow;
    }
  }
}
