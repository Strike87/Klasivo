/**
 * Klasivo — Remove Participant from LiveKit Room
 *
 * Callable function (v2) that allows teachers to kick a disruptive
 * student from a live class. Uses LiveKit's RoomServiceClient to
 * forcibly remove the participant from the room, then updates
 * attendance records.
 *
 * Security:
 *   - enforceAppCheck: true
 *   - Caller must be authenticated with teacher/owner/admin role
 *   - Caller must belong to the same organization as the room
 */

import { onCall, CallableRequest } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';
import { RoomServiceClient } from 'livekit-server-sdk';

import { initSentry } from '../config/sentry';

// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = defineSecret('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = defineSecret('LIVEKIT_API_SECRET');

// ─── Types ────────────────────────────────────────────────────
interface RemoveParticipantRequest {
  roomName: string;
  participantIdentity: string;
  roomId: string;
}

const db = admin.firestore();

export const removeParticipant = onCall(
  {
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
  },
  async (request: CallableRequest<RemoveParticipantRequest>) => {
    initSentry();
    Sentry.setTag('service', 'livekit');
    Sentry.setTag('function', 'removeParticipant');

    // ── Auth check ───────────────────────────────────────────
    if (!request.auth) {
      throw new Error('User must be authenticated.');
    }

    const callerUid = request.auth.uid;

    // ── Verify caller is a teacher/owner/admin ───────────────
    const callerDoc = await db.collection('users').doc(callerUid).get();
    if (!callerDoc.exists) {
      throw new Error('User profile not found.');
    }

    const callerRole = callerDoc.data()?.['role'] as string;
    if (!['teacher', 'owner', 'admin'].includes(callerRole)) {
      Sentry.captureMessage(`Non-teacher ${callerUid} attempted to remove participant`);
      throw new Error('Only teachers can remove participants.');
    }

    const { roomName, participantIdentity, roomId } = request.data ?? {};

    if (!roomName || !participantIdentity || !roomId) {
      throw new Error('roomName, participantIdentity, and roomId are required.');
    }

    // ── Verify caller is in the same org as the room ─────────
    const roomDoc = await db.collection('livekit_rooms').doc(roomId).get();
    if (!roomDoc.exists) {
      throw new Error('Room not found.');
    }

    const roomOrgId = roomDoc.data()?.['organizationId'] as string;
    const callerOrgId = callerDoc.data()?.['organizationId'] as string;
    if (roomOrgId !== callerOrgId) {
      throw new Error('You can only remove participants from rooms in your organization.');
    }

    Sentry.setTag('room', roomName);
    Sentry.setUser({ id: callerUid });

    // ── Remove participant via LiveKit SDK ────────────────────
    const livekitUrl = roomDoc.data()?.['metadata']?.['livekitUrl'] as string
      ?? 'https://klasivo.livekit.cloud';

    const roomService = new RoomServiceClient(
      livekitUrl.replace('wss://', 'https://'),
      LIVEKIT_API_KEY.value(),
      LIVEKIT_API_SECRET.value(),
    );

    try {
      await roomService.removeParticipant(roomName, participantIdentity);
      console.log(`Removed participant ${participantIdentity} from room ${roomName}`);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      console.error(`Failed to remove participant ${participantIdentity}: ${msg}`);
      // Participant might have already left — continue to update attendance
    }

    // ── Update attendance record ─────────────────────────────
    try {
      await db
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('attendance')
        .doc(participantIdentity)
        .update({
          leftAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          removedBy: callerUid,
          removedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (err: unknown) {
      // Attendance doc might not exist — non-critical
      console.warn(`Could not update attendance for ${participantIdentity}: ${err}`);
    }

    // ── Send notification to removed participant ─────────────
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

    Sentry.addBreadcrumb({
      category: 'livekit',
      message: `Participant ${participantIdentity} removed from room ${roomName}`,
      level: 'info',
    });

    return { success: true, removedIdentity: participantIdentity };
  },
);
