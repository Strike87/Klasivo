export declare const VALID_ROLES: readonly ["super_admin", "owner", "admin", "campus_manager", "stage_manager", "academic_supervisor", "teacher", "assistant_teacher", "observer", "student", "parent"];
export type KlasivoRole = typeof VALID_ROLES[number];
/** Roles that can assign roles to others. */
export declare const ROLE_ASSIGNMENT_ROLES: KlasivoRole[];
/** Roles that can assign scope to others. */
export declare const SCOPE_ASSIGNMENT_ROLES: KlasivoRole[];
/** Roles that can set permission overrides. */
export declare const OVERRIDE_ASSIGNMENT_ROLES: KlasivoRole[];
/** Staff roles (non-student, non-parent, non-observer). */
export declare const STAFF_ROLES: KlasivoRole[];
/** Scoped roles — require campus/stage/class scope assignment. */
export declare const SCOPED_ROLES: KlasivoRole[];
/** Roles with all-access scope (no scope arrays needed). */
export declare const ALL_ACCESS_ROLES: KlasivoRole[];
export declare const SCOPE_ACCESS_LEVELS: Record<string, string>;
/**
 * Get the scopeAccessLevel for a role, with safe default.
 * Mirrors Dart's scopeAccessLevelForRole().
 */
export declare function getScopeAccessLevel(role: string): string;
/**
 * Check if a role string is a valid Klasivo role.
 */
export declare function isValidRole(role: string): boolean;
/**
 * Build the custom claims object for setCustomUserClaims().
 * Only includes the three standard claims fields.
 */
export declare function buildCustomClaims(role: string, organizationId: string): Record<string, string>;
/**
 * Verify that the caller belongs to the same organization as the target.
 * Super_admin is exempt (cross-org access).
 */
export declare function verifyOrgBoundary(callerOrgId: string, targetOrgId: string, callerRole: string): boolean;
/** Roles that can send teacher invitations (administrative onboarding action). */
export declare const INVITATION_ROLES: KlasivoRole[];
/** Roles that can send school-wide announcements. */
export declare const ANNOUNCEMENT_ROLES: KlasivoRole[];
/** Roles that can reset other users' passwords. */
export declare const PASSWORD_RESET_ROLES: KlasivoRole[];
/**
 * Roles that receive roomAdmin grant in LiveKit tokens.
 *
 * roomAdmin grants classroom moderation: mute/unmute participants,
 * remove participants, and manage the classroom session.
 * If roomAdmin is extended to include recording control or room
 * metadata modification, consider narrowing this to supervisory
 * roles only (owner/admin/campus_manager/stage_manager).
 */
export declare const LIVEKIT_ADMIN_ROLES: KlasivoRole[];
export declare const ROOM_TYPES: readonly ["classroom", "meeting", "webinar"];
export type RoomType = typeof ROOM_TYPES[number];
/** Room types that require scope-level authorization (classId mandatory). */
export declare const SCOPE_ENFORCED_ROOM_TYPES: RoomType[];
/** Room types that require only org-level authorization. */
export declare const ORG_ONLY_ROOM_TYPES: RoomType[];
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
export declare function verifyScopeAuthorization(scopeAccessLevel: string, callerScope: Record<string, string[]>, roomData: Record<string, unknown>): ScopeAuthResult;
