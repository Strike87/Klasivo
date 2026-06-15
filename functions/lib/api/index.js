"use strict";
/**
 * Klasivo — API Gateway v1 (Express on Firebase Functions)
 *
 * Central backend gateway for api.klasivo.app.
 * All sensitive operations route through here — the Flutter app never
 * touches LiveKit secrets, Resend keys, or admin operations directly.
 *
 * Architecture:
 *   Flutter App → api.klasivo.app/v1/* → Firebase Functions → LiveKit/Resend/Firebase
 *
 * Routes (v1):
 *   GET  /v1/health                 → Health check + service status
 *   POST /v1/livekit/token          → Generate LiveKit JWT
 *   POST /v1/livekit/remove         → Remove participant from room
 *   POST /v1/livekit/mute           → Mute a participant (teacher only)
 *   POST /v1/livekit/endRoom        → End a live class room
 *   POST /v1/storage/upload-url     → Generate signed upload URL
 *   POST /v1/analytics/event        → Record server-side analytics event
 *   GET  /v1/admin/users            → List users in organization
 *   GET  /v1/admin/schools          → List organizations
 *   GET  /v1/admin/reports/summary  → Organization summary stats
 *   GET  /v1/docs                   → OpenAPI/Swagger JSON
 *
 * Security:
 *   - Bearer token auth (Firebase ID token) on all mutation endpoints
 *   - Admin endpoints require teacher/owner/admin role
 *   - Rate limiting at Cloudflare level
 *   - Security headers via Firebase Hosting config
 *   - Audit logging for all important actions
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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.api = void 0;
const admin = __importStar(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const params_1 = require("firebase-functions/params");
const Sentry = __importStar(require("@sentry/node"));
const express_1 = __importDefault(require("express"));
const sentry_1 = require("../config/sentry");
const rbac_1 = require("../utils/rbac");
// ─── Secrets ──────────────────────────────────────────────────
const LIVEKIT_API_KEY = (0, params_1.defineSecret)('LIVEKIT_API_KEY');
const LIVEKIT_API_SECRET = (0, params_1.defineSecret)('LIVEKIT_API_SECRET');
// ─── Express setup ──────────────────────────────────────────────
const app = (0, express_1.default)();
app.use(express_1.default.json());
// ─── Sentry scope isolation middleware ──────────────────────────────
// CRITICAL: Cloud Functions v2 with concurrency means a single instance
// handles multiple requests. Without scope isolation, Sentry tags and
// user context from one request leak into the next.
app.use((_req, _res, next) => {
    (0, sentry_1.initSentry)();
    // Each request gets its own isolated Sentry scope
    Sentry.withIsolationScope((scope) => {
        scope.clear();
        // Store the scope on the request for route handlers to use
        _req.sentryScope = scope;
        next();
    });
});
// ═══════════════════════════════════════════════════════════════════
// Middleware
// ═══════════════════════════════════════════════════════════════════
// ─── Auth middleware ────────────────────────────────────────────
async function verifyAuthToken(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({
            error: 'Missing or invalid Authorization header. Use: Bearer <Firebase ID token>',
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
            req.userRole = userDoc.data()?.['role'];
            req.userOrgId = userDoc.data()?.['organizationId'];
            req.userName = userDoc.data()?.['fullName'];
        }
        // Set Sentry user context on the isolated scope for this request
        const scope = req.sentryScope;
        if (scope) {
            scope.setUser({ id: decodedToken.uid, email: decodedToken.email });
            if (req.userRole)
                scope.setTag('role', req.userRole);
            if (req.userOrgId)
                scope.setTag('organizationId', req.userOrgId);
        }
        next();
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Token verification failed: ${msg}`);
        res.status(401).json({ error: 'Invalid or expired token.' });
    }
}
// ─── Admin-only middleware ──────────────────────────────────────
function requireAdmin(req, res, next) {
    if (!req.user) {
        res.status(401).json({ error: 'Authentication required.' });
        return;
    }
    if (!['teacher', 'owner', 'admin'].includes(req.userRole ?? '')) {
        res.status(403).json({ error: 'Admin access required.' });
        return;
    }
    next();
}
// ─── Audit logging middleware ───────────────────────────────────
async function auditLog(req, _res, next) {
    // Only audit mutation requests from authenticated users
    if (req.method === 'GET' || !req.user) {
        next();
        return;
    }
    try {
        const db = admin.firestore();
        await db.collection('audit_logs').add({
            actorId: req.user.uid, // legacy — remove in Phase 3
            actorName: req.userName ?? req.user.email ?? req.user.uid, // legacy — remove in Phase 3
            actorRole: req.userRole ?? 'unknown', // legacy — keep for backward compat
            performedBy: req.user.uid, // canonical actor field
            performedByRole: req.userRole ?? 'unknown', // Phase 1: add
            performedByOrgId: req.userOrgId ?? null, // Phase 1: add
            organizationId: req.userOrgId ?? null,
            action: `${req.method} ${req.path}`,
            resource: req.path,
            requestBody: _sanitizeForAudit(req.body),
            ipAddress: req.ip ?? req.headers['x-forwarded-for'] ?? 'unknown',
            userAgent: req.headers['user-agent'] ?? 'unknown',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (err) {
        // Audit logging failure should never block the request
        console.warn(`Audit log write failed: ${err instanceof Error ? err.message : String(err)}`);
    }
    next();
}
/** Remove sensitive fields from request body before logging */
function _sanitizeForAudit(body) {
    if (!body || typeof body !== 'object')
        return {};
    const sanitized = { ...body };
    const sensitiveKeys = ['password', 'token', 'secret', 'apiKey', 'creditCard', 'cvv'];
    for (const key of Object.keys(sanitized)) {
        if (sensitiveKeys.some((sk) => key.toLowerCase().includes(sk.toLowerCase()))) {
            sanitized[key] = '[REDACTED]';
        }
    }
    return sanitized;
}
// Apply audit logging to all v1 routes
app.use('/v1', auditLog);
// ─── LiveKit Token Denial Audit Helper ─────────────────────────
/**
 * Write an audit event when a LiveKit token is denied via the API.
 * Invaluable for monitoring during scope authorization rollout.
 */
