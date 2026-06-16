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
      // Claim value "class" should be preserved as "class" (not "class_")
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

    test('scopeAccessLevelEnum converts "class" to ScopeAccessLevel.class_', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'teacher',
        'organizationId': 'org123',
        'scopeAccessLevel': 'class',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.class_);
    });

    test('scopeAccessLevelEnum converts "all" to ScopeAccessLevel.all', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'admin',
        'organizationId': 'org123',
        'scopeAccessLevel': 'all',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.all);
    });

    test('scopeAccessLevelEnum converts "campus" to ScopeAccessLevel.campus', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'campus_manager',
        'organizationId': 'org123',
        'scopeAccessLevel': 'campus',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.campus);
    });

    test('scopeAccessLevelEnum converts "stage" to ScopeAccessLevel.stage', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'stage_manager',
        'organizationId': 'org123',
        'scopeAccessLevel': 'stage',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.stage);
    });

    test('scopeAccessLevelEnum converts "self" to ScopeAccessLevel.self', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'student',
        'organizationId': 'org123',
        'scopeAccessLevel': 'self',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.self);
    });

    test('scopeAccessLevelEnum converts "linked" to ScopeAccessLevel.linked', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'parent',
        'organizationId': 'org123',
        'scopeAccessLevel': 'linked',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.linked);
    });

    test('unknown scopeAccessLevel defaults to ScopeAccessLevel.self', () {
      final claims = CustomClaims.fromTokenClaims({
        'role': 'teacher',
        'organizationId': 'org123',
        'scopeAccessLevel': 'unknown_value',
      });
      expect(claims.scopeAccessLevelEnum, ScopeAccessLevel.self);
    });
  });

  group('scopeAccessLevelFromClaim', () {
    test('maps "class" to ScopeAccessLevel.class_', () {
      expect(scopeAccessLevelFromClaim('class'), ScopeAccessLevel.class_);
    });

    test('maps "all" to ScopeAccessLevel.all', () {
      expect(scopeAccessLevelFromClaim('all'), ScopeAccessLevel.all);
    });

    test('maps "campus" to ScopeAccessLevel.campus', () {
      expect(scopeAccessLevelFromClaim('campus'), ScopeAccessLevel.campus);
    });

    test('maps "stage" to ScopeAccessLevel.stage', () {
      expect(scopeAccessLevelFromClaim('stage'), ScopeAccessLevel.stage);
    });

    test('maps "self" to ScopeAccessLevel.self', () {
      expect(scopeAccessLevelFromClaim('self'), ScopeAccessLevel.self);
    });

    test('maps "linked" to ScopeAccessLevel.linked', () {
      expect(scopeAccessLevelFromClaim('linked'), ScopeAccessLevel.linked);
    });

    test('unknown value defaults to ScopeAccessLevel.self', () {
      expect(scopeAccessLevelFromClaim('invalid'), ScopeAccessLevel.self);
    });
  });

  group('scopeAccessLevelToClaim', () {
    test('maps ScopeAccessLevel.class_ to "class"', () {
      expect(scopeAccessLevelToClaim(ScopeAccessLevel.class_), 'class');
    });

    test('maps ScopeAccessLevel.all to "all"', () {
      expect(scopeAccessLevelToClaim(ScopeAccessLevel.all), 'all');
    });

    test('maps ScopeAccessLevel.campus to "campus"', () {
      expect(scopeAccessLevelToClaim(ScopeAccessLevel.campus), 'campus');
    });

    test('maps ScopeAccessLevel.stage to "stage"', () {
      expect(scopeAccessLevelToClaim(ScopeAccessLevel.stage), 'stage');
    });

    test('maps ScopeAccessLevel.self to "self"', () {
      expect(scopeAccessLevelToClaim(ScopeAccessLevel.self), 'self');
    });

    test('maps ScopeAccessLevel.linked to "linked"', () {
      expect(scopeAccessLevelToClaim(ScopeAccessLevel.linked), 'linked');
    });

    test('round-trip: fromClaim(toClaim(level)) == level for all values', () {
      for (final level in ScopeAccessLevel.values) {
        expect(scopeAccessLevelFromClaim(scopeAccessLevelToClaim(level)), level);
      }
    });
  });
}
