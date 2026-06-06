import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/group_service.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());

final groupsByClassProvider = StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(groupServiceProvider).getGroupsByClassStream(classId);
});

final groupsByClassListProvider = Provider.family<List<GroupData>, String>((ref, classId) {
  final asyncGroups = ref.watch(groupsByClassProvider(classId));
  return asyncGroups.when(
    data: (snapshot) => snapshot.docs.map((doc) => GroupData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class GroupData {
  final String id;
  final String classId;
  final String name;
  final String teacherId;
  final String institutionId;
  final DateTime? createdAt;

  GroupData({
    required this.id,
    required this.classId,
    required this.name,
    required this.teacherId,
    this.institutionId = AppConstants.defaultInstitutionId,
    this.createdAt,
  });

  factory GroupData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupData(
      id: doc.id,
      classId: data['classId'] ?? '',
      name: data['name'] ?? '',
      teacherId: data['teacherId'] ?? '',
      institutionId: data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'name': name,
      'teacherId': teacherId,
      'institutionId': institutionId,
    };
  }
}