async function _logTokenDenied(uid, role, orgId, roomId, reason, message) {
    try {
        await admin.firestore().collection('audit_logs').add({
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
        console.warn('Failed to write livekit_token_denied audit event');
    }
}
// ═══════════════════════════════════════════════════════════════════
// Health Check
// ═══════════════════════════════════════════════════════════════════
app.get('/v1/health', async (_req, res) => {
    const services = {};
    // Check Firestore
    try {
        await admin.firestore().collection('_health').doc('ping').get();
        services['firestore'] = 'ok';
    }
    catch {
        services['firestore'] = 'error';
    }
    // Check Firebase Auth
    try {
        await admin.auth().listUsers(1);
        services['auth'] = 'ok';
    }
    catch {
        services['auth'] = 'error';
    }
    // Check Storage
    try {
        const bucket = admin.storage().bucket();
        await bucket.exists();
        services['storage'] = 'ok';
    }
    catch {
        services['storage'] = 'error';
    }
    const allOk = Object.values(services).every((s) => s === 'ok');
    res.status(allOk ? 200 : 503).json({
        status: allOk ? 'ok' : 'degraded',
        version: 'v1',
        timestamp: new Date().toISOString(),
        services,
    });
});
// ═══════════════════════════════════════════════════════════════════
// LiveKit Routes
// ═══════════════════════════════════════════════════════════════════
app.post('/v1/livekit/token', verifyAuthToken, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'livekit');
    scope?.setTag('endpoint', '/v1/livekit/token');
    if (!req.user) {
        res.status(401).json({ error: 'Authentication required.' });
        return;
    }
    const { roomId, displayName } = req.body ?? {};
    // roomName/isTeacher: REMOVED — derived from room document and caller claims
    if (!roomId || typeof roomId !== 'string') {
        res.status(400).json({ error: 'roomId is required and must be a string.' });
        return;
    }
    try {
        // ── Load room document ──────────────────────────────────
        const roomDoc = await admin.firestore().collection('livekit_rooms').doc(roomId).get();
        if (!roomDoc.exists) {
            res.status(404).json({ error: 'Room not found.' });
            return;
        }
        const roomData = roomDoc.data();
        const roomName = roomData['name'];
        if (!roomName) {
            res.status(500).json({ error: 'Room document is missing a name field.' });
            return;
        }
        // Room name sanitization
        const sanitizedRoomName = roomName.replace(/[^a-zA-Z0-9_-]/g, '');
        if (sanitizedRoomName.length === 0 || sanitizedRoomName.length > 128) {
            res.status(500).json({ error: 'Invalid room name in document.' });
            return;
        }
        // ── Org boundary check ──────────────────────────────────
        const roomOrgId = roomData['organizationId'];
        if (!(0, rbac_1.verifyOrgBoundary)(req.userOrgId ?? '', roomOrgId, req.userRole ?? '')) {
            await _logTokenDenied(req.user.uid, req.userRole ?? 'unknown', req.userOrgId ?? '', roomId, 'org_boundary', 'Cross-org access denied');
            Sentry.captureMessage(`Cross-org LiveKit token attempt (API): caller=${req.userOrgId} room=${roomOrgId}`);
            res.status(403).json({ error: 'You can only join rooms in your organization.' });
            return;
        }
        // ── Scope authorization ────────────────────────────────
        const scopeAccessLevel = req.user?.token?.['scopeAccessLevel'] || '';
        const callerScope = {};
        // Load caller's scope arrays from user doc (already loaded by verifyAuthToken middleware)
        const callerDoc = await admin.firestore().collection('users').doc(req.user.uid).get();
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
            await _logTokenDenied(req.user.uid, req.userRole ?? 'unknown', req.userOrgId ?? '', roomId, scopeResult.reason ?? 'unknown', scopeResult.message ?? 'Scope authorization failed');
            Sentry.captureMessage(`LiveKit scope denial (API): uid=${req.user.uid} room=${roomId} reason=${scopeResult.reason}`);
            res.status(403).json({ error: scopeResult.message || 'You are not authorized to access this room.' });
            return;
        }
        // ── Server-side role determination ──────────────────────
        const isTeacherOrAbove = rbac_1.LIVEKIT_ADMIN_ROLES.includes(req.userRole);
        const { AccessToken } = await Promise.resolve().then(() => __importStar(require('livekit-server-sdk')));
        const token = new AccessToken(LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value(), { identity: req.user.uid, name: displayName || req.user.uid });
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
        res.json({ token: jwt });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`LiveKit token generation failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to generate token.' });
    }
});
app.post('/v1/livekit/remove', verifyAuthToken, requireAdmin, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'livekit');
    scope?.setTag('endpoint', '/v1/livekit/remove');
    const { roomName, participantIdentity, roomId } = req.body ?? {};
    if (!roomName || !participantIdentity || !roomId) {
        res.status(400).json({ error: 'roomName, participantIdentity, and roomId are required.' });
        return;
    }
    try {
        const { RoomServiceClient } = await Promise.resolve().then(() => __importStar(require('livekit-server-sdk')));
        const db = admin.firestore();
        const roomDoc = await db.collection('livekit_rooms').doc(roomId).get();
        if (!roomDoc.exists) {
            res.status(404).json({ error: 'Room not found.' });
            return;
        }
        const roomOrgId = roomDoc.data()?.['organizationId'];
        if (roomOrgId !== req.userOrgId) {
            res.status(403).json({ error: 'You can only remove participants from rooms in your organization.' });
            return;
        }
        const livekitUrl = roomDoc.data()?.['metadata']?.['livekitUrl'] ??
            'https://klasivo.livekit.cloud';
        const roomService = new RoomServiceClient(livekitUrl.replace('wss://', 'https://'), LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value());
        try {
            await roomService.removeParticipant(roomName, participantIdentity);
        }
        catch (err) {
            console.warn(`Failed to remove participant ${participantIdentity}: ${err instanceof Error ? err.message : String(err)}`);
        }
        // Update attendance
        try {
            await db.collection('livekit_rooms').doc(roomId).collection('attendance').doc(participantIdentity).update({
                leftAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                removedBy: req.user.uid,
                removedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        catch (err) {
            console.warn(`Could not update attendance for ${participantIdentity}: ${err}`);
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
        }
        catch (err) {
            console.warn(`Could not create removal notification: ${err}`);
        }
        res.json({ success: true, removedIdentity: participantIdentity });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Remove participant failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to remove participant.' });
    }
});
app.post('/v1/livekit/mute', verifyAuthToken, requireAdmin, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'livekit');
    scope?.setTag('endpoint', '/v1/livekit/mute');
    const { roomName, participantIdentity, mute, roomId } = req.body ?? {};
    if (!roomName || !participantIdentity) {
        res.status(400).json({ error: 'roomName and participantIdentity are required.' });
        return;
    }
    if (typeof mute !== 'boolean') {
        res.status(400).json({ error: 'mute must be a boolean (true = mute, false = unmute).' });
        return;
    }
    try {
        const { RoomServiceClient } = await Promise.resolve().then(() => __importStar(require('livekit-server-sdk')));
        // Resolve LiveKit URL
        let livekitUrl = 'https://klasivo.livekit.cloud';
        if (roomId) {
            const roomDoc = await admin.firestore().collection('livekit_rooms').doc(roomId).get();
            if (roomDoc.exists) {
                livekitUrl = roomDoc.data()?.['metadata']?.['livekitUrl'] ?? livekitUrl;
            }
        }
        const roomService = new RoomServiceClient(livekitUrl.replace('wss://', 'https://'), LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value());
        await roomService.updateParticipant(roomName, participantIdentity, {
            permission: { canPublish: !mute },
        });
        res.json({
            success: true,
            participantIdentity,
            muted: mute,
            message: mute ? 'Participant muted.' : 'Participant unmuted.',
        });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Mute participant failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to update participant.' });
    }
});
app.post('/v1/livekit/endRoom', verifyAuthToken, requireAdmin, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'livekit');
    scope?.setTag('endpoint', '/v1/livekit/endRoom');
    const { roomName, roomId } = req.body ?? {};
    if (!roomName || !roomId) {
        res.status(400).json({ error: 'roomName and roomId are required.' });
        return;
    }
    try {
        const { RoomServiceClient } = await Promise.resolve().then(() => __importStar(require('livekit-server-sdk')));
        const db = admin.firestore();
        const roomDoc = await db.collection('livekit_rooms').doc(roomId).get();
        if (!roomDoc.exists) {
            res.status(404).json({ error: 'Room not found.' });
            return;
        }
        const roomOrgId = roomDoc.data()?.['organizationId'];
        if (roomOrgId !== req.userOrgId) {
            res.status(403).json({ error: 'You can only end rooms in your organization.' });
            return;
        }
        const livekitUrl = roomDoc.data()?.['metadata']?.['livekitUrl'] ??
            'https://klasivo.livekit.cloud';
        const roomService = new RoomServiceClient(livekitUrl.replace('wss://', 'https://'), LIVEKIT_API_KEY.value(), LIVEKIT_API_SECRET.value());
        await roomService.deleteRoom(roomName);
        // Update room status in Firestore
        await db.collection('livekit_rooms').doc(roomId).update({
            isActive: false,
            endedAt: admin.firestore.FieldValue.serverTimestamp(),
            endedBy: req.user.uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.json({ success: true, roomName, message: 'Room ended successfully.' });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`End room failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to end room.' });
    }
});
// ═══════════════════════════════════════════════════════════════════
// Storage — Signed Upload URLs
// ═══════════════════════════════════════════════════════════════════
/**
 * POST /v1/storage/upload-url
 *
 * Generates a signed URL for the client to upload a file directly to
 * Firebase Storage. The client never needs storage credentials.
 *
 * Request body:
 *   { "filePath": "organizations/abc123/logo.png", "contentType": "image/png" }
 *
 * Response:
 *   { "uploadUrl": "https://storage.googleapis.com/...", "expiresAt": "..." }
 */
