// ─── Class Domain Model ──────────────────────────────────────────────────────
// Extracted from class_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class ClassData {
  final String id;
  final String organizationId;
  final String stageId;
  final String name;
  final String code;
  final int capacity;
  final String? homeroomTeacherId;
  final String? grade;
  final String? teacherId;
  final String? academicYear;
  final int studentCount;
  final String createdBy;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClassData({
    required this.id,
    required this.organizationId,
    required this.stageId,
    required this.name,
    this.code = '',
    this.capacity = 0,
    this.homeroomTeacherId,
    this.grade,
    this.teacherId,
    this.academicYear,
    this.studentCount = 0,
    this.createdBy = '',
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory ClassData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      stageId: data['stageId'] ?? '',
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      capacity: data['capacity'] ?? 0,
      homeroomTeacherId: data['homeroomTeacherId'] as String?,
      grade: data['grade'] as String?,
      teacherId: data['teacherId'] as String?,
      academicYear: data['academicYear'] as String?,
      studentCount: data['studentCount'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      isArchived: data['isArchived'] ?? false,
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      archivedBy: data['archivedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'stageId': stageId,
      'name': name,
      'code': code,
      'capacity': capacity,
      'homeroomTeacherId': homeroomTeacherId,
      'grade': grade,
      'teacherId': teacherId,
      'academicYear': academicYear,
      'studentCount': studentCount,
      'isArchived': isArchived,
      'archivedAt': archivedAt,
      'archivedBy': archivedBy,
    };
  }

  ClassData copyWith({
    String? name,
    String? stageId,
    String? code,
    int? capacity,
    String? homeroomTeacherId,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
  }) {
    return ClassData(
      id: id,
      organizationId: organizationId,
      stageId: stageId ?? this.stageId,
      name: name ?? this.name,
      code: code ?? this.code,
      capacity: capacity ?? this.capacity,
      homeroomTeacherId: homeroomTeacherId ?? this.homeroomTeacherId,
      grade: grade,
      teacherId: teacherId,
      academicYear: academicYear,
      studentCount: studentCount,
      createdBy: createdBy,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
