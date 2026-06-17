// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — Shared Constants & Helpers (TypeScript)
//
// Single source of truth for role and scope-access-level mappings.
// Used by assignRole, assignScope, syncClaims, setPermissionOverrides.
//
// NOTE: These must stay in sync with the Dart-side definitions:
//   - lib/core/rbac/roles.dart          → VALID_ROLES, role collections
//   - lib/core/rbac/scope_access_level.dart → SCOPE_ACCESS_LEVELS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Role Constants ────────────────────────────────────────────────────────────

export const VALID_ROLES = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
  'academic_supervisor', 'teacher', 'assistant_teacher', 'observer',
  'student', 'parent',
] as const;

export type KlasivoRole = typeof VALID_ROLES[number];

/** Roles that can assign roles to others. */
export const ROLE_ASSIGNMENT_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin',
];

/** Roles that can assign scope to others. */
export const SCOPE_ASSIGNMENT_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
];

/** Roles that can set permission overrides. */
export const OVERRIDE_ASSIGNMENT_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin',
];

/** Staff roles (non-student, non-parent, non-observer). */
export const STAFF_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
  'academic_supervisor', 'teacher', 'assistant_teacher',
];

/** Scoped roles — require campus/stage/class scope assignment. */
export const SCOPED_ROLES: KlasivoRole[] = [
  'campus_manager', 'stage_manager', 'academic_supervisor',
  'teacher', 'assistant_teacher',
];

/** Roles with all-access scope (no scope arrays needed). */
export const ALL_ACCESS_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin', 'observer',
];

// ─── Scope Access Level Mapping ───────────────────────────────────────────────
//
// Maps each role to its scopeAccessLevel for custom claims.
// Claim value convention: "class" (not "class_"), matching Dart's
// scopeAccessLevelToClaim() / scopeAccessLevelFromClaim().

export const SCOPE_ACCESS_LEVELS: Record<string, string> = {
  super_admin: 'all',
  owner: 'all',
  admin: 'all',
  campus_manager: 'campus',
  stage_manager: 'stage',
  academic_supervisor: 'stage',
  teacher: 'class',        // ← "class" in claims, NOT "class_"
  assistant_teacher: 'class',
  observer: 'all',
  student: 'self',
  parent: 'linked',
};

/**
 * Get the scopeAccessLevel for a role, with safe default.
 * Mirrors Dart's scopeAccessLevelForRole().
 */
export function getScopeAccessLevel(role: string): string {
  return SCOPE_ACCESS_LEVELS[role] || 'self';
}

/**
 * Check if a role string is a valid Klasivo role.
 */
export function isValidRole(role: string): boolean {
  return VALID_ROLES.includes(role as KlasivoRole);
}

/**
 * Build the custom claims object for setCustomUserClaims().
 * Only includes the three standard claims fields.
 */
export function buildCustomClaims(
  role: string,
  organizationId: string,
): Record<string, string> {
  return {
    role,
    organizationId,
    scopeAccessLevel: getScopeAccessLevel(role),
  };
}

/**
 * Verify that the caller belongs to the same organization as the target.
 * Super_admin is exempt (cross-org access).
 */
export function verifyOrgBoundary(
  callerOrgId: string,
  targetOrgId: string,
  callerRole: string,
): boolean {
  if (callerRole === 'super_admin') return true;
  // D8 PARTIAL FAIL-CLOSED: empty org IDs cannot match anything.
  if (!callerOrgId || !targetOrgId) return false;
  return callerOrgId === targetOrgId;
}

// ─── Role Hierarchy (Phase 2 D6) ───────────────────────────────────────────
//
// Ordinal rank for role comparison. Higher number = higher privilege.
// Used by changeUserPassword to prevent scoped accounts from resetting
// passwords of higher-privileged accounts (org takeover prevention).
//
// Must stay in sync with lib/core/rbac/role_hierarchy.dart.

export const ROLE_HIERARCHY: Record<string, number> = {
  super_admin: 90,
  owner: 80,
  admin: 70,
  campus_manager: 60,
  stage_manager: 50,
  academic_supervisor: 45,
  teacher: 40,
  assistant_teacher: 35,
  observer: 30,
  student: 20,
  parent: 10,
};