app.post('/v1/storage/upload-url', verifyAuthToken, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'storage');
    scope?.setTag('endpoint', '/v1/storage/upload-url');
    const { filePath, contentType } = req.body ?? {};
    if (!filePath || typeof filePath !== 'string') {
        res.status(400).json({ error: 'filePath is required.' });
        return;
    }
    // Validate path doesn't escape allowed prefixes
    const allowedPrefixes = [
        `users/${req.user.uid}/`,
        `organizations/${req.userOrgId ?? ''}/`,
        'exams/',
        'materials/',
        'submissions/',
    ];
    const isAllowed = allowedPrefixes.some((prefix) => filePath.startsWith(prefix));
    if (!isAllowed) {
        res.status(403).json({
            error: 'File path must start with an allowed prefix.',
            allowedPrefixes: ['users/{uid}/', 'organizations/{orgId}/', 'exams/', 'materials/', 'submissions/'],
        });
        return;
    }
    // Prevent path traversal
    if (filePath.includes('..') || filePath.includes('//')) {
        res.status(400).json({ error: 'Invalid file path.' });
        return;
    }
    try {
        const bucket = admin.storage().bucket();
        const file = bucket.file(filePath);
        const expiresInMinutes = 15;
        const expiresAt = new Date(Date.now() + expiresInMinutes * 60 * 1000);
        const [uploadUrl] = await file.getSignedUrl({
            action: 'write',
            expires: expiresAt,
            contentType: contentType || 'application/octet-stream',
        });
        // Also generate a read URL
        const [downloadUrl] = await file.getSignedUrl({
            action: 'read',
            expires: expiresAt,
        });
        res.json({
            uploadUrl,
            downloadUrl,
            filePath,
            expiresAt: expiresAt.toISOString(),
        });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Signed URL generation failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to generate upload URL.' });
    }
});
// ═══════════════════════════════════════════════════════════════════
// Analytics — Server-side Event Recording
// ═══════════════════════════════════════════════════════════════════
/**
 * POST /v1/analytics/event
 *
 * Records an analytics event server-side. Harder to fake than client-side events.
 *
 * Request body:
 *   { "event": "class_joined", "metadata": { "roomId": "..." } }
 *
 * Supported events:
 *   class_joined, class_completed, class_left,
 *   assignment_submitted, assignment_viewed,
 *   exam_started, exam_submitted, exam_completed,
 *   material_viewed, resource_downloaded
 */
