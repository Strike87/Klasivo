/**
 * Klasivo — Generate LiveKit Video/Audio Token
 *
 * Callable function (v2) that mints a LiveKit JWT access token
 * for an authenticated user to join a specific room.
 *
 * Grants:
 *   - All authenticated users: roomJoin, canPublish, canSubscribe, canPublishData
 *   - Teachers/owners: roomAdmin (mute participants, end room, etc.)
 *
 * Secrets: LIVEKIT_API_KEY, LIVEKIT_API_SECRET
 * Enforced: AppCheck, Auth
 */

import { onCall, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as Sentry from '@sentry/node';
import { AccessToken } from 'livekit-server-sdk';

import { initSentry } from '../config/sentry';

// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');

// ─── Types ────────────────────────────────────────────────────
interface LiveKitTokenRequest {
  roomName: string;
  displayName?: string;
  isTeacher?: boolean;
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
    const { roomName, displayName, isTeacher = false } = request.data ?? {};

    // ── Input validation ─────────────────────────────────────
    if (!roomName || typeof roomName !== 'string') {
      throw new Error('roomName is required and must be a string.');
    }

    // Room name sanitization — only alphanumeric, hyphens, underscores
    const sanitizedRoomName = roomName.replace(/[^a-zA-Z0-9_-]/g, '');
    if (sanitizedRoomName !== roomName || roomName.length === 0 || roomName.length > 128) {
      throw new Error('Invalid roomName. Use 1-128 chars: letters, digits, hyphens, underscores.');
    }

    Sentry.setTag('room', sanitizedRoomName);
    Sentry.setUser({ id: uid });

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
      roomAdmin: isTeacher,
    });

    const jwt = await token.toJwt();

    Sentry.addBreadcrumb({
      category: 'livekit',
      message: `Token generated for room ${sanitizedRoomName}`,
      level: 'info',
    });

    return { token: jwt };
  },
);
