import '../domain/exam_model.dart';
import '../../../core/services/interfaces/i_exam_service.dart';

/// Repository layer for exam operations.
class ExamRepository {
  final IExamService _examService;

  ExamRepository(this._examService);

  Future<String> createExam({required Map<String, dynamic> examData}) =>
      _examService.createExam(examData: examData);

  Future<void> updateExam({required String examId, required Map<String, dynamic> updates}) =>
      _examService.updateExam(examId: examId, updates: updates);

  Future<void> publishExam({required String examId}) =>
      _examService.publishExam(examId: examId);

  Future<void> unpublishExam({required String examId}) =>
      _examService.unpublishExam(examId: examId);

  Future<void> archiveExam({required String examId}) =>
      _examService.archiveExam(examId: examId);

  Future<void> deleteExam({required String examId}) =>
      _examService.deleteExam(examId: examId);

  Future<ExamModel?> getExam(String examId) async {
    final data = await _examService.getExam(examId);
    if (data == null) return null;
    return ExamModel.fromFirestore(data, examId);
  }

  Future<void> recalculateTotalMarks(String examId) =>
      _examService.recalculateTotalMarks(examId);
}