app.post('/v1/analytics/event', verifyAuthToken, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'analytics');
    scope?.setTag('endpoint', '/v1/analytics/event');
    const { event, metadata } = req.body ?? {};
    if (!event || typeof event !== 'string') {
        res.status(400).json({ error: 'event is required and must be a string.' });
        return;
    }
    const allowedEvents = [
        'class_joined', 'class_completed', 'class_left',
        'assignment_submitted', 'assignment_viewed',
        'exam_started', 'exam_submitted', 'exam_completed',
        'material_viewed', 'resource_downloaded',
    ];
    if (!allowedEvents.includes(event)) {
        res.status(400).json({ error: `Unknown event. Allowed: ${allowedEvents.join(', ')}` });
        return;
    }
    try {
        const db = admin.firestore();
        await db.collection('analytics_events').add({
            event,
            userId: req.user.uid,
            userRole: req.userRole ?? 'unknown',
            organizationId: req.userOrgId ?? null,
            metadata: metadata ?? {},
            clientIp: req.ip ?? req.headers['x-forwarded-for'] ?? 'unknown',
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.json({ success: true, event });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Analytics event recording failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to record event.' });
    }
});
// ═══════════════════════════════════════════════════════════════════
// Admin API
// ═══════════════════════════════════════════════════════════════════
/**
 * GET /v1/admin/users?role=student&limit=50&cursor=xxx
 *
 * List users in the caller's organization.
 * Teachers see students. Owners see everyone.
 */
