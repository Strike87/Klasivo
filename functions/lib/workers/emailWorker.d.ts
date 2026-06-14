/**
 * Klasivo — Email Worker
 *
 * Firestore trigger that processes emails from the emailQueue collection.
 *
 * Flow:
 *   emailQueue doc created (status: pending)
 *     ↓
 *   Worker picks it up → status: processing
 *     ↓
 *   Dispatches to the right emailService function
 *     ↓
 *   Success → status: sent, log to emailLogs
 *   Failure → retry (up to 5 attempts), then status: failed
 *
 * Retry strategy:
 *   - Simple in-function retry with backoff (1s, 2s, 3s, 4s)
 *   - Max 5 attempts per queue entry
 *   - After 5 failures, mark as 'failed' and stop
 */
import * as functions from 'firebase-functions/v1';
export declare const emailWorker: functions.CloudFunction<functions.firestore.QueryDocumentSnapshot>;
//# sourceMappingURL=emailWorker.d.ts.map