"use strict";
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
exports.removeParticipant = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const livekit_server_sdk_1 = require("livekit-server-sdk");
const sentry_1 = require("../config/sentry");
// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = (0, params_1.defineSecret)('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = (0, params_1.defineSecret)('LIVEKIT_API_SECRET');
const db = admin.firestore();
exports.removeParticipant = (0, https_1.onCall)({
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0, // On-demand — not latency-critical
    maxInstances: 20, // Cap — removals are infrequent
    concurrency: 80,
}, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
        scope.setTag('service', 'livekit');
        scope.setTag('function', 'removeParticipant');
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
        const callerRole = callerDoc.data()?.['role'];
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
        const roomOrgId = roomDoc.data()?.['organizationId'];
        const callerOrgId = callerDoc.data()?.['organizationId'];
        if (roomOrgId !== callerOrgId) {
            throw new Error('You can only remove participants from rooms in your organization.');
        }
        scope.setTag('room', roomName);
        scope.setUser({ id: callerUid });
        // ── Remove participant via LiveKit SDK ────────────────────
        const livekitUrl = roomDoc.data()?.['metadata']?.['livekitUrl']
            ?? 'https://klasivo.livekit.cloud';
        const roomService = new livekit_server_sdk_1.RoomServiceClient(livekitUrl.replace('wss://', 'https://'), LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value());
        try {
            await roomService.removeParticipant(roomName, participantIdentity);
            console.log(`Removed participant ${participantIdentity} from room ${roomName}`);
        }
        catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            console.error(`Failed to remove participant ${participantIdentity}: ${msg}`);
            Sentry.captureException(err, { tags: { step: 'livekit_remove_participant' } });
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
        }
        catch (err) {
            // Attendance doc might not exist — non-critical
            console.warn(`Could not update attendance for ${participantIdentity}: ${err}`);
            Sentry.captureException(err, { tags: { step: 'update_attendance' } });
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
        }
        catch (err) {
            console.warn(`Could not create removal notification: ${err}`);
            Sentry.captureException(err, { tags: { step: 'create_removal_notification' } });
        }
        Sentry.addBreadcrumb({
            category: 'livekit',
            message: `Participant ${participantIdentity} removed from room ${roomName}`,
            level: 'info',
        });
        return { success: true, removedIdentity: participantIdentity };
    }); // withIsolatedScope
});
//# sourceMappingURL=removeParticipant.js.map