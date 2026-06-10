import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

/// Service for tracking student progress through LMS content.
/// Tracks which materials students have viewed and which lessons they've completed.
/// This data feeds into the overall Progress Tracking and Parent Dashboard.
class ContentProgressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record that a student has viewed a material
  Future<void> markMaterialViewed({
    required String studentId,
    required String materialId,
    required String lessonId,
    required String subjectId,
    required String classId,
    String? organizationId,
  }) async {
    try {
      // Check if already recorded
      final existing = await _firestore
          .collection(AppConstants.contentProgressCollection)
          .where('studentId', isEqualTo: studentId)
          .where('materialId', isEqualTo: materialId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update view count and last viewed
        await existing.docs.first.reference.update({
          'viewCount': FieldValue.increment(1),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      await _firestore
          .collection(AppConstants.contentProgressCollection)
          .add({
        'studentId': studentId,
        'materialId': materialId,
        'lessonId': lessonId,
        'subjectId': subjectId,
        'classId': classId,
        'organizationId': organizationId,
        'contentType': 'material',
        'status': 'viewed',
        'viewCount': 1,
        'completedAt': null,
        'lastViewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Mark a lesson as completed by a student
  Future<void> markLessonCompleted({
    required String studentId,
    required String lessonId,
    required String subjectId,
    required String classId,
    String? organizationId,
  }) async {
    try {
      // Check if already recorded
      final existing = await _firestore
          .collection(AppConstants.contentProgressCollection)
          .where('studentId', isEqualTo: studentId)
          .where('lessonId', isEqualTo: lessonId)
          .where('contentType', isEqualTo: 'lesson')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      await _firestore
          .collection(AppConstants.contentProgressCollection)
          .add({
        'studentId': studentId,
        'materialId': null,
        'lessonId': lessonId,
        'subjectId': subjectId,
        'classId': classId,
        'organizationId': organizationId,
        'contentType': 'lesson',
        'status': 'completed',
        'viewCount': 1,
        'completedAt': FieldValue.serverTimestamp(),
        'lastViewedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get progress for a student in a specific subject
  Stream<QuerySnapshot> getStudentSubjectProgress({
    required String studentId,
    required String subjectId,
  }) {
    return _firestore
        .collection(AppConstants.contentProgressCollection)
        .where('studentId', isEqualTo: studentId)
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('lastViewedAt', descending: true)
        .snapshots();
  }

  /// Get progress for a student in a class (all subjects)
  Stream<QuerySnapshot> getStudentClassProgress({
    required String studentId,
    required String classId,
  }) {
    return _firestore
        .collection(AppConstants.contentProgressCollection)
        .where('studentId', isEqualTo: studentId)
        .where('classId', isEqualTo: classId)
        .orderBy('lastViewedAt', descending: true)
        .snapshots();
  }

  /// Get all students' progress for a specific lesson (for teacher view)
  Stream<QuerySnapshot> getLessonProgress({
    required String lessonId,
  }) {
    return _firestore
        .collection(AppConstants.contentProgressCollection)
        .where('lessonId', isEqualTo: lessonId)
        .where('contentType', isEqualTo: 'lesson')
        .snapshots();
  }

  /// Get content completion stats for a student in a subject
  Future<Map<String, dynamic>> getSubjectCompletionStats({
    required String studentId,
    required String subjectId,
  }) async {
    try {
      final progressSnapshot = await _firestore
          .collection(AppConstants.contentProgressCollection)
          .where('studentId', isEqualTo: studentId)
          .where('subjectId', isEqualTo: subjectId)
          .get();

      int lessonsCompleted = 0;
      int materialsViewed = 0;
      int totalViews = 0;

      for (final doc in progressSnapshot.docs) {
        final data = doc.data();
        final contentType = data['contentType'] as String? ?? '';
        final status = data['status'] as String? ?? '';
        final viewCount = data['viewCount'] as int? ?? 0;

        if (contentType == 'lesson' && status == 'completed') {
          lessonsCompleted++;
        }
        if (contentType == 'material') {
          materialsViewed++;
          totalViews += viewCount;
        }
      }

      // Count total lessons and materials in the subject
      final lessonsSnapshot = await _firestore
          .collection(AppConstants.lessonsCollection)
          .where('subjectId', isEqualTo: subjectId)
          .where('isArchived', isEqualTo: false)
          .get();

      final materialsSnapshot = await _firestore
          .collection(AppConstants.materialsCollection)
          .where('subjectId', isEqualTo: subjectId)
          .where('isArchived', isEqualTo: false)
          .get();

      final totalLessons = lessonsSnapshot.docs.length;
      final totalMaterials = materialsSnapshot.docs.length;

      final lessonCompletionRate = totalLessons > 0
          ? (lessonsCompleted / totalLessons) * 100
          : 0.0;
      final materialViewRate = totalMaterials > 0
          ? (materialsViewed / totalMaterials) * 100
          : 0.0;

      return {
        'lessonsCompleted': lessonsCompleted,
        'totalLessons': totalLessons,
        'lessonCompletionRate': lessonCompletionRate,
        'materialsViewed': materialsViewed,
        'totalMaterials': totalMaterials,
        'materialViewRate': materialViewRate,
        'totalViews': totalViews,
      };
    } catch (e) {
      rethrow;
    }
  }
}
