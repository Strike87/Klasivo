/**
 * Klasivo — Generate LiveKit Video/Audio Token
 *
 * Callable function (v2) that mints a LiveKit JWT access token
 * for an authenticated user to join a specific room.
 *
 * Security chain:
 *   1. Auth required (enforceAppCheck DISABLED — no client AppCheck init)
 *   2. Room document loaded by roomId (client cannot choose roomName)
 *   3. Org boundary: caller must belong to room's organization
 *   4. Scope authorization: caller must have access to room's scope
 *      - classroom: classId required on room, must be in caller's classIds
 *      - meeting/webinar: org boundary only (staff only, no students/parents)
 *      - ALL checks fail-closed: missing metadata = DENY
 *   5. Server-side role determination (from claims, not client input)
 *
 * Grants:
 *   - All authenticated users: roomJoin, canPublish, canSubscribe, canPublishData
 *   - Staff roles (LIVEKIT_ADMIN_ROLES): roomAdmin (mute/remove/end room)
 *
 * Secrets: LIVEKIT_API_KEY, LIVEKIT_API_SECRET
 * Enforced: AppCheck, Auth
 */

import { onCall, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';
import { AccessToken } from 'livekit-server-sdk';

import { initSentry, withIsolatedScope } from '../config/sentry';
import { verifyOrgBoundary, verifyScopeAuthorization, LIVEKIT_ADMIN_ROLES } from '../utils/rbac';

// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');

// ─── Types ────────────────────────────────────────────────────
interface LiveKitTokenRequest {
  roomId: string;          // Required — server derives roomName from Firestore
  displayName?: string;
}

interface LiveKitTokenResponse {
  token: string;
}

// ─── Function ─────────────────────────────────────────────────
export const generateLiveKitToken = onCall(
  {
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    // enforceAppCheck: true — DISABLED: client has no FirebaseAppCheck init
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 50,     // Cap to prevent runaway billing
    concurrency: 100,     // High concurrency — v2 supports up to 1000
    cpu: 1,               // Full CPU for fast JWT signing
  },
  async (request: CallableRequest<LiveKitTokenRequest>): Promise<LiveKitTokenResponse> => {
    initSentry();
    return withIsolatedScope(async (scope) => {
    scope.setTag('service', 'livekit');
    scope.setTag('function', 'generateLiveKitToken');

    // ── Auth check ───────────────────────────────────────────
    if (!request.auth) {
      Sentry.captureMessage('Unauthenticated LiveKit token request');
      throw new Error('User must be authenticated.');
    }

    const uid = request.auth.uid;
    const { roomId, displayName } = request.data ?? {};

    // ── Input validation ─────────────────────────────────────
    if (!roomId || typeof roomId !== 'string') {
      throw new Error('roomId is required and must be a string.');
    }

    // ── Load room document ───────────────────────────────────
    const db = admin.firestore();
    const roomDoc = await db.collection('livekit_rooms').doc(roomId).get();

    if (!roomDoc.exists) {
      throw new Error('Room not found.');
    }

    // Derive roomName from the trusted room document (not from client)
    const roomData = roomDoc.data()!;
    const roomName = roomData['name'] as string;
    if (!roomName) {
      throw new Error('Room document is missing a name field.');
    }

    // Room name sanitization — only alphanumeric, hyphens, underscores
    const sanitizedRoomName = roomName.replace(/[^a-zA-Z0-9_-]/g, '');
    if (sanitizedRoomName.length === 0 || sanitizedRoomName.length > 128) {
      throw new Error('Invalid room name in document. Use 1-128 chars: letters, digits, hyphens, underscores.');
    }

    scope.setTag('room', sanitizedRoomName);
    scope.setUser({ id: uid });

    // ── Org boundary check ───────────────────────────────────
    const callerOrgId = (request.auth.token.organizationId as string) || '';
    const roomOrgId = roomData['organizationId'] as string;
    const callerRole = (request.auth.token.role as string) || '';
    const scopeAccessLevel = (request.auth.token.scopeAccessLevel as string) || '';

    if (!verifyOrgBoundary(callerOrgId, roomOrgId, callerRole)) {
      await _logTokenDenied(db, uid, callerRole, callerOrgId, roomId, 'org_boundary', 'Cross-org access denied');
      Sentry.captureMessage(`Cross-org LiveKit token attempt: caller=${callerOrgId} room=${roomOrgId}`);
      throw new Error('You can only join rooms in your organization.');
    }

    // ── Scope authorization ──────────────────────────────────
    // Load caller's scope arrays from Firestore user doc
    const callerDoc = await db.collection('users').doc(uid).get();
    const callerScope: Record<string, string[]> = {};
    if (callerDoc.exists) {
      const callerData = callerDoc.data()!;
      callerScope['campusIds'] = callerData['campusIds'] as string[] || [];
      callerScope['stageIds'] = callerData['stageIds'] as string[] || [];
      callerScope['classIds'] = callerData['classIds'] as string[] || [];
      callerScope['subjectIds'] = callerData['subjectIds'] as string[] || [];
      callerScope['studentIds'] = callerData['studentIds'] as string[] || [];
    }

    const scopeResult = verifyScopeAuthorization(
      scopeAccessLevel,
      callerScope,
      roomData as Record<string, unknown>,
    );

    if (!scopeResult.authorized) {
      await _logTokenDenied(db, uid, callerRole, callerOrgId, roomId, scopeResult.reason ?? 'unknown', scopeResult.message ?? 'Scope authorization failed');
      Sentry.captureMessage(`LiveKit scope denial: uid=${uid} room=${roomId} reason=${scopeResult.reason}`);
      throw new Error(scopeResult.message || 'You are not authorized to access this room.');
    }

    // ── Server-side role determination ────────────────────────
    // roomAdmin grants classroom moderation: mute/unmute, remove participants,
    // end room. Determined from caller's claims, NOT from client input.
    const isTeacherOrAbove = LIVEKIT_ADMIN_ROLES.includes(callerRole as any);

    // ── Build token ──────────────────────────────────────────
    const token = new AccessToken(
      LIVEKIT_API_KEY.value(),
      LIVEKIT_API_SECRET.value(),
      {
        identity: uid,
        name: displayName || uid,
      },
    );

    token.addGrant({
      room: sanitizedRoomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      roomAdmin: isTeacherOrAbove,
    });

    const jwt = await token.toJwt();

    Sentry.addBreadcrumb({
      category: 'livekit',
      message: `Token generated for room ${sanitizedRoomName}, roomAdmin=${isTeacherOrAbove}`,
      level: 'info',
    });

    return { token: jwt };
    }); // withIsolatedScope
  },
);

// ─── Audit Helper ─────────────────────────────────────────────

/**
 * Write an audit event when a LiveKit token is denied.
 * These events are invaluable for monitoring and debugging
 * during scope authorization rollout.
 */
async function _logTokenDenied(
  db: admin.firestore.Firestore,
  uid: string,
  role: string,
  orgId: string,
  roomId: string,
  reason: string,
  message: string,
): Promise<void> {
  try {
    await db.collection('audit_logs').add({
      organizationId: orgId,
      performedBy: uid,
      performedByRole: role,
      performedByOrgId: orgId,
      action: 'livekit_token_denied',
      targetType: 'livekit_room',
      targetId: roomId,
      metadata: { reason, message },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch {
    // Audit logging failure should never block the denial
    console.warn('Failed to write livekit_token_denied audit event');
  }
}
