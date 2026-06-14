/// Domain model for an exam submission.
class SubmissionModel {
  final String id;
  final String examId;
  final String studentId;
  final String classId;
  final String organizationId;
  final String status; // started, submitted, graded
  final int? score;
  final int? totalMarks;
  final double? percentage;
  final int violationCount;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int? timeSpentSeconds;

  const SubmissionModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.classId,
    required this.organizationId,
    this.status = 'started',
    this.score,
    this.totalMarks,
    this.percentage,
    this.violationCount = 0,
    this.startedAt,
    this.submittedAt,
    this.timeSpentSeconds,
  });

  factory SubmissionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return SubmissionModel(
      id: id,
      examId: data['examId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      status: data['status'] as String? ?? 'started',
      score: data['score'] as int?,
      totalMarks: data['totalMarks'] as int?,
      percentage: data['percentage'] as double?,
      violationCount: data['violationCount'] as int? ?? 0,
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as dynamic).toDate() as DateTime?
          : null,
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as dynamic).toDate() as DateTime?
          : null,
      timeSpentSeconds: data['timeSpentSeconds'] as int?,
    );
  }

  bool get isStarted => status == 'started';
  bool get isSubmitted => status == 'submitted';
  bool get isGraded => status == 'graded';
  bool get hasViolations => violationCount > 0;
}
