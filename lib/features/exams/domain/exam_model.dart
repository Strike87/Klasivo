/// Domain model for a Klasivo exam.
class ExamModel {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String organizationId;
  final String status; // draft, published, archived
  final int durationMinutes;
  final int totalMarks;
  final int questionCount;
  final bool isRandomized;
  final bool allowRetake;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final int version;

  const ExamModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.organizationId,
    this.status = 'draft',
    this.durationMinutes = 60,
    this.totalMarks = 0,
    this.questionCount = 0,
    this.isRandomized = false,
    this.allowRetake = false,
    this.startDate,
    this.endDate,
    required this.createdAt,
    this.version = 1,
  });

  factory ExamModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ExamModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      durationMinutes: data['durationMinutes'] as int? ?? 60,
      totalMarks: data['totalMarks'] as int? ?? 0,
      questionCount: data['questionCount'] as int? ?? 0,
      isRandomized: data['isRandomized'] as bool? ?? false,
      allowRetake: data['allowRetake'] as bool? ?? false,
      startDate: data['startDate'] != null
          ? (data['startDate'] as dynamic).toDate() as DateTime?
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as dynamic).toDate() as DateTime?
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime?
          : DateTime.now(),
      version: data['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'classId': classId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'organizationId': organizationId,
      'status': status,
      'durationMinutes': durationMinutes,
      'totalMarks': totalMarks,
      'questionCount': questionCount,
      'isRandomized': isRandomized,
      'allowRetake': allowRetake,
      'version': version,
    };
  }

  ExamModel copyWith({
    String? title,
    String? description,
    String? status,
    int? totalMarks,
    int? questionCount,
    bool? isRandomized,
    bool? allowRetake,
    int? version,
  }) {
    return ExamModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId,
      organizationId: organizationId,
      status: status ?? this.status,
      durationMinutes: durationMinutes,
      totalMarks: totalMarks ?? this.totalMarks,
      questionCount: questionCount ?? this.questionCount,
      isRandomized: isRandomized ?? this.isRandomized,
      allowRetake: allowRetake ?? this.allowRetake,
      startDate: startDate,
      endDate: endDate,
      createdAt: createdAt,
      version: version ?? this.version,
    );
  }

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isArchived => status == 'archived';
}
