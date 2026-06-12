import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/exam_repository.dart';
import '../../../core/services/exam_service.dart';
import '../../../core/services/interfaces/i_exam_service.dart';

/// Production [IExamService] implementation
final examServiceProvider = Provider<IExamService>((ref) => ExamService());

/// [ExamRepository] provider
final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepository(ref.watch(examServiceProvider));
});
