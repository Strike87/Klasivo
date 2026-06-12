import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  // ─── Video Progress Tracking ─────────────────────────────────────────────

  /// Save video playback progress for resume functionality.
  /// [positionSeconds] is the current playback position.
  /// [durationSeconds] is the total video duration.
  Future<void> saveVideoProgress({
    required String studentId,
    required String lessonId,
    required String subjectId,
    required String classId,
    required int positionSeconds,
    required int durationSeconds,
    String? organizationId,
  }) async {
    try {
      // Find existing progress record
      final existing = await _firestore
          .collection(AppConstants.contentProgressCollection)
          .where('studentId', isEqualTo: studentId)
          .where('lessonId', isEqualTo: lessonId)
          .where('contentType', isEqualTo: 'video')
          .limit(1)
          .get();

      final progressPercent = durationSeconds > 0
          ? (positionSeconds / durationSeconds * 100).round()
          : 0;

      // Auto-complete if watched > 90%
      final isCompleted = progressPercent >= 90;

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({
          'positionSeconds': positionSeconds,
          'durationSeconds': durationSeconds,
          'progressPercent': progressPercent,
          if (isCompleted) 'status': 'completed',
          if (isCompleted) 'completedAt': FieldValue.serverTimestamp(),
          'lastViewedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore
            .collection(AppConstants.contentProgressCollection)
            .add({
          'studentId': studentId,
          'materialId': null,
          'lessonId': lessonId,
          'subjectId': subjectId,
          'classId': classId,
          'organizationId': organizationId,
          'contentType': 'video',
          'status': isCompleted ? 'completed' : 'in_progress',
          'positionSeconds': positionSeconds,
          'durationSeconds': durationSeconds,
          'progressPercent': progressPercent,
          'viewCount': 1,
          'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
          'lastViewedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // If video completed, also mark the lesson as completed
      if (isCompleted) {
        await markLessonCompleted(
          studentId: studentId,
          lessonId: lessonId,
          subjectId: subjectId,
          classId: classId,
          organizationId: organizationId,
        );
      }
    } catch (e) {
      // Non-critical: video progress save failure shouldn't disrupt playback
      debugPrint('[ContentProgress] Failed to save video progress: $e');
    }
  }

  /// Get saved video playback position for resume functionality.
  /// Returns position in seconds, or 0 if no saved progress.
  Future<int> getVideoResumePosition({
    required String studentId,
    required String lessonId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.contentProgressCollection)
          .where('studentId', isEqualTo: studentId)
          .where('lessonId', isEqualTo: lessonId)
          .where('contentType', isEqualTo: 'video')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      final data = snapshot.docs.first.data();
      return data['positionSeconds'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get video progress percentage for a lesson.
  Future<int> getVideoProgressPercent({
    required String studentId,
    required String lessonId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.contentProgressCollection)
          .where('studentId', isEqualTo: studentId)
          .where('lessonId', isEqualTo: lessonId)
          .where('contentType', isEqualTo: 'video')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      return snapshot.docs.first.data()['progressPercent'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get overall content completion percentage for a subject.
  /// Combines lesson completion + material views + video progress.
  Future<double> getOverallCompletionRate({
    required String studentId,
    required String subjectId,
  }) async {
    try {
      final stats = await getSubjectCompletionStats(
        studentId: studentId,
        subjectId: subjectId,
      );

      final lessonRate = stats['lessonCompletionRate'] as double? ?? 0.0;
      final materialRate = stats['materialViewRate'] as double? ?? 0.0;

      // Weighted average: lessons 60%, materials 40%
      return (lessonRate * 0.6) + (materialRate * 0.4);
    } catch (e) {
      return 0.0;
    }
  }
}
