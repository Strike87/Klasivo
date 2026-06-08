import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/parent_link_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final parentLinkServiceProvider =
    Provider<ParentLinkService>((ref) => ParentLinkService());

// ─── Parent's Linked Students Stream ─────────────────────────────────────────

final parentLinksStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final parentId = ref.watch(userIdProvider);
  if (parentId == null || parentId.isEmpty) return const Stream.empty();
  return ref.read(parentLinkServiceProvider).getParentLinksStream(parentId);
});

// ─── Parent's Linked Students List ───────────────────────────────────────────

final parentLinksProvider = Provider<List<ParentLinkData>>((ref) {
  final asyncLinks = ref.watch(parentLinksStreamProvider);
  return asyncLinks.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => ParentLinkData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Student's Parents Stream (teacher/admin) ────────────────────────────────

final studentParentsStreamProvider =
    StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, studentId) {
  return ref.read(parentLinkServiceProvider).getStudentParentsStream(studentId);
});

final studentParentsListProvider =
    Provider.family<List<ParentLinkData>, String>((ref, studentId) {
  final asyncParents = ref.watch(studentParentsStreamProvider(studentId));
  return asyncParents.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => ParentLinkData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// ─── Parent Viewing Student Results ──────────────────────────────────────────

final parentStudentResultsProvider =
    StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, studentId) {
  final parentId = ref.watch(userIdProvider);
  if (parentId == null || parentId.isEmpty) return const Stream.empty();
  return ref
      .read(parentLinkServiceProvider)
      .getStudentResultsForParent(parentId: parentId, studentId: studentId);
});

// ─── Parent Viewing Student Attendance ───────────────────────────────────────

final parentStudentAttendanceProvider =
    StreamProvider.family.autoDispose<QuerySnapshot, String>((ref, studentId) {
  final parentId = ref.watch(userIdProvider);
  if (parentId == null || parentId.isEmpty) return const Stream.empty();
  return ref
      .read(parentLinkServiceProvider)
      .getStudentAttendanceForParent(parentId: parentId, studentId: studentId);
});

// ─── Parent Link Data Model ──────────────────────────────────────────────────

class ParentLinkData {
  final String id;
  final String code;
  final String organizationId;
  final String studentId;
  final String? parentId;
  final String? generatedBy;
  final String status;
  final DateTime? expiresAt;
  final DateTime? linkedAt;
  final String? studentName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ParentLinkData({
    required this.id,
    required this.code,
    required this.organizationId,
    required this.studentId,
    this.parentId,
    this.generatedBy,
    this.status = AppConstants.parentLinkPending,
    this.expiresAt,
    this.linkedAt,
    this.studentName,
    this.createdAt,
    this.updatedAt,
  });

  factory ParentLinkData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParentLinkData(
      id: doc.id,
      code: data['code'] ?? '',
      organizationId: data['organizationId'] ?? '',
      studentId: data['studentId'] ?? '',
      parentId: data['parentId'],
      generatedBy: data['generatedBy'],
      status: data['status'] ?? AppConstants.parentLinkPending,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      linkedAt: (data['linkedAt'] as Timestamp?)?.toDate(),
      studentName: data['studentName'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isPending => status == AppConstants.parentLinkPending;
  bool get isApproved => status == AppConstants.parentLinkApproved;
  bool get isRevoked => status == AppConstants.parentLinkRevoked;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'organizationId': organizationId,
      'studentId': studentId,
      'parentId': parentId,
      'generatedBy': generatedBy,
      'status': status,
      'expiresAt': expiresAt,
      'linkedAt': linkedAt,
      'studentName': studentName,
    };
  }
}
