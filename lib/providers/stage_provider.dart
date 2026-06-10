import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/stage_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ─────────────────────────────────────────────────────────

final stageServiceProvider = Provider<StageService>((ref) => StageService());

// ─── Stages Stream (all stages for current org) ──────────────────────────────

final stagesStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(stageServiceProvider).getStagesStream(orgId);
});

// ─── Parsed Stages List ───────────────────────────────────────────────────────

final stagesProvider = Provider<List<StageData>>((ref) {
  final asyncStages = ref.watch(stagesStreamProvider);
  return asyncStages.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => StageData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// ─── Single Stage by ID ───────────────────────────────────────────────────────

final stageByIdProvider =
    Provider.family<StageData?, String>((ref, stageId) {
  final stages = ref.watch(stagesProvider);
  try {
    return stages.firstWhere((s) => s.id == stageId);
  } catch (_) {
    return null;
  }
});

// ─── Stage Data Model ─────────────────────────────────────────────────────────

class StageData {
  final String id;
  final String organizationId;
  final String name;
  final String description;
  final int order;
  final String createdBy;
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StageData({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description = '',
    this.order = 0,
    this.createdBy = '',
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory StageData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StageData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      order: data['order'] ?? 0,
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
      'name': name,
      'description': description,
      'order': order,
      'isArchived': isArchived,
      'archivedAt': archivedAt,
      'archivedBy': archivedBy,
    };
  }

  StageData copyWith({
    String? name,
    String? description,
    int? order,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
  }) {
    return StageData(
      id: id,
      organizationId: organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      order: order ?? this.order,
      createdBy: createdBy,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
