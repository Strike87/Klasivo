// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Role Hierarchy & Role Resolver Tests
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/rbac/rbac.dart';

void main() {
  group('RoleHierarchy', () {
    // ─── Descendant Tests ────────────────────────────────────────────────

    test('super_admin has owner as descendant', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.superAdmin);
      expect(descendants, contains(KlasivoRole.owner));
    });

    test('owner has admin as descendant', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.owner);
      expect(descendants, contains(KlasivoRole.admin));
    });

    test('admin has campus_manager, stage_manager, and observer as descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.admin);
      expect(descendants, contains(KlasivoRole.campusManager));
      expect(descendants, contains(KlasivoRole.stageManager));
      expect(descendants, contains(KlasivoRole.observer));
    });

    test('stage_manager has academic_supervisor, teacher, assistant_teacher as descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.stageManager);
      expect(descendants, contains(KlasivoRole.academicSupervisor));
      expect(descendants, contains(KlasivoRole.teacher));
      expect(descendants, contains(KlasivoRole.assistantTeacher));
    });

    test('assistant_teacher has no descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.assistantTeacher);
      expect(descendants, isEmpty);
    });

    test('observer has no descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.observer);
      expect(descendants, isEmpty);
    });

    test('student has no descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.student);
      expect(descendants, isEmpty);
    });

    test('parent has no descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.parent);
      expect(descendants, isEmpty);
    });

    test('super_admin has all management roles as descendants', () {
      final descendants = RoleHierarchy.getDescendants(KlasivoRole.superAdmin);
      expect(descendants, containsAll([
        KlasivoRole.owner,
        KlasivoRole.admin,
        KlasivoRole.campusManager,
        KlasivoRole.stageManager,
        KlasivoRole.academicSupervisor,
        KlasivoRole.teacher,
        KlasivoRole.assistantTeacher,
        KlasivoRole.observer,
      ]));
    });

    // ─── Ancestor Tests ──────────────────────────────────────────────────

    test('assistant_teacher has teacher, academic_supervisor, stage_manager, admin, owner, super_admin as ancestors', () {
      final ancestors = RoleHierarchy.getAncestors(KlasivoRole.assistantTeacher);
      expect(ancestors, containsAll([
        KlasivoRole.teacher,
        KlasivoRole.academicSupervisor,
        KlasivoRole.stageManager,
        KlasivoRole.admin,
        KlasivoRole.owner,
        KlasivoRole.superAdmin,
      ]));
    });

    test('super_admin has no ancestors', () {
      final ancestors = RoleHierarchy.getAncestors(KlasivoRole.superAdmin);
      expect(ancestors, isEmpty);
    });

    test('campus_manager has admin, owner, super_admin as ancestors', () {
      final ancestors = RoleHierarchy.getAncestors(KlasivoRole.campusManager);
      expect(ancestors, containsAll([
        KlasivoRole.admin,
        KlasivoRole.owner,
        KlasivoRole.superAdmin,
      ]));
    });

    test('student has no ancestors', () {
      final ancestors = RoleHierarchy.getAncestors(KlasivoRole.student);
      expect(ancestors, isEmpty);
    });

    // ─── Inherits From Tests ─────────────────────────────────────────────

    test('owner inherits from admin', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.owner, KlasivoRole.admin), isTrue);
    });

    test('admin inherits from campus_manager', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.admin, KlasivoRole.campusManager), isTrue);
    });

    test('admin inherits from stage_manager', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.admin, KlasivoRole.stageManager), isTrue);
    });

    test('admin inherits from observer', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.admin, KlasivoRole.observer), isTrue);
    });

    test('teacher inherits from assistant_teacher', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.teacher, KlasivoRole.assistantTeacher), isTrue);
    });

    test('assistant_teacher does NOT inherit from teacher', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.assistantTeacher, KlasivoRole.teacher), isFalse);
    });

    test('student does NOT inherit from teacher', () {
      expect(RoleHierarchy.inheritsFrom(KlasivoRole.student, KlasivoRole.teacher), isFalse);
    });

    test('role inherits from itself', () {
      for (final role in KlasivoRole.allRoles) {
        expect(RoleHierarchy.inheritsFrom(role, role), isTrue, reason: '$role should inherit from itself');
      }
    });

    // ─── Parent Tests ────────────────────────────────────────────────────

    test('parent of assistant_teacher is teacher', () {
      expect(RoleHierarchy.getParent(KlasivoRole.assistantTeacher), KlasivoRole.teacher);
    });

    test('parent of teacher is academic_supervisor', () {
      expect(RoleHierarchy.getParent(KlasivoRole.teacher), KlasivoRole.academicSupervisor);
    });

    test('parent of super_admin is null', () {
      expect(RoleHierarchy.getParent(KlasivoRole.superAdmin), isNull);
    });

    test('parent of student is null', () {
      expect(RoleHierarchy.getParent(KlasivoRole.student), isNull);
    });

    // ─── Depth Tests ─────────────────────────────────────────────────────

    test('super_admin depth is 0', () {
      expect(RoleHierarchy.depth(KlasivoRole.superAdmin), 0);
    });

    test('owner depth is 1', () {
      expect(RoleHierarchy.depth(KlasivoRole.owner), 1);
    });

    test('assistant_teacher has deepest depth', () {
      expect(RoleHierarchy.depth(KlasivoRole.assistantTeacher), 5);
    });
  });

  group('RoleResolver', () {
    setUp(() {
      RoleResolver.clearCache();
    });

    // ─── Delta Permissions ───────────────────────────────────────────────

    test('assistant_teacher delta contains only support permissions', () {
      final delta = RoleResolver.getDeltaPermissions(KlasivoRole.assistantTeacher);
      expect(delta, contains(Permission.attendanceMark));
      expect(delta, contains(Permission.attendanceView));
      expect(delta, contains(Permission.assignmentView));
      expect(delta, contains(Permission.assignmentGrade));
      expect(delta, contains(Permission.examView));
      expect(delta, contains(Permission.examGrade));
      expect(delta, contains(Permission.studentView));
      expect(delta, contains(Permission.messageSend));
      expect(delta, contains(Permission.messageReceive));
      // Cannot create/publish/delete
      expect(delta, isNot(contains(Permission.examCreate)));
      expect(delta, isNot(contains(Permission.examPublish)));
      expect(delta, isNot(contains(Permission.examDelete)));
    });

    test('teacher delta contains academic authority', () {
      final delta = RoleResolver.getDeltaPermissions(KlasivoRole.teacher);
      expect(delta, contains(Permission.examCreate));
      expect(delta, contains(Permission.examPublish));
      expect(delta, contains(Permission.examDelete));
      expect(delta, contains(Permission.assignmentCreate));
      expect(delta, contains(Permission.assignmentPublish));
      expect(delta, contains(Permission.attendanceEdit));
      expect(delta, contains(Permission.analyticsView));
    });

    test('observer delta contains only view permissions', () {
      final delta = RoleResolver.getDeltaPermissions(KlasivoRole.observer);
      // All permissions should be :view or read-only
      for (final perm in delta) {
        if (perm != Permission.orgView) {
          expect(perm.contains(':view') || perm == Permission.notificationView,
              isTrue,
              reason: '$perm should be a view permission for observer');
        }
      }
    });

    // ─── Effective Permissions (Inheritance) ─────────────────────────────

    test('teacher inherits assistant_teacher permissions', () {
      final teacherPerms = RoleResolver.getEffectivePermissions(KlasivoRole.teacher);
      final assistantPerms = RoleResolver.getDeltaPermissions(KlasivoRole.assistantTeacher);
      for (final perm in assistantPerms) {
        expect(teacherPerms, contains(perm), reason: 'Teacher should inherit $perm from assistant_teacher');
      }
    });

    test('academic_supervisor inherits teacher + assistant_teacher permissions', () {
      final supervisorPerms = RoleResolver.getEffectivePermissions(KlasivoRole.academicSupervisor);
      final teacherPerms = RoleResolver.getEffectivePermissions(KlasivoRole.teacher);
      for (final perm in teacherPerms) {
        expect(supervisorPerms, contains(perm), reason: 'Academic supervisor should inherit $perm');
      }
    });

    test('stage_manager inherits academic_supervisor permissions', () {
      final stagePerms = RoleResolver.getEffectivePermissions(KlasivoRole.stageManager);
      final supervisorPerms = RoleResolver.getEffectivePermissions(KlasivoRole.academicSupervisor);
      for (final perm in supervisorPerms) {
        expect(stagePerms, contains(perm), reason: 'Stage manager should inherit $perm');
      }
    });

    test('admin inherits from campus_manager, stage_manager, and observer', () {
      final adminPerms = RoleResolver.getEffectivePermissions(KlasivoRole.admin);
      final cmPerms = RoleResolver.getEffectivePermissions(KlasivoRole.campusManager);
      final smPerms = RoleResolver.getEffectivePermissions(KlasivoRole.stageManager);
      final obsPerms = RoleResolver.getEffectivePermissions(KlasivoRole.observer);

      for (final perm in cmPerms) {
        expect(adminPerms, contains(perm), reason: 'Admin should inherit $perm from campus_manager');
      }
      for (final perm in smPerms) {
        expect(adminPerms, contains(perm), reason: 'Admin should inherit $perm from stage_manager');
      }
      for (final perm in obsPerms) {
        expect(adminPerms, contains(perm), reason: 'Admin should inherit $perm from observer');
      }
    });

    test('owner inherits admin permissions', () {
      final ownerPerms = RoleResolver.getEffectivePermissions(KlasivoRole.owner);
      final adminPerms = RoleResolver.getEffectivePermissions(KlasivoRole.admin);
      for (final perm in adminPerms) {
        expect(ownerPerms, contains(perm), reason: 'Owner should inherit $perm from admin');
      }
    });

    test('super_admin has wildcard permission', () {
      final perms = RoleResolver.getEffectivePermissions(KlasivoRole.superAdmin);
      expect(perms, contains(Permission.all));
    });

    // ─── roleHasPermission ───────────────────────────────────────────────

    test('super_admin has every permission', () {
      for (final perm in Permission.allPermissions) {
        expect(RoleResolver.roleHasPermission(KlasivoRole.superAdmin, perm), isTrue,
            reason: 'super_admin should have $perm');
      }
    });

    test('teacher can create exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.teacher, Permission.examCreate), isTrue);
    });

    test('assistant_teacher cannot create exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.assistantTeacher, Permission.examCreate), isFalse);
    });

    test('assistant_teacher can grade exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.assistantTeacher, Permission.examGrade), isTrue);
    });

    test('assistant_teacher cannot publish exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.assistantTeacher, Permission.examPublish), isFalse);
    });

    test('assistant_teacher cannot delete exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.assistantTeacher, Permission.examDelete), isFalse);
    });

    test('observer has view permissions only', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.observer, Permission.examView), isTrue);
      expect(RoleResolver.roleHasPermission(KlasivoRole.observer, Permission.examCreate), isFalse);
      expect(RoleResolver.roleHasPermission(KlasivoRole.observer, Permission.classView), isTrue);
      expect(RoleResolver.roleHasPermission(KlasivoRole.observer, Permission.classCreate), isFalse);
    });

    test('student can take exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.student, Permission.examTake), isTrue);
    });

    test('student cannot create exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.student, Permission.examCreate), isFalse);
    });

    test('parent can view own children', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.parent, Permission.parentViewOwnChildren), isTrue);
    });

    test('parent cannot create exams', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.parent, Permission.examCreate), isFalse);
    });

    test('owner can manage org', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.owner, Permission.orgManage), isTrue);
    });

    test('admin cannot delete org', () {
      expect(RoleResolver.roleHasPermission(KlasivoRole.admin, Permission.orgDelete), isFalse);
    });

    // ─── rolesWithPermission ─────────────────────────────────────────────

    test('exam:grade is available to assistant_teacher, teacher, and above', () {
      final roles = RoleResolver.rolesWithPermission(Permission.examGrade);
      expect(roles, contains(KlasivoRole.assistantTeacher));
      expect(roles, contains(KlasivoRole.teacher));
      expect(roles, contains(KlasivoRole.academicSupervisor));
      expect(roles, contains(KlasivoRole.stageManager));
      expect(roles, contains(KlasivoRole.campusManager));
      expect(roles, contains(KlasivoRole.admin));
      expect(roles, contains(KlasivoRole.owner));
      expect(roles, contains(KlasivoRole.superAdmin));
      // Student and parent cannot grade
      expect(roles, isNot(contains(KlasivoRole.student)));
      expect(roles, isNot(contains(KlasivoRole.parent)));
    });

    // ─── Cache Consistency ───────────────────────────────────────────────

    test('cache returns same result as fresh computation', () {
      final first = RoleResolver.getEffectivePermissions(KlasivoRole.teacher);
      final second = RoleResolver.getEffectivePermissions(KlasivoRole.teacher);
      expect(first, equals(second));
    });

    test('clearCache allows fresh computation', () {
      final first = RoleResolver.getEffectivePermissions(KlasivoRole.teacher);
      RoleResolver.clearCache();
      final second = RoleResolver.getEffectivePermissions(KlasivoRole.teacher);
      expect(first, equals(second));
    });
  });
}
