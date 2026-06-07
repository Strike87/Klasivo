import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/invite_code_service.dart';
import 'organization_provider.dart';

final inviteCodeServiceProvider =
    Provider<InviteCodeService>((ref) => InviteCodeService());

final inviteCodesStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(inviteCodeServiceProvider).getInviteCodesStream(orgId);
});

final inviteCodesProvider = Provider<List<InviteCodeData>>((ref) {
  final asyncCodes = ref.watch(inviteCodesStreamProvider);
  return asyncCodes.when(
    data: (snapshot) => snapshot.docs
        .map((doc) => InviteCodeData.fromFirestore(doc))
        .toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

class InviteCodeData {
  final String id;
  final String code;
  final String type;
  final String organizationId;
  final String? classId;
  final String createdBy;
  final bool isUsed;
  final String? usedBy;
  final int maxUses;
  final int useCount;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime? createdAt;

  InviteCodeData({
    required this.id,
    required this.code,
    required this.type,
    required this.organizationId,
    this.classId,
    this.createdBy = '',
    this.isUsed = false,
    this.usedBy,
    this.maxUses = 1,
    this.useCount = 0,
    this.expiresAt,
    this.usedAt,
    this.createdAt,
  });

  factory InviteCodeData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteCodeData(
      id: doc.id,
      code: data['code'] ?? '',
      type: data['type'] ?? '',
      organizationId: data['organizationId'] ?? '',
      classId: data['classId'],
      createdBy: data['createdBy'] ?? '',
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
      maxUses: data['maxUses'] ?? 1,
      useCount: data['useCount'] ?? 0,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isValid => !isUsed && !isExpired;

  String get typeLabel {
    switch (type) {
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      default:
        return type;
    }
  }
}
