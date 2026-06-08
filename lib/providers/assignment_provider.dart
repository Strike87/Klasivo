import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/assignment_service.dart';
import 'organization_provider.dart';

final assignmentServiceProvider =
    Provider<AssignmentService>((ref) => AssignmentService());

final assignmentsByClassProvider =
    StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, classId) {
  return ref.read(assignmentServiceProvider).getAssignmentsByClassStream(classId);
});

final assignmentsByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(assignmentServiceProvider)
      .getAssignmentsByOrganizationStream(orgId);
});

final assignmentsProvider = Provider<List<AssignmentData>>((ref) {
  final asyncAssignments = ref.watch(assignmentsByOrgProvider);
  return asyncAssignments.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => AssignmentData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

final assignmentsByClassListProvider =
    Provider.family<List<AssignmentData>, String>((ref, classId) {
  final asyncAssignments = ref.watch(assignmentsByClassProvider(classId));
  return asyncAssignments.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => AssignmentData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

class AssignmentData {
  final String id;
  final String organizationId;
  final String classId;
  final String title;
  final String? description;
  final String? subjectId;
  final String? groupId;
  final DateTime dueDate;
  final String status;
  final List<String> attachments;
  final String createdBy;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AssignmentData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.title,
    this.description,
    this.subjectId,
    this.groupId,
    required this.dueDate,
    this.status = AppConstants.assignmentStatusDraft,
    this.attachments = const [],
    this.createdBy = '',
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  factory AssignmentData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AssignmentData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      subjectId: data['subjectId'],
      groupId: data['groupId'],
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? AppConstants.assignmentStatusDraft,
      attachments: List<String>.from(data['attachments'] ?? []),
      createdBy: data['createdBy'] ?? '',
      isArchived: data['isArchived'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isDraft => status == AppConstants.assignmentStatusDraft;
  bool get isPublished => status == AppConstants.assignmentStatusPublished;
  bool get isOverdue => dueDate.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'classId': classId,
      'title': title,
      'description': description,
      'subjectId': subjectId,
      'groupId': groupId,
      'dueDate': dueDate,
      'status': status,
      'attachments': attachments,
      'isArchived': isArchived,
    };
  }
}
