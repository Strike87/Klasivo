import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/exam_service.dart';
import 'auth_provider.dart';
import 'class_provider.dart';
import 'organization_provider.dart';

final examServiceProvider = Provider<ExamService>((ref) => ExamService());

final examsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null || orgId.isEmpty) return const Stream.empty();
  return ref.read(examServiceProvider).getExamsStream(teacherId, organizationId: orgId);
});

final examsProvider = Provider<List<ExamData>>((ref) {
  final asyncExams = ref.watch(examsStreamProvider);
  return asyncExams.when(
    skipLoadingOnReload: true,  // P0-9: prevent dashboard flicker on pull-to-refresh
    data: (snapshot) =>
        snapshot.docs.map((doc) => ExamData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) {
      debugPrint('examsProvider error: $e');
      return [];
    },
  );
});

final upcomingExamsProvider = Provider<List<ExamData>>((ref) {
  final exams = ref.watch(examsProvider);
  final now = DateTime.now();
  return exams
      .where((e) =>
          e.status == AppConstants.statusPublished && e.endDate.isAfter(now))
      .toList();
});

final completedExamsProvider = Provider<List<ExamData>>((ref) {
  final exams = ref.watch(examsProvider);
  final now = DateTime.now();
  return exams
      .where((e) =>
          e.status == AppConstants.statusPublished && e.endDate.isBefore(now))
      .toList();
});

final draftExamsProvider = Provider<List<ExamData>>((ref) {
  final exams = ref.watch(examsProvider);
  return exams
      .where((e) => e.status == AppConstants.statusDraft)
      .toList();
});

final examStatsProvider = Provider<Map<String, int>>((ref) {
  final exams = ref.watch(examsProvider);
  final now = DateTime.now();
  int upcoming = 0;
  int completed = 0;
  int draft = 0;

  for (final exam in exams) {
    if (exam.status == AppConstants.statusDraft) {
      draft++;
    } else if (exam.endDate.isBefore(now)) {
      completed++;
    } else {
      upcoming++;
    }
  }

  return {
    'upcoming': upcoming,
    'completed': completed,
    'draft': draft,
    'total': exams.length,
  };
});

final classExamsStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null || orgId.isEmpty) return const Stream.empty();
  return ref.read(examServiceProvider).getClassExamsStream(classId, organizationId: orgId);
});

// ─── Exam Stats Stream Provider ──────────────────────────────────────────
// NOTE: examStatsStreamProvider is defined in exam_stats_provider.dart
// to avoid duplicate provider definitions.

// ─── Exam Data Model ────────────────────────────────────────────────────────

class ExamData {
  final String id;
  final String teacherId;
  final String title;
  final String? description;
  final String classId;
  final int durationMinutes;
  final DateTime startDate;
  final DateTime endDate;
  final int totalMarks;
  final int passingScore;
  final String status;
  final int questionCount;
  final bool isRandomized;
  final bool allowRetake;
  final String organizationId;
  final DateTime? createdAt;
  final DateTime? publishedAt;

  ExamData({
    required this.id,
    required this.teacherId,
    required this.title,
    this.description,
    required this.classId,
    required this.durationMinutes,
    required this.startDate,
    required this.endDate,
    this.totalMarks = 0,
    this.passingScore = 0,
    this.status = AppConstants.statusDraft,
    this.questionCount = 0,
    this.isRandomized = false,
    this.allowRetake = false,
    this.organizationId = AppConstants.defaultInstitutionId,
    this.createdAt,
    this.publishedAt,
  });

  factory ExamData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamData(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'],
      classId: data['classId'] ?? '',
      durationMinutes: data['durationMinutes'] as int? ?? 30,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalMarks: data['totalMarks'] as int? ?? 0,
      passingScore: data['passingScore'] as int? ?? 0,
      status: data['status'] ?? AppConstants.statusDraft,
      questionCount: data['questionCount'] as int? ?? 0,
      isRandomized: data['isRandomized'] as bool? ?? false,
      allowRetake: data['allowRetake'] as bool? ?? false,
      organizationId: data['organizationId'] ?? data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isActive =>
      status == AppConstants.statusPublished &&
      DateTime.now().isAfter(startDate) &&
      DateTime.now().isBefore(endDate);

  bool get canStart =>
      status == AppConstants.statusPublished &&
      DateTime.now().isAfter(startDate);

  bool get isEnded => DateTime.now().isAfter(endDate);

  String getClassName(List<ClassData> classes) {
    final cls = classes.where((c) => c.id == classId).firstOrNull;
    return cls?.name ?? 'Unknown Class';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'classId': classId,
      'durationMinutes': durationMinutes,
      'startDate': startDate,
      'endDate': endDate,
      'totalMarks': totalMarks,
      'passingScore': passingScore,
      'status': status,
      'questionCount': questionCount,
      'isRandomized': isRandomized,
      'allowRetake': allowRetake,
      'organizationId': organizationId,
      'createdAt': createdAt,
      'publishedAt': publishedAt,
    };
  }
}
