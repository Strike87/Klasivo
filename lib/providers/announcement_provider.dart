import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/app_constants.dart';
import '../core/services/announcement_service.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final announcementServiceProvider = Provider<AnnouncementService>((ref) => AnnouncementService());

// ─── Data Model ────────────────────────────────────────────────────────────

class AnnouncementData {
  final String id;
  final String organizationId;
  final String title;
  final String content;
  final String targetType; // 'organization', 'class', 'group'
  final String targetId;
  final String? createdBy;
  final String? createdByName;
  final bool isPinned;
  final bool isActive;
  final DateTime? expiresAt;
  final List<String> readBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AnnouncementData({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.content,
    required this.targetType,
    required this.targetId,
    this.createdBy,
    this.createdByName,
    this.isPinned = false,
    this.isActive = true,
    this.expiresAt,
    this.readBy = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory AnnouncementData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      targetType: data['targetType'] ?? 'organization',
      targetId: data['targetId'] ?? '',
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      isPinned: data['isPinned'] ?? false,
      isActive: data['isActive'] ?? true,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'title': title,
    'content': content,
    'targetType': targetType,
    'targetId': targetId,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'isPinned': isPinned,
    'isActive': isActive,
    'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'readBy': readBy,
    'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
  };

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool isReadBy(String userId) => readBy.contains(userId);

  String get targetLabel {
    switch (targetType) {
      case 'organization': return 'Everyone';
      case 'class': return 'Class';
      case 'group': return 'Group';
      default: return targetType;
    }
  }
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final announcementsByOrgProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(announcementServiceProvider).getAnnouncementsByOrganizationStream(orgId);
});

final announcementsByClassProvider = StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(announcementServiceProvider).getAnnouncementsByTargetStream(orgId, 'class', classId);
});

final announcementsForStudentProvider = StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(announcementServiceProvider).getAnnouncementsForStudentStream(orgId, classId);
});

// ─── Derived List Providers ────────────────────────────────────────────────

final announcementsProvider = Provider<List<AnnouncementData>>((ref) {
  final asyncAnnouncements = ref.watch(announcementsByOrgProvider);
  return asyncAnnouncements.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => AnnouncementData.fromFirestore(doc))
        .where((a) => !a.isExpired)
        .toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Announcements provider error: $e'); return []; },
  );
});

final pinnedAnnouncementsProvider = Provider<List<AnnouncementData>>((ref) {
  final announcements = ref.watch(announcementsProvider);
  return announcements.where((a) => a.isPinned).toList();
});
