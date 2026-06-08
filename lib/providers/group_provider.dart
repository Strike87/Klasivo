import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/group_service.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());

final groupsByClassProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(groupServiceProvider).getGroupsByClassStream(classId);
});

final groupsByClassListProvider =
    Provider.family<List<GroupData>, String>((ref, classId) {
  final asyncGroups = ref.watch(groupsByClassProvider(classId));
  return asyncGroups.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => GroupData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

class GroupData {
  final String id;
  final String organizationId;
  final String classId;
  final String name;
  final String createdBy;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GroupData({
    required this.id,
    required this.organizationId,
    required this.classId,
    required this.name,
    this.createdBy = '',
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  factory GroupData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'] ?? '',
      name: data['name'] ?? '',
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
      'classId': classId,
      'name': name,
      'isArchived': isArchived,
    };
  }
}
