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
export declare const onLiveKitRoomCreated: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/firestore").FirestoreEvent<import("firebase-functions/v2/firestore").QueryDocumentSnapshot | undefined, {
    roomId: string;
}>>;
export declare const onLiveKitRoomUpdated: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/firestore").FirestoreEvent<import("firebase-functions/v2/firestore").Change<import("firebase-functions/v2/firestore").QueryDocumentSnapshot> | undefined, {
    roomId: string;
}>>;
