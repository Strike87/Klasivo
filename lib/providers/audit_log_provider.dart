import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/app_constants.dart';
import '../core/services/audit_log_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final auditLogServiceProvider = Provider<AuditLogService>((ref) => AuditLogService());

// ─── Data Model ────────────────────────────────────────────────────────────

class AuditLogData {
  final String id;
  final String organizationId;
  final String userId;
  final String userName;
  final String action; // 'create', 'update', 'delete', 'publish', 'archive'
  final String targetType; // 'exam', 'class', 'student', etc.
  final String targetId;
  final String? targetName;
  final String? details;
  final Map<String, dynamic> metadata;
  final DateTime? timestamp;

  AuditLogData({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.targetName,
    this.details,
    this.metadata = const {},
    this.timestamp,
  });

  factory AuditLogData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLogData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      action: data['action'] ?? '',
      targetType: data['targetType'] ?? '',
      targetId: data['targetId'] ?? '',
      targetName: data['targetName'],
      details: data['details'],
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  /// Human-readable action description
  String get description {
    final actionLabel = switch (action) {
      'create' => 'created',
      'update' => 'updated',
      'delete' => 'deleted',
      'publish' => 'published',
      'archive' => 'archived',
      'submit' => 'submitted',
      'grade' => 'graded',
      'link' => 'linked',
      'revoke' => 'revoked',
      _ => action,
    };
    final targetLabel = switch (targetType) {
      'exam' => 'Exam',
      'class' => 'Class',
      'student' => 'Student',
      'teacher' => 'Teacher',
      'assignment' => 'Assignment',
      'announcement' => 'Announcement',
      'gradebook' => 'Gradebook',
      'attendance' => 'Attendance',
      'question_bank' => 'Question Bank',
      'organization' => 'Organization',
      'invite_code' => 'Invite Code',
      'academic_year' => 'Academic Year',
      _ => targetType,
    };
    final name = targetName != null ? ' "$targetName"' : '';
    return '$userName $actionLabel $targetLabel$name';
  }

  /// Action icon
  IconData get actionIcon => switch (action) {
    'create' => Icons.add_circle,
    'update' => Icons.edit,
    'delete' => Icons.delete,
    'publish' => Icons.publish,
    'archive' => Icons.archive,
    'submit' => Icons.send,
    'grade' => Icons.grade,
    'link' => Icons.link,
    'revoke' => Icons.link_off,
    _ => Icons.info,
  };

  /// Action color
  int get actionColor => switch (action) {
    'create' => 0xFF12B886,   // Emerald
    'update' => 0xFF3B5BDB,   // Indigo
    'delete' => 0xFFFA5252,   // Red
    'publish' => 0xFF845EF7,  // Purple
    'archive' => 0xFFF59F00,  // Amber
    'submit' => 0xFF15AABF,   // Cyan
    'grade' => 0xFF12B886,    // Emerald
    _ => 0xFF868E96,          // Grey
  };
}

// ─── Stream Providers ──────────────────────────────────────────────────────

final auditLogsProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(auditLogServiceProvider).getAuditLogsStream(orgId);
});

final auditLogsByTypeProvider = StreamProvider.family<QuerySnapshot, String>((ref, targetType) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(auditLogServiceProvider).getAuditLogsByTypeStream(orgId, targetType);
});

final auditLogsByUserProvider = StreamProvider.family<QuerySnapshot, String>((ref, userId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  if (orgId == null) return const Stream.empty();
  return ref.read(auditLogServiceProvider).getAuditLogsByUserStream(orgId, userId);
});

// ─── Derived List Provider ─────────────────────────────────────────────────

final auditLogsListProvider = Provider<List<AuditLogData>>((ref) {
  final asyncLogs = ref.watch(auditLogsProvider);
  return asyncLogs.when(
    data: (snapshot) => snapshot.docs.map((doc) => AuditLogData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Audit logs provider error: $e'); return []; },
  );
});
