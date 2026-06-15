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
import * as admin from 'firebase-admin';
declare global {
    namespace Express {
        interface Request {
            user?: admin.auth.DecodedIdToken;
            userRole?: string;
            userOrgId?: string;
            userName?: string;
        }
    }
}
export declare const api: import("firebase-functions/v2/https").HttpsFunction;
