import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/stage_service.dart';
import 'auth_provider.dart';

final stageServiceProvider = Provider<StageService>((ref) => StageService());

final stagesStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  return ref.read(stageServiceProvider).getStagesStream(teacherId);
});

final stagesProvider = Provider<List<StageData>>((ref) {
  final asyncStages = ref.watch(stagesStreamProvider);
  return asyncStages.when(
    data: (snapshot) => snapshot.docs.map((doc) => StageData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class StageData {
  final String id;
  final String teacherId;
  final String name;
  final String institutionId;
  final DateTime? createdAt;

  StageData({
    required this.id,
    required this.teacherId,
    required this.name,
    this.institutionId = AppConstants.defaultInstitutionId,
    this.createdAt,
  });

  factory StageData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StageData(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      name: data['name'] ?? '',
      institutionId: data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'name': name,
      'institutionId': institutionId,
    };
  }
}
