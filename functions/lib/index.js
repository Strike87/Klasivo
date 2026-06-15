"use strict";
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
exports.scheduledClassReminder = exports.onLiveKitRoomUpdated = exports.onLiveKitRoomCreated = exports.emailWorker = exports.sentryTestEvent = exports.setPermissionOverrides = exports.changeUserPassword = exports.syncClaims = exports.assignScope = exports.assignRole = exports.removeParticipant = exports.generateLiveKitToken = exports.sendSchoolAnnouncement = exports.sendTeacherInvitation = exports.sendContactForm = exports.onUserDeleted = exports.onUserCreated = exports.api = void 0;
const admin = __importStar(require("firebase-admin"));
// Initialise Firebase Admin once — must run before any function invocation
admin.initializeApp();
// ─── API Gateway (v2 onRequest — serves api.klasivo.app) ─────
var api_1 = require("./api");
Object.defineProperty(exports, "api", { enumerable: true, get: function () { return api_1.api; } });
// ─── Auth Triggers (v1 — no v2 after-event API exists) ────────
var onUserCreated_1 = require("./functions/onUserCreated");
Object.defineProperty(exports, "onUserCreated", { enumerable: true, get: function () { return onUserCreated_1.onUserCreated; } });
var onUserDeleted_1 = require("./functions/onUserDeleted");
Object.defineProperty(exports, "onUserDeleted", { enumerable: true, get: function () { return onUserDeleted_1.onUserDeleted; } });
// ─── Callable Functions (v2) ─────────────────────────────────
var sendContactForm_1 = require("./functions/sendContactForm");
Object.defineProperty(exports, "sendContactForm", { enumerable: true, get: function () { return sendContactForm_1.sendContactForm; } });
var sendTeacherInvitation_1 = require("./functions/sendTeacherInvitation");
Object.defineProperty(exports, "sendTeacherInvitation", { enumerable: true, get: function () { return sendTeacherInvitation_1.sendTeacherInvitation; } });
var sendSchoolAnnouncement_1 = require("./functions/sendSchoolAnnouncement");
Object.defineProperty(exports, "sendSchoolAnnouncement", { enumerable: true, get: function () { return sendSchoolAnnouncement_1.sendSchoolAnnouncement; } });
var generateLiveKitToken_1 = require("./functions/generateLiveKitToken");
Object.defineProperty(exports, "generateLiveKitToken", { enumerable: true, get: function () { return generateLiveKitToken_1.generateLiveKitToken; } });
var removeParticipant_1 = require("./functions/removeParticipant");
Object.defineProperty(exports, "removeParticipant", { enumerable: true, get: function () { return removeParticipant_1.removeParticipant; } });
// ─── RBAC Functions (v2 — migrated from v1) ───────────────────
var assignRole_1 = require("./functions/assignRole");
Object.defineProperty(exports, "assignRole", { enumerable: true, get: function () { return assignRole_1.assignRole; } });
var assignScope_1 = require("./functions/assignScope");
Object.defineProperty(exports, "assignScope", { enumerable: true, get: function () { return assignScope_1.assignScope; } });
var syncClaims_1 = require("./functions/syncClaims");
Object.defineProperty(exports, "syncClaims", { enumerable: true, get: function () { return syncClaims_1.syncClaims; } });
var changeUserPassword_1 = require("./functions/changeUserPassword");
Object.defineProperty(exports, "changeUserPassword", { enumerable: true, get: function () { return changeUserPassword_1.changeUserPassword; } });
var setPermissionOverrides_1 = require("./functions/setPermissionOverrides");
Object.defineProperty(exports, "setPermissionOverrides", { enumerable: true, get: function () { return setPermissionOverrides_1.setPermissionOverrides; } });
// ─── Diagnostic Functions (v2) ──────────────────────────────────
var sentryTestEvent_1 = require("./functions/sentryTestEvent");
Object.defineProperty(exports, "sentryTestEvent", { enumerable: true, get: function () { return sentryTestEvent_1.sentryTestEvent; } });
// ─── Firestore Triggers (v2) ─────────────────────────────────
var emailWorker_1 = require("./workers/emailWorker");
Object.defineProperty(exports, "emailWorker", { enumerable: true, get: function () { return emailWorker_1.emailWorker; } });
var onLiveKitRoomEvents_1 = require("./functions/onLiveKitRoomEvents");
Object.defineProperty(exports, "onLiveKitRoomCreated", { enumerable: true, get: function () { return onLiveKitRoomEvents_1.onLiveKitRoomCreated; } });
Object.defineProperty(exports, "onLiveKitRoomUpdated", { enumerable: true, get: function () { return onLiveKitRoomEvents_1.onLiveKitRoomUpdated; } });
// ─── Scheduled Functions (v2) ────────────────────────────────
var scheduledClassReminder_1 = require("./functions/scheduledClassReminder");
Object.defineProperty(exports, "scheduledClassReminder", { enumerable: true, get: function () { return scheduledClassReminder_1.scheduledClassReminder; } });
//# sourceMappingURL=index.js.map