app.get('/v1/admin/users', verifyAuthToken, requireAdmin, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'admin');
    scope?.setTag('endpoint', '/v1/admin/users');
    if (!req.userOrgId) {
        res.status(400).json({ error: 'User is not associated with an organization.' });
        return;
    }
    try {
        const db = admin.firestore();
        const role = req.query['role'];
        const limit = Math.min(parseInt(req.query['limit']) || 50, 100);
        const cursor = req.query['cursor'];
        let query = db
            .collection('users')
            .where('organizationId', '==', req.userOrgId)
            .orderBy('createdAt', 'desc')
            .limit(limit + 1); // +1 to detect next page
        // Non-owners can only see students
        if (req.userRole !== 'owner' && req.userRole !== 'admin') {
            query = query.where('role', '==', 'student');
        }
        else if (role) {
            query = query.where('role', '==', role);
        }
        if (cursor) {
            const cursorDoc = await db.collection('users').doc(cursor).get();
            if (cursorDoc.exists) {
                query = query.startAfter(cursorDoc);
            }
        }
        const snapshot = await query.get();
        const users = snapshot.docs.slice(0, limit).map((doc) => {
            const data = doc.data();
            return {
                uid: doc.id,
                fullName: data['fullName'] ?? '',
                email: data['email'] ?? '',
                role: data['role'] ?? '',
                isActive: data['isActive'] ?? true,
                createdAt: data['createdAt'] ?? null,
            };
        });
        const hasNextPage = snapshot.docs.length > limit;
        const nextCursor = hasNextPage ? snapshot.docs[limit - 1]?.id : null;
        res.json({ users, nextCursor, hasMore: hasNextPage });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Admin users list failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to list users.' });
    }
});
/**
 * GET /v1/admin/schools
 *
 * List organizations. Only available to owners and admins.
 */
