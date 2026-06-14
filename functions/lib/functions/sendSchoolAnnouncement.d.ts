/**
 * Klasivo — sendSchoolAnnouncement Callable Function
 *
 * Broadcast an announcement to one or more recipients.
 * Supports three priority levels: urgent, important, normal.
 *
 * Flow:
 *   Flutter → Callable → emailQueue → emailWorker → emailService → Resend
 *
 * The function returns immediately with the queue ID.
 * The email will be sent asynchronously by the worker.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendSchoolAnnouncement').call({
 *     to: ['parent1@email.com', 'parent2@email.com'],  // or single string
 *     schoolName: 'Al-Noor School',
 *     title: 'Midterm Exam Schedule',
 *     message: 'Dear parents, ...',
 *     senderName: 'Principal Mohamed',
 *     senderRole: 'Principal',
 *     priority: 'important',  // 'urgent' | 'important' | 'normal'
 *   });
 */
import * as functions from 'firebase-functions/v1';
export declare const sendSchoolAnnouncementFn: functions.HttpsFunction & functions.Runnable<any>;
//# sourceMappingURL=sendSchoolAnnouncement.d.ts.map