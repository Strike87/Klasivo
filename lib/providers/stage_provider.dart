import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/stage_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

final stageServiceProvider = Provider<StageService>((ref) => StageService());

final stagesStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(stageServiceProvider).getStagesStream(orgId);
});

final stagesProvider = Provider<List<StageData>>((ref) {
  final asyncStages = ref.watch(stagesStreamProvider);
  return asyncStages.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => StageData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class StageData {
  final String id;
  final String organizationId;
  final String name;
  final int order;
  final String createdBy;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StageData({
    required this.id,
    required this.organizationId,
    required this.name,
    this.order = 0,
    this.createdBy = '',
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  factory StageData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StageData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      name: data['name'] ?? '',
      order: data['order'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      isArchived: data['isArchived'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizationId': organizationId,
      'name': name,
      'order': order,
      'isArchived': isArchived,
    };
  }
}
