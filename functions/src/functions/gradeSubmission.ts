/**
 * gradeSubmission — Server-side auto-grading for objective exams
 *
 * Called by staff or triggered on submission. Reads all answers, compares
 * to correct answers, calculates score/percentage, updates submission with
 * grading fields. Student client CANNOT write these fields (blocked by
 * studentSafeSubmissionUpdate).
 *
 * Security:
 *   - Staff-only (students cannot trigger their own grading)
 *   - Server-side deadline check (exam window must be open or closed)
 *   - Idempotency: rejects re-grading if a teacher has already manually
 *     graded the submission (status=='reviewed' or manuallyGraded==true)
 *   - Org boundary verification (prevent cross-tenant grading)
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { verifyOrgBoundary } from '../utils/rbac';

export const gradeSubmission = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 60,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'exams');
      scope.setTag('function', 'gradeSubmission');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const { submissionId, examId } = request.data as { submissionId: string; examId: string };

      if (!submissionId || !examId) {
        throw new HttpsError('invalid-argument', 'submissionId and examId are required.');
      }

      const db = getFirestore();

      // Get submission
      const subRef = db.collection('submissions').doc(submissionId);
      const subDoc = await subRef.get();
      if (!subDoc.exists) {
        throw new HttpsError('not-found', 'Submission not found.');
      }

            const subData = subDoc.data()!;
      const studentId = subData.studentId as string;

      // ─── Caller must be staff (students cannot trigger their own grading) ──
      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';
      const isStaff = ['super_admin', 'owner', 'admin', 'teacher', 'assistant_teacher'].includes(callerRole);

      if (!isStaff) {
        throw new HttpsError('permission-denied', 'Only staff can grade submissions.');
      }

      // ─── Verify org boundary — prevent cross-tenant grading ─────────────
      const submissionOrgId = (subData.organizationId as string) || '';
      if (!verifyOrgBoundary(callerOrgId, submissionOrgId, callerRole)) {
        throw new HttpsError('permission-denied', 'Cross-org grading not allowed.');
      }

      // ─── Idempotency: reject re-grading if teacher has manually graded ────
      const submissionStatus = (subData.status as string) || '';
      const manuallyGraded = (subData.manuallyGraded as boolean) || false;
      if (manuallyGraded || submissionStatus === 'reviewed') {
        throw new HttpsError(
          'failed-precondition',
          'This submission was manually graded and cannot be auto-graded.',
        );
      }

      // ─── Server-side deadline check (exam window must have opened) ──────
      const examDoc = await db.collection('exams').doc(examId).get();
      if (!examDoc.exists) {
        throw new HttpsError('not-found', 'Exam not found.');
      }
      const examData = examDoc.data()!;
      const endTime = examData['endTime'] as { toDate: () => Date } | null;
      const startTime = examData['startTime'] as { toDate: () => Date } | null;
      const now = Date.now();

      // Allow grading if exam has started (or has no start time). Reject if
      // the exam hasn't opened yet — prevents pre-grading before the window.
      if (startTime && startTime.toDate().getTime() > now) {
        throw new HttpsError(
          'failed-precondition',
          'Exam has not started yet. Cannot grade before the exam window opens.',
        );
      }

      // Get questions
      const questionsSnapshot = await db.collection('questions')
        .where('examId', '==', examId)
        .get();

      // Get answers
      const answersSnapshot = await db.collection('answers')
        .where('submissionId', '==', submissionId)
        .get();

      // Grade
      let score = 0;
      let totalMarks = 0;
      const batch = db.batch();

      for (const qDoc of questionsSnapshot.docs) {
        const qData = qDoc.data();
        const marks = (qData.marks as number) || 0;
        totalMarks += marks;

        const correctAnswer = qData.correctAnswer as string || '';
        const answerDoc = answersSnapshot.docs.find(
          (a) => a.data().questionId === qDoc.id
        );

        if (answerDoc) {
          const studentAnswer = (answerDoc.data().answer as string) || '';
          const isCorrect = studentAnswer.trim().toLowerCase() === correctAnswer.trim().toLowerCase();
          const marksAwarded = isCorrect ? marks : 0;
          score += marksAwarded;

          batch.update(answerDoc.ref, {
            isCorrect: isCorrect,
            marksAwarded: marksAwarded,
            gradedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      const percentage = totalMarks > 0 ? Math.round((score / totalMarks) * 100) : 0;

      // Update submission with grading fields (server-side, bypasses client rules)
      batch.update(subRef, {
        status: 'submitted',
        score: score,
        percentage: percentage,
        totalMarks: totalMarks,
        gradedAt: FieldValue.serverTimestamp(),
        isGraded: true,
      });

      await batch.commit();

      return { success: true, score, percentage, totalMarks };
    });
  },
);
