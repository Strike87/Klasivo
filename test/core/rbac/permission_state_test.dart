import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/rbac/rbac.dart';

void main() {
  group('PermissionState', () {
    test('initial state has empty values', () {
      const state = PermissionState.initial;
      expect(state.role, '');
      expect(state.userId, '');
      expect(state.organizationId, '');
      expect(state.mustChangePassword, false);
      expect(state.isAuthenticated, false);
      expect(state.needsPasswordChange, false);
    });

    test('isAuthenticated returns true when role and userId are set', () {
      const state = PermissionState(role: 'teacher', userId: 'user123');
      expect(state.isAuthenticated, true);
    });

    test('needsPasswordChange returns true when mustChangePassword is true', () {
      const state = PermissionState(role: 'student', userId: 'user123', mustChangePassword: true);
      expect(state.needsPasswordChange, true);
    });

    test('needsPasswordChange returns false when mustChangePassword is false', () {
      const state = PermissionState(role: 'teacher', userId: 'user123', mustChangePassword: false);
      expect(state.needsPasswordChange, false);
    });

    test('copyWith preserves existing values', () {
      const state = PermissionState(role: 'teacher', userId: 'user123', organizationId: 'org1');
      final copied = state.copyWith(mustChangePassword: true);
      expect(copied.role, 'teacher');
      expect(copied.userId, 'user123');
      expect(copied.organizationId, 'org1');
      expect(copied.mustChangePassword, true);
    });

    test('copyWith can update mustChangePassword to false', () {
      const state = PermissionState(role: 'student', userId: 'user123', mustChangePassword: true);
      final copied = state.copyWith(mustChangePassword: false);
      expect(copied.mustChangePassword, false);
      expect(copied.needsPasswordChange, false);
    });

    test('equality includes mustChangePassword', () {
      const a = PermissionState(role: 'teacher', userId: 'u1', mustChangePassword: true);
      const b = PermissionState(role: 'teacher', userId: 'u1', mustChangePassword: false);
      expect(a == b, false);
    });

    test('same values produce equal states', () {
      const a = PermissionState(role: 'teacher', userId: 'u1', mustChangePassword: true);
      const b = PermissionState(role: 'teacher', userId: 'u1', mustChangePassword: true);
      expect(a == b, true);
    });
  });
}
