"use strict";
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
exports.generateLiveKitToken = void 0;
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const admin = __importStar(require("firebase-admin"));
const Sentry = __importStar(require("@sentry/node"));
const livekit_server_sdk_1 = require("livekit-server-sdk");
const sentry_1 = require("../config/sentry");
const rbac_1 = require("../utils/rbac");
// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = (0, params_1.defineSecret)('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = (0, params_1.defineSecret)('LIVEKIT_API_SECRET');
// ─── Function ─────────────────────────────────────────────────
exports.generateLiveKitToken = (0, https_1.onCall)({
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 1, // Keep warm — latency-critical for live class join
    maxInstances: 50, // Cap to prevent runaway billing
    concurrency: 100, // High concurrency — v2 supports up to 1000
    cpu: 1, // Full CPU for fast JWT signing
}, async (request) => {
    (0, sentry_1.initSentry)();
    return (0, sentry_1.withIsolatedScope)(async (scope) => {
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
        const roomData = roomDoc.data();
        const roomName = roomData['name'];
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
        const callerOrgId = request.auth.token.organizationId || '';
        const roomOrgId = roomData['organizationId'];
        const callerRole = request.auth.token.role || '';
        const scopeAccessLevel = request.auth.token.scopeAccessLevel || '';
        if (!(0, rbac_1.verifyOrgBoundary)(callerOrgId, roomOrgId, callerRole)) {
            await _logTokenDenied(db, uid, callerRole, callerOrgId, roomId, 'org_boundary', 'Cross-org access denied');
            Sentry.captureMessage(`Cross-org LiveKit token attempt: caller=${callerOrgId} room=${roomOrgId}`);
            throw new Error('You can only join rooms in your organization.');
        }
        // ── Scope authorization ──────────────────────────────────
        // Load caller's scope arrays from Firestore user doc
        const callerDoc = await db.collection('users').doc(uid).get();
        const callerScope = {};
        if (callerDoc.exists) {
            const callerData = callerDoc.data();
            callerScope['campusIds'] = callerData['campusIds'] || [];
            callerScope['stageIds'] = callerData['stageIds'] || [];
            callerScope['classIds'] = callerData['classIds'] || [];
            callerScope['subjectIds'] = callerData['subjectIds'] || [];
            callerScope['studentIds'] = callerData['studentIds'] || [];
        }
        const scopeResult = (0, rbac_1.verifyScopeAuthorization)(scopeAccessLevel, callerScope, roomData);
        if (!scopeResult.authorized) {
            await _logTokenDenied(db, uid, callerRole, callerOrgId, roomId, scopeResult.reason ?? 'unknown', scopeResult.message ?? 'Scope authorization failed');
            Sentry.captureMessage(`LiveKit scope denial: uid=${uid} room=${roomId} reason=${scopeResult.reason}`);
            throw new Error(scopeResult.message || 'You are not authorized to access this room.');
        }
        // ── Server-side role determination ────────────────────────
        // roomAdmin grants classroom moderation: mute/unmute, remove participants,
        // end room. Determined from caller's claims, NOT from client input.
        const isTeacherOrAbove = rbac_1.LIVEKIT_ADMIN_ROLES.includes(callerRole);
        // ── Build token ──────────────────────────────────────────
        const token = new livekit_server_sdk_1.AccessToken(LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value(), {
            identity: uid,
            name: displayName || uid,
        });
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
});
// ─── Audit Helper ─────────────────────────────────────────────
/**
 * Write an audit event when a LiveKit token is denied.
 * These events are invaluable for monitoring and debugging
 * during scope authorization rollout.
 */
async function _logTokenDenied(db, uid, role, orgId, roomId, reason, message) {
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
    }
    catch {
        // Audit logging failure should never block the denial
        console.warn('Failed to write livekit_token_denied audit event');
    }
}
//# sourceMappingURL=generateLiveKitToken.js.map