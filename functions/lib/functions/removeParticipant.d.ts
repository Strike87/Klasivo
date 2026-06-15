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
interface RemoveParticipantRequest {
    roomName: string;
    participantIdentity: string;
    roomId: string;
}
export declare const removeParticipant: import("firebase-functions/v2/https").CallableFunction<RemoveParticipantRequest, Promise<{
    success: boolean;
    removedIdentity: string;
}>, unknown>;
export {};
