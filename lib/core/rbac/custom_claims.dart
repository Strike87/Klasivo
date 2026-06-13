// Barrel: KLASIVO RBAC v2.0 — Custom Claims Model
//
// Defines the shape of Firebase Auth custom claims for Klasivo:
//   {
//     "role": "teacher",
//     "organizationId": "org123",
//     "scopeAccessLevel": "class"
//   }
//
// roleVersion is NOT in claims — it lives on the Firestore user doc only.
// Flutter watches roleVersion on the user doc to know when to force-refresh the token.
//
// Note: scopeAccessLevel is stored as a plain string in claims (e.g., "class"),
// not as the Dart enum name ("class_"). Use scopeAccessLevelFromClaim() /
// scopeAccessLevelToClaim() for conversion.

import 'scope_access_level.dart';

class CustomClaims {
  final String role;
  final String organizationId;
  final String scopeAccessLevel;

  const CustomClaims({
    required this.role,
    required this.organizationId,
    required this.scopeAccessLevel,
  });

  // From Firebase Auth ID token claims
  factory CustomClaims.fromTokenClaims(Map<String, dynamic> claims) {
    final rawScope = claims['scopeAccessLevel'] as String? ?? 'self';
    return CustomClaims(
      role: claims['role'] as String? ?? '',
      organizationId: claims['organizationId'] as String? ?? '',
      // Convert claim string (e.g., "class") through the mapping layer
      // to ensure consistency — even though we store as string,
      // this validates the value is a known scope level.
      scopeAccessLevel: scopeAccessLevelToClaim(scopeAccessLevelFromClaim(rawScope)),
    );
  }

  /// Get the ScopeAccessLevel enum for this claim's scopeAccessLevel.
  ScopeAccessLevel get scopeAccessLevelEnum => scopeAccessLevelFromClaim(scopeAccessLevel);

  // To Firebase Admin SDK setCustomUserClaims format
  Map<String, dynamic> toClaimsMap() {
    return {
      'role': role,
      'organizationId': organizationId,
      'scopeAccessLevel': scopeAccessLevel,
    };
  }

  bool get isValid => role.isNotEmpty && organizationId.isNotEmpty;

  static const CustomClaims empty = CustomClaims(
    role: '',
    organizationId: '',
    scopeAccessLevel: 'self',
  );

  @override
  String toString() => 'CustomClaims(role: $role, orgId: $organizationId, scope: $scopeAccessLevel)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomClaims &&
          role == other.role &&
          organizationId == other.organizationId &&
          scopeAccessLevel == other.scopeAccessLevel;

  @override
  int get hashCode => Object.hash(role, organizationId, scopeAccessLevel);
}
