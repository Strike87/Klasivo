// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Staff Approval Policy Enum
//
// Organization-level policy that controls how self-registering
// staff applications are handled. Set on the `organizations` document
// as `staffApprovalPolicy`.
//
// This policy is checked by the `submitStaffApplication` Cloud Function
// at the moment of application creation.
// ═══════════════════════════════════════════════════════════════════════════════

/// Organization-level policy for staff onboarding.
///
/// Controls how self-registering staff are handled:
/// - [manual]:       Creates a pending application for owner review (default).
/// - [inviteOnly]:   Self-registration is auto-rejected; only invitations accepted.
/// - [autoApprove]:  Self-registration is immediately approved; claims are set.
enum StaffApprovalPolicy {
  /// Self-registration creates a pending_review application.
  /// Owner/admin must explicitly approve before access is granted.
  /// This is the safest default for new organizations.
  manual('manual'),

  /// Self-registration is automatically rejected.
  /// Staff can only join via explicit invitation from owner/admin.
  /// Use this for organizations that want full control over who joins.
  inviteOnly('invite_only'),

  /// Self-registration is immediately approved.
  /// Custom claims are set automatically upon registration.
  /// Use this for open organizations or testing environments.
  autoApprove('auto_approve');

  const StaffApprovalPolicy(this.id);

  /// Firestore-compatible string identifier.
  final String id;

  /// Parse from a Firestore string identifier.
  /// Returns [manual] for unknown or null values (safest default).
  static StaffApprovalPolicy fromId(String? id) {
    return StaffApprovalPolicy.values.firstWhere(
      (e) => e.id == id,
      orElse: () => StaffApprovalPolicy.manual,
    );
  }

  /// Backward-compatible alias for [fromId].
  @Deprecated('Use fromId instead for consistency with other enums')
  static StaffApprovalPolicy fromString(String? value) => fromId(value);

  /// Human-readable description of this policy.
  String get description => switch (this) {
        manual => 'Staff must be approved by an administrator',
        inviteOnly => 'Staff can only join via invitation',
        autoApprove => 'Staff are automatically approved upon registration',
      };

  /// Whether self-registration is allowed under this policy.
  /// Both `manual` and `auto_approve` allow it; `invite_only` does not.
  bool get allowsSelfRegistration =>
      this == StaffApprovalPolicy.manual ||
      this == StaffApprovalPolicy.autoApprove;
}
