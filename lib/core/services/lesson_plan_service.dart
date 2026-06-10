import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class LessonPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new lesson plan
  Future<String> createLessonPlan({
    required String organizationId,
    required String subjectId,
    String? chapterId,
    required String title,
    required String objectives,
    required String topics,
    required String activities,
    String? homework,
    String? resources,
    int? duration, // minutes
    String? notes,
    bool isTemplate = false,
    String? templateName,
    String? createdBy,
    String? createdByName,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.lessonPlansCollection)
          .add({
        'organizationId': organizationId,
        'subjectId': subjectId,
        'chapterId': chapterId,
        'title': title,
        'objectives': objectives,
        'topics': topics,
        'activities': activities,
        'homework': homework,
        'resources': resources,
        'duration': duration,
        'notes': notes,
        'isTemplate': isTemplate,
        'templateName': templateName,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating lesson plan: $e');
      rethrow;
    }
  }

  /// Update a lesson plan
  Future<void> updateLessonPlan(String lessonPlanId, {
    String? subjectId,
    String? chapterId,
    String? title,
    String? objectives,
    String? topics,
    String? activities,
    String? homework,
    String? resources,
    int? duration,
    String? notes,
    bool? isTemplate,
    String? templateName,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (subjectId != null) data['subjectId'] = subjectId;
      if (chapterId != null) data['chapterId'] = chapterId;
      if (title != null) data['title'] = title;
      if (objectives != null) data['objectives'] = objectives;
      if (topics != null) data['topics'] = topics;
      if (activities != null) data['activities'] = activities;
      if (homework != null) data['homework'] = homework;
      if (resources != null) data['resources'] = resources;
      if (duration != null) data['duration'] = duration;
      if (notes != null) data['notes'] = notes;
      if (isTemplate != null) data['isTemplate'] = isTemplate;
      if (templateName != null) data['templateName'] = templateName;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.lessonPlansCollection)
          .doc(lessonPlanId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating lesson plan: $e');
      rethrow;
    }
  }

  /// Delete a lesson plan
  Future<void> deleteLessonPlan(String lessonPlanId) async {
    try {
      await _firestore
          .collection(AppConstants.lessonPlansCollection)
          .doc(lessonPlanId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting lesson plan: $e');
      rethrow;
    }
  }

  /// Get a single lesson plan
  Future<Map<String, dynamic>?> getLessonPlan(String lessonPlanId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.lessonPlansCollection)
          .doc(lessonPlanId)
          .get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      debugPrint('Error getting lesson plan: $e');
      rethrow;
    }
  }

  /// Stream lesson plans by organization
  Stream<QuerySnapshot> getLessonPlansByOrganizationStream(String orgId) {
    return _firestore
        .collection(AppConstants.lessonPlansCollection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream lesson plans by subject
  Stream<QuerySnapshot> getLessonPlansBySubjectStream(String orgId, String subjectId) {
    return _firestore
        .collection(AppConstants.lessonPlansCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream lesson plan templates (where isTemplate == true)
  Stream<QuerySnapshot> getLessonPlanTemplatesStream(String orgId) {
    return _firestore
        .collection(AppConstants.lessonPlansCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isTemplate', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
