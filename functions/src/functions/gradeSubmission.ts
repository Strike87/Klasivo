/**
 * gradeSubmission — P1-3: Server-side exam grading
 *
 * Called after student submits. Reads all answers, compares to correct answers,
 * calculates score/percentage, updates submission with grading fields.
 * Student client CANNOT write these fields (blocked by studentSafeSubmissionUpdate).
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

      // Verify caller is the student who owns this submission OR staff
      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';
      const isStaff = ['super_admin', 'owner', 'admin', 'teacher', 'assistant_teacher'].includes(callerRole);

      if (callerUid !== studentId && !isStaff) {
        throw new HttpsError('permission-denied', 'Can only grade your own submission.');
      }

      // Verify org boundary — prevent cross-tenant grading
      const submissionOrgId = (subData.organizationId as string) || '';
      if (!verifyOrgBoundary(callerOrgId, submissionOrgId, callerRole)) {
        throw new HttpsError('permission-denied', 'Cross-org grading not allowed.');
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
