import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log an audit event
  Future<void> log({
    required String organizationId,
    required String userId,
    required String userName,
    required String action,
    required String targetType, // 'exam', 'class', 'student', 'assignment', 'announcement', etc.
    required String targetId,
    String? targetName,
    String? details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection(AppConstants.auditLogsCollection).add({
        'organizationId': organizationId,
        'userId': userId,
        'userName': userName,
        'action': action, // 'create', 'update', 'delete', 'publish', 'archive', etc.
        'targetType': targetType,
        'targetId': targetId,
        'targetName': targetName,
        'details': details,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging audit event: $e');
      // Don't rethrow — audit logging should never break the main flow
    }
  }

  /// Convenience: Log a create action
  Future<void> logCreate({
    required String organizationId,
    required String userId,
    required String userName,
    required String targetType,
    required String targetId,
    String? targetName,
    String? details,
  }) => log(
    organizationId: organizationId,
    userId: userId,
    userName: userName,
    action: 'create',
    targetType: targetType,
    targetId: targetId,
    targetName: targetName,
    details: details,
  );

  /// Convenience: Log an update action
  Future<void> logUpdate({
    required String organizationId,
    required String userId,
    required String userName,
    required String targetType,
    required String targetId,
    String? targetName,
    String? details,
  }) => log(
    organizationId: organizationId,
    userId: userId,
    userName: userName,
    action: 'update',
    targetType: targetType,
    targetId: targetId,
    targetName: targetName,
    details: details,
  );

  /// Convenience: Log a delete action
  Future<void> logDelete({
    required String organizationId,
    required String userId,
    required String userName,
    required String targetType,
    required String targetId,
    String? targetName,
    String? details,
  }) => log(
    organizationId: organizationId,
    userId: userId,
    userName: userName,
    action: 'delete',
    targetType: targetType,
    targetId: targetId,
    targetName: targetName,
    details: details,
  );

  /// Stream audit logs by organization
  Stream<QuerySnapshot> getAuditLogsStream(String orgId, {int limit = 100}) {
    return _firestore
        .collection(AppConstants.auditLogsCollection)
        .where('organizationId', orgId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Stream audit logs filtered by target type
  Stream<QuerySnapshot> getAuditLogsByTypeStream(String orgId, String targetType, {int limit = 50}) {
    return _firestore
        .collection(AppConstants.auditLogsCollection)
        .where('organizationId', orgId)
        .where('targetType', targetType)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Stream audit logs filtered by user
  Stream<QuerySnapshot> getAuditLogsByUserStream(String orgId, String userId, {int limit = 50}) {
    return _firestore
        .collection(AppConstants.auditLogsCollection)
        .where('organizationId', orgId)
        .where('userId', userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get audit log count for an organization
  Future<int> getAuditLogCount(String orgId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.auditLogsCollection)
          .where('organizationId', orgId)
          .count()
          .get();
      return snapshot.count;
    } catch (e) {
      debugPrint('Error getting audit log count: $e');
      return 0;
    }
  }
}
