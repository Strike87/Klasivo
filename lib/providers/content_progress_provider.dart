import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';
import '../core/services/content_progress_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONTENT PROGRESS PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Singleton provider for ContentProgressService
final contentProgressServiceProvider = Provider<ContentProgressService>((ref) {
  return ContentProgressService();
});

/// Current user ID from Hive
final _currentStudentIdProvider = Provider<String?>((ref) {
  try {
    final box = Hive.box(AppConstants.authBox);
    return box.get('userId') as String?;
  } catch (_) {
    return null;
  }
});

/// Subject completion stats for the current student
final subjectCompletionProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, subjectId) async {
  final studentId = ref.watch(_currentStudentIdProvider);
  if (studentId == null) return {};

  final service = ref.watch(contentProgressServiceProvider);
  return service.getSubjectCompletionStats(
    studentId: studentId,
    subjectId: subjectId,
  );
});

/// Overall completion rate for a subject (0.0 to 100.0)
final subjectCompletionRateProvider = FutureProvider.family<double, String>((ref, subjectId) async {
  final studentId = ref.watch(_currentStudentIdProvider);
  if (studentId == null) return 0.0;

  final service = ref.watch(contentProgressServiceProvider);
  return service.getOverallCompletionRate(
    studentId: studentId,
    subjectId: subjectId,
  );
});

/// Video progress percent for a specific lesson
final videoProgressProvider = FutureProvider.family<int, String>((ref, lessonId) async {
  final studentId = ref.watch(_currentStudentIdProvider);
  if (studentId == null) return 0;

  final service = ref.watch(contentProgressServiceProvider);
  return service.getVideoProgressPercent(
    studentId: studentId,
    lessonId: lessonId,
  );
});

/// Stream of content progress for a student in a subject
final studentSubjectProgressStreamProvider = StreamProvider.family<dynamic, String>((ref, subjectId) {
  final studentId = ref.watch(_currentStudentIdProvider);
  if (studentId == null) return Stream.empty();

  final service = ref.watch(contentProgressServiceProvider);
  return service.getStudentSubjectProgress(
    studentId: studentId,
    subjectId: subjectId,
  );
});
