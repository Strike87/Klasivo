/**
 * Klasivo — API Gateway (Express on Firebase Functions)
 *
 * Serves all REST endpoints under api.klasivo.app via Firebase Hosting rewrites.
 * This is the single `onRequest` entry point; Firebase Hosting routes all
 * traffic from api.klasivo.app/* → this function.
 *
 * Routes:
 *   GET  /health              → Health check
 *   POST /livekit/token       → Generate LiveKit JWT
 *   POST /livekit/remove      → Remove participant from room
 *
 * Security:
 *   - All mutation endpoints verify Firebase ID tokens (Authorization: Bearer <token>)
 *   - Rate limiting is handled at Cloudflare level
 *   - Security headers applied via Firebase Hosting headers config
 *
 * Note: OTP endpoints are intentionally omitted for launch.
 *       Firebase Authentication handles phone/SMS verification natively.
 *       Custom OTP can be added later when a dedicated SMS provider is needed.
 */

import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as Sentry from '@sentry/node';
import express, { Request, Response, NextFunction } from 'express';

import { initSentry } from '../config/sentry';

// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');

// ─── Extend Express Request ─────────────────────────────────────
declare global {
  namespace Express {
    interface Request {
      user?: admin.auth.DecodedIdToken;
      userRole?: string;
      userOrgId?: string;
    }
  }
}

// ─── Express setup ──────────────────────────────────────────────
const app = express();
app.use(express.json());

// ─── Auth middleware ────────────────────────────────────────────

async function verifyAuthToken(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res
      .status(401)
      .json({
        error:
          'Missing or invalid Authorization header. Use: Bearer <Firebase ID token>',
      });
    return;
  }

  const idToken = authHeader.split('Bearer ')[1];
  if (!idToken) {
    res.status(401).json({ error: 'Empty bearer token.' });
    return;
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;

    const userDoc = await admin
      .firestore()
      .collection('users')
      .doc(decodedToken.uid)
      .get();
    if (userDoc.exists) {
      req.userRole = userDoc.data()?.['role'] as string | undefined;
      req.userOrgId = userDoc.data()?.['organizationId'] as string | undefined;
    }

    next();
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Token verification failed: ${msg}`);
    res.status(401).json({ error: 'Invalid or expired token.' });
  }
}

// ─── Health Check ───────────────────────────────────────────────

app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ─── LiveKit Routes ─────────────────────────────────────────────

app.post(
  '/livekit/token',
  verifyAuthToken,
  async (req: Request, res: Response) => {
    initSentry();
    Sentry.setTag('service', 'livekit');
    Sentry.setTag('endpoint', '/livekit/token');

    if (!req.user) {
      res.status(401).json({ error: 'Authentication required.' });
      return;
    }

    const { roomName, displayName, isTeacher } = req.body ?? {};

    if (!roomName || typeof roomName !== 'string') {
      res
        .status(400)
        .json({ error: 'roomName is required and must be a string.' });
      return;
    }

    const sanitizedRoomName = roomName.replace(/[^a-zA-Z0-9_-]/g, '');
    if (
      sanitizedRoomName !== roomName ||
      roomName.length === 0 ||
      roomName.length > 128
    ) {
      res
        .status(400)
        .json({
          error:
            'Invalid roomName. Use 1-128 chars: letters, digits, hyphens, underscores.',
        });
      return;
    }

    try {
      const { AccessToken } = await import('livekit-server-sdk');

      const token = new AccessToken(
        LIVEKIT_API_KEY.value(),
        LIVEKIT_API_SECRET.value(),
        {
          identity: req.user.uid,
          name: displayName || req.user.uid,
        },
      );

      const isTeacherOrAbove =
        isTeacher === true ||
        req.userRole === 'teacher' ||
        req.userRole === 'owner' ||
        req.userRole === 'admin';

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
        message: `Token generated for room ${sanitizedRoomName}`,
        level: 'info',
      });

      res.json({ token: jwt });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`LiveKit token generation failed: ${msg}`);
      Sentry.captureException(err);
      res.status(500).json({ error: 'Failed to generate token.' });
    }
  },
);

app.post(
  '/livekit/remove',
  verifyAuthToken,
  async (req: Request, res: Response) => {
    initSentry();
    Sentry.setTag('service', 'livekit');
    Sentry.setTag('endpoint', '/livekit/remove');

    if (!req.user) {
      res.status(401).json({ error: 'Authentication required.' });
      return;
    }

    if (!['teacher', 'owner', 'admin'].includes(req.userRole ?? '')) {
      res
        .status(403)
        .json({ error: 'Only teachers can remove participants.' });
      return;
    }

    const { roomName, participantIdentity, roomId } = req.body ?? {};

    if (!roomName || !participantIdentity || !roomId) {
      res
        .status(400)
        .json({ error: 'roomName, participantIdentity, and roomId are required.' });
      return;
    }

    try {
      const { RoomServiceClient } = await import('livekit-server-sdk');
      const db = admin.firestore();
      const roomDoc = await db.collection('livekit_rooms').doc(roomId).get();

      if (!roomDoc.exists) {
        res.status(404).json({ error: 'Room not found.' });
        return;
      }

      const roomOrgId = roomDoc.data()?.['organizationId'] as string;
      if (roomOrgId !== req.userOrgId) {
        res
          .status(403)
          .json({
            error:
              'You can only remove participants from rooms in your organization.',
          });
        return;
      }

      const livekitUrl =
        (roomDoc.data()?.['metadata']?.['livekitUrl'] as string) ??
        'https://klasivo.livekit.cloud';

      const roomService = new RoomServiceClient(
        livekitUrl.replace('wss://', 'https://'),
        LIVEKIT_API_KEY.value(),
        LIVEKIT_API_SECRET.value(),
      );

      try {
        await roomService.removeParticipant(roomName, participantIdentity);
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        console.warn(
          `Failed to remove participant ${participantIdentity}: ${msg}`,
        );
      }

      // Update attendance
      try {
        await db
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('attendance')
          .doc(participantIdentity)
          .update({
            leftAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            removedBy: req.user.uid,
            removedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      } catch (err: unknown) {
        console.warn(
          `Could not update attendance for ${participantIdentity}: ${err}`,
        );
      }

      // Create in-app notification
      try {
        await db.collection('notifications').add({
          userId: participantIdentity,
          type: 'removed_from_class',
          title: 'Removed from Class',
          body: `You have been removed from the live class "${roomDoc.data()?.['name'] ?? roomName}".`,
          data: { roomId, roomName },
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err: unknown) {
        console.warn(`Could not create removal notification: ${err}`);
      }

      res.json({ success: true, removedIdentity: participantIdentity });
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`Remove participant failed: ${msg}`);
      Sentry.captureException(err);
      res.status(500).json({ error: 'Failed to remove participant.' });
    }
  },
);

// ─── 404 Catch-all ──────────────────────────────────────────────

app.use((_req: Request, res: Response) => {
  res.status(404).json({
    error: 'Not Found',
    availableEndpoints: [
      'GET  /health',
      'POST /livekit/token',
      'POST /livekit/remove',
    ],
  });
});

// ─── Export as Firebase Function ─────────────────────────────────

export const api = onRequest(
  {
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    region: 'us-central1',
    cors: true,
  },
  app,
);