/**
 * Get the hierarchy ordinal for a role. Unknown roles default to 0
 * (lower than any known role — fail-closed for privilege checks).
 */
export function roleRank(role: string): number {
  return ROLE_HIERARCHY[role] ?? 0;
}

/**
 * Returns true if the caller's role is strictly higher than the target's role.
 * Equal roles do NOT count as "higher" — this prevents same-rank password resets.
 *
 * Examples:
 *   isHigherRole('owner', 'admin') → true
 *   isHigherRole('admin', 'admin') → false  (same rank — denied)
 *   isHigherRole('campus_manager', 'owner') → false  (caller LOWER — denied)
 *   isHigherRole('super_admin', 'owner') → true
 */
export function isHigherRole(callerRole: string, targetRole: string): boolean {
  return roleRank(callerRole) > roleRank(targetRole);
}

/**
 * Returns true if the caller's role is at least as high as the target's role.
 * Used for actions where same-rank is allowed (e.g., viewing).
 */
export function isAtLeastRole(callerRole: string, targetRole: string): boolean {
  return roleRank(callerRole) >= roleRank(targetRole);
}

// ─── Capability-Based Access Constants ────────────────────────────────────
//
// Single source of truth for role-based capability checks.
// Use these instead of inline role arrays to prevent hierarchy drift.
//
// TODO(Phase-2B): Add hasMinimumRole() and canPerformAction() helpers
// that use ROLE_HIERARCHY for ordinal comparison instead of inclusion checks.

/** Roles that can send teacher invitations (administrative onboarding action). */
export const INVITATION_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin',
];

/** Roles that can send school-wide announcements. */
export const ANNOUNCEMENT_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
];

/** Roles that can reset other users' passwords. */
export const PASSWORD_RESET_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
];

/**
 * Roles that receive roomAdmin grant in LiveKit tokens.
 *
 * roomAdmin grants classroom moderation: mute/unmute participants,
 * remove participants, and manage the classroom session.
 * If roomAdmin is extended to include recording control or room
 * metadata modification, consider narrowing this to supervisory
 * roles only (owner/admin/campus_manager/stage_manager).
 */
export const LIVEKIT_ADMIN_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin',
  'campus_manager', 'stage_manager',
  'academic_supervisor', 'teacher', 'assistant_teacher',
];

// ─── LiveKit Room Type Constants ─────────────────────────────────────────
//
// Explicit room types determine which authorization rules apply.
// Must stay in sync with Dart's RoomType enum in livekit_room_model.dart.

export const ROOM_TYPES = ['classroom', 'meeting', 'webinar'] as const;
export type RoomType = typeof ROOM_TYPES[number];

/** Room types that require scope-level authorization (classId mandatory). */
export const SCOPE_ENFORCED_ROOM_TYPES: RoomType[] = ['classroom'];

/** Room types that require only org-level authorization. */
export const ORG_ONLY_ROOM_TYPES: RoomType[] = ['meeting', 'webinar'];

// ─── Scope Authorization (Fail-Closed) ──────────────────────────────────
//
// Data-driven scope validation for LiveKit token issuance.
// Uses a lookup table for scopeAccessLevel → validation strategy,
// making future roles easier to add.
//
// PHILOSOPHY: Missing metadata on either the room OR the caller → DENY.
// This prevents rooms created before the migration from becoming bypasses.

/** Scope field on a room document, mapped by scopeAccessLevel. */
interface ScopeRequirement {
  /** The room field to check (e.g., 'classId'). */
  roomField: string;
  /** The caller's scope array field (e.g., 'classIds'). */
  callerField: string;
}

/**
 * Lookup table: scopeAccessLevel → which scope fields must match.
 *
 * Each entry maps a caller's scopeAccessLevel to the chain of
 * scope fields checked, from broadest to narrowest.
 *
 * The validator checks the narrowest applicable level.
 * If the room is missing the required field, the result is DENY.
 */
const SCOPE_REQUIREMENTS: Record<string, ScopeRequirement> = {
  campus: { roomField: 'campusId', callerField: 'campusIds' },
  stage:  { roomField: 'stageId',  callerField: 'stageIds' },
  class:  { roomField: 'classId',  callerField: 'classIds' },
  self:   { roomField: 'classId',  callerField: 'classIds' },
  linked: { roomField: 'classId',  callerField: 'classIds' },
};

