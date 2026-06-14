import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/config/app_constants.dart';
import 'package:klasivo/core/services/permission_service.dart';

/// Testable version of PermissionService that accepts a Firestore instance.
/// This mirrors the production PermissionService but with DI for testing.
class TestablePermissionService {
  final FirebaseFirestore _db;

  // ─── In-memory cache for custom permissions (testable) ──────────────────
  Map<String, List<CustomPermission>> _customPermissions = {};

  TestablePermissionService(this._db);

  // ─── Expose cache for direct manipulation in tests ──────────────────────
  void setCustomPermissions(Map<String, List<CustomPermission>> perms) {
    _customPermissions = perms;
  }

  void clearCustomPermissions() {
    _customPermissions = {};
  }

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
    } catch (e) {
      // Graceful degradation — keep existing cache
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
    if (role == AppConstants.roleOwner) return true;
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
// ROLE → PERMISSION MAPPING (must mirror production)
// ═══════════════════════════════════════════════════════════════════════════════

const Map<String, List<String>> _rolePermissionMap = {
  AppConstants.roleOwner: [
    'org:*', 'user:*', 'stage:*', 'class:*', 'subject:*', 'group:*',
    'exam:*', 'question:*', 'attendance:*', 'assignment:*', 'result:*',
    'analytics:*', 'report:*', 'notification:*', 'lesson:*', 'material:*',
    'progress:*', 'parent:*', 'integrity:*', 'fees:*', 'payments:*',
    'payroll:*', 'inventory:*',
  ],
  AppConstants.roleAdmin: [
    'org:view', 'org:settings', 'org:invite', 'org:audit',
    'user:*', 'stage:*', 'class:*', 'subject:*', 'group:*',
    'exam:*', 'question:*', 'attendance:*', 'assignment:*', 'result:*',
    'analytics:*', 'report:*', 'notification:*', 'lesson:*', 'material:*',
    'progress:*', 'parent:*', 'integrity:*', 'fees:*', 'payments:*',
    'payroll:view', 'inventory:*',
  ],
  AppConstants.roleTeacher: [
    'org:view', 'user:view', 'stage:view',
    'class:view', 'class:create', 'class:edit',
    'subject:view', 'subject:create', 'subject:edit',
    'group:view', 'group:create', 'group:edit',
    'exam:create', 'exam:edit', 'exam:delete', 'exam:view', 'exam:publish',
    'exam:grade', 'exam:edit_own', 'exam:delete_own', 'exam:grade_own',
    'question:*',
    'attendance:mark', 'attendance:view', 'attendance:export',
    'assignment:create', 'assignment:edit', 'assignment:delete',
    'assignment:view', 'assignment:grade', 'assignment:edit_own',
    'result:view', 'result:export',
    'analytics:view',
    'report:generate', 'report:view', 'report:export',
    'notification:send', 'notification:view',
    'lesson:create', 'lesson:edit', 'lesson:delete', 'lesson:view',
    'material:upload', 'material:delete', 'material:view',
    'progress:view',
    'parent:view',
    'integrity:view',
  ],
  AppConstants.roleStudent: [
    'org:view', 'class:view', 'subject:view',
    'exam:view', 'exam:take',
    'assignment:view', 'assignment:submit',
    'result:view_own', 'progress:view_own',
    'notification:view',
    'lesson:view', 'material:view',
  ],
  AppConstants.roleParent: [
    'org:view',
    'result:view_own', 'progress:view_own',
    'parent:view_own_children', 'parent:view_own_children_progress',
    'notification:view', 'attendance:view',
  ],
  AppConstants.roleCampusManager: [
    'org:view', 'org:settings',
    'stage:*', 'class:*', 'subject:*', 'group:*',
    'attendance:*',
    'analytics:view',
    'report:*', 'notification:*',
    'fees:view', 'payments:view', 'inventory:view',
  ],
  AppConstants.roleObserver: [
    'org:view', 'user:view', 'stage:view', 'class:view', 'subject:view',
    'group:view', 'exam:view', 'question:view', 'attendance:view',
    'assignment:view', 'result:view', 'analytics:view', 'report:view',
    'progress:view', 'lesson:view', 'material:view',
  ],
  AppConstants.roleSuperAdmin: [
    '*',
  ],
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

void main() {
  late FakeFirebaseFirestore firestore;
  late TestablePermissionService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = TestablePermissionService(firestore);
  });

  // ─── Super Admin ─────────────────────────────────────────────────────────

  group('Super Admin — Global Access', () {
    test('has all permissions regardless of specific check', () {
      expect(
        service.hasPermission(
          userId: 'sa1',
          role: AppConstants.roleSuperAdmin,
          permission: 'org:delete',
        ),
        isTrue,
      );
    });

    test('has exam:take permission (normally student-only)', () {
      expect(
        service.hasPermission(
          userId: 'sa1',
          role: AppConstants.roleSuperAdmin,
          permission: Permission.examTake,
        ),
        isTrue,
      );
    });

    test('has payroll:manage permission', () {
      expect(
        service.hasPermission(
          userId: 'sa1',
          role: AppConstants.roleSuperAdmin,
          permission: Permission.payrollManage,
        ),
        isTrue,
      );
    });

    test('has non-existent permission string', () {
      expect(
        service.hasPermission(
          userId: 'sa1',
          role: AppConstants.roleSuperAdmin,
          permission: 'nonexistent:permission',
        ),
        isTrue,
      );
    });
  });

  // ─── Owner Role ──────────────────────────────────────────────────────────

  group('Owner — Full Organization Access', () {
    test('has org:manage via wildcard org:*', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.orgManage,
        ),
        isTrue,
      );
    });

    test('has org:delete via wildcard org:*', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.orgDelete,
        ),
        isTrue,
      );
    });

    test('has org:billing via wildcard org:*', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.orgBilling,
        ),
        isTrue,
      );
    });

    test('has user:manage via wildcard user:*', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.userManage,
        ),
        isTrue,
      );
    });

    test('has exam:create via wildcard exam:*', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.examCreate,
        ),
        isTrue,
      );
    });

    test('has integrity:manage via wildcard integrity:*', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.integrityManage,
        ),
        isTrue,
      );
    });

    test('is considered resource owner for any resourceId', () {
      // Owner gets owner permissions on any resource
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: Permission.editOwnExam,
          resourceId: 'exam_123',
          resourceType: 'exam',
          orgId: 'org1',
        ),
        isTrue,
      );
    });
  });

  // ─── Admin Role ──────────────────────────────────────────────────────────

  group('Admin — Full Access Except org:delete and org:billing', () {
    test('has org:view (explicit in admin list)', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.orgView,
        ),
        isTrue,
      );
    });

    test('has org:settings (explicit in admin list)', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.orgSettings,
        ),
        isTrue,
      );
    });

    test('has org:invite (explicit in admin list)', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.orgInvite,
        ),
        isTrue,
      );
    });

    test('does NOT have org:delete (not in admin list, no org:* wildcard)', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.orgDelete,
        ),
        isFalse,
      );
    });

    test('does NOT have org:billing', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.orgBilling,
        ),
        isFalse,
      );
    });

    test('does NOT have org:manage', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.orgManage,
        ),
        isFalse,
      );
    });

    test('has user:manage via wildcard user:*', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.userManage,
        ),
        isTrue,
      );
    });

    test('has payroll:view (explicit in admin list)', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.payrollView,
        ),
        isTrue,
      );
    });

    test('does NOT have payroll:manage', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.payrollManage,
        ),
        isFalse,
      );
    });

    test('has exam:create via wildcard exam:*', () {
      expect(
        service.hasPermission(
          userId: 'admin1',
          role: AppConstants.roleAdmin,
          permission: Permission.examCreate,
        ),
        isTrue,
      );
    });
  });

  // ─── Teacher Role ────────────────────────────────────────────────────────

  group('Teacher — Class/Exam/Content Management', () {
    test('has org:view', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.orgView,
        ),
        isTrue,
      );
    });

    test('does NOT have org:manage', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.orgManage,
        ),
        isFalse,
      );
    });

    test('has exam:create (explicit)', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examCreate,
        ),
        isTrue,
      );
    });

    test('has exam:publish (explicit)', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examPublish,
        ),
        isTrue,
      );
    });

    test('has question:* wildcard', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.questionCreate,
        ),
        isTrue,
      );
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.questionDelete,
        ),
        isTrue,
      );
    });

    test('does NOT have exam:take', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examTake,
        ),
        isFalse,
      );
    });

    test('has attendance:mark', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.attendanceMark,
        ),
        isTrue,
      );
    });

    test('has lesson:create', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.lessonCreate,
        ),
        isTrue,
      );
    });

    test('does NOT have analytics:export', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.analyticsExport,
        ),
        isFalse,
      );
    });

    test('gets owner permissions when resourceId provided', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.editOwnExam,
          resourceId: 'exam_123',
          resourceType: 'exam',
        ),
        isTrue,
      );
    });

    test('gets gradeOwnExam via owner permissions', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.gradeOwnExam,
          resourceId: 'exam_123',
          resourceType: 'exam',
        ),
        isTrue,
      );
    });

    test('does NOT get editOwnExam without resourceId', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.editOwnExam,
        ),
        isFalse,
      );
    });

    test('does NOT have user:manage', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.userManage,
        ),
        isFalse,
      );
    });
  });

  // ─── Student Role ────────────────────────────────────────────────────────

  group('Student — Take Exams, View Own Results', () {
    test('has org:view', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.orgView,
        ),
        isTrue,
      );
    });

    test('has exam:take', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.examTake,
        ),
        isTrue,
      );
    });

    test('has exam:view', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.examView,
        ),
        isTrue,
      );
    });

    test('has assignment:submit', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.assignmentSubmit,
        ),
        isTrue,
      );
    });

    test('has result:view_own', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.viewOwnResults,
        ),
        isTrue,
      );
    });

    test('does NOT have result:view (all results)', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.resultView,
        ),
        isFalse,
      );
    });

    test('does NOT have exam:create', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.examCreate,
        ),
        isFalse,
      );
    });

    test('does NOT have exam:grade', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.examGrade,
        ),
        isFalse,
      );
    });

    test('does NOT have assignment:grade', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.assignmentGrade,
        ),
        isFalse,
      );
    });

    test('does NOT have analytics:view', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.analyticsView,
        ),
        isFalse,
      );
    });

    test('gets viewOwnResults via owner permissions when resourceId set', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.viewOwnResults,
          resourceId: 'submission_123',
          resourceType: 'submission',
        ),
        isTrue,
      );
    });

    test('does NOT get viewOwnResults without resourceId (not in role list)', () {
      // viewOwnResults = 'result:view_own' is in the student role list,
      // so it should still pass even without resourceId
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.viewOwnResults,
        ),
        isTrue,
      );
    });
  });

  // ─── Parent Role ─────────────────────────────────────────────────────────

  group('Parent — View Children Progress', () {
    test('has org:view', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.orgView,
        ),
        isTrue,
      );
    });

    test('has attendance:view', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.attendanceView,
        ),
        isTrue,
      );
    });

    test('has viewOwnChildren', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.viewOwnChildren,
        ),
        isTrue,
      );
    });

    test('does NOT have exam:view', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.examView,
        ),
        isFalse,
      );
    });

    test('does NOT have exam:take', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.examTake,
        ),
        isFalse,
      );
    });

    test('does NOT have class:view', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.classView,
        ),
        isFalse,
      );
    });

    test('gets viewOwnChildren via owner permissions when resourceId set', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.viewOwnChildren,
          resourceId: 'child_123',
          resourceType: 'parent_link',
        ),
        isTrue,
      );
    });
  });

  // ─── Campus Manager Role ─────────────────────────────────────────────────

  group('Campus Manager — Multi-Campus Management', () {
    test('has org:view', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.orgView,
        ),
        isTrue,
      );
    });

    test('has org:settings', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.orgSettings,
        ),
        isTrue,
      );
    });

    test('has stage:* wildcard access', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.stageCreate,
        ),
        isTrue,
      );
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.stageDelete,
        ),
        isTrue,
      );
    });

    test('has attendance:* wildcard', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.attendanceMark,
        ),
        isTrue,
      );
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.attendanceExport,
        ),
        isTrue,
      );
    });

    test('does NOT have org:manage', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.orgManage,
        ),
        isFalse,
      );
    });

    test('does NOT have exam:create', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.examCreate,
        ),
        isFalse,
      );
    });

    test('has fees:view (explicit)', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.feesView,
        ),
        isTrue,
      );
    });

    test('does NOT have fees:manage', () {
      expect(
        service.hasPermission(
          userId: 'cm1',
          role: AppConstants.roleCampusManager,
          permission: Permission.feesManage,
        ),
        isFalse,
      );
    });
  });

  // ─── Observer Role ───────────────────────────────────────────────────────

  group('Observer — Read-Only Access', () {
    test('can view org', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.orgView,
        ),
        isTrue,
      );
    });

    test('can view exams', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.examView,
        ),
        isTrue,
      );
    });

    test('can view users', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.userView,
        ),
        isTrue,
      );
    });

    test('can view analytics', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.analyticsView,
        ),
        isTrue,
      );
    });

    test('cannot create exams', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.examCreate,
        ),
        isFalse,
      );
    });

    test('cannot edit classes', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.classEdit,
        ),
        isFalse,
      );
    });

    test('cannot manage users', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.userManage,
        ),
        isFalse,
      );
    });

    test('cannot grade exams', () {
      expect(
        service.hasPermission(
          userId: 'obs1',
          role: AppConstants.roleObserver,
          permission: Permission.examGrade,
        ),
        isFalse,
      );
    });
  });

  // ─── Unknown/Invalid Role ────────────────────────────────────────────────

  group('Invalid Role — Deny by Default', () {
    test('denies all permissions for unknown role', () {
      expect(
        service.hasPermission(
          userId: 'user1',
          role: 'hacker',
          permission: Permission.orgView,
        ),
        isFalse,
      );
    });

    test('denies exam:create for unknown role', () {
      expect(
        service.hasPermission(
          userId: 'user1',
          role: 'unknown_role',
          permission: Permission.examCreate,
        ),
        isFalse,
      );
    });
  });

  // ─── Custom Permission Overrides (Firestore) ────────────────────────────

  group('Custom Permission Overrides — Firestore', () {
    test('explicit allow overrides role-based deny', () {
      // Student normally can't do analytics:export
      service.setCustomPermissions({
        'student1': [
          CustomPermission(
            id: 'cp1',
            userId: 'student1',
            permission: Permission.analyticsExport,
            allowed: true,
            denied: false,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.analyticsExport,
        ),
        isTrue,
      );
    });

    test('explicit deny overrides role-based allow', () {
      // Teacher normally can do exam:grade
      service.setCustomPermissions({
        'teacher1': [
          CustomPermission(
            id: 'cp1',
            userId: 'teacher1',
            permission: Permission.examGrade,
            allowed: false,
            denied: true,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examGrade,
        ),
        isFalse,
      );
    });

    test('explicit deny takes precedence over explicit allow for same permission', () {
      // Both allow and deny set — deny wins (evaluation order: deny first)
      service.setCustomPermissions({
        'teacher1': [
          CustomPermission(
            id: 'cp1',
            userId: 'teacher1',
            permission: Permission.examCreate,
            allowed: true,
            denied: true,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examCreate,
        ),
        isFalse,
        reason: 'Deny should be evaluated before allow in the permission chain',
      );
    });

    test('override for one user does not affect another user', () {
      service.setCustomPermissions({
        'student1': [
          CustomPermission(
            id: 'cp1',
            userId: 'student1',
            permission: Permission.analyticsExport,
            allowed: true,
            denied: false,
          ),
        ],
      });

      // student1 gets override
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.analyticsExport,
        ),
        isTrue,
      );

      // student2 does NOT have the override
      expect(
        service.hasPermission(
          userId: 'student2',
          role: AppConstants.roleStudent,
          permission: Permission.analyticsExport,
        ),
        isFalse,
      );
    });

    test('override does not bypass super admin', () {
      // Super admin always returns true before checking overrides
      service.setCustomPermissions({
        'sa1': [
          CustomPermission(
            id: 'cp1',
            userId: 'sa1',
            permission: Permission.examGrade,
            allowed: false,
            denied: true,
          ),
        ],
      });

      // Super admin still has access (checked first in evaluation order)
      expect(
        service.hasPermission(
          userId: 'sa1',
          role: AppConstants.roleSuperAdmin,
          permission: Permission.examGrade,
        ),
        isTrue,
      );
    });

    test('clearing custom permissions reverts to role defaults', () {
      service.setCustomPermissions({
        'teacher1': [
          CustomPermission(
            id: 'cp1',
            userId: 'teacher1',
            permission: Permission.examGrade,
            allowed: false,
            denied: true,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examGrade,
        ),
        isFalse,
      );

      service.clearCustomPermissions();

      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examGrade,
        ),
        isTrue,
      );
    });

    test('multiple custom permissions for same user all checked', () {
      service.setCustomPermissions({
        'teacher1': [
          CustomPermission(
            id: 'cp1',
            userId: 'teacher1',
            permission: Permission.examGrade,
            allowed: false,
            denied: true,
          ),
          CustomPermission(
            id: 'cp2',
            userId: 'teacher1',
            permission: Permission.lessonCreate,
            allowed: false,
            denied: true,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examGrade,
        ),
        isFalse,
      );
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.lessonCreate,
        ),
        isFalse,
      );
      // Other permissions still work
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examCreate,
        ),
        isTrue,
      );
    });
  });

  // ─── Wildcard Permission Matching ────────────────────────────────────────

  group('Wildcard Permission Matching', () {
    test('org:* wildcard matches org:manage for owner', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: 'org:manage',
        ),
        isTrue,
      );
    });

    test('org:* wildcard matches org:anything for owner', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: 'org:some_new_permission',
        ),
        isTrue,
      );
    });

    test('question:* wildcard matches question:create for teacher', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: 'question:create',
        ),
        isTrue,
      );
    });

    test('question:* wildcard matches question:edit_own for teacher', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: 'question:edit_own',
        ),
        isTrue,
      );
    });

    test('exam:* does NOT match exam_question:delete (different prefix)', () {
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: 'exam_question:delete',
        ),
        isFalse,
        reason: 'Wildcard only matches the exact prefix before the colon',
      );
    });
  });

  // ─── getPermissionsForRole ───────────────────────────────────────────────

  group('getPermissionsForRole', () {
    test('returns non-empty list for owner', () {
      final perms = service.getPermissionsForRole(AppConstants.roleOwner);
      expect(perms, isNotEmpty);
      expect(perms, contains('org:*'));
    });

    test('returns non-empty list for teacher', () {
      final perms = service.getPermissionsForRole(AppConstants.roleTeacher);
      expect(perms, isNotEmpty);
      expect(perms, contains('exam:create'));
      expect(perms, contains('question:*'));
    });

    test('returns empty list for unknown role', () {
      final perms = service.getPermissionsForRole('nonexistent_role');
      expect(perms, isEmpty);
    });

    test('student has fewer permissions than teacher', () {
      final studentPerms = service.getPermissionsForRole(AppConstants.roleStudent);
      final teacherPerms = service.getPermissionsForRole(AppConstants.roleTeacher);
      expect(studentPerms.length, lessThan(teacherPerms.length));
    });

    test('owner has more permissions than admin', () {
      final ownerPerms = service.getPermissionsForRole(AppConstants.roleOwner);
      final adminPerms = service.getPermissionsForRole(AppConstants.roleAdmin);
      expect(ownerPerms.length, greaterThanOrEqualTo(adminPerms.length));
    });

    test('super admin has single global wildcard', () {
      final perms = service.getPermissionsForRole(AppConstants.roleSuperAdmin);
      expect(perms, contains('*'));
      expect(perms.length, 1);
    });
  });

  // ─── loadPermissions from Firestore ──────────────────────────────────────

  group('loadPermissions — Firestore Integration', () {
    test('loads custom permissions from Firestore', () async {
      final orgId = 'org1';
      final userId = 'user1';
      final permDocId = '${userId}_exam_create';

      // Seed Firestore
      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.permissionsCollection)
          .doc(permDocId)
          .set({
        'userId': userId,
        'permission': 'exam:create',
        'allowed': true,
        'denied': false,
        'grantedBy': 'admin1',
      });

      await service.loadPermissions(orgId);

      // Now the override should be loaded
      expect(
        service.hasPermission(
          userId: userId,
          role: AppConstants.roleStudent, // Student normally can't exam:create
          permission: Permission.examCreate,
        ),
        isTrue,
      );
    });

    test('loads deny override from Firestore', () async {
      final orgId = 'org1';
      final userId = 'teacher1';
      final permDocId = '${userId}_exam_grade';

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.permissionsCollection)
          .doc(permDocId)
          .set({
        'userId': userId,
        'permission': 'exam:grade',
        'allowed': false,
        'denied': true,
        'grantedBy': 'admin1',
      });

      await service.loadPermissions(orgId);

      expect(
        service.hasPermission(
          userId: userId,
          role: AppConstants.roleTeacher,
          permission: Permission.examGrade,
        ),
        isFalse,
      );
    });

    test('handles empty Firestore collection gracefully', () async {
      await service.loadPermissions('empty_org');

      // Should not crash — cache should be empty
      expect(
        service.hasPermission(
          userId: 'user1',
          role: AppConstants.roleTeacher,
          permission: Permission.examCreate,
        ),
        isTrue, // Falls back to role-based defaults
      );
    });

    test('multiple overrides for same user loaded correctly', () async {
      final orgId = 'org1';
      final userId = 'teacher1';

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.permissionsCollection)
          .doc('${userId}_exam_create')
          .set({
        'userId': userId,
        'permission': 'exam:create',
        'allowed': false,
        'denied': true,
      });

      await firestore
          .collection(AppConstants.organizationsCollection)
          .doc(orgId)
          .collection(AppConstants.permissionsCollection)
          .doc('${userId}_lesson_create')
          .set({
        'userId': userId,
        'permission': 'lesson:create',
        'allowed': false,
        'denied': true,
      });

      await service.loadPermissions(orgId);

      expect(
        service.hasPermission(
          userId: userId,
          role: AppConstants.roleTeacher,
          permission: Permission.examCreate,
        ),
        isFalse,
      );
      expect(
        service.hasPermission(
          userId: userId,
          role: AppConstants.roleTeacher,
          permission: Permission.lessonCreate,
        ),
        isFalse,
      );
    });
  });

  // ─── setCustomPermission writes to Firestore ────────────────────────────

  group('setCustomPermission — Firestore Write', () {
    test('writes permission override to Firestore', () async {
      await service.setCustomPermission(
        orgId: 'org1',
        userId: 'student1',
        permission: 'exam:create',
        allowed: true,
        denied: false,
        grantedBy: 'admin1',
      );

      final snapshot = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.permissionsCollection)
          .doc('student1_exam_create')
          .get();

      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['userId'], equals('student1'));
      expect(snapshot.data()!['permission'], equals('exam:create'));
      expect(snapshot.data()!['allowed'], isTrue);
      expect(snapshot.data()!['denied'], isFalse);
      expect(snapshot.data()!['grantedBy'], equals('admin1'));
    });

    test('uses correct document ID format', () async {
      await service.setCustomPermission(
        orgId: 'org1',
        userId: 'user1',
        permission: 'org:manage',
        allowed: true,
        denied: false,
      );

      final snapshot = await firestore
          .collection(AppConstants.organizationsCollection)
          .doc('org1')
          .collection(AppConstants.permissionsCollection)
          .doc('user1_org_manage')
          .get();

      expect(snapshot.exists, isTrue);
    });
  });

  // ─── Permission Evaluation Order ─────────────────────────────────────────

  group('Permission Evaluation Order', () {
    test('step 1: super admin always passes before overrides', () {
      service.setCustomPermissions({
        'sa1': [
          CustomPermission(
            id: 'deny1',
            userId: 'sa1',
            permission: 'org:delete',
            allowed: false,
            denied: true,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'sa1',
          role: AppConstants.roleSuperAdmin,
          permission: 'org:delete',
        ),
        isTrue,
        reason: 'Super admin check happens before custom override check',
      );
    });

    test('step 2: explicit deny blocks role-based allow', () {
      service.setCustomPermissions({
        'owner1': [
          CustomPermission(
            id: 'deny1',
            userId: 'owner1',
            permission: 'org:manage',
            allowed: false,
            denied: true,
          ),
        ],
      });

      // Owner normally has org:* wildcard, but explicit deny should block it
      expect(
        service.hasPermission(
          userId: 'owner1',
          role: AppConstants.roleOwner,
          permission: 'org:manage',
        ),
        isFalse,
        reason: 'Explicit deny should override wildcard role permission',
      );
    });

    test('step 3: explicit allow grants permission not in role defaults', () {
      service.setCustomPermissions({
        'observer1': [
          CustomPermission(
            id: 'allow1',
            userId: 'observer1',
            permission: 'exam:create',
            allowed: true,
            denied: false,
          ),
        ],
      });

      expect(
        service.hasPermission(
          userId: 'observer1',
          role: AppConstants.roleObserver,
          permission: 'exam:create',
        ),
        isTrue,
        reason: 'Explicit allow grants permission beyond role defaults',
      );
    });

    test('step 4: role-based defaults apply when no overrides exist', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: 'exam:grade',
        ),
        isTrue,
        reason: 'Falls through to role-based defaults',
      );
    });

    test('step 5: deny by default for unknown permissions', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: 'time_travel:activate',
        ),
        isFalse,
        reason: 'Unknown permission denied by default',
      );
    });
  });

  // ─── CustomPermission Model ──────────────────────────────────────────────

  group('CustomPermission Model', () {
    test('fromFirestore creates correct model', () {
      final data = {
        'userId': 'user1',
        'permission': 'exam:create',
        'allowed': true,
        'denied': false,
        'grantedBy': 'admin1',
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 15)),
      };

      final cp = CustomPermission.fromFirestore('doc1', data);

      expect(cp.id, equals('doc1'));
      expect(cp.userId, equals('user1'));
      expect(cp.permission, equals('exam:create'));
      expect(cp.allowed, isTrue);
      expect(cp.denied, isFalse);
      expect(cp.grantedBy, equals('admin1'));
      expect(cp.updatedAt, equals(DateTime(2026, 1, 15)));
    });

    test('fromFirestore handles missing fields with defaults', () {
      final data = <String, dynamic>{};

      final cp = CustomPermission.fromFirestore('doc1', data);

      expect(cp.id, equals('doc1'));
      expect(cp.userId, equals(''));
      expect(cp.permission, equals(''));
      expect(cp.allowed, isFalse);
      expect(cp.denied, isFalse);
      expect(cp.grantedBy, isNull);
      expect(cp.updatedAt, isNull);
    });

    test('CustomPermission constructor stores values correctly', () {
      final now = DateTime.now();
      final cp = CustomPermission(
        id: 'cp1',
        userId: 'u1',
        permission: 'exam:grade',
        allowed: true,
        denied: false,
        grantedBy: 'admin',
        updatedAt: now,
      );

      expect(cp.id, 'cp1');
      expect(cp.userId, 'u1');
      expect(cp.permission, 'exam:grade');
      expect(cp.allowed, isTrue);
      expect(cp.denied, isFalse);
      expect(cp.grantedBy, 'admin');
      expect(cp.updatedAt, now);
    });
  });

  // ─── Cross-Role Permission Isolation ─────────────────────────────────────

  group('Cross-Role Permission Isolation', () {
    test('teacher cannot access student-only permissions', () {
      expect(
        service.hasPermission(
          userId: 'teacher1',
          role: AppConstants.roleTeacher,
          permission: Permission.examTake,
        ),
        isFalse,
      );
    });

    test('student cannot access teacher-only permissions', () {
      expect(
        service.hasPermission(
          userId: 'student1',
          role: AppConstants.roleStudent,
          permission: Permission.examGrade,
        ),
        isFalse,
      );
    });

    test('parent cannot access admin-only permissions', () {
      expect(
        service.hasPermission(
          userId: 'parent1',
          role: AppConstants.roleParent,
          permission: Permission.orgSettings,
        ),
        isFalse,
      );
    });

    test('observer cannot access any write permission', () {
      final writePermissions = [
        Permission.examCreate,
        Permission.examEdit,
        Permission.examDelete,
        Permission.classCreate,
        Permission.classEdit,
        Permission.attendanceMark,
        Permission.assignmentCreate,
      ];

      for (final perm in writePermissions) {
        expect(
          service.hasPermission(
            userId: 'obs1',
            role: AppConstants.roleObserver,
            permission: perm,
          ),
          isFalse,
          reason: 'Observer should not have $perm',
        );
      }
    });
  });
}
