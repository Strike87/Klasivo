"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ORG_ONLY_ROOM_TYPES = exports.SCOPE_ENFORCED_ROOM_TYPES = exports.ROOM_TYPES = exports.LIVEKIT_ADMIN_ROLES = exports.PASSWORD_RESET_ROLES = exports.ANNOUNCEMENT_ROLES = exports.INVITATION_ROLES = exports.SCOPE_ACCESS_LEVELS = exports.ALL_ACCESS_ROLES = exports.SCOPED_ROLES = exports.STAFF_ROLES = exports.OVERRIDE_ASSIGNMENT_ROLES = exports.SCOPE_ASSIGNMENT_ROLES = exports.ROLE_ASSIGNMENT_ROLES = exports.VALID_ROLES = void 0;
exports.getScopeAccessLevel = getScopeAccessLevel;
exports.isValidRole = isValidRole;
exports.buildCustomClaims = buildCustomClaims;
exports.verifyOrgBoundary = verifyOrgBoundary;
exports.verifyScopeAuthorization = verifyScopeAuthorization;
// ─── Role Constants ────────────────────────────────────────────────────────────
exports.VALID_ROLES = [
    'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
    'academic_supervisor', 'teacher', 'assistant_teacher', 'observer',
    'student', 'parent',
];
/** Roles that can assign roles to others. */
exports.ROLE_ASSIGNMENT_ROLES = [
    'super_admin', 'owner', 'admin',
];
/** Roles that can assign scope to others. */
exports.SCOPE_ASSIGNMENT_ROLES = [
    'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
];
/** Roles that can set permission overrides. */
exports.OVERRIDE_ASSIGNMENT_ROLES = [
    'super_admin', 'owner', 'admin',
];
/** Staff roles (non-student, non-parent, non-observer). */
exports.STAFF_ROLES = [
    'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
    'academic_supervisor', 'teacher', 'assistant_teacher',
];
/** Scoped roles — require campus/stage/class scope assignment. */
exports.SCOPED_ROLES = [
    'campus_manager', 'stage_manager', 'academic_supervisor',
    'teacher', 'assistant_teacher',
];
/** Roles with all-access scope (no scope arrays needed). */
exports.ALL_ACCESS_ROLES = [
    'super_admin', 'owner', 'admin', 'observer',
];
// ─── Scope Access Level Mapping ───────────────────────────────────────────────
//
// Maps each role to its scopeAccessLevel for custom claims.
// Claim value convention: "class" (not "class_"), matching Dart's
// scopeAccessLevelToClaim() / scopeAccessLevelFromClaim().
exports.SCOPE_ACCESS_LEVELS = {
    super_admin: 'all',
    owner: 'all',
    admin: 'all',
    campus_manager: 'campus',
    stage_manager: 'stage',
    academic_supervisor: 'stage',
    teacher: 'class', // ← "class" in claims, NOT "class_"
    assistant_teacher: 'class',
    observer: 'all',
    student: 'self',
    parent: 'linked',
};
/**
 * Get the scopeAccessLevel for a role, with safe default.
 * Mirrors Dart's scopeAccessLevelForRole().
 */
function getScopeAccessLevel(role) {
    return exports.SCOPE_ACCESS_LEVELS[role] || 'self';
}
/**
 * Check if a role string is a valid Klasivo role.
 */
function isValidRole(role) {
    return exports.VALID_ROLES.includes(role);
}
/**
 * Build the custom claims object for setCustomUserClaims().
 * Only includes the three standard claims fields.
 */
function buildCustomClaims(role, organizationId) {
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
function verifyOrgBoundary(callerOrgId, targetOrgId, callerRole) {
    if (callerRole === 'super_admin')
        return true;
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
exports.INVITATION_ROLES = [
    'super_admin', 'owner', 'admin',
];
/** Roles that can send school-wide announcements. */
exports.ANNOUNCEMENT_ROLES = [
    'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
];
/** Roles that can reset other users' passwords. */
exports.PASSWORD_RESET_ROLES = [
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
exports.LIVEKIT_ADMIN_ROLES = [
    'super_admin', 'owner', 'admin',
    'campus_manager', 'stage_manager',
    'academic_supervisor', 'teacher', 'assistant_teacher',
];
// ─── LiveKit Room Type Constants ─────────────────────────────────────────
//
// Explicit room types determine which authorization rules apply.
// Must stay in sync with Dart's RoomType enum in livekit_room_model.dart.
exports.ROOM_TYPES = ['classroom', 'meeting', 'webinar'];
/** Room types that require scope-level authorization (classId mandatory). */
exports.SCOPE_ENFORCED_ROOM_TYPES = ['classroom'];
/** Room types that require only org-level authorization. */
exports.ORG_ONLY_ROOM_TYPES = ['meeting', 'webinar'];
/**
 * Lookup table: scopeAccessLevel → which scope fields must match.
 *
 * Each entry maps a caller's scopeAccessLevel to the chain of
 * scope fields checked, from broadest to narrowest.
 *
 * The validator checks the narrowest applicable level.
 * If the room is missing the required field, the result is DENY.
 */
const SCOPE_REQUIREMENTS = {
    campus: { roomField: 'campusId', callerField: 'campusIds' },
    stage: { roomField: 'stageId', callerField: 'stageIds' },
    class: { roomField: 'classId', callerField: 'classIds' },
    self: { roomField: 'classId', callerField: 'classIds' },
    linked: { roomField: 'classId', callerField: 'classIds' },
};
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
function verifyScopeAuthorization(scopeAccessLevel, callerScope, roomData) {
    // ── All-access roles: org boundary is sufficient ──────────
    if (scopeAccessLevel === 'all') {
        return { authorized: true };
    }
    const roomType = roomData['roomType'];
    // ── Meeting/webinar: org-level only, no scope check ──────
    if (exports.ORG_ONLY_ROOM_TYPES.includes(roomType)) {
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
    if (!exports.SCOPE_ENFORCED_ROOM_TYPES.includes(roomType)) {
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
    const roomScopeValue = roomData[requirement.roomField];
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
//# sourceMappingURL=rbac.js.map