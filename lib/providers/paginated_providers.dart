import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/pagination_service.dart';
import 'pagination_provider.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';
import 'student_provider.dart';
import 'exam_provider.dart';
import 'announcement_provider.dart';
import 'notification_provider.dart';
import 'assignment_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PAGINATED PROVIDERS — Concrete pagination providers for major lists
//
// Each provider creates a PaginationNotifier bound to a specific collection
// with the appropriate filters. Screens consume these via ref.watch() and
// pass the loader function to KlasivoPaginatedList.
//
// These providers complement (not replace) the existing stream providers.
// Stream providers are still used for real-time updates on small datasets.
// Paginated providers are used for large lists that benefit from cursor-based
// pagination to reduce memory and bandwidth usage.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Pagination Service Singleton ──────────────────────────────────────────

final paginationServiceProvider = Provider<PaginationService>((ref) {
  return PaginationService();
});

// ─── All Students (org-wide) ──────────────────────────────────────────────

final studentsPaginatedProvider =
    StateNotifierProvider<PaginationNotifier<StudentData>,
        PaginatedState<StudentData>>((ref) {
  final service = ref.watch(paginationServiceProvider);
  final orgId = ref.watch(currentOrganizationIdProvider);

  return PaginationNotifier<StudentData>((cursor) => service.fetchPage(
        collectionPath: 'users',
        fromFirestore: StudentData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'createdAt',
        descending: true,
        filters: [
          QueryFilter.equalTo('organizationId', orgId),
          QueryFilter.equalTo('role', 'student'),
          QueryFilter.equalTo('isActive', true),
        ],
      ));
});

// ─── Exams by Teacher ─────────────────────────────────────────────────────

final examsPaginatedProvider =
    StateNotifierProvider<PaginationNotifier<ExamData>,
        PaginatedState<ExamData>>((ref) {
  final service = ref.watch(paginationServiceProvider);
  final teacherId = ref.watch(currentUserIdProvider);
  final orgId = ref.watch(currentOrganizationIdProvider);

  final filters = <QueryFilter>[
    if (teacherId != null) QueryFilter.equalTo('teacherId', teacherId),
    if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
  ];

  return PaginationNotifier<ExamData>((cursor) => service.fetchPage(
        collectionPath: 'exams',
        fromFirestore: ExamData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'createdAt',
        descending: true,
        filters: filters,
      ));
});

// ─── Published Exams by Class ─────────────────────────────────────────────

final classExamsPaginatedProvider = StateNotifierProvider.family<
    PaginationNotifier<ExamData>,
    PaginatedState<ExamData>,
    String>((ref, classId) {
  final service = ref.watch(paginationServiceProvider);
  final orgId = ref.watch(currentOrganizationIdProvider);

  return PaginationNotifier<ExamData>((cursor) => service.fetchPage(
        collectionPath: 'exams',
        fromFirestore: ExamData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'startDate',
        descending: false,
        filters: [
          if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
          QueryFilter.equalTo('classId', classId),
          QueryFilter.equalTo('status', 'published'),
        ],
      ));
});

// ─── Announcements by Org ─────────────────────────────────────────────────

final announcementsPaginatedProvider =
    StateNotifierProvider<PaginationNotifier<AnnouncementData>,
        PaginatedState<AnnouncementData>>((ref) {
  final service = ref.watch(paginationServiceProvider);
  final orgId = ref.watch(currentOrganizationIdProvider);

  return PaginationNotifier<AnnouncementData>((cursor) => service.fetchPage(
        collectionPath: 'announcements',
        fromFirestore: AnnouncementData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'createdAt',
        descending: true,
        filters: [
          if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
          QueryFilter.equalTo('isActive', true),
        ],
      ));
});

// ─── Notifications by User ────────────────────────────────────────────────

final notificationsPaginatedProvider =
    StateNotifierProvider<PaginationNotifier<NotificationData>,
        PaginatedState<NotificationData>>((ref) {
  final service = ref.watch(paginationServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  return PaginationNotifier<NotificationData>((cursor) => service.fetchPage(
        collectionPath: 'notifications',
        fromFirestore: NotificationData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'createdAt',
        descending: true,
        filters: [
          if (userId != null) QueryFilter.equalTo('userId', userId),
        ],
      ));
});

// ─── Assignments by Org ───────────────────────────────────────────────────

final assignmentsPaginatedProvider =
    StateNotifierProvider<PaginationNotifier<AssignmentData>,
        PaginatedState<AssignmentData>>((ref) {
  final service = ref.watch(paginationServiceProvider);
  final orgId = ref.watch(currentOrganizationIdProvider);

  return PaginationNotifier<AssignmentData>((cursor) => service.fetchPage(
        collectionPath: 'assignments',
        fromFirestore: AssignmentData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'createdAt',
        descending: true,
        filters: [
          if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
          QueryFilter.equalTo('isArchived', false),
        ],
      ));
});

// ─── Assignments by Class ─────────────────────────────────────────────────

final classAssignmentsPaginatedProvider = StateNotifierProvider.family<
    PaginationNotifier<AssignmentData>,
    PaginatedState<AssignmentData>,
    String>((ref, classId) {
  final service = ref.watch(paginationServiceProvider);
  final orgId = ref.watch(currentOrganizationIdProvider);

  return PaginationNotifier<AssignmentData>((cursor) => service.fetchPage(
        collectionPath: 'assignments',
        fromFirestore: AssignmentData.fromFirestore,
        cursor: cursor,
        pageSize: 20,
        orderBy: 'dueDate',
        descending: false,
        filters: [
          if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
          QueryFilter.equalTo('classId', classId),
          QueryFilter.equalTo('isArchived', false),
        ],
      ));
});
