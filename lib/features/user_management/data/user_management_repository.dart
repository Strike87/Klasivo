// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — User Management Repository
//
// Wraps Cloud Function calls and Firestore queries for RBAC user management.
// All CF calls enforce organization boundary validation server-side.
//
// Cloud Functions used:
//   - assignRole          → { targetUserId, newRole }
//   - assignScope         → { targetUserId, scopeData }
//   - setPermissionOverrides → { targetUserId, overrides, mode? }
//   - syncClaims          → { targetUserId? }
//
// Firestore reads:
//   - users collection (org-scoped queries)
//   - campuses, stages, classes (for scope tree)
//   - audit_logs (for user audit history)
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/rbac/roles.dart';

// ─── Data Models ───────────────────────────────────────────────────────────────

/// Lightweight user model for the People Hub list view.
class UserListItem {
  final String id;
  final String fullName;
  final String? email;
  final String role;
  final String organizationId;
  final String? scopeAccessLevel;
  final List<String> campusIds;
  final List<String> stageIds;
  final List<String> classIds;
  final List<String> subjectIds;
  final Map<String, dynamic> permissionOverrides;
  final bool isActive;
  final String? photoUrl;
  final DateTime? createdAt;

  const UserListItem({
    required this.id,
    required this.fullName,
    this.email,
    required this.role,
    required this.organizationId,
    this.scopeAccessLevel,
    this.campusIds = const [],
    this.stageIds = const [],
    this.classIds = const [],
    this.subjectIds = const [],
    this.permissionOverrides = const {},
    this.isActive = true,
    this.photoUrl,
    this.createdAt,
  });

  factory UserListItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserListItem(
      id: doc.id,
      fullName: data['fullName'] as String? ?? data['name'] as String? ?? '',
      email: data['email'] as String?,
      role: data['role'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      scopeAccessLevel: data['scopeAccessLevel'] as String?,
      campusIds: List<String>.from(data['campusIds'] ?? []),
      stageIds: List<String>.from(data['stageIds'] ?? []),
      classIds: List<String>.from(data['classIds'] ?? []),
      subjectIds: List<String>.from(data['subjectIds'] ?? []),
      permissionOverrides: Map<String, dynamic>.from(data['permissionOverrides'] ?? {}),
      isActive: data['isActive'] as bool? ?? true,
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Whether this user has any scope assignments.
  bool get hasScopeAssignment =>
      campusIds.isNotEmpty ||
      stageIds.isNotEmpty ||
      classIds.isNotEmpty ||
      subjectIds.isNotEmpty;

  /// Whether this user has any permission overrides.
  bool get hasOverrides => permissionOverrides.isNotEmpty;

  /// Human-readable role display name.
  String get roleDisplayName => KlasivoRole.displayName(role);
}

/// Full RBAC profile for a single user (for User Detail screen).
class UserRbacProfile {
  final UserListItem user;
  final int roleVersion;

  const UserRbacProfile({
    required this.user,
    this.roleVersion = 0,
  });

  factory UserRbacProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserRbacProfile(
      user: UserListItem.fromFirestore(doc),
      roleVersion: data['roleVersion'] as int? ?? 0,
    );
  }
}

/// Node in the scope tree (Campus → Stage → Class hierarchy).
class ScopeTreeNode {
  final String id;
  final String name;
  final String type; // 'campus', 'stage', 'class'
  final String? parentId;
  final List<ScopeTreeNode> children;
  final bool isActive;

  const ScopeTreeNode({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.children = const [],
    this.isActive = true,
  });
}

// ─── Repository ────────────────────────────────────────────────────────────────

class UserManagementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── User Queries ──────────────────────────────────────────────────────