/** Result of scope authorization check. */
export interface ScopeAuthResult {
  /** Whether the caller is authorized for this room. */
  authorized: boolean;
  /** Machine-readable reason for denial (empty if authorized). */
  reason?: 'missing_room_scope' | 'missing_caller_scope' | 'scope_mismatch' | 'room_type_mismatch';
  /** Human-readable explanation. */
  message?: string;
}

/**
 * Verify that a caller is authorized to access a specific room
 * based on their scope access level and the room's scope metadata.
 *
 * This function is FAIL-CLOSED:
 *   - Missing room scope metadata → DENY
 *   - Missing caller scope arrays → DENY
 *   - Empty caller scope arrays → DENY (not "all access")
 *   - Unknown scopeAccessLevel → DENY
 *   - Unknown roomType → DENY
 *
 * Only `scopeAccessLevel === 'all'` bypasses scope checks
 * (super_admin, owner, admin — org boundary already verified).
 *
 * @param scopeAccessLevel  Caller's scopeAccessLevel from claims
 * @param callerScope       Caller's scope arrays from Firestore user doc
 * @param roomData          Room document data from Firestore
 * @returns ScopeAuthResult with authorized flag and denial reason
 */
export function verifyScopeAuthorization(
  scopeAccessLevel: string,
  callerScope: Record<string, string[]>,
  roomData: Record<string, unknown>,
): ScopeAuthResult {
  // ── All-access roles: org boundary is sufficient ──────────
  if (scopeAccessLevel === 'all') {
    return { authorized: true };
  }

  const roomType = roomData['roomType'] as string;

  // ── Meeting/webinar: org-level only, no scope check ──────
  if (ORG_ONLY_ROOM_TYPES.includes(roomType as RoomType)) {
    // For meetings, verify caller is at least staff (not student/parent)
    if (scopeAccessLevel === 'self' || scopeAccessLevel === 'linked') {
      return {
        authorized: false,
        reason: 'scope_mismatch',
        message: 'Students and parents cannot access meeting rooms.',
      };
    }
    return { authorized: true };
  }

  // ── Classroom: scope validation required ──────────────────
  if (!SCOPE_ENFORCED_ROOM_TYPES.includes(roomType as RoomType)) {
    // Unknown room type — fail closed
    return {
      authorized: false,
      reason: 'room_type_mismatch',
      message: `Unknown room type: ${roomType}. Authorization denied.`,
    };
  }

  // Look up which scope fields to check for this access level
  const requirement = SCOPE_REQUIREMENTS[scopeAccessLevel];
  if (!requirement) {
    // Unknown scopeAccessLevel — fail closed
    return {
      authorized: false,
      reason: 'scope_mismatch',
      message: `Unknown scopeAccessLevel: ${scopeAccessLevel}. Authorization denied.`,
    };
  }

  // ── Check room has the required scope field ───────────────
  const roomScopeValue = roomData[requirement.roomField] as string | undefined;
  if (!roomScopeValue) {
    return {
      authorized: false,
      reason: 'missing_room_scope',
      message: `Room is missing ${requirement.roomField}. Cannot verify scope authorization.`,
    };
  }

  // ── Check caller has scope arrays ─────────────────────────
  const callerScopeArray = callerScope[requirement.callerField];
  if (!callerScopeArray || !Array.isArray(callerScopeArray)) {
    return {
      authorized: false,
      reason: 'missing_caller_scope',
      message: `Caller is missing ${requirement.callerField}. Cannot verify scope authorization.`,
    };
  }

  // ── Fail-closed: empty scope array = DENY ─────────────────
  if (callerScopeArray.length === 0) {
    return {
      authorized: false,
      reason: 'missing_caller_scope',
      message: `Caller has empty ${requirement.callerField}. Access denied (fail-closed).`,
    };
  }

  // ── Check scope match ─────────────────────────────────────
  if (!callerScopeArray.includes(roomScopeValue)) {
    return {
      authorized: false,
      reason: 'scope_mismatch',
      message: `Caller's ${requirement.callerField} does not include this room's ${requirement.roomField}.`,
    };
  }

  return { authorized: true };
}
