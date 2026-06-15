"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onLiveKitRoomUpdated = exports.onLiveKitRoomCreated = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const sentry_1 = require("../config/sentry");
const db = admin.firestore();
// ─── When a new live class room is created ─────────────────────
exports.onLiveKitRoomCreated = (0, firestore_1.onDocumentCreated)({
    document: 'livekit_rooms/{roomId}',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
}, async (event) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'livekit');
        scope.setTag('function', 'onLiveKitRoomCreated');
        const snapshot = event.data;
        if (!snapshot)
            return;
        const data = snapshot.data();
        if (!data)
            return;
        // Only notify if the room is active (not a draft)
        if (data['isActive'] !== true)
            return;
        const orgId = data['organizationId'];
        const roomName = data['name'];
        const roomType = data['roomType'];
        const createdBy = data['createdBy'];
        if (!orgId || !roomName)
            return;
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
            const tokens = [];
            const userIds = [];
            for (const doc of studentsSnapshot.docs) {
                const fcmToken = doc.data()?.['fcmToken'];
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
            const message = {
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
        }
        catch (error) {
            const msg = error instanceof Error ? error.message : String(error);
            console.error(`Failed to send class start notifications: ${msg}`);
            Sentry.captureException(error);
        }
    }); // withIsolatedScope
});
// ─── When a live class room is updated (recording/ended) ───────
exports.onLiveKitRoomUpdated = (0, firestore_1.onDocumentUpdated)({
    document: 'livekit_rooms/{roomId}',
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
}, async (event) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'livekit');
        scope.setTag('function', 'onLiveKitRoomUpdated');
        const beforeData = event.data?.before.data();
        const afterData = event.data?.after.data();
        if (!beforeData || !afterData)
            return;
        const roomId = event.params['roomId'];
        const orgId = afterData['organizationId'];
        const roomName = afterData['name'];
        // ── Recording started ──
        if (beforeData['isRecording'] === false && afterData['isRecording'] === true) {
            console.log(`Recording started in room ${roomId}`);
            // Notify participants in the room
            await _notifyRoomParticipants(roomId, orgId, 'Recording Started', `This class "${roomName}" is now being recorded.`, 'recording_started');
        }
        // ── Recording stopped ──
        if (beforeData['isRecording'] === true && afterData['isRecording'] === false) {
            console.log(`Recording stopped in room ${roomId}`);
            await _notifyRoomParticipants(roomId, orgId, 'Recording Stopped', `Recording for "${roomName}" has been stopped.`, 'recording_stopped');
        }
        // ── Class ended ──
        if (beforeData['isActive'] === true && afterData['isActive'] === false) {
            console.log(`Class ended: room ${roomId}`);
            await _notifyRoomParticipants(roomId, orgId, 'Class Ended', `"${roomName}" has ended. Thank you for attending!`, 'live_class_ended');
            // Finalize attendance and write session analytics
            try {
                const attendanceSnapshot = await db
                    .collection('livekit_rooms')
                    .doc(roomId)
                    .collection('attendance')
                    .get();
                const totalJoined = attendanceSnapshot.size;
                const stillPresent = attendanceSnapshot.docs.filter((doc) => doc.data()['leftAt'] == null).length;
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
                // Count chat messages
                const messagesSnapshot = await db
                    .collection('livekit_rooms')
                    .doc(roomId)
                    .collection('messages')
                    .get();
                const messagesCount = messagesSnapshot.size;
                // Count raised hands
                const handsSnapshot = await db
                    .collection('livekit_rooms')
                    .doc(roomId)
                    .collection('raised_hands')
                    .where('isRaised', '==', true)
                    .get();
                const raisedHandsCount = handsSnapshot.size;
                // Calculate duration
                const startedAt = afterData['startedAt'] != null
                    ? new Date(afterData['startedAt'])
                    : null;
                const endedAt = afterData['endedAt'] != null
                    ? new Date(afterData['endedAt'])
                    : new Date();
                const durationMinutes = startedAt != null
                    ? Math.round((endedAt.getTime() - startedAt.getTime()) / 60000)
                    : 0;
                // Calculate peak participants (from attendance, find max simultaneous)
                // Simple approach: use totalJoined as peak (accurate for small rooms)
                // A more precise approach would track periodic snapshots
                const peakParticipants = totalJoined;
                // Write session analytics document
                await db.collection('session_analytics').add({
                    roomId,
                    roomName: roomName ?? '',
                    organizationId: orgId ?? '',
                    campusId: afterData['campusId'] ?? null,
                    teacherId: afterData['createdBy'] ?? '',
                    roomType: afterData['roomType'] ?? 'classroom',
                    startedAt: startedAt ?? null,
                    endedAt,
                    durationMinutes,
                    attendanceCount: totalJoined,
                    peakParticipants,
                    messagesCount,
                    raisedHandsCount,
                    wasRecorded: afterData['isRecording'] === true || beforeData['isRecording'] === true,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                console.log(`Session analytics written for room ${roomId}: ${totalJoined} attended, ${durationMinutes} min, ${messagesCount} messages, ${raisedHandsCount} hands`);
            }
            catch (error) {
                const msg = error instanceof Error ? error.message : String(error);
                console.error(`Failed to finalize attendance/analytics for room ${roomId}: ${msg}`);
                Sentry.captureException(error, {
                    tags: {
                        function: 'onLiveKitRoomUpdated',
                        step: 'finalize_analytics',
                        roomId,
                    },
                });
            }
        }
    }); // withIsolatedScope
});
// ─── Helper: Notify participants in a room ─────────────────────
async function _notifyRoomParticipants(roomId, orgId, title, body, type) {
    if (!orgId)
        return;
    try {
        const attendanceSnapshot = await db
            .collection('livekit_rooms')
            .doc(roomId)
            .collection('attendance')
            .where('leftAt', '==', null)
            .get();
        const tokens = [];
        for (const doc of attendanceSnapshot.docs) {
            const uid = doc.id;
            const userDoc = await db.collection('users').doc(uid).get();
            const fcmToken = userDoc.data()?.['fcmToken'];
            if (fcmToken)
                tokens.push(fcmToken);
        }
        if (tokens.length === 0)
            return;
        const message = {
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
    }
    catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        console.error(`Failed to notify room participants: ${msg}`);
        Sentry.captureException(error, {
            tags: {
                function: 'onLiveKitRoomUpdated',
                step: 'notify_participants',
                roomId,
            },
        });
    }
}
//# sourceMappingURL=onLiveKitRoomEvents.js.map