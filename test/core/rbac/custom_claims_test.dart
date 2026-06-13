import 'package:flutter_test/flutter_test.dart';
import 'package:klasivo/core/rbac/rbac.dart';

void main() {
  group('CustomClaims', () {
    test('creates from token claims map', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'teacher',
        'organizationId': 'org123',
        'scopeAccessLevel': 'class',
      });
      expect(claims.role, 'teacher');
      expect(claims.organizationId, 'org123');
      expect(claims.scopeAccessLevel, 'class');
    });

    test('handles missing claims gracefully', () {
      final claims = CustomClaims.fromTokenClaims({});
      expect(claims.role, '');
      expect(claims.organizationId, '');
      expect(claims.scopeAccessLevel, 'self');
    });

    test('toClaimsMap produces correct structure', () {
      const claims = CustomClaims(role: 'admin', organizationId: 'org456', scopeAccessLevel: 'all');
      final map = claims.toClaimsMap();
      expect(map['role'], 'admin');
      expect(map['organizationId'], 'org456');
      expect(map['scopeAccessLevel'], 'all');
    });

    test('isValid returns true when all fields are set', () {
      const claims = CustomClaims(role: 'teacher', organizationId: 'org123', scopeAccessLevel: 'class');
      expect(claims.isValid, true);
    });

    test('isValid returns false when role is empty', () {
      const claims = CustomClaims(role: '', organizationId: 'org123', scopeAccessLevel: 'class');
      expect(claims.isValid, false);
    });

    test('isValid returns false when organizationId is empty', () {
      const claims = CustomClaims(role: 'teacher', organizationId: '', scopeAccessLevel: 'class');
      expect(claims.isValid, false);
    });

    test('empty constant has isValid false', () {
      expect(CustomClaims.empty.isValid, false);
    });

    test('equality works correctly', () {
      const a = CustomClaims(role: 'teacher', organizationId: 'org1', scopeAccessLevel: 'class');
      const b = CustomClaims(role: 'teacher', organizationId: 'org1', scopeAccessLevel: 'class');
      const c = CustomClaims(role: 'admin', organizationId: 'org1', scopeAccessLevel: 'all');
      expect(a == b, true);
      expect(a == c, false);
    });

    test('hashCode is consistent with equality', () {
      const a = CustomClaims(role: 'teacher', organizationId: 'org1', scopeAccessLevel: 'class');
      const b = CustomClaims(role: 'teacher', organizationId: 'org1', scopeAccessLevel: 'class');
      expect(a.hashCode, b.hashCode);
    });
  });
}
