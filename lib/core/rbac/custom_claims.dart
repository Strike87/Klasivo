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
    return CustomClaims(
      role: claims['role'] as String? ?? '',
      organizationId: claims['organizationId'] as String? ?? '',
      scopeAccessLevel: claims['scopeAccessLevel'] as String? ?? 'self',
    );
  }

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
