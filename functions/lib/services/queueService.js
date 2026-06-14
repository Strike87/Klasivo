"use strict";
/**
 * Klasivo — Queue Service
 *
 * Writes email jobs to the emailQueue Firestore collection.
 * The emailWorker picks them up and sends them via Resend.
 *
 * Why a queue?
 *   - Retries automatically on Resend failures
 *   - Survives Resend outages
 *   - Handles bulk announcements safely
 *   - Callable functions return immediately
 *
 * Direct-send emails (welcome, contact form) do NOT go through the queue.
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
exports.queueEmail = queueEmail;
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// ─── Public API ───────────────────────────────────────────────
/**
 * Queue an email for async delivery.
 *
 * Returns immediately with the queue document ID.
 * The emailWorker will process it and update the status.
 *
 * @returns The Firestore document ID of the queue entry
 */
async function queueEmail(params) {
    const entry = {
        type: params.type,
        to: Array.isArray(params.to) ? params.to : [params.to],
        payload: params.payload,
        status: 'pending',
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const docRef = await db.collection('emailQueue').add(entry);
    console.log(`Email queued — id: ${docRef.id}, type: ${params.type}, to: ${entry.to}`);
    return docRef.id;
}
//# sourceMappingURL=queueService.js.map