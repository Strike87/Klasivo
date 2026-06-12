// ─── Riverpod Generator Example: Exam Feature ─────────────────────────────
//
// Demonstrates @riverpod with async data (exam streams).
// After running build_runner, the .g.dart file will contain
// generated AsyncNotifierProvider boilerplate.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/exam_repository.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/services/interfaces/i_exam_service.dart';

part 'exam_generated_providers.g.dart';

/// Production exam service provider.
@riverpod
IExamService examService(Ref ref) {
  return ExamService();
}

/// Exam repository provider — depends on [examServiceProvider].
@riverpod
ExamRepository examRepository(Ref ref) {
  return ExamRepository(ref.watch(examServiceProvider));
}
