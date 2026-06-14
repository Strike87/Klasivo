"use strict";
/**
 * Klasivo — Firebase Cloud Functions
 *
 * All functions are exported from this single entry point
 * so Firebase can discover and deploy them.
 *
 * ─── Email Functions ──────────────────────────────────────────
 *   onUserCreated          — Auth trigger: send welcome email (direct)
 *   sendContactForm        — Public: forward contact form to support (direct)
 *   sendTeacherInvitation  — Auth: queue teacher invitation
 *   sendSchoolAnnouncement — Auth: queue announcement
 *
 * ─── Email Worker ─────────────────────────────────────────────
 *   emailWorker            — Processes emailQueue, retries on failure
 *
 * ─── Auth Triggers ────────────────────────────────────────────
 *   onUserDelete           — Cascade-delete org data when owner removed
 *
 * ─── Firestore Triggers ──────────────────────────────────────
 *   onNewMessageNotification — Push notification on new notification doc
 *   onNewMessage             — Push notification on new message doc
 *
 * ─── Firebase Auth ────────────────────────────────────────────
 *   Email Verification  → user.sendEmailVerification()  (native)
 *   Password Reset      → FirebaseAuth.instance.sendPasswordResetEmail()  (native)
 *   No custom Resend functions needed for these.
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
exports.onNewMessage = exports.onNewMessageNotification = exports.onUserDelete = exports.emailWorker = exports.sendSchoolAnnouncement = exports.sendTeacherInvitation = exports.sendContactForm = exports.onUserCreated = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
// ─── Initialise Firebase Admin ────────────────────────────────
admin.initializeApp();
const db = admin.firestore();
// ═══════════════════════════════════════════════════════════════
// Email Functions (from src/functions/)
// ═══════════════════════════════════════════════════════════════
var onUserCreated_1 = require("./functions/onUserCreated");
Object.defineProperty(exports, "onUserCreated", { enumerable: true, get: function () { return onUserCreated_1.onUserCreated; } });
var sendContactForm_1 = require("./functions/sendContactForm");
Object.defineProperty(exports, "sendContactForm", { enumerable: true, get: function () { return sendContactForm_1.sendContactForm; } });
var sendTeacherInvitation_1 = require("./functions/sendTeacherInvitation");
Object.defineProperty(exports, "sendTeacherInvitation", { enumerable: true, get: function () { return sendTeacherInvitation_1.sendTeacherInvitationFn; } });
var sendSchoolAnnouncement_1 = require("./functions/sendSchoolAnnouncement");
Object.defineProperty(exports, "sendSchoolAnnouncement", { enumerable: true, get: function () { return sendSchoolAnnouncement_1.sendSchoolAnnouncementFn; } });
// ═══════════════════════════════════════════════════════════════
// Email Worker (from src/workers/)
// ═══════════════════════════════════════════════════════════════
var emailWorker_1 = require("./workers/emailWorker");
Object.defineProperty(exports, "emailWorker", { enumerable: true, get: function () { return emailWorker_1.emailWorker; } });
// ═══════════════════════════════════════════════════════════════
// Auth Trigger — User Delete (cascade)
// ═══════════════════════════════════════════════════════════════
/**
 * Cascade delete all organization data when a Firebase Auth user (owner) is deleted.
 * Also handles cleanup when any user is deleted.
 */
exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
    const uid = user.uid;
    console.log(`User deleted: ${uid}`);
    try {
        // 1. Check if this user is an owner of any organization
        const orgSnapshot = await db
            .collection('organizations')
            .where('ownerId', '==', uid)
            .limit(1)
            .get();
        if (!orgSnapshot.empty) {
            const orgId = orgSnapshot.docs[0].id;
            console.log(`Owner deleted — cascade deleting organization: ${orgId}`);
            await deleteOrganizationData(orgId);
        }
        else {
            await cleanupUserReferences(uid);
        }
        // 2. Delete the user document
        const userDoc = db.collection('users').doc(uid);
        const userDocSnap = await userDoc.get();
        if (userDocSnap.exists) {
            await userDoc.delete();
            console.log(`Deleted user document for ${uid}`);
        }
        console.log(`Cascade delete completed for user: ${uid}`);
        return null;
    }
    catch (error) {
        console.error(`Cascade delete FAILED for user ${uid}:`, error);
        throw error;
    }
});
// ═══════════════════════════════════════════════════════════════
// Firestore Triggers — Push Notifications
// ═══════════════════════════════════════════════════════════════
/**
 * Firestore trigger: When a new notification document is created with
 * relatedType === 'conversation', send an FCM push notification.
 */
