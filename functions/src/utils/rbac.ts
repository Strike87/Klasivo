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
  return callerOrgId === targetOrgId;
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