app.get('/v1/admin/schools', verifyAuthToken, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'admin');
    scope?.setTag('endpoint', '/v1/admin/schools');
    // Only owners/admins can list schools
    if (!['owner', 'admin'].includes(req.userRole ?? '')) {
        res.status(403).json({ error: 'Only owners can list organizations.' });
        return;
    }
    try {
        const db = admin.firestore();
        const limit = Math.min(parseInt(req.query['limit']) || 50, 100);
        let query = db.collection('organizations').orderBy('createdAt', 'desc').limit(limit);
        // Non-super-admin users see only their own org
        if (req.userRole !== 'admin') {
            query = query.where('ownerId', '==', req.user.uid);
        }
        const snapshot = await query.get();
        const schools = snapshot.docs.map((doc) => {
            const data = doc.data();
            return {
                id: doc.id,
                name: data['name'] ?? '',
                slug: data['slug'] ?? '',
                ownerId: data['ownerId'] ?? '',
                isActive: data['isActive'] ?? true,
                plan: data['plan'] ?? 'free',
                createdAt: data['createdAt'] ?? null,
            };
        });
        res.json({ schools });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Admin schools list failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to list schools.' });
    }
});
/**
 * GET /v1/admin/reports/summary
 *
 * Organization summary statistics for the admin dashboard.
 */
