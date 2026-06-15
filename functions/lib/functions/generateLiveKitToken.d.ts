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
interface LiveKitTokenRequest {
    roomId: string;
    displayName?: string;
}
interface LiveKitTokenResponse {
    token: string;
}
export declare const generateLiveKitToken: import("firebase-functions/v2/https").CallableFunction<LiveKitTokenRequest, Promise<LiveKitTokenResponse>, unknown>;
export {};
