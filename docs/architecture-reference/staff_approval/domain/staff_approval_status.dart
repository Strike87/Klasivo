// ═══════════════════════════════════════════════════════════════════════════════
// ⚠️  ARCHITECTURE REFERENCE — NOT COMPILED, NOT WIRED INTO THE APP  ⚠️
// ─────────────────────────────────────────────────────────────────────────────
// This file was MOVED here from lib/features/staff_approval/domain/ as part of the Sprint 1
// scaffold cleanup (Phase 5+). It is preserved as a DESIGN REFERENCE for a
// future typed-model migration, but it is NOT included in the Flutter build
// (this directory is outside `lib/`).
//
// Before relying on this as the design source for a migration, verify field
// shapes match what the live service actually writes to Firestore. See
// download/scaffold-investigation-report.md for full context.
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO — Staff Approval Status Enum
//
// Represents the lifecycle states of a staff onboarding application.
// State transitions are enforced server-side by Cloud Functions
// using Firestore transactions for idempotency.
//
// Allowed transitions:
//   pending_review → approved
//   pending_review → rejected
//   invited        → approved   (accept invitation)
//   invited        → declined   (decline invitation)
//   invited        → expired    (TTL passed)
//   approved       → revoked    (owner revokes access)
//
// All other transitions are DENIED server-side.
// ═══════════════════════════════════════════════════════════════════════════════

/// The approval status of a staff onboarding application.
///
/// Each status represents a distinct stage in the staff lifecycle.
/// Transitions are validated server-side; see the Cloud Functions
/// `reviewStaffApplication`, `revokeStaffAccess`, `acceptStaffInvitation`,
/// and `declineStaffInvitation` for enforcement logic.
enum StaffApprovalStatus {
  /// Self-registered, awaiting owner/admin review.
  /// No custom claims set — zero permissions.
  pendingReview('pending_review'),

  /// Owner/admin sent an invitation email.
  /// Awaiting the invitee to accept or decline.
  invited('invited'),

  /// Full access granted. Custom claims are set.
  /// User can perform all actions within their assigned scope.
  approved('approved'),

  /// Application denied by owner/admin.
  /// The applicant may reapply (creates a new application doc).
  rejected('rejected'),

  /// Was previously approved, but access has been removed.
  /// Custom claims are stripped. User set to inactive.
  revoked('revoked'),

  /// Invitation expired before the invitee accepted.
  /// The invitation TTL has passed.
  expired('expired'),

  /// Invitee explicitly declined the invitation.
  declined('declined');

  const StaffApprovalStatus(this.value);

  /// Firestore-compatible string value.
  final String value;

  /// Parse from a Firestore string value.
  /// Returns [pendingReview] for unknown values (fail-safe default).
  static StaffApprovalStatus fromString(String? value) {
    return StaffApprovalStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => StaffApprovalStatus.pendingReview,
    );
  }

  /// Whether this status represents a terminal state
  /// (no further automatic transitions expected).
  bool get isTerminal =>
      this == StaffApprovalStatus.rejected ||
      this == StaffApprovalStatus.revoked ||
      this == StaffApprovalStatus.expired ||
      this == StaffApprovalStatus.declined;

  /// Whether this status represents an active, approved staff member.
  bool get isActive => this == StaffApprovalStatus.approved;

  /// Whether this status represents a pending action
  /// (waiting for a human decision or response).
  bool get isPending =>
      this == StaffApprovalStatus.pendingReview ||
      this == StaffApprovalStatus.invited;
}

/// Validates whether a state transition is allowed.
///
/// This is the client-side mirror of the server-side validation
/// in Cloud Functions. The server is the ultimate authority,
/// but this helper enables UI-level validation and early feedback.
class StaffApprovalTransition {
  StaffApprovalTransition._();

  /// Map of allowed transitions: from → set of allowed to statuses.
  static const Map<StaffApprovalStatus, Set<StaffApprovalStatus>> _allowed = {
    StaffApprovalStatus.pendingReview: {
      StaffApprovalStatus.approved,
      StaffApprovalStatus.rejected,
    },
    StaffApprovalStatus.invited: {
      StaffApprovalStatus.approved,
      StaffApprovalStatus.declined,
      StaffApprovalStatus.expired,
    },
    StaffApprovalStatus.approved: {
      StaffApprovalStatus.revoked,
    },
    // Terminal states — no outgoing transitions
    StaffApprovalStatus.rejected: {},
    StaffApprovalStatus.revoked: {},
    StaffApprovalStatus.expired: {},
    StaffApprovalStatus.declined: {},
  };

  /// Check whether a transition from [from] to [to] is allowed.
  static bool isAllowed(
    StaffApprovalStatus from,
    StaffApprovalStatus to,
  ) {
    return _allowed[from]?.contains(to) ?? false;
  }

  /// Get all allowed target statuses from [from].
  static Set<StaffApprovalStatus> allowedTargets(StaffApprovalStatus from) {
    return Set.unmodifiable(_allowed[from] ?? const {});
  }
}
