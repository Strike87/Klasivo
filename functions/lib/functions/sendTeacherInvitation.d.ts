/**
 * Klasivo — sendTeacherInvitation Callable Function
 *
 * School owner invites a teacher to join their organisation.
 *
 * Flow:
 *   Flutter → Callable → emailQueue → emailWorker → emailService → Resend
 *
 * The function returns immediately with the queue ID.
 * The email will be sent asynchronously by the worker.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendTeacherInvitation').call({
 *     email: 'teacher@school.com',
 *     teacherName: 'Dr. Ahmed',
 *     schoolName: 'Al-Noor School',
 *     inviterName: 'Mohamed (Admin)',
 *     inviteCode: 'ABC-XYZ',
 *     orgId: 'org123',
 *   });
 */
import * as functions from 'firebase-functions/v1';
export declare const sendTeacherInvitationFn: functions.HttpsFunction & functions.Runnable<any>;
//# sourceMappingURL=sendTeacherInvitation.d.ts.map