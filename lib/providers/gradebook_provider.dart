import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/gradebook_service.dart';
import 'organization_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final gradebookServiceProvider =
    Provider<GradebookService>((ref) => GradebookService());

// ─── Gradebook Categories ────────────────────────────────────────────────────

final gradebookCategoriesByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(gradebookServiceProvider)
      .getCategoriesByClassStream(orgId, classId);
});

final gradebookCategoriesListProvider =
    Provider.family<List<GradebookCategoryData>, String>((ref, classId) {
  final asyncCats = ref.watch(gradebookCategoriesByClassProvider(classId));
  return asyncCats.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => GradebookCategoryData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Gradebook Entries ────────────────────────────────────────────────────────

final gradebookEntriesByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref
      .read(gradebookServiceProvider)
      .getEntriesByClassStream(orgId, classId);
});

final gradebookEntriesByStudentProvider =
    Provider.family<List<GradebookEntryData>, String>((ref, classId) {
  final asyncEntries = ref.watch(gradebookEntriesByClassProvider(classId));
  return asyncEntries.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => GradebookEntryData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Student Grade Summary ────────────────────────────────────────────────────

final studentGradeSummaryProvider = FutureProvider.family<
    Map<String, dynamic>, ({String classId, String studentId})>((ref, params) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) {
    return {
      'weightedAverage': 0.0,
      'categories': <Map<String, dynamic>>[],
      'totalEntries': 0,
      'classRank': 0,
    };
  }
  return ref.read(gradebookServiceProvider).getStudentGradeSummary(
        organizationId: orgId,
        classId: params.classId,
        studentId: params.studentId,
      );
});

// ─── Gradebook Category Data Model ───────────────────────────────────────────

class GradebookCategoryData {
  final String id;
  final String organizationId;
  final String classId;
  final String name;
  final String type;
  final double weight;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GradebookCategoryData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.name,
    required this.type,
    required this.weight,
    this.createdAt,
    this.updatedAt,
  });

  factory GradebookCategoryData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GradebookCategoryData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      name: data['name'] ?? '',
      type: data['type'] ?? AppConstants.categoryExam,
      weight: (data['weight'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get typeLabel {
    switch (type) {
      case AppConstants.categoryExam:
        return 'Exam';
      case AppConstants.categoryHomework:
        return 'Homework';
      case AppConstants.categoryQuiz:
        return 'Quiz';
      case AppConstants.categoryParticipation:
        return 'Participation';
      case AppConstants.categoryProject:
        return 'Project';
      case AppConstants.categoryFinal:
        return 'Final';
      default:
        return type;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'classId': classId,
      'name': name,
      'type': type,
      'weight': weight,
    };
  }
}

// ─── Gradebook Entry Data Model ───────────────────────────────────────────────

class GradebookEntryData {
  final String id;
  final String organizationId;
  final String classId;
  final String studentId;
  final String categoryId;
  final String title;
  final double score;
  final double maxScore;
  final String? examId;
  final String? assignmentId;
  final String? feedback;
  final String? gradedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GradebookEntryData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.studentId,
    required this.categoryId,
    required this.title,
    required this.score,
    required this.maxScore,
    this.examId,
    this.assignmentId,
    this.feedback,
    this.gradedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory GradebookEntryData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GradebookEntryData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      studentId: data['studentId'] ?? '',
      categoryId: data['categoryId'] ?? '',
      title: data['title'] ?? '',
      score: (data['score'] ?? 0).toDouble(),
      maxScore: (data['maxScore'] ?? 100).toDouble(),
      examId: data['examId'],
      assignmentId: data['assignmentId'],
      feedback: data['feedback'],
      gradedBy: data['gradedBy'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  double get percentage => maxScore > 0 ? (score / maxScore * 100) : 0;
  bool get isPassing => percentage >= 50;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'classId': classId,
      'studentId': studentId,
      'categoryId': categoryId,
      'title': title,
      'score': score,
      'maxScore': maxScore,
      'examId': examId,
      'assignmentId': assignmentId,
      'feedback': feedback,
      'gradedBy': gradedBy,
    };
  }
}
