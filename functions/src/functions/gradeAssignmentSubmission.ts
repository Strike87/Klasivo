/**
 * gradeAssignmentSubmission — Server-side assignment grading
 *
 * Called when a teacher grades an assignment submission. Updates score,
 * percentage, feedback, status via Admin SDK (bypasses client rules).
 *
 * Student client CANNOT write grading fields — only this CF can.
 *
 * Pattern matches gradeSubmission.ts (the exam equivalent).
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

interface GradeAssignmentData {
  submissionId: string;
  score: number;
  feedback?: string;
  gradedBy: string;
  gradedByName: string;
  rubricScores?: Record<string, number>;
}

const STAFF_ROLES = ['super_admin', 'owner', 'admin', 'teacher', 'assistant_teacher'];

export const gradeAssignmentSubmission = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'assignments');
      scope.setTag('function', 'gradeAssignmentSubmission');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      const callerRole = (request.auth.token.role as string) || '';
      const callerOrgId = (request.auth.token.organizationId as string) || '';

      if (!STAFF_ROLES.includes(callerRole)) {
        throw new HttpsError('permission-denied', 'Only staff can grade assignments.');
      }

      const data = request.data as GradeAssignmentData;

      if (!data.submissionId || typeof data.score !== 'number') {
        throw new HttpsError('invalid-argument', 'submissionId and numeric score are required.');
      }

      const db = getFirestore();

      const subRef = db.collection('assignment_submissions').doc(data.submissionId);
      const subDoc = await subRef.get();

      if (!subDoc.exists) {
        throw new HttpsError('not-found', 'Submission not found.');
      }

      const subData = subDoc.data()!;

      // Verify org boundary — prevent cross-tenant grading
      if (subData.organizationId !== callerOrgId) {
        throw new HttpsError('permission-denied', 'Cross-org grading not allowed.');
      }

      const maxScore = (subData.maxScore as number) || 100;
      if (data.score < 0 || data.score > maxScore) {
        throw new HttpsError('invalid-argument', `Score must be 0-${maxScore}.`);
      }

      // Apply late penalty if applicable
      const latePenalty = (subData.latePenalty as number) || 0;
      const adjustedScore = data.score * (1 - latePenalty);
      const percentage = (adjustedScore / maxScore) * 100;

      await subRef.update({
        score: adjustedScore,
        originalScore: data.score,
        percentage,
        status: 'graded',
        gradedBy: data.gradedBy,
        gradedByName: data.gradedByName,
        gradedAt: FieldValue.serverTimestamp(),
        feedback: data.feedback || null,
        rubricScores: data.rubricScores || null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // Audit log
      await db.collection('audit_logs').add({
        organizationId: callerOrgId,
        performedBy: callerUid,
        performedByRole: callerRole,
        action: 'grade_assignment_submission',
        targetType: 'assignment_submission',
        targetId: data.submissionId,
        metadata: {
          score: adjustedScore,
          originalScore: data.score,
          percentage,
          latePenaltyApplied: latePenalty > 0,
        },
        timestamp: FieldValue.serverTimestamp(),
        serverVerified: true,
      });

      // Send notification to student
      const studentUid = subData.studentId as string;
      if (studentUid) {
        await db.collection('notifications').add({
          organizationId: callerOrgId,
          userId: studentUid,
          type: 'assignment_graded',
          title: 'Assignment Graded',
          body: `Your submission scored ${percentage.toFixed(1)}%`,
          data: {
            submissionId: data.submissionId,
            assignmentId: subData.assignmentId,
          },
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      return { success: true, score: adjustedScore, percentage };
    });
  },
);