exports.onNewMessageNotification = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snap, context) => {
    const data = snap.data();
    const userId = data.userId;
    const relatedType = data.relatedType;
    const type = data.type;
    if (type !== 'new_message' && relatedType !== 'conversation') {
        return null;
    }
    try {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            console.log(`User ${userId} not found, skipping push`);
            return null;
        }
        const fcmToken = userDoc.data()?.fcmToken;
        if (!fcmToken) {
            console.log(`No FCM token for user ${userId}, skipping push`);
            return null;
        }
        const message = {
            token: fcmToken,
            notification: {
                title: data.title || 'New Message',
                body: data.body || 'You have a new message',
            },
            data: {
                type: type || 'new_message',
                relatedType: relatedType || 'conversation',
                relatedId: data.relatedId || '',
                organizationId: data.organizationId || '',
                notificationId: context.params.notificationId,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'klasivo_messages',
                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                },
            },
            apns: {
                payload: {
                    aps: {
                        badge: 1,
                        sound: 'default',
                    },
                },
            },
        };
        const response = await admin.messaging().send(message);
        console.log(`Push sent to ${userId}: ${response}`);
        return response;
    }
    catch (error) {
        const err = error;
        console.error(`Failed to send push to ${userId}:`, error);
        if (err.code === 'messaging/invalid-registration-token' ||
            err.code === 'messaging/registration-token-not-registered') {
            await db.collection('users').doc(userId).update({
                fcmToken: admin.firestore.FieldValue.delete(),
                fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Cleared invalid FCM token for user ${userId}`);
        }
        return null;
    }
});
/**
 * Firestore trigger: When a new message is created directly, also send
 * push notifications to all conversation participants (except sender).
 */
exports.onNewMessage = functions.firestore
    .document('messages/{messageId}')
    .onCreate(async (snap) => {
    const data = snap.data();
    const conversationId = data.conversationId;
    const senderId = data.senderId;
    const text = data.text || '';
    if (!conversationId || !senderId)
        return null;
    try {
        const convDoc = await db.collection('conversations').doc(conversationId).get();
        if (!convDoc.exists)
            return null;
        const convData = convDoc.data();
        const participantIds = convData.participantIds || [];
        const recipients = participantIds.filter((id) => id !== senderId);
        if (recipients.length === 0)
            return null;
        const senderDoc = await db.collection('users').doc(senderId).get();
        const senderName = senderDoc.exists ? (senderDoc.data()?.name || 'Someone') : 'Someone';
        const convName = convData.name || null;
        const title = convName || senderName;
        const preview = text.length > 100 ? text.substring(0, 100) + '...' : text;
        const tokens = [];
        const tokenMap = {};
        for (const recipientId of recipients) {
            const userDoc = await db.collection('users').doc(recipientId).get();
            if (userDoc.exists && userDoc.data()?.fcmToken) {
                const token = userDoc.data().fcmToken;
                tokens.push(token);
                tokenMap[token] = recipientId;
            }
        }
        if (tokens.length === 0)
            return null;
        const message = {
            tokens,
            notification: { title, body: preview },
            data: {
                type: 'new_message',
                relatedType: 'conversation',
                relatedId: conversationId,
                organizationId: convData.organizationId || '',
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'klasivo_messages',
                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                },
            },
            apns: {
                payload: {
                    aps: {
                        badge: 1,
                        sound: 'default',
                    },
                },
            },
        };
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Push sent to ${response.successCount}/${tokens.length} recipients`);
        if (response.failureCount > 0) {
            const invalidUserIds = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const token = tokens[idx];
                    const err = resp.error;
                    if (err?.code === 'messaging/invalid-registration-token' ||
                        err?.code === 'messaging/registration-token-not-registered') {
                        invalidUserIds.push(tokenMap[token]);
                    }
                }
            });
            for (const userId of invalidUserIds) {
                await db.collection('users').doc(userId).update({
                    fcmToken: admin.firestore.FieldValue.delete(),
                    fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
        return null;
    }
    catch (error) {
        console.error('Failed to send message push:', error);
        return null;
    }
});
// ═══════════════════════════════════════════════════════════════
// Helpers — Cascade Delete
// ═══════════════════════════════════════════════════════════════
async function deleteOrganizationData(orgId) {
    const collectionsToClean = [
        'users',
        'stages',
        'classes',
        'subjects',
        'groups',
        'group_members',
        'teacher_assignments',
        'exams',
        'question_banks',
        'invite_codes',
        'assignments',
        'assignment_submissions',
        'attendance',
        'conversations',
        'messages',
        'analytics_cache',
        'notifications',
    ];
    for (const collectionName of collectionsToClean) {
        if (collectionName === 'group_members') {
            const groupsSnapshot = await db
                .collection('groups')
                .where('organizationId', '==', orgId)
                .get();
            const groupIds = groupsSnapshot.docs.map((doc) => doc.id);
            let totalDeleted = 0;
            for (let i = 0; i < groupIds.length; i += 30) {
                const chunk = groupIds.slice(i, i + 30);
                const snapshot = await db
                    .collection('group_members')
                    .where('groupId', 'in', chunk)
                    .get();
                totalDeleted += await deleteSnapshot(snapshot);
            }
            if (totalDeleted > 0)
                console.log(`Deleted ${totalDeleted} from group_members for org ${orgId}`);
            continue;
        }
        if (collectionName === 'assignment_submissions') {
            const assignmentsSnapshot = await db
                .collection('assignments')
                .where('organizationId', '==', orgId)
                .get();
            const assignmentIds = assignmentsSnapshot.docs.map((doc) => doc.id);
            let totalDeleted = 0;
            for (let i = 0; i < assignmentIds.length; i += 30) {
                const chunk = assignmentIds.slice(i, i + 30);
                const snapshot = await db
                    .collection('assignment_submissions')
                    .where('assignmentId', 'in', chunk)
                    .get();
                totalDeleted += await deleteSnapshot(snapshot);
            }
            if (totalDeleted > 0)
                console.log(`Deleted ${totalDeleted} from assignment_submissions for org ${orgId}`);
            continue;
        }
        if (collectionName === 'messages') {
            const convsSnapshot = await db
                .collection('conversations')
                .where('organizationId', '==', orgId)
                .get();
            const convIds = convsSnapshot.docs.map((doc) => doc.id);
            let totalDeleted = 0;
            for (let i = 0; i < convIds.length; i += 30) {
                const chunk = convIds.slice(i, i + 30);
                const snapshot = await db
                    .collection('messages')
                    .where('conversationId', 'in', chunk)
                    .get();
                totalDeleted += await deleteSnapshot(snapshot);
            }
            if (totalDeleted > 0)
                console.log(`Deleted ${totalDeleted} from messages for org ${orgId}`);
            continue;
        }
        const snapshot = await db
            .collection(collectionName)
            .where('organizationId', '==', orgId)
            .get();
        if (!snapshot.empty) {
            const count = await deleteSnapshot(snapshot);
            console.log(`Deleted ${count} from ${collectionName} for org ${orgId}`);
        }
    }
    // Exam-related sub-collections
    const examsSnapshot = await db
        .collection('exams')
        .where('organizationId', '==', orgId)
        .get();
    const examIds = examsSnapshot.docs.map((doc) => doc.id);
    if (examIds.length > 0) {
        const examCollections = ['questions', 'submissions', 'violations', 'exam_attempts', 'exam_stats'];
        for (const collectionName of examCollections) {
            let totalDeleted = 0;
            for (let i = 0; i < examIds.length; i += 30) {
                const chunk = examIds.slice(i, i + 30);
                const snapshot = await db
                    .collection(collectionName)
                    .where('examId', 'in', chunk)
                    .get();
                totalDeleted += await deleteSnapshot(snapshot);
            }
            if (totalDeleted > 0)
                console.log(`Deleted ${totalDeleted} from ${collectionName} for org ${orgId}`);
        }
        // Delete answers (linked via submissionId)
        const submissionIds = [];
        for (let i = 0; i < examIds.length; i += 30) {
            const chunk = examIds.slice(i, i + 30);
            const subSnapshot = await db
                .collection('submissions')
                .where('examId', 'in', chunk)
                .get();
            submissionIds.push(...subSnapshot.docs.map((doc) => doc.id));
        }
        if (submissionIds.length > 0) {
            let answersDeleted = 0;
            for (let i = 0; i < submissionIds.length; i += 30) {
                const chunk = submissionIds.slice(i, i + 30);
                const ansSnapshot = await db
                    .collection('answers')
                    .where('submissionId', 'in', chunk)
                    .get();
                answersDeleted += await deleteSnapshot(ansSnapshot);
            }
            if (answersDeleted > 0)
                console.log(`Deleted ${answersDeleted} from answers for org ${orgId}`);
        }
    }
    // Delete the organization document
    await db.collection('organizations').doc(orgId).delete();
    console.log(`Deleted organization document: ${orgId}`);
}
async function cleanupUserReferences(uid) {
    const taSnapshot = await db
        .collection('teacher_assignments')
        .where('teacherId', '==', uid)
        .get();
    if (!taSnapshot.empty) {
        await deleteSnapshot(taSnapshot);
        console.log(`Deleted ${taSnapshot.size} teacher_assignments for user ${uid}`);
    }
    const gmSnapshot = await db
        .collection('group_members')
        .where('studentId', '==', uid)
        .get();
    if (!gmSnapshot.empty) {
        await deleteSnapshot(gmSnapshot);
        console.log(`Deleted ${gmSnapshot.size} group_members for user ${uid}`);
    }
    const notifSnapshot = await db
        .collection('notifications')
        .where('userId', '==', uid)
        .get();
    if (!notifSnapshot.empty) {
        await deleteSnapshot(notifSnapshot);
        console.log(`Deleted ${notifSnapshot.size} notifications for user ${uid}`);
    }
    const codeSnapshot = await db
        .collection('invite_codes')
        .where('createdBy', '==', uid)
        .get();
    if (!codeSnapshot.empty) {
        await deleteSnapshot(codeSnapshot);
        console.log(`Deleted ${codeSnapshot.size} invite_codes for user ${uid}`);
    }
    const attSnapshot = await db
        .collection('attendance')
        .where('studentId', '==', uid)
        .get();
    if (!attSnapshot.empty) {
        await deleteSnapshot(attSnapshot);
        console.log(`Deleted ${attSnapshot.size} attendance records for user ${uid}`);
    }
    const convSnapshot = await db
        .collection('conversations')
        .where('participantIds', 'array-contains', uid)
        .get();
    if (!convSnapshot.empty) {
        const batch = db.batch();
        for (const doc of convSnapshot.docs) {
            const participants = doc.data()['participantIds'] || [];
            const updated = participants.filter((id) => id !== uid);
            if (updated.length === 0) {
                batch.delete(doc.ref);
            }
            else {
                batch.update(doc.ref, {
                    participantIds: updated,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
        await batch.commit();
        console.log(`Updated/removed ${convSnapshot.size} conversations for user ${uid}`);
    }
    const studentCacheDoc = db.collection('analytics_cache').doc(`student_${uid}`);
    const teacherCacheDoc = db.collection('analytics_cache').doc(`teacher_${uid}`);
    const batch = db.batch();
    const studentCache = await studentCacheDoc.get();
    const teacherCache = await teacherCacheDoc.get();
    if (studentCache.exists)
        batch.delete(studentCacheDoc);
    if (teacherCache.exists)
        batch.delete(teacherCacheDoc);
    await batch.commit();
}
async function deleteSnapshot(snapshot) {
    if (snapshot.empty)
        return 0;
    const batchPromises = [];
    let batch = db.batch();
    let opCount = 0;
    for (const doc of snapshot.docs) {
        batch.delete(doc.ref);
        opCount++;
        if (opCount === 500) {
            batchPromises.push(batch.commit());
            batch = db.batch();
            opCount = 0;
        }
    }
    if (opCount > 0) {
        batchPromises.push(batch.commit());
    }
    await Promise.all(batchPromises);
    return snapshot.size;
}
//# sourceMappingURL=index.js.map