  /// Stream all users in the current organization.
  Stream<List<UserListItem>> getUsersStream(String orgId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserListItem.fromFirestore(doc)).toList());
  }

  /// Stream users filtered by a single role.
  Stream<List<UserListItem>> getUsersByRoleStream(String orgId, String role) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('role', isEqualTo: role)
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserListItem.fromFirestore(doc)).toList());
  }

  /// Stream users filtered by multiple roles (e.g., all staff).
  Stream<List<UserListItem>> getUsersByRolesStream(
      String orgId, List<String> roles) {
    // Firestore `whereIn` supports up to 30 values
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('role', whereIn: roles)
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserListItem.fromFirestore(doc)).toList());
  }

  /// Get a single user's full RBAC profile.
  Future<UserRbacProfile> getUserRbacProfile(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    if (!doc.exists) throw Exception('User not found');
    return UserRbacProfile.fromFirestore(doc);
  }

  /// Stream a single user's RBAC profile (for real-time updates).
  Stream<UserRbacProfile> getUserRbacProfileStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) throw Exception('User not found');
      return UserRbacProfile.fromFirestore(doc);
    });
  }

  // ─── Scope Tree Data ──────────────────────────────────────────────────

  /// Fetch all campuses for the organization.
  Future<List<ScopeTreeNode>> getCampuses(String orgId) async {
    final snapshot = await _firestore
        .collection(AppConstants.campusesCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => ScopeTreeNode(
              id: doc.id,
              name: (doc.data()['name'] as String?) ?? '',
              type: 'campus',
              isActive: doc.data()['isActive'] as bool? ?? true,
            ))
        .toList();
  }

  /// Fetch all stages for the organization.
  Future<List<ScopeTreeNode>> getStages(String orgId) async {
    final snapshot = await _firestore
        .collection(AppConstants.stagesCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isArchived', isEqualTo: false)
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((doc) => ScopeTreeNode(
              id: doc.id,
              name: (doc.data()['name'] as String?) ?? '',
              type: 'stage',
              isActive: !(doc.data()['isArchived'] as bool? ?? false),
            ))
        .toList();
  }

  /// Fetch all classes for the organization, grouped by stageId.
  Future<List<ScopeTreeNode>> getClasses(String orgId) async {
    final snapshot = await _firestore
        .collection(AppConstants.classesCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isArchived', isEqualTo: false)
        .orderBy('name')
        .get();
    return snapshot.docs
        .map((doc) => ScopeTreeNode(
              id: doc.id,
              name: (doc.data()['name'] as String?) ?? '',
              type: 'class',
              parentId: doc.data()['stageId'] as String?,
              isActive: !(doc.data()['isArchived'] as bool? ?? false),
            ))
        .toList();
  }

  /// Build the full scope tree: Campus → Stage → Class.
  /// Since the data model doesn't link campuses to stages directly,
  /// we build: flat campuses + hierarchical stages → classes.
  Future<List<ScopeTreeNode>> buildScopeTree(String orgId) async {
    final campuses = await getCampuses(orgId);
    final stages = await getStages(orgId);
    final classes = await getClasses(orgId);

    // Build stage → class subtree
    final stageNodes = stages.map((stage) {
      final stageClasses =
          classes.where((c) => c.parentId == stage.id).toList();
      return ScopeTreeNode(
        id: stage.id,
        name: stage.name,
        type: 'stage',
        children: stageClasses,
        isActive: stage.isActive,
      );
    }).toList();

    // If campuses exist, nest stages under each campus (flat for now,
    // since the data model doesn't link campus → stage directly).
    // If no campuses, return stages as root nodes.
    if (campuses.isNotEmpty) {
      return campuses.map((campus) {
        return ScopeTreeNode(
          id: campus.id,
          name: campus.name,
          type: 'campus',
          children: stageNodes, // All stages shown under each campus
          isActive: campus.isActive,
        );
      }).toList();
    }

    return stageNodes;
  }

  // ─── Audit History ─────────────────────────────────────────────────────

  /// Stream audit logs for a specific user (targetId = userId).
  Stream<List<Map<String, dynamic>>> getUserAuditStream(
    String orgId,
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection(AppConstants.auditLogsCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('targetId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // ─── Cloud Function Calls ──────────────────────────────────────────────

  /// Assign a new role to a user via Cloud Function.
  Future<void> assignRole({
    required String targetUserId,
    required String newRole,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('assignRole')
          .call({
        'targetUserId': targetUserId,
        'newRole': newRole,
      });
      debugPrint('[UserManagement] Role assigned: $newRole for $targetUserId');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserManagement] assignRole failed: ${e.message}');
      rethrow;
    }
  }

  /// Assign scope to a user via Cloud Function.
  Future<void> assignScope({
    required String targetUserId,
    required Map<String, dynamic> scopeData,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('assignScope')
          .call({
        'targetUserId': targetUserId,
        'scopeData': scopeData,
      });
      debugPrint('[UserManagement] Scope assigned for $targetUserId');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserManagement] assignScope failed: ${e.message}');
      rethrow;
    }
  }

  /// Set permission overrides for a user via Cloud Function.
  Future<void> setPermissionOverrides({
    required String targetUserId,
    required Map<String, bool> overrides,
    String mode = 'merge',
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('setPermissionOverrides')
          .call({
        'targetUserId': targetUserId,
        'overrides': overrides,
        'mode': mode,
      });
      debugPrint(
          '[UserManagement] Overrides set for $targetUserId ($mode mode)');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserManagement] setPermissionOverrides failed: ${e.message}');
      rethrow;
    }
  }

  /// Sync a user's custom claims via Cloud Function.
  Future<void> syncClaims({String? targetUserId}) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('syncClaims').call({
        if (targetUserId != null) 'targetUserId': targetUserId,
      });
      debugPrint('[UserManagement] Claims synced');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[UserManagement] syncClaims failed: ${e.message}');
      rethrow;
    }
  }

  /// Get total user count for the organization.
  Future<int> getUserCount(String orgId, {String? role}) async {
    Query query = _firestore
        .collection(AppConstants.usersCollection)
        .where('organizationId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true);

    if (role != null) {
      query = query.where('role', isEqualTo: role);
    }

    final snapshot = await query.count().get();
    return snapshot.count;
  }
}
