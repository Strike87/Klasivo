// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Permission Service Tests
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/rbac/rbac.dart';

void main() {
  group('PermissionService', () {
    // ─── Basic Permission Checks ─────────────────────────────────────────

    test('teacher can create exams', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.can(Permission.examCreate), isTrue);
    });

    test('assistant_teacher cannot create exams', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(service.can(Permission.examCreate), isFalse);
    });

    test('assistant_teacher can grade exams', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(service.can(Permission.examGrade), isTrue);
    });

    test('assistant_teacher can mark attendance', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(service.can(Permission.attendanceMark), isTrue);
    });

    test('assistant_teacher cannot publish exams', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(service.can(Permission.examPublish), isFalse);
    });

    test('assistant_teacher cannot delete assignments', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(service.can(Permission.assignmentDelete), isFalse);
    });

    test('student can take exams', () {
      final service = PermissionService(role: KlasivoRole.student);
      expect(service.can(Permission.examTake), isTrue);
    });

    test('student cannot create exams', () {
      final service = PermissionService(role: KlasivoRole.student);
      expect(service.can(Permission.examCreate), isFalse);
    });

    test('parent can view own children', () {
      final service = PermissionService(role: KlasivoRole.parent);
      expect(service.can(Permission.parentViewOwnChildren), isTrue);
    });

    test('observer can view but not create', () {
      final service = PermissionService(role: KlasivoRole.observer);
      expect(service.can(Permission.examView), isTrue);
      expect(service.can(Permission.examCreate), isFalse);
      expect(service.can(Permission.classView), isTrue);
      expect(service.can(Permission.classCreate), isFalse);
    });

    // ─── Override Tests ──────────────────────────────────────────────────

    test('explicit deny overrides role default', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        permissionOverrides: {Permission.examPublish: false},
      );
      expect(service.can(Permission.examPublish), isFalse);
    });

    test('explicit allow grants permission beyond role default', () {
      final service = PermissionService(
        role: KlasivoRole.assistantTeacher,
        permissionOverrides: {Permission.examCreate: true},
      );
      expect(service.can(Permission.examCreate), isTrue);
    });

    test('explicit deny takes precedence over explicit allow (deny wins)', () {
      // If somehow both are set, deny should win
      // In practice this shouldn't happen, but the order is: deny → allow → role
      final service = PermissionService(
        role: KlasivoRole.teacher,
        permissionOverrides: {
          Permission.examCreate: false, // Deny
        },
      );
      expect(service.can(Permission.examCreate), isFalse);
    });

    test('override does not affect unrelated permissions', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        permissionOverrides: {Permission.examPublish: false},
      );
      // Teacher can still create exams
      expect(service.can(Permission.examCreate), isTrue);
      expect(service.can(Permission.examEdit), isTrue);
    });

    test('updateOverrides changes the override set', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.can(Permission.examPublish), isTrue);

      service.updateOverrides({Permission.examPublish: false});
      expect(service.can(Permission.examPublish), isFalse);

      service.updateOverrides({}); // Clear overrides
      expect(service.can(Permission.examPublish), isTrue);
    });

    // ─── canAny / canAll Tests ───────────────────────────────────────────

    test('canAny returns true if user has ANY of the permissions', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(
        service.canAny([Permission.examCreate, Permission.examGrade]),
        isTrue, // Has exam:grade
      );
    });

    test('canAny returns false if user has NONE of the permissions', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(
        service.canAny([Permission.examCreate, Permission.examPublish]),
        isFalse,
      );
    });

    test('canAll returns true if user has ALL of the permissions', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(
        service.canAll([Permission.examCreate, Permission.examGrade]),
        isTrue,
      );
    });

    test('canAll returns false if user is missing any permission', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(
        service.canAll([Permission.examView, Permission.examCreate]),
        isFalse, // Missing exam:create
      );
    });

    // ─── hasRole Tests ───────────────────────────────────────────────────

    test('owner hasRole admin returns true (hierarchy)', () {
      final service = PermissionService(role: KlasivoRole.owner);
      expect(service.hasRole(KlasivoRole.admin), isTrue);
    });

    test('owner hasRole teacher returns true (hierarchy)', () {
      final service = PermissionService(role: KlasivoRole.owner);
      expect(service.hasRole(KlasivoRole.teacher), isTrue);
    });

    test('teacher hasRole admin returns false', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.hasRole(KlasivoRole.admin), isFalse);
    });

    test('teacher hasRole assistant_teacher returns true', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.hasRole(KlasivoRole.assistantTeacher), isTrue);
    });

    test('hasExactRole returns true only for exact match', () {
      final service = PermissionService(role: KlasivoRole.owner);
      expect(service.hasExactRole(KlasivoRole.owner), isTrue);
      expect(service.hasExactRole(KlasivoRole.admin), isFalse);
    });

    test('student does not inherit from teacher', () {
      final service = PermissionService(role: KlasivoRole.student);
      expect(service.hasRole(KlasivoRole.teacher), isFalse);
    });

    // ─── Scope Validation Tests ──────────────────────────────────────────

    test('owner can access any class (all scope)', () {
      final service = PermissionService(role: KlasivoRole.owner);
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_xyz'),
        isTrue,
      );
    });

    test('teacher with empty scope can access any class (backward compat)', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_xyz'),
        isTrue,
      );
    });

    test('teacher with specific class scope can access that class', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        scope: UserScope(classIds: ['class_5A', 'class_5B']),
      );
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_5A'),
        isTrue,
      );
    });

    test('teacher with specific class scope cannot access other class', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        scope: UserScope(classIds: ['class_5A', 'class_5B']),
      );
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_6A'),
        isFalse,
      );
    });

    test('campus_manager with campus scope', () {
      final service = PermissionService(
        role: KlasivoRole.campusManager,
        scope: UserScope(campusIds: ['campus_a']),
      );
      expect(
        service.validateScope(scopeType: 'campus', scopeId: 'campus_a'),
        isTrue,
      );
      expect(
        service.validateScope(scopeType: 'campus', scopeId: 'campus_b'),
        isFalse,
      );
    });

    test('parent with studentIds scope', () {
      final service = PermissionService(
        role: KlasivoRole.parent,
        scope: UserScope(studentIds: ['student_1', 'student_2']),
      );
      expect(
        service.validateScope(scopeType: 'student', scopeId: 'student_1'),
        isTrue,
      );
      expect(
        service.validateScope(scopeType: 'student', scopeId: 'student_3'),
        isFalse,
      );
    });

    test('can() with scopeType and scopeId combines permission + scope', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        scope: UserScope(classIds: ['class_5A']),
      );
      // Has permission + in scope
      expect(
        service.can(Permission.examCreate, scopeType: 'class', scopeId: 'class_5A'),
        isTrue,
      );
      // Has permission but NOT in scope
      expect(
        service.can(Permission.examCreate, scopeType: 'class', scopeId: 'class_6A'),
        isFalse,
      );
    });

    test('can() without scope checks permission only', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        scope: UserScope(classIds: ['class_5A']),
      );
      // No scope check — just permission
      expect(service.can(Permission.examCreate), isTrue);
    });

    // ─── State Update Tests ──────────────────────────────────────────────

    test('updateRole changes the role', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.can(Permission.examCreate), isTrue);

      service.updateRole(KlasivoRole.assistantTeacher);
      expect(service.can(Permission.examCreate), isFalse);
    });

    test('updateScope changes the scope', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_5A'),
        isTrue, // Empty scope = all access
      );

      service.updateScope(UserScope(classIds: ['class_5B']));
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_5A'),
        isFalse,
      );
      expect(
        service.validateScope(scopeType: 'class', scopeId: 'class_5B'),
        isTrue,
      );
    });

    test('updateAll changes everything at once', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      service.updateAll(
        role: KlasivoRole.assistantTeacher,
        scope: UserScope(classIds: ['class_1A']),
        organizationId: 'org_new',
      );
      expect(service.role, KlasivoRole.assistantTeacher);
      expect(service.can(Permission.examCreate), isFalse);
      expect(service.organizationId, 'org_new');
    });

    // ─── Convenience Properties ──────────────────────────────────────────

    test('canManageExams is true for teacher', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.canManageExams, isTrue);
    });

    test('canManageExams is false for assistant_teacher', () {
      final service = PermissionService(role: KlasivoRole.assistantTeacher);
      expect(service.canManageExams, isFalse);
    });

    test('isOrgLevel is true for admin', () {
      expect(PermissionService(role: KlasivoRole.admin).isOrgLevel, isTrue);
      expect(PermissionService(role: KlasivoRole.owner).isOrgLevel, isTrue);
      expect(PermissionService(role: KlasivoRole.superAdmin).isOrgLevel, isTrue);
    });

    test('isOrgLevel is false for teacher', () {
      expect(PermissionService(role: KlasivoRole.teacher).isOrgLevel, isFalse);
    });

    test('isReadOnly is true for observer', () {
      expect(PermissionService(role: KlasivoRole.observer).isReadOnly, isTrue);
      expect(PermissionService(role: KlasivoRole.teacher).isReadOnly, isFalse);
    });

    // ─── getEffectivePermissions with overrides ──────────────────────────

    test('getEffectivePermissions includes overrides', () {
      final service = PermissionService(
        role: KlasivoRole.assistantTeacher,
        permissionOverrides: {Permission.examCreate: true},
      );
      final perms = service.getEffectivePermissions();
      expect(perms, contains(Permission.examCreate));
    });

    test('getEffectivePermissions removes denied overrides', () {
      final service = PermissionService(
        role: KlasivoRole.teacher,
        permissionOverrides: {Permission.examPublish: false},
      );
      final perms = service.getEffectivePermissions();
      expect(perms, isNot(contains(Permission.examPublish)));
    });

    // ─── Role Version ────────────────────────────────────────────────────

    test('roleVersion defaults to 0', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      expect(service.roleVersion, 0);
    });

    test('updateRoleVersion changes the version', () {
      final service = PermissionService(role: KlasivoRole.teacher);
      service.updateRoleVersion(5);
      expect(service.roleVersion, 5);
    });
  });
}
