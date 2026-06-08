import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/exam_template_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final examTemplateServiceProvider =
    Provider<ExamTemplateService>((ref) => ExamTemplateService());

// ─── Templates by Teacher Stream ─────────────────────────────────────────────

final examTemplatesByTeacherProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) return const Stream.empty();
  return ref
      .read(examTemplateServiceProvider)
      .getTemplatesByTeacherStream(teacherId);
});

// ─── Templates by Organization Stream ────────────────────────────────────────

final examTemplatesByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(examTemplateServiceProvider)
      .getTemplatesByOrganizationStream(orgId);
});

// ─── Templates List Provider ─────────────────────────────────────────────────

final examTemplatesProvider = Provider<List<ExamTemplateData>>((ref) {
  final asyncTemplates = ref.watch(examTemplatesByOrgProvider);
  return asyncTemplates.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => ExamTemplateData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Exam Template Data Model ────────────────────────────────────────────────

class ExamTemplateData {
  final String id;
  final String organizationId;
  final String teacherId;
  final String name;
  final String? description;
  final int durationMinutes;
  final int questionCount;
  final double totalMarks;
  final String? subjectId;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExamTemplateData({
    required this.id,
    required this.organizationId,
    required this.teacherId,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.questionCount,
    required this.totalMarks,
    this.subjectId,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.createdAt,
    this.updatedAt,
  });

  factory ExamTemplateData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamTemplateData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      teacherId: data['teacherId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      durationMinutes: data['durationMinutes'] ?? 60,
      questionCount: data['questionCount'] ?? 0,
      totalMarks: (data['totalMarks'] ?? 0).toDouble(),
      subjectId: data['subjectId'],
      shuffleQuestions: data['shuffleQuestions'] ?? false,
      shuffleOptions: data['shuffleOptions'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'teacherId': teacherId,
      'name': name,
      'description': description,
      'durationMinutes': durationMinutes,
      'questionCount': questionCount,
      'totalMarks': totalMarks,
      'subjectId': subjectId,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
    };
  }
}
