/**
 * Klasivo — Firebase Cloud Functions (TypeScript)
 *
 * Barrel export of all Cloud Functions.
 * Firebase picks up named exports from the compiled `lib/index.js`.
 *
 * Functions:
 *   API Gateway (v2 onRequest):
 *     api — Express app serving api.klasivo.app/v1/* REST endpoints
 *           (health, livekit/*, storage/upload-url, analytics/event,
 *            admin/users, admin/schools, admin/reports/summary, docs)
 *
 *   Auth Triggers (v1 — no v2 equivalent for after-events):
 *     onUserCreated  — Queue welcome email when a new user signs up
 *     onUserDeleted  — Cascade-delete org data when an owner is removed
 *
 *   Callable Functions (v2):
 *     sendContactForm        — Forward contact-form to support (direct send)
 *     sendTeacherInvitation  — Queue teacher invitation email
 *     sendSchoolAnnouncement — Queue school announcement email
 *     generateLiveKitToken   — Mint LiveKit JWT for video/audio rooms
 *     removeParticipant      — Kick disruptive student from a live class
 *
 *   Firestore Triggers (v2):
 *     emailWorker            — Process emailQueue documents (send + retry)
 *     onLiveKitRoomCreated   — Push notifications when a live class starts
 *     onLiveKitRoomUpdated   — Recording/end notifications + session analytics
 *
 *   Scheduled (v2):
 *     scheduledClassReminder — Send reminders for classes starting in 10 min
 *
 *   Note: Auth triggers use firebase-functions/v1 because v2 only
 *   provides blocking functions (beforeUserCreated), not after-event
 *   triggers.
 */

import * as admin from 'firebase-admin';

// Initialise Firebase Admin once — must run before any function invocation
admin.initializeApp();

// ─── API Gateway (v2 onRequest — serves api.klasivo.app) ─────
export { api } from './api';

// ─── Auth Triggers (v1) ──────────────────────────────────────
export { onUserCreated } from './functions/onUserCreated';
export { onUserDeleted } from './functions/onUserDeleted';

// ─── Callable Functions (v2) ─────────────────────────────────
export { sendContactForm } from './functions/sendContactForm';
export { sendTeacherInvitation } from './functions/sendTeacherInvitation';
export { sendSchoolAnnouncement } from './functions/sendSchoolAnnouncement';
export { generateLiveKitToken } from './functions/generateLiveKitToken';
export { removeParticipant } from './functions/removeParticipant';

// ─── Firestore Triggers (v2) ─────────────────────────────────
export { emailWorker } from './workers/emailWorker';
export { onLiveKitRoomCreated, onLiveKitRoomUpdated } from './functions/onLiveKitRoomEvents';

// ─── Scheduled Functions (v2) ────────────────────────────────
export { scheduledClassReminder } from './functions/scheduledClassReminder';
