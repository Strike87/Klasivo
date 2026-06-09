import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/lesson_plan_service.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final lessonPlanServiceProvider = Provider<LessonPlanService>((ref) => LessonPlanService());

// ─── Data Model ────────────────────────────────────────────────────────────

class LessonPlanData {
  final String id;
  final String organizationId;
  final String subjectId;
  final String chapterId;
  final String title;
  final String objectives;
  final String topics;
  final String activities;
  final String? homework;
  final String? resources;
  final int duration;
  final String notes;
  final bool isTemplate;
  final String templateName;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LessonPlanData({
    required this.id,
    required this.organizationId,
    required this.subjectId,
    required this.chapterId,
    required this.title,
    required this.objectives,
    required this.topics,
    required this.activities,
    this.homework,
    this.resources,
    required this.duration,
    required this.notes,
    this.isTemplate = false,
    this.templateName = '',
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  factory LessonPlanData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LessonPlanData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      subjectId: data['subjectId'] ?? '',
      chapterId: data['chapterId'] ?? '',
      title: data['title'] ?? '',
      objectives: data['objectives'] ?? '',
      topics: data['topics'] ?? '',
      activities: data['activities'] ?? '',
      homework: data['homework'],
      resources: data['resources'],
      duration: data['duration'] ?? 0,
      notes: data['notes'] ?? '',
      isTemplate: data['isTemplate'] ?? false,
      templateName: data['templateName'] ?? '',
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'subjectId': subjectId,
    'chapterId': chapterId,
    'title': title,
    'objectives': objectives,
    'topics': topics,
    'activities': activities,
    'homework': homework,
    'resources': resources,
    'duration': duration,
    'notes': notes,
    'isTemplate': isTemplate,
    'templateName': templateName,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  bool get hasHomework => homework != null && homework!.isNotEmpty;

  bool get hasResources => resources != null && resources!.isNotEmpty;

  String get durationFormatted => '$duration min';
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final lessonPlansByOrgStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(lessonPlanServiceProvider).getLessonPlansByOrganizationStream(orgId);
});

final lessonPlansBySubjectStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, subjectId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(lessonPlanServiceProvider).getLessonPlansBySubjectStream(orgId, subjectId);
});

// ─── Derived List Providers ────────────────────────────────────────────────

final lessonPlansProvider = Provider<List<LessonPlanData>>((ref) {
  final asyncLessonPlans = ref.watch(lessonPlansByOrgStreamProvider);
  return asyncLessonPlans.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => LessonPlanData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Lesson plans provider error: $e'); return []; },
  );
});

final lessonPlansBySubjectProvider = Provider.family<List<LessonPlanData>, String>((ref, subjectId) {
  final lessonPlans = ref.watch(lessonPlansProvider);
  return lessonPlans.where((lp) => lp.subjectId == subjectId).toList();
});

final lessonPlanTemplatesProvider = Provider<List<LessonPlanData>>((ref) {
  final lessonPlans = ref.watch(lessonPlansProvider);
  return lessonPlans.where((lp) => lp.isTemplate).toList();
});

final recentLessonPlansProvider = Provider<List<LessonPlanData>>((ref) {
  final lessonPlans = ref.watch(lessonPlansProvider);
  final sorted = [...lessonPlans]..sort((a, b) {
    final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bDate.compareTo(aDate);
  });
  return sorted.take(10).toList();
});
