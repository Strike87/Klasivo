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
 *     createStudent          — Create student Auth + Firestore doc (Admin SDK)
 *     assignRole             — Assign a role to a user (custom claims + Firestore)
 *     assignScope            — Assign scope (campus/stage/class) to a user + refresh claims
 *     syncClaims             — Re-sync custom claims from Firestore user doc
 *     changeUserPassword     — Change/reset user password (email or student_code)
 *     setPermissionOverrides — Set/clear permission overrides for a user
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
 *   triggers. All callable functions have been migrated to v2.
 */

import * as admin from 'firebase-admin';

// Initialise Firebase Admin once — must run before any function invocation
admin.initializeApp();

// ─── API Gateway (v2 onRequest — serves api.klasivo.app) ─────
export { api } from './api';

// ─── Auth Triggers (v1 — no v2 after-event API exists) ────────
export { onUserCreated } from './functions/onUserCreated';
export { onUserDeleted } from './functions/onUserDeleted';

// ─── Callable Functions (v2) ─────────────────────────────────
export { sendContactForm } from './functions/sendContactForm';
export { sendTeacherInvitation } from './functions/sendTeacherInvitation';
export { sendSchoolAnnouncement } from './functions/sendSchoolAnnouncement';
export { generateLiveKitToken } from './functions/generateLiveKitToken';
export { removeParticipant } from './functions/removeParticipant';

// ─── Student Management Functions (v2) ────────────────────────
export { createStudent } from './functions/createStudent';
export { deleteStudent } from './functions/deleteStudent';

// ─── Auth Onboarding (v2) ─────────────────────────────────────
// Phase 2 D7: redeemInviteCode closes the invite_codes catch-22.
// Pre-auth callable that creates Auth + Firestore + claims atomically.
export { redeemInviteCode } from './functions/redeemInviteCode';

// P0-1/P0-2/P0-3: Owner + Parent + Teacher registration CFs (Day 3+ patch).
// Client-side writes were blocked by Firestore rules:
//   - role:'owner' not in allowed self-create list
//   - organizationId:null fails is-string check (parent)
//   - invite_codes update requires safeStaffUpdate() which fails pre-claim-sync (teacher)
export { registerOwner } from './functions/registerOwner';
export { registerParent } from './functions/registerParent';
export { registerTeacher } from './functions/registerTeacher';

// N3 FIX: Parent-child linking. After registration a parent has organizationId:''
// and empty-org claims. The client cannot complete the link (rules block the parent
// from writing its own org, status, or claims). linkParent does it server-side.
export { linkParent } from './functions/linkParent';

// ─── RBAC Functions (v2 — migrated from v1) ───────────────────
export { assignRole } from './functions/assignRole';
export { assignScope } from './functions/assignScope';
export { syncClaims } from './functions/syncClaims';
export { changeUserPassword } from './functions/changeUserPassword';
export { setPermissionOverrides } from './functions/setPermissionOverrides';
export { deleteOrganization } from './functions/deleteOrganization';  // C-08 PATCH

// ─── Diagnostic Functions (v2) ──────────────────────────────────
export { sentryTestEvent } from './functions/sentryTestEvent';

// ─── Firestore Triggers (v2) ─────────────────────────────────
export { emailWorker } from './workers/emailWorker';
export { onLiveKitRoomCreated, onLiveKitRoomUpdated } from './functions/onLiveKitRoomEvents';

// ─── Scheduled Functions (v2) ────────────────────────────────
export { scheduledClassReminder } from './functions/scheduledClassReminder';
export { gradeSubmission } from './functions/gradeSubmission';
export { gradeAssignmentSubmission } from './functions/gradeAssignmentSubmission';
