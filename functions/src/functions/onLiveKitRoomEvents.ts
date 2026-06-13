/**
 * Klasivo — Notify Students When a Live Class Starts
 *
 * Firestore trigger (v2) that fires when a new `livekit_rooms` document
 * is created with `isActive: true`. It sends push notifications to all
 * students in the organization via FCM.
 *
 * Also handles:
 *   - Session recording start/stop notifications
 *   - Attendance summary when a room ends
 */

import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';

import { initSentry } from '../config/sentry';

const db = admin.firestore();

// ─── When a new live class room is created ─────────────────────

export const onLiveKitRoomCreated = onDocumentCreated(
  {
    document: 'livekit_rooms/{roomId}',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
  },
  async (event) => {
    initSentry();
    Sentry.setTag('service', 'livekit');
    Sentry.setTag('function', 'onLiveKitRoomCreated');

    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    if (!data) return;

    // Only notify if the room is active (not a draft)
    if (data['isActive'] !== true) return;

    const orgId = data['organizationId'] as string | undefined;
    const roomName = data['name'] as string | undefined;
    const roomType = data['roomType'] as string | undefined;
    const createdBy = data['createdBy'] as string | undefined;

    if (!orgId || !roomName) return;

    console.log(`New live class started: "${roomName}" in org ${orgId}`);

    try {
      // Get the teacher's name
      let teacherName = 'A teacher';
      if (createdBy) {
        const teacherDoc = await db.collection('users').doc(createdBy).get();
        if (teacherDoc.exists) {
          teacherName = teacherDoc.data()?.['fullName'] ?? teacherName;
        }
      }

      // Find all students in the organization
      const studentsSnapshot = await db
        .collection('users')
        .where('organizationId', '==', orgId)
        .where('role', '==', 'student')
        .where('isActive', '==', true)
        .get();

      if (studentsSnapshot.empty) {
        console.log('No active students found in org — skipping notifications');
        return;
      }

      // Collect FCM tokens
      const tokens: string[] = [];
      const userIds: string[] = [];

      for (const doc of studentsSnapshot.docs) {
        const fcmToken = doc.data()?.['fcmToken'] as string | undefined;
        if (fcmToken) {
          tokens.push(fcmToken);
          userIds.push(doc.id);
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for students — skipping notifications');
        return;
      }

      // Build notification
      const typeLabel = roomType === 'exam_proctoring' ? 'Proctored Exam' : 'Live Class';
      const notification = {
        title: `${typeLabel} Starting: ${roomName}`,
        body: `${teacherName} has started "${roomName}". Tap to join!`,
      };

      // Send multicast
      const message: admin.messaging.MulticastMessage = {
        notification,
        data: {
          type: 'live_class_started',
          roomId: snapshot.id,
          orgId,
          roomName,
          roomType: roomType ?? 'classroom',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        tokens,
        android: {
          priority: 'high',
          notification: {
            channelId: 'live_classes',
            icon: 'ic_notification',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Push notifications sent: ${response.successCount}/${tokens.length} successful`);

      // Create in-app notifications for students without FCM tokens too
      const batch = db.batch();
      for (const uid of userIds) {
        const notifRef = db.collection('notifications').doc();
        batch.set(notifRef, {
          userId: uid,
          type: 'live_class_started',
          title: notification.title,
          body: notification.body,
          data: {
            roomId: snapshot.id,
            orgId,
            roomName,
            roomType: roomType ?? 'classroom',
          },
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      console.log(`In-app notifications created for ${userIds.length} students`);

      Sentry.addBreadcrumb({
        category: 'livekit',
        message: `Class start notifications sent to ${response.successCount} students`,
        level: 'info',
      });
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error(`Failed to send class start notifications: ${msg}`);
      Sentry.captureException(error);
    }
  },
);

// ─── When a live class room is updated (recording/ended) ───────

export const onLiveKitRoomUpdated = onDocumentUpdated(
  {
    document: 'livekit_rooms/{roomId}',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
  },
  async (event) => {
    initSentry();
    Sentry.setTag('service', 'livekit');
    Sentry.setTag('function', 'onLiveKitRoomUpdated');

    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();
    if (!beforeData || !afterData) return;

    const roomId = event.params['roomId'];
    const orgId = afterData['organizationId'] as string | undefined;
    const roomName = afterData['name'] as string | undefined;

    // ── Recording started ──
    if (beforeData['isRecording'] === false && afterData['isRecording'] === true) {
      console.log(`Recording started in room ${roomId}`);
      // Notify participants in the room
      await _notifyRoomParticipants(
        roomId,
        orgId,
        'Recording Started',
        `This class "${roomName}" is now being recorded.`,
        'recording_started',
      );
    }

    // ── Recording stopped ──
    if (beforeData['isRecording'] === true && afterData['isRecording'] === false) {
      console.log(`Recording stopped in room ${roomId}`);
      await _notifyRoomParticipants(
        roomId,
        orgId,
        'Recording Stopped',
        `Recording for "${roomName}" has been stopped.`,
        'recording_stopped',
      );
    }

    // ── Class ended ──
    if (beforeData['isActive'] === true && afterData['isActive'] === false) {
      console.log(`Class ended: room ${roomId}`);
      await _notifyRoomParticipants(
        roomId,
        orgId,
        'Class Ended',
        `"${roomName}" has ended. Thank you for attending!`,
        'live_class_ended',
      );

      // Write attendance summary to room metadata
      try {
        const attendanceSnapshot = await db
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('attendance')
          .get();

        const totalJoined = attendanceSnapshot.size;
        const stillPresent = attendanceSnapshot.docs.filter(
          (doc) => doc.data()['leftAt'] == null,
        ).length;

        // Auto-mark remaining attendees as left
        const batch = db.batch();
        for (const doc of attendanceSnapshot.docs) {
          if (doc.data()['leftAt'] == null) {
            batch.update(doc.ref, {
              leftAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
        await batch.commit();

        console.log(`Attendance summary for room ${roomId}: ${totalJoined} joined, ${stillPresent} were still present at end`);
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error(`Failed to finalize attendance for room ${roomId}: ${msg}`);
      }
    }
  },
);

// ─── Helper: Notify participants in a room ─────────────────────

async function _notifyRoomParticipants(
  roomId: string,
  orgId: string | undefined,
  title: string,
  body: string,
  type: string,
): Promise<void> {
  if (!orgId) return;

  try {
    const attendanceSnapshot = await db
      .collection('livekit_rooms')
      .doc(roomId)
      .collection('attendance')
      .where('leftAt', '==', null)
      .get();

    const tokens: string[] = [];
    for (const doc of attendanceSnapshot.docs) {
      const uid = doc.id;
      const userDoc = await db.collection('users').doc(uid).get();
      const fcmToken = userDoc.data()?.['fcmToken'] as string | undefined;
      if (fcmToken) tokens.push(fcmToken);
    }

    if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      notification: { title, body },
      data: {
        type,
        roomId,
        orgId,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens,
      android: {
        priority: 'high',
        notification: {
          channelId: 'live_classes',
          icon: 'ic_notification',
        },
      },
    };

    await admin.messaging().sendEachForMulticast(message);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`Failed to notify room participants: ${msg}`);
  }
}
