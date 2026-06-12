"use strict";
/**
 * Klasivo — Firebase Cloud Functions (TypeScript)
 *
 * Barrel export of all Cloud Functions.
 * Firebase picks up named exports from the compiled `lib/index.js`.
 *
 * Functions:
 *   Auth Triggers (v1 — no v2 equivalent for after-events):
 *     onUserCreated  — Queue welcome email when a new user signs up
 *     onUserDeleted  — Cascade-delete org data when an owner is removed
 *
 *   Callable Functions (v2):
 *     sendContactForm        — Forward contact-form to support (direct send)
 *     sendTeacherInvitation  — Queue teacher invitation email
 *     sendSchoolAnnouncement — Queue school announcement email
 *
 *   Firestore Triggers (v2):
 *     emailWorker — Process emailQueue documents (send + retry)
 *
 *   Note: Auth triggers use firebase-functions/v1 because v2 only
 *   provides blocking functions (beforeUserCreated), not after-event
 *   triggers.
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
exports.emailWorker = exports.sendSchoolAnnouncement = exports.sendTeacherInvitation = exports.sendContactForm = exports.onUserDeleted = exports.onUserCreated = void 0;
const admin = __importStar(require("firebase-admin"));
// Initialise Firebase Admin once — must run before any function invocation
admin.initializeApp();
// ─── Auth Triggers (v1) ──────────────────────────────────────
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
// ─── Firestore Triggers (v2) ─────────────────────────────────
var emailWorker_1 = require("./workers/emailWorker");
Object.defineProperty(exports, "emailWorker", { enumerable: true, get: function () { return emailWorker_1.emailWorker; } });
//# sourceMappingURL=index.js.map