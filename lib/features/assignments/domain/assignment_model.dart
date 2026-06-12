/// Domain model for a Klasivo assignment.
class AssignmentModel {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String organizationId;
  final DateTime? dueDate;
  final String status; // draft, published, closed
  final DateTime createdAt;

  const AssignmentModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.organizationId,
    this.dueDate,
    this.status = 'draft',
    required this.createdAt,
  });

  factory AssignmentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AssignmentModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as dynamic).toDate() as DateTime?
          : null,
      status: data['status'] as String? ?? 'draft',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate() as DateTime?
          : DateTime.now(),
    );
  }

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isClosed => status == 'closed';
}
