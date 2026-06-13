/**
 * Klasivo — Generate LiveKit Video/Audio Token
 *
 * Callable function (v2) that mints a LiveKit JWT access token
 * for an authenticated user to join a specific room.
 *
 * Security chain:
 *   1. Auth required (enforceAppCheck)
 *   2. Room document loaded by roomId (client cannot choose roomName)
 *   3. Org boundary: caller must belong to room's organization
 *   4. Server-side role determination (isTeacher from claims, not client)
 *   5. TODO(Phase-2A-cont): Scope-level authorization (requires classId/stageId on rooms)
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

import { initSentry } from '../config/sentry';
import { verifyOrgBoundary, LIVEKIT_ADMIN_ROLES } from '../utils/rbac';

// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');

// ─── Types ────────────────────────────────────────────────────
interface LiveKitTokenRequest {
  roomId: string;          // Required — server derives roomName from Firestore
  displayName?: string;
  // roomName: REMOVED — derived from room document
  // isTeacher: REMOVED — determined server-side from caller's role
}

interface LiveKitTokenResponse {
  token: string;
}

// ─── Function ─────────────────────────────────────────────────
export const generateLiveKitToken = onCall(
  {
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
  },
  async (request: CallableRequest<LiveKitTokenRequest>): Promise<LiveKitTokenResponse> => {
    initSentry();
    Sentry.setTag('service', 'livekit');
    Sentry.setTag('function', 'generateLiveKitToken');

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

    Sentry.setTag('room', sanitizedRoomName);
    Sentry.setUser({ id: uid });

    // ── Org boundary check ───────────────────────────────────
    const callerOrgId = (request.auth.token.organizationId as string) || '';
    const roomOrgId = roomData['organizationId'] as string;
    const callerRole = (request.auth.token.role as string) || '';

    if (!verifyOrgBoundary(callerOrgId, roomOrgId, callerRole)) {
      Sentry.captureMessage(`Cross-org LiveKit token attempt: caller=${callerOrgId} room=${roomOrgId}`);
      throw new Error('You can only join rooms in your organization.');
    }

    // ── Server-side role determination ────────────────────────
    // roomAdmin grants classroom moderation: mute/unmute, remove participants,
    // end room. Determined from caller's claims, NOT from client input.
    const isTeacherOrAbove = LIVEKIT_ADMIN_ROLES.includes(callerRole as any);

    // TODO(Phase-2A-cont): Add scope-level authorization here once
    // livekit_rooms have classId/stageId/subjectId fields. Flow:
    //   1. Read caller's scope arrays from users/{uid}
    //   2. Check room.classId against caller.classIds (for class-scoped roles)
    //   3. Check room.campusId against caller.campusIds (for campus-scoped roles)
    //   4. Use fail-closed logic: empty scope array = DENY, not "all access"
    //   5. Students: verify classId is in their enrolled classIds
    //   6. Parents: verify studentId is in their linked studentIds

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
  },
);
