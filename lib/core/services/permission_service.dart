import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PERMISSION SERVICE — Granular Role-Based Access Control
//
// 8 Roles: owner, admin, teacher, student, parent, campus_manager, observer,
//          super_admin
//
// Permission model:
// - Each permission is a string like "exam:create", "class:edit", "org:manage"
// - Role → Permission mapping is defined in code (with Firestore overrides)
// - Resource-level permissions: "class:edit:classId123"
// - Context rules: Time-based, location-based, ownership-based
//
// Evaluation order:
// 1. Check explicit deny (Firestore override)
// 2. Check explicit allow (Firestore override)
// 3. Check role-based defaults (code)
// 4. Deny by default
// ═══════════════════════════════════════════════════════════════════════════════

class PermissionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Singleton accessor for use in non-DI contexts (e.g., route guards) ──
  static final PermissionService instance = PermissionService._();

  PermissionService._();

  // ─── In-memory cache for custom permissions ─────────────────────────────
  static Map<String, List<CustomPermission>> _customPermissions = {};

  // ─── Load custom permissions for an organization ────────────────────────
  Future<void> loadPermissions(String orgId) async {
    try {
      final snapshot = await _db
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.permissionsCollection)
          .get();

      final Map<String, List<CustomPermission>> newCache = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String? ?? doc.id;
        final permission = CustomPermission.fromFirestore(doc.id, data);

        newCache.putIfAbsent(userId, () => []);
        newCache[userId]!.add(permission);
      }

      _customPermissions = newCache;
      debugPrint('[PermissionService] Loaded permissions for ${_customPermissions.length} users');
    } catch (e) {
      debugPrint('[PermissionService] Failed to load permissions: $e');
    }
  }

  // ─── Check if a user has a permission ───────────────────────────────────
  bool hasPermission({
    required String userId,
    required String role,
    required String permission,
    String? resourceId,
    String? resourceType,
    String? orgId,
    Map<String, dynamic>? context,
  }) {
    // 1. Super admin has all permissions
    if (role == AppConstants.roleSuperAdmin) return true;

    // 2. Check explicit deny (Firestore overrides)
    final customPerms = _customPermissions[userId];
    if (customPerms != null) {
      for (final cp in customPerms) {
        if (cp.permission == permission && cp.denied) return false;
      }
    }

    // 3. Check explicit allow (Firestore overrides)
    if (customPerms != null) {
      for (final cp in customPerms) {
        if (cp.permission == permission && cp.allowed) return true;
      }
    }

    // 4. Check role-based defaults
    final rolePermissions = _rolePermissionMap[role];
    if (rolePermissions == null) return false;

    // 4a. Check for wildcard (e.g., "org:*" matches "org:manage")
    if (rolePermissions.contains('${permission.split(':')[0]}:*')) return true;

    // 4b. Check exact permission
    if (rolePermissions.contains(permission)) return true;

    // 4c. Check resource ownership context
    if (resourceId != null && _isOwner(role, userId, resourceId, resourceType, orgId)) {
      // Owners get additional permissions on their own resources
      if (_ownerPermissions(role).contains(permission)) return true;
    }

    // 5. Deny by default
    return false;
  }

  // ─── Get all permissions for a role ─────────────────────────────────────
  List<String> getPermissionsForRole(String role) {
    return _rolePermissionMap[role] ?? [];
  }

  // ─── Check ownership for resource-level permissions ─────────────────────
  bool _isOwner(
    String role,
    String userId,
    String resourceId,
    String? resourceType,
    String? orgId,
  ) {
    // Organization owner is always "owner" of everything in their org
    if (role == AppConstants.roleOwner) return true;
    // Teachers own resources they created — this is handled by resource-level checks
    // in the UI layer (comparing createdBy == userId)
    return false;
  }

  // ─── Additional permissions for resource owners ─────────────────────────
  List<String> _ownerPermissions(String role) {
    return switch (role) {
      'teacher' => [
        Permission.editOwnExam,
        Permission.deleteOwnExam,
        Permission.editOwnQuestion,
        Permission.editOwnAssignment,
        Permission.gradeOwnExam,
      ],
      'student' => [
        Permission.viewOwnResults,
        Permission.viewOwnProgress,
      ],
      'parent' => [
        Permission.viewOwnChildren,
        Permission.viewOwnChildrenProgress,
      ],
      _ => [],
    };
  }

  // ─── Set custom permission (admin only) ─────────────────────────────────
  Future<void> setCustomPermission({
    required String orgId,
    required String userId,
    required String permission,
    required bool allowed,
    required bool denied,
    String? grantedBy,
  }) async {
    await _db
        .collection(AppConstants.organizationsCollection)
        .doc(orgId)
        .collection(AppConstants.permissionsCollection)
        .doc('${userId}_${permission.replaceAll(':', '_')}')
        .set({
      'userId': userId,
      'permission': permission,
      'allowed': allowed,
      'denied': denied,
      'grantedBy': grantedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMISSION CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

class Permission {
  Permission._();

  // ─── Organization ───────────────────────────────────────────────────────
  static const String orgManage = 'org:manage';
  static const String orgView = 'org:view';
  static const String orgSettings = 'org:settings';
  static const String orgDelete = 'org:delete';
  static const String orgBilling = 'org:billing';
  static const String orgInvite = 'org:invite';
  static const String orgAudit = 'org:audit';

  // ─── Users / People ─────────────────────────────────────────────────────
  static const String userManage = 'user:manage';
  static const String userView = 'user:view';
  static const String userCreate = 'user:create';
  static const String userEdit = 'user:edit';
  static const String userDelete = 'user:delete';
  static const String userAssignRole = 'user:assign_role';

  // ─── Academic Structure ─────────────────────────────────────────────────
  static const String stageCreate = 'stage:create';
  static const String stageEdit = 'stage:edit';
  static const String stageDelete = 'stage:delete';
  static const String stageView = 'stage:view';

  static const String classCreate = 'class:create';
  static const String classEdit = 'class:edit';
  static const String classDelete = 'class:delete';
  static const String classView = 'class:view';

  static const String subjectCreate = 'subject:create';
  static const String subjectEdit = 'subject:edit';
  static const String subjectDelete = 'subject:delete';
  static const String subjectView = 'subject:view';

  static const String groupCreate = 'group:create';
  static const String groupEdit = 'group:edit';
  static const String groupDelete = 'group:delete';
  static const String groupView = 'group:view';

  // ─── Exams ──────────────────────────────────────────────────────────────
  static const String examCreate = 'exam:create';
  static const String examEdit = 'exam:edit';
  static const String examDelete = 'exam:delete';
  static const String examView = 'exam:view';
  static const String examPublish = 'exam:publish';
  static const String examTake = 'exam:take';
  static const String examGrade = 'exam:grade';
  static const String editOwnExam = 'exam:edit_own';
  static const String deleteOwnExam = 'exam:delete_own';
  static const String gradeOwnExam = 'exam:grade_own';

  // ─── Questions ──────────────────────────────────────────────────────────
  static const String questionCreate = 'question:create';
  static const String questionEdit = 'question:edit';
  static const String questionDelete = 'question:delete';
  static const String questionView = 'question:view';
  static const String editOwnQuestion = 'question:edit_own';

  // ─── Attendance ─────────────────────────────────────────────────────────
  static const String attendanceMark = 'attendance:mark';
  static const String attendanceView = 'attendance:view';
  static const String attendanceExport = 'attendance:export';

  // ─── Assignments ────────────────────────────────────────────────────────
  static const String assignmentCreate = 'assignment:create';
  static const String assignmentEdit = 'assignment:edit';
  static const String assignmentDelete = 'assignment:delete';
  static const String assignmentView = 'assignment:view';
  static const String assignmentSubmit = 'assignment:submit';
  static const String assignmentGrade = 'assignment:grade';
  static const String editOwnAssignment = 'assignment:edit_own';

  // ─── Results / Grades ───────────────────────────────────────────────────
  static const String resultView = 'result:view';
  static const String resultExport = 'result:export';
  static const String viewOwnResults = 'result:view_own';

  // ─── Analytics ──────────────────────────────────────────────────────────
  static const String analyticsView = 'analytics:view';
  static const String analyticsExport = 'analytics:export';

  // ─── Reports ────────────────────────────────────────────────────────────
  static const String reportGenerate = 'report:generate';
  static const String reportView = 'report:view';
  static const String reportExport = 'report:export';

  // ─── Notifications ──────────────────────────────────────────────────────
  static const String notificationSend = 'notification:send';
  static const String notificationManage = 'notification:manage';
  static const String notificationView = 'notification:view';

  // ─── LMS (v1.7) ─────────────────────────────────────────────────────────
  static const String lessonCreate = 'lesson:create';
  static const String lessonEdit = 'lesson:edit';
  static const String lessonDelete = 'lesson:delete';
  static const String lessonView = 'lesson:view';

  static const String materialUpload = 'material:upload';
  static const String materialDelete = 'material:delete';
  static const String materialView = 'material:view';

  static const String progressView = 'progress:view';
  static const String viewOwnProgress = 'progress:view_own';

  // ─── Parent (v1.7) ──────────────────────────────────────────────────────
  static const String parentLink = 'parent:link';
  static const String parentView = 'parent:view';
  static const String viewOwnChildren = 'parent:view_own_children';
  static const String viewOwnChildrenProgress = 'parent:view_own_children_progress';

  // ─── Integrity ──────────────────────────────────────────────────────────
  static const String integrityView = 'integrity:view';
  static const String integrityManage = 'integrity:manage';

  // ─── ERP (v1.9) ─────────────────────────────────────────────────────────
  static const String feesManage = 'fees:manage';
  static const String feesView = 'fees:view';
  static const String paymentsManage = 'payments:manage';
  static const String paymentsView = 'payments:view';
  static const String payrollManage = 'payroll:manage';
  static const String payrollView = 'payroll:view';
  static const String inventoryManage = 'inventory:manage';
  static const String inventoryView = 'inventory:view';
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE → PERMISSION MAPPING
// ═══════════════════════════════════════════════════════════════════════════════

const Map<String, List<String>> _rolePermissionMap = {
  // ─── Owner — Full access to everything ──────────────────────────────────
  AppConstants.roleOwner: [
    'org:*',
    'user:*',
    'stage:*',
    'class:*',
    'subject:*',
    'group:*',
    'exam:*',
    'question:*',
    'attendance:*',
    'assignment:*',
    'result:*',
    'analytics:*',
    'report:*',
    'notification:*',
    'lesson:*',
    'material:*',
    'progress:*',
    'parent:*',
    'integrity:*',
    'fees:*',
    'payments:*',
    'payroll:*',
    'inventory:*',
  ],

  // ─── Admin — Full access except org deletion and billing ────────────────
  AppConstants.roleAdmin: [
    'org:view',
    'org:settings',
    'org:invite',
    'org:audit',
    'user:*',
    'stage:*',
    'class:*',
    'subject:*',
    'group:*',
    'exam:*',
    'question:*',
    'attendance:*',
    'assignment:*',
    'result:*',
    'analytics:*',
    'report:*',
    'notification:*',
    'lesson:*',
    'material:*',
    'progress:*',
    'parent:*',
    'integrity:*',
    'fees:*',
    'payments:*',
    'payroll:view',
    'inventory:*',
  ],

  // ─── Teacher — Manage own classes, exams, content ───────────────────────
  AppConstants.roleTeacher: [
    'org:view',
    'user:view',
    'stage:view',
    'class:view',
    'class:create',
    'class:edit',
    'subject:view',
    'subject:create',
    'subject:edit',
    'group:view',
    'group:create',
    'group:edit',
    'exam:create',
    'exam:edit',
    'exam:delete',
    'exam:view',
    'exam:publish',
    'exam:grade',
    'exam:edit_own',
    'exam:delete_own',
    'exam:grade_own',
    'question:*',
    'attendance:mark',
    'attendance:view',
    'attendance:export',
    'assignment:create',
    'assignment:edit',
    'assignment:delete',
    'assignment:view',
    'assignment:grade',
    'assignment:edit_own',
    'result:view',
    'result:export',
    'analytics:view',
    'report:generate',
    'report:view',
    'report:export',
    'notification:send',
    'notification:view',
    'lesson:create',
    'lesson:edit',
    'lesson:delete',
    'lesson:view',
    'material:upload',
    'material:delete',
    'material:view',
    'progress:view',
    'parent:view',
    'integrity:view',
  ],

  // ─── Student — Take exams, view own results ─────────────────────────────
  AppConstants.roleStudent: [
    'org:view',
    'class:view',
    'subject:view',
    'exam:view',
    'exam:take',
    'assignment:view',
    'assignment:submit',
    'result:view_own',
    'progress:view_own',
    'notification:view',
    'lesson:view',
    'material:view',
  ],

  // ─── Parent — View children's progress and results ──────────────────────
  AppConstants.roleParent: [
    'org:view',
    'result:view_own',
    'progress:view_own',
    'parent:view_own_children',
    'parent:view_own_children_progress',
    'notification:view',
    'attendance:view',
  ],

  // ─── Campus Manager — Multi-campus management ───────────────────────────
  AppConstants.roleCampusManager: [
    'org:view',
    'org:settings',
    'stage:*',
    'class:*',
    'subject:*',
    'group:*',
    'attendance:*',
    'analytics:view',
    'report:*',
    'notification:*',
    'fees:view',
    'payments:view',
    'inventory:view',
  ],

  // ─── Observer — Read-only access ────────────────────────────────────────
  AppConstants.roleObserver: [
    'org:view',
    'user:view',
    'stage:view',
    'class:view',
    'subject:view',
    'group:view',
    'exam:view',
    'question:view',
    'attendance:view',
    'assignment:view',
    'result:view',
    'analytics:view',
    'report:view',
    'progress:view',
    'lesson:view',
    'material:view',
  ],

  // ─── Super Admin — System-level access (across all orgs) ────────────────
  AppConstants.roleSuperAdmin: [
    '*', // All permissions across all organizations
  ],
};

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOM PERMISSION MODEL (Firestore overrides)
// ═══════════════════════════════════════════════════════════════════════════════

class CustomPermission {
  final String id;
  final String userId;
  final String permission;
  final bool allowed;
  final bool denied;
  final String? grantedBy;
  final DateTime? updatedAt;

  const CustomPermission({
    required this.id,
    required this.userId,
    required this.permission,
    required this.allowed,
    required this.denied,
    this.grantedBy,
    this.updatedAt,
  });

  factory CustomPermission.fromFirestore(String id, Map<String, dynamic> data) {
    return CustomPermission(
      id: id,
      userId: data['userId'] as String? ?? '',
      permission: data['permission'] as String? ?? '',
      allowed: data['allowed'] as bool? ?? false,
      denied: data['denied'] as bool? ?? false,
      grantedBy: data['grantedBy'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