app.get('/v1/admin/reports/summary', verifyAuthToken, requireAdmin, async (req, res) => {
    (0, sentry_1.initSentry)();
    const scope = req.sentryScope;
    scope?.setTag('service', 'admin');
    scope?.setTag('endpoint', '/v1/admin/reports/summary');
    if (!req.userOrgId) {
        res.status(400).json({ error: 'User is not associated with an organization.' });
        return;
    }
    try {
        const db = admin.firestore();
        const orgId = req.userOrgId;
        // Count users by role
        const usersSnapshot = await db
            .collection('users')
            .where('organizationId', '==', orgId)
            .where('isActive', '==', true)
            .get();
        const teachers = usersSnapshot.docs.filter((d) => d.data()['role'] === 'teacher').length;
        const students = usersSnapshot.docs.filter((d) => d.data()['role'] === 'student').length;
        const parents = usersSnapshot.docs.filter((d) => d.data()['role'] === 'parent').length;
        // Count exams
        const examsSnapshot = await db
            .collection('exams')
            .where('organizationId', '==', orgId)
            .get();
        const activeExams = examsSnapshot.docs.filter((d) => d.data()['isActive'] === true).length;
        // Count classes
        const classesSnapshot = await db
            .collection('classes')
            .where('organizationId', '==', orgId)
            .get();
        // Count active live rooms
        const liveRoomsSnapshot = await db
            .collection('livekit_rooms')
            .where('organizationId', '==', orgId)
            .where('isActive', '==', true)
            .get();
        // Count assignments
        const assignmentsSnapshot = await db
            .collection('assignments')
            .where('organizationId', '==', orgId)
            .get();
        res.json({
            organizationId: orgId,
            users: {
                total: usersSnapshot.size,
                teachers,
                students,
                parents,
            },
            exams: {
                total: examsSnapshot.size,
                active: activeExams,
            },
            classes: classesSnapshot.size,
            activeLiveRooms: liveRoomsSnapshot.size,
            assignments: assignmentsSnapshot.size,
            generatedAt: new Date().toISOString(),
        });
    }
    catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        console.error(`Admin summary failed: ${msg}`);
        Sentry.captureException(err);
        res.status(500).json({ error: 'Failed to generate summary.' });
    }
});
// ═══════════════════════════════════════════════════════════════════
// API Documentation
// ═══════════════════════════════════════════════════════════════════
app.get('/v1/docs', (_req, res) => {
    res.json(OPENAPI_SPEC);
});
// ═══════════════════════════════════════════════════════════════════
// Legacy routes (redirect to /v1)
// ═══════════════════════════════════════════════════════════════════
app.get('/health', (_req, res) => {
    res.redirect(301, '/v1/health');
});
// ═══════════════════════════════════════════════════════════════════
// 404 Catch-all
// ═══════════════════════════════════════════════════════════════════
app.use((_req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: 'See /v1/docs for available endpoints.',
        availableEndpoints: [
            'GET  /v1/health',
            'POST /v1/livekit/token',
            'POST /v1/livekit/remove',
            'POST /v1/livekit/mute',
            'POST /v1/livekit/endRoom',
            'POST /v1/storage/upload-url',
            'POST /v1/analytics/event',
            'GET  /v1/admin/users',
            'GET  /v1/admin/schools',
            'GET  /v1/admin/reports/summary',
            'GET  /v1/docs',
        ],
    });
});
// ═══════════════════════════════════════════════════════════════════
// OpenAPI Specification
// ═══════════════════════════════════════════════════════════════════
const OPENAPI_SPEC = {
    openapi: '3.0.3',
    info: {
        title: 'Klasivo API',
        description: 'Central backend gateway for Klasivo — education platform. All sensitive operations route through this API. The Flutter app never touches LiveKit secrets, Resend keys, or admin operations directly.',
        version: '1.0.0',
        contact: { name: 'Klasivo Support', email: 'support@klasivo.app', url: 'https://klasivo.app' },
        license: { name: 'Proprietary' },
    },
    servers: [{ url: 'https://api.klasivo.app', description: 'Production' }],
    security: [{ BearerAuth: [] }],
    paths: {
        '/v1/health': {
            get: {
                summary: 'Health check',
                description: 'Returns API status and downstream service health.',
                security: [],
                responses: {
                    '200': { description: 'All services healthy', content: { 'application/json': { schema: { type: 'object', properties: { status: { type: 'string' }, version: { type: 'string' }, timestamp: { type: 'string' }, services: { type: 'object' } } } } } },
                    '503': { description: 'One or more services degraded' },
                },
            },
        },
        '/v1/livekit/token': {
            post: {
                summary: 'Generate LiveKit token',
                description: 'Creates a JWT access token for joining a LiveKit room. roomId is required; roomName and isTeacher are determined server-side. Staff roles (LIVEKIT_ADMIN_ROLES) get roomAdmin grant.',
                requestBody: {
                    required: true,
                    content: { 'application/json': { schema: { type: 'object', required: ['roomId'], properties: { roomId: { type: 'string', description: 'Firestore document ID of the livekit_rooms entry' }, displayName: { type: 'string' } } } } },
                },
                responses: {
                    '200': { description: 'Token generated', content: { 'application/json': { schema: { type: 'object', properties: { token: { type: 'string' } } } } } },
                    '401': { description: 'Missing or invalid auth token' },
                    '403': { description: 'Not authorized — cross-org access denied' },
                    '404': { description: 'Room not found' },
                },
            },
        },
        '/v1/livekit/remove': {
            post: {
                summary: 'Remove participant from room',
                description: 'Kicks a participant from a LiveKit room. Teacher/owner/admin only.',
                requestBody: {
                    required: true,
                    content: { 'application/json': { schema: { type: 'object', required: ['roomName', 'participantIdentity', 'roomId'], properties: { roomName: { type: 'string' }, participantIdentity: { type: 'string' }, roomId: { type: 'string' } } } } },
                },
                responses: { '200': { description: 'Participant removed' }, '403': { description: 'Not authorized' }, '404': { description: 'Room not found' } },
            },
        },
        '/v1/livekit/mute': {
            post: {
                summary: 'Mute/unmute participant',
                description: 'Toggles a participant\'s ability to publish audio/video. Teacher only.',
                requestBody: {
                    required: true,
                    content: { 'application/json': { schema: { type: 'object', required: ['roomName', 'participantIdentity', 'mute'], properties: { roomName: { type: 'string' }, participantIdentity: { type: 'string' }, mute: { type: 'boolean' }, roomId: { type: 'string' } } } } },
                },
                responses: { '200': { description: 'Participant muted/unmuted' }, '403': { description: 'Not authorized' } },
            },
        },
        '/v1/livekit/endRoom': {
            post: {
                summary: 'End a live room',
                description: 'Ends a LiveKit room and updates Firestore status. Teacher/owner/admin only.',
                requestBody: {
                    required: true,
                    content: { 'application/json': { schema: { type: 'object', required: ['roomName', 'roomId'], properties: { roomName: { type: 'string' }, roomId: { type: 'string' } } } } },
                },
                responses: { '200': { description: 'Room ended' }, '403': { description: 'Not authorized' }, '404': { description: 'Room not found' } },
            },
        },
        '/v1/storage/upload-url': {
            post: {
                summary: 'Generate signed upload URL',
                description: 'Returns a signed URL for direct file upload to Firebase Storage. Client never needs storage credentials.',
                requestBody: {
                    required: true,
                    content: { 'application/json': { schema: { type: 'object', required: ['filePath'], properties: { filePath: { type: 'string', description: 'Storage path, e.g. organizations/abc/logo.png' }, contentType: { type: 'string', description: 'MIME type, e.g. image/png' } } } } },
                },
                responses: { '200': { description: 'Signed URLs generated', content: { 'application/json': { schema: { type: 'object', properties: { uploadUrl: { type: 'string' }, downloadUrl: { type: 'string' }, filePath: { type: 'string' }, expiresAt: { type: 'string' } } } } } }, '403': { description: 'Path not in allowed prefixes' } },
            },
        },
        '/v1/analytics/event': {
            post: {
                summary: 'Record analytics event',
                description: 'Server-side analytics event recording. Harder to fake than client-side.',
                requestBody: {
                    required: true,
                    content: { 'application/json': { schema: { type: 'object', required: ['event'], properties: { event: { type: 'string', enum: ['class_joined', 'class_completed', 'class_left', 'assignment_submitted', 'assignment_viewed', 'exam_started', 'exam_submitted', 'exam_completed', 'material_viewed', 'resource_downloaded'] }, metadata: { type: 'object' } } } } },
                },
                responses: { '200': { description: 'Event recorded' }, '400': { description: 'Unknown event type' } },
            },
        },
        '/v1/admin/users': {
            get: {
                summary: 'List organization users',
                description: 'Teachers see students. Owners see everyone. Supports pagination.',
                parameters: [
                    { name: 'role', in: 'query', schema: { type: 'string', enum: ['student', 'teacher', 'owner', 'parent'] } },
                    { name: 'limit', in: 'query', schema: { type: 'integer', default: 50, maximum: 100 } },
                    { name: 'cursor', in: 'query', schema: { type: 'string' } },
                ],
                responses: { '200': { description: 'User list' } },
            },
        },
        '/v1/admin/schools': {
            get: {
                summary: 'List organizations',
                description: 'Owners see their own. Admins see all.',
                parameters: [
                    { name: 'limit', in: 'query', schema: { type: 'integer', default: 50, maximum: 100 } },
                ],
                responses: { '200': { description: 'School list' }, '403': { description: 'Not authorized' } },
            },
        },
        '/v1/admin/reports/summary': {
            get: {
                summary: 'Organization summary statistics',
                description: 'Returns user counts, exam counts, active rooms, and more.',
                responses: { '200': { description: 'Summary statistics' } },
            },
        },
    },
    components: {
        securitySchemes: {
            BearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT', description: 'Firebase ID token' },
        },
    },
};
// ═══════════════════════════════════════════════════════════════════
// Export as Firebase Function
// ═══════════════════════════════════════════════════════════════════
exports.api = (0, https_1.onRequest)({
    secrets: [LIVEKIT_API_KEY, LIVEKIT_API_SECRET, 'SENTRY_DSN'],
    region: 'us-central1',
    cors: true,
    memory: '512MiB',
    timeoutSeconds: 60,
    minInstances: 1, // Keep warm — API gateway is latency-critical
    maxInstances: 100, // Cap — 100 instances × 80 concurrency = 8,000 concurrent req
    concurrency: 80, // Handle multiple requests per instance
    cpu: 1, // Full CPU for Express middleware chain
}, app);
//# sourceMappingURL=index.js.map