import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';

import {
  OVERRIDE_ASSIGNMENT_ROLES,
  isValidRole,
  verifyOrgBoundary,
  type KlasivoRole,
} from '../utils/rbac';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RBAC v2.0 — setPermissionOverrides (v2 callable)
//
// Sets or clears permission overrides for a user.
//
// Permission overrides allow fine-grained control beyond role-based defaults:
//   - { "exam:publish": false } → Deny exam publishing even if role allows it
//   - { "exam:create": true }   → Grant exam creation even if role lacks it
//
// Stored on the Firestore user doc as permissionOverrides: Map<String, bool>
//
// Security:
//   - Only super_admin, owner, admin can set overrides
//   - Caller must be in the same organization (unless super_admin)
//   - Override keys must be valid permission strings (colon notation)
//   - Admin cannot set overrides for super_admin or owner
// ═══════════════════════════════════════════════════════════════════════════════

interface SetPermissionOverridesData {
  targetUserId: string;
  organizationId: string;
  overrides: Record<string, boolean>;
  /** If true, replaces all existing overrides. If false (default), merges. */
  replace?: boolean;
}

// Basic validation: permission strings must match "category:action" pattern
const PERMISSION_RE = /^[a-z_]+:[a-z_]+$/;
const WILDCARD = '*';

function isValidPermissionKey(key: string): boolean {
  if (key === WILDCARD) return true;
  return PERMISSION_RE.test(key);
}

export const setPermissionOverrides = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    concurrency: 80,
  },
  async (request: CallableRequest<SetPermissionOverridesData>) => {
    // ─── Auth Check ─────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const callerUid = request.auth.uid;
    const callerClaims = request.auth.token;
    const callerRole = (callerClaims.role as string) || '';

    if (!OVERRIDE_ASSIGNMENT_ROLES.includes(callerRole as KlasivoRole)) {
      throw new HttpsError(
        'permission-denied',
        'Only super_admin, owner, or admin can set permission overrides.',
      );
    }

    // ─── Input Validation ───────────────────────────────────────────────
    const { targetUserId, organizationId, overrides, replace = false } = request.data;

    if (!targetUserId || !organizationId || overrides === undefined) {
      throw new HttpsError(
        'invalid-argument',
        'targetUserId, organizationId, and overrides are required.',
      );
    }

    // Validate override keys
    const overrideEntries = Object.entries(overrides);
    for (const [key, value] of overrideEntries) {
      if (typeof value !== 'boolean') {
        throw new HttpsError(
          'invalid-argument',
          `Override value for "${key}" must be a boolean, got ${typeof value}.`,
        );
      }
      if (!isValidPermissionKey(key)) {
        throw new HttpsError(
          'invalid-argument',
          `Invalid permission key: "${key}". Must match "category:action" pattern or be "*".`,
        );
      }
    }

    // ─── Org Boundary ───────────────────────────────────────────────────
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (!verifyOrgBoundary(callerOrgId, organizationId, callerRole)) {
      throw new HttpsError(
        'permission-denied',
        'Cannot set overrides for users in a different organization.',
      );
    }

    // ─── Get Target User ────────────────────────────────────────────────
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', `User ${targetUserId} not found.`);
    }

    const userData = userDoc.data()!;
    const targetRole = userData.role || 'unknown';

    // Admin cannot set overrides for super_admin or owner
    if (callerRole === 'admin' && ['super_admin', 'owner'].includes(targetRole)) {
      throw new HttpsError(
        'permission-denied',
        'Admins cannot set permission overrides for super_admin or owner.',
      );
    }

    // ─── Build Override Map ─────────────────────────────────────────────
    let finalOverrides: Record<string, boolean>;

    if (replace) {
      finalOverrides = { ...overrides };
    } else {
      const existingOverrides = (userData.permissionOverrides || {}) as Record<string, boolean>;
      finalOverrides = { ...existingOverrides, ...overrides };
    }

    // ─── Update Firestore ───────────────────────────────────────────────
    await db.collection('users').doc(targetUserId).update({
      permissionOverrides: finalOverrides,
      roleVersion: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ─── Audit Log ──────────────────────────────────────────────────────
    await db.collection('audit_logs').add({
      organizationId: organizationId,
      performedBy: callerUid,
      performedByRole: callerRole,
      performedByOrgId: (callerClaims.organizationId as string) || organizationId,
      userId: callerUid,
      action: 'set_permission_overrides',
      targetType: 'user',
      targetId: targetUserId,
      metadata: {
        targetRole: targetRole,
        overrides: finalOverrides,
        replace: replace,
        overrideCount: Object.keys(finalOverrides).length,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      targetUserId,
      overrides: finalOverrides,
      overrideCount: Object.keys(finalOverrides).length,
    };
  });
