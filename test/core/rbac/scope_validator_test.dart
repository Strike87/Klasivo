// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Scope Validator Tests
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/rbac/rbac.dart';

void main() {
  group('ScopeValidator', () {
    // ─── ScopeAccessLevel.all ────────────────────────────────────────────

    test('all access level always returns true', () {
      final validator = ScopeValidator(
        scope: UserScope.empty,
        accessLevel: ScopeAccessLevel.all,
      );
      expect(validator.validate(scopeType: 'campus', scopeId: 'any'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'any'), isTrue);
      expect(validator.validate(scopeType: 'stage', scopeId: 'any'), isTrue);
    });

    test('forRole factory creates correct access level for owner', () {
      final validator = ScopeValidator.forRole(
        KlasivoRole.owner,
        scope: UserScope.empty,
      );
      expect(validator.accessLevel, ScopeAccessLevel.all);
    });

    // ─── ScopeAccessLevel.campus ─────────────────────────────────────────

    test('campus_manager with empty scope grants all access (backward compat)', () {
      final validator = ScopeValidator(
        scope: UserScope.empty,
        accessLevel: ScopeAccessLevel.campus,
      );
      expect(validator.validate(scopeType: 'campus', scopeId: 'campus_a'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5A'), isTrue);
    });

    test('campus_manager with campus scope can access that campus', () {
      final validator = ScopeValidator(
        scope: UserScope(campusIds: ['campus_a', 'campus_b']),
        accessLevel: ScopeAccessLevel.campus,
      );
      expect(validator.validate(scopeType: 'campus', scopeId: 'campus_a'), isTrue);
      expect(validator.validate(scopeType: 'campus', scopeId: 'campus_b'), isTrue);
      expect(validator.validate(scopeType: 'campus', scopeId: 'campus_c'), isFalse);
    });

    test('campus_manager with campus scope can access classes within scope', () {
      final validator = ScopeValidator(
        scope: UserScope(
          campusIds: ['campus_a'],
          classIds: ['class_5A'],
        ),
        accessLevel: ScopeAccessLevel.campus,
      );
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5A'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'class_6A'), isFalse);
    });

    // ─── ScopeAccessLevel.stage ──────────────────────────────────────────

    test('stage_manager with stage scope', () {
      final validator = ScopeValidator(
        scope: UserScope(stageIds: ['primary', 'middle']),
        accessLevel: ScopeAccessLevel.stage,
      );
      expect(validator.validate(scopeType: 'stage', scopeId: 'primary'), isTrue);
      expect(validator.validate(scopeType: 'stage', scopeId: 'high'), isFalse);
    });

    test('stage_manager with stage + class scope', () {
      final validator = ScopeValidator(
        scope: UserScope(
          stageIds: ['primary'],
          classIds: ['class_1A', 'class_2A'],
        ),
        accessLevel: ScopeAccessLevel.stage,
      );
      expect(validator.validate(scopeType: 'class', scopeId: 'class_1A'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5A'), isFalse);
    });

    test('academic_supervisor has same scope level as stage_manager', () {
      expect(
        scopeAccessLevelForRole(KlasivoRole.academicSupervisor),
        ScopeAccessLevel.stage,
      );
    });

    // ─── ScopeAccessLevel.class_ ─────────────────────────────────────────

    test('teacher with class scope can access assigned classes', () {
      final validator = ScopeValidator(
        scope: UserScope(classIds: ['class_5A', 'class_5B']),
        accessLevel: ScopeAccessLevel.class_,
      );
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5A'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5B'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'class_6A'), isFalse);
    });

    test('teacher with subject scope', () {
      final validator = ScopeValidator(
        scope: UserScope(subjectIds: ['math', 'physics']),
        accessLevel: ScopeAccessLevel.class_,
      );
      expect(validator.validate(scopeType: 'subject', scopeId: 'math'), isTrue);
      expect(validator.validate(scopeType: 'subject', scopeId: 'chemistry'), isFalse);
    });

    test('teacher with academic year scope', () {
      final validator = ScopeValidator(
        scope: UserScope(academicYearIds: ['ay_2024']),
        accessLevel: ScopeAccessLevel.class_,
      );
      expect(validator.validate(scopeType: 'academic_year', scopeId: 'ay_2024'), isTrue);
      expect(validator.validate(scopeType: 'academic_year', scopeId: 'ay_2025'), isFalse);
    });

    test('class-scoped user can access campus/stage types (service validates)', () {
      final validator = ScopeValidator(
        scope: UserScope(classIds: ['class_5A']),
        accessLevel: ScopeAccessLevel.class_,
      );
      // Cannot determine campus/stage from class scope alone
      // Service layer must validate the relationship
      expect(validator.validate(scopeType: 'campus', scopeId: 'campus_a'), isTrue);
      expect(validator.validate(scopeType: 'stage', scopeId: 'primary'), isTrue);
    });

    // ─── ScopeAccessLevel.self (student) ─────────────────────────────────

    test('student with class enrollment can access that class', () {
      final validator = ScopeValidator(
        scope: UserScope(classIds: ['class_5A']),
        accessLevel: ScopeAccessLevel.self,
      );
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5A'), isTrue);
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5B'), isFalse);
    });

    test('student with empty class scope can access any class (backward compat)', () {
      final validator = ScopeValidator(
        scope: UserScope.empty,
        accessLevel: ScopeAccessLevel.self,
      );
      expect(validator.validate(scopeType: 'class', scopeId: 'class_5A'), isTrue);
    });

    // ─── ScopeAccessLevel.linked (parent) ────────────────────────────────

    test('parent can access linked student data', () {
      final validator = ScopeValidator(
        scope: UserScope(studentIds: ['student_1', 'student_2']),
        accessLevel: ScopeAccessLevel.linked,
      );
      expect(validator.validate(scopeType: 'student', scopeId: 'student_1'), isTrue);
      expect(validator.validate(scopeType: 'student', scopeId: 'student_2'), isTrue);
      expect(validator.validate(scopeType: 'student', scopeId: 'student_3'), isFalse);
    });

    test('parent with empty studentIds cannot access any student', () {
      final validator = ScopeValidator(
        scope: UserScope.empty,
        accessLevel: ScopeAccessLevel.linked,
      );
      expect(validator.validate(scopeType: 'student', scopeId: 'student_1'), isFalse);
    });

    test('parent cannot access campus resources directly', () {
      final validator = ScopeValidator(
        scope: UserScope(studentIds: ['student_1']),
        accessLevel: ScopeAccessLevel.linked,
      );
      expect(validator.validate(scopeType: 'campus', scopeId: 'campus_a'), isFalse);
    });

    // ─── accessibleIdsFor ────────────────────────────────────────────────

    test('accessibleIdsFor returns null when all access', () {
      final validator = ScopeValidator(
        scope: UserScope.empty,
        accessLevel: ScopeAccessLevel.all,
      );
      expect(validator.accessibleIdsFor('class'), isNull);
    });

    test('accessibleIdsFor returns list when scope is set', () {
      final validator = ScopeValidator(
        scope: UserScope(classIds: ['class_5A', 'class_5B']),
        accessLevel: ScopeAccessLevel.class_,
      );
      final ids = validator.accessibleIdsFor('class');
      expect(ids, isNotNull);
      expect(ids, ['class_5A', 'class_5B']);
    });

    // ─── isAllAccess ─────────────────────────────────────────────────────

    test('isAllAccess is true for all access level', () {
      expect(
        ScopeValidator(scope: UserScope.empty, accessLevel: ScopeAccessLevel.all).isAllAccess,
        isTrue,
      );
    });

    test('isAllAccess is true for campus_manager with empty campusIds', () {
      expect(
        ScopeValidator(scope: UserScope.empty, accessLevel: ScopeAccessLevel.campus).isAllAccess,
        isTrue,
      );
    });

    test('isAllAccess is false for teacher with assigned classes', () {
      expect(
        ScopeValidator(scope: UserScope(classIds: ['class_5A']), accessLevel: ScopeAccessLevel.class_).isAllAccess,
        isFalse,
      );
    });

    // ─── Unknown scopeType ───────────────────────────────────────────────

    test('unknown scopeType returns false for scoped roles', () {
      final validator = ScopeValidator(
        scope: UserScope(classIds: ['class_5A']),
        accessLevel: ScopeAccessLevel.class_,
      );
      expect(validator.validate(scopeType: 'unknown_type', scopeId: 'any'), isFalse);
    });
  });

  group('UserScope', () {
    test('empty scope has no assigned scope', () {
      expect(UserScope.empty.hasAssignedScope, isFalse);
    });

    test('scope with classIds has assigned scope', () {
      expect(
        UserScope(classIds: ['class_5A']).hasAssignedScope,
        isTrue,
      );
    });

    test('fromJson / toJson round-trip', () {
      const scope = UserScope(
        campusIds: ['campus_a'],
        stageIds: ['primary'],
        classIds: ['class_5A', 'class_5B'],
        subjectIds: ['math'],
        academicYearIds: ['ay_2024'],
        studentIds: ['student_1'],
      );
      final json = scope.toJson();
      final fromJson = UserScope.fromJson(json);
      expect(fromJson, scope);
    });

    test('copyWith preserves unspecified fields', () {
      const scope = UserScope(classIds: ['class_5A'], subjectIds: ['math']);
      final copied = scope.copyWith(classIds: ['class_5B']);
      expect(copied.classIds, ['class_5B']);
      expect(copied.subjectIds, ['math']);
    });

    test('merge produces union of scopes', () {
      const scope1 = UserScope(classIds: ['class_5A'], campusIds: ['campus_a']);
      const scope2 = UserScope(classIds: ['class_5B'], campusIds: ['campus_b']);
      final merged = scope1.merge(scope2);
      expect(merged.classIds, containsAll(['class_5A', 'class_5B']));
      expect(merged.campusIds, containsAll(['campus_a', 'campus_b']));
    });

    test('equality works correctly', () {
      const scope1 = UserScope(classIds: ['class_5A']);
      const scope2 = UserScope(classIds: ['class_5A']);
      const scope3 = UserScope(classIds: ['class_5B']);
      expect(scope1, equals(scope2));
      expect(scope1, isNot(equals(scope3)));
    });
  });

  group('PermissionGroups', () {
    test('forRole returns effective permissions', () {
      final teacherPerms = PermissionGroups.forRole(KlasivoRole.teacher);
      expect(teacherPerms, contains(Permission.examCreate));
      expect(teacherPerms, contains(Permission.attendanceMark)); // Inherited from assistant_teacher
    });

    test('deltaForRole returns only unique permissions', () {
      final teacherDelta = PermissionGroups.deltaForRole(KlasivoRole.teacher);
      // Teacher delta should NOT contain assistant_teacher permissions
      expect(teacherDelta, isNot(contains(Permission.attendanceMark)));
      // Teacher delta SHOULD contain teacher-specific permissions
      expect(teacherDelta, contains(Permission.examCreate));
    });

    test('custom groups have valid permissions', () {
      for (final group in PermissionGroups.customGroups.values) {
        for (final perm in group.permissions) {
          expect(Permission.allPermissions.contains(perm) || perm == Permission.all,
              isTrue,
              reason: '${group.name} has invalid permission: $perm');
        }
      }
    });

    test('applyOverrides adds and removes permissions', () {
      final result = PermissionGroups.applyOverrides(
        KlasivoRole.teacher,
        {Permission.examPublish: false, Permission.billingManage: true},
      );
      expect(result, isNot(contains(Permission.examPublish)));
      expect(result, contains(Permission.billingManage));
    });

    test('override templates are valid', () {
      for (final entry in PermissionGroups.teacherNoPublish.entries) {
        expect(Permission.allPermissions.contains(entry.key), isTrue);
      }
      for (final entry in PermissionGroups.noExport.entries) {
        expect(Permission.allPermissions.contains(entry.key), isTrue);
      }
    });
  });

  group('KlasivoRole', () {
    test('all roles are valid', () {
      for (final role in KlasivoRole.allRoles) {
        expect(KlasivoRole.isValid(role), isTrue, reason: '$role should be valid');
      }
    });

    test('invalid role string returns false', () {
      expect(KlasivoRole.isValid('nonexistent_role'), isFalse);
      expect(KlasivoRole.isValid(''), isFalse);
    });

    test('displayName returns non-empty for all roles', () {
      for (final role in KlasivoRole.allRoles) {
        expect(KlasivoRole.displayName(role).isNotEmpty, isTrue, reason: '$role should have a display name');
      }
    });

    test('scopeDescription returns non-empty for all roles', () {
      for (final role in KlasivoRole.allRoles) {
        expect(KlasivoRole.scopeDescription(role).isNotEmpty, isTrue, reason: '$role should have a scope description');
      }
    });

    test('new roles are in allRoles list', () {
      expect(KlasivoRole.allRoles, contains(KlasivoRole.stageManager));
      expect(KlasivoRole.allRoles, contains(KlasivoRole.academicSupervisor));
      expect(KlasivoRole.allRoles, contains(KlasivoRole.assistantTeacher));
    });

    test('new roles are scoped roles', () {
      expect(KlasivoRole.isScoped(KlasivoRole.stageManager), isTrue);
      expect(KlasivoRole.isScoped(KlasivoRole.academicSupervisor), isTrue);
      expect(KlasivoRole.isScoped(KlasivoRole.assistantTeacher), isTrue);
    });
  });
}
