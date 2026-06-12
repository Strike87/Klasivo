import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import * as Sentry from '@sentry/node';
import { initSentry } from '../config/sentry';

const db = admin.firestore();

export const onUserDeleted = functions
  .runWith({ secrets: ['SENTRY_DSN'] })
  .auth.user().onDelete(async (user) => {
    initSentry();
    Sentry.setTag('service', 'auth');
    Sentry.setTag('function', 'onUserDeleted');

    const uid = user.uid;
    console.log(`User deleted: ${uid}`);

    try {
      const orgSnapshot = await db
        .collection('organizations')
        .where('ownerId', '==', uid)
        .limit(1)
        .get();

      if (!orgSnapshot.empty) {
        const orgDoc = orgSnapshot.docs[0];
        if (orgDoc) {
          const orgId = orgDoc.id;
          console.log(`Owner deleted — cascade deleting organization: ${orgId}`);
          await deleteOrganizationData(orgId);
        }
      } else {
        await cleanupUserReferences(uid);
      }

      const userDocRef = db.collection('users').doc(uid);
      const userDocSnap = await userDocRef.get();
      if (userDocSnap.exists) {
        await userDocRef.delete();
        console.log(`Deleted user document for ${uid}`);
      }

      console.log(`Cascade delete completed for user: ${uid}`);
      return null;
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      console.error(`Cascade delete FAILED for user ${uid}: ${msg}`);
      Sentry.captureException(error);
      throw error;
    }
  });

async function deleteOrganizationData(orgId: string): Promise<void> {
  const collectionsToClean = [
    'users', 'stages', 'classes', 'subjects', 'groups', 'group_members',
    'teacher_assignments', 'exams', 'question_banks', 'invite_codes',
    'assignments', 'assignment_submissions', 'attendance', 'conversations',
    'messages', 'analytics_cache', 'notifications',
  ];

  for (const collectionName of collectionsToClean) {
    if (collectionName === 'group_members') {
      const groupsSnapshot = await db.collection('groups').where('organizationId', '==', orgId).get();
      const groupIds = groupsSnapshot.docs.map((doc) => doc.id);
      let totalDeleted = 0;
      for (let i = 0; i < groupIds.length; i += 30) {
        const chunk = groupIds.slice(i, i + 30);
        const snapshot = await db.collection('group_members').where('groupId', 'in', chunk).get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from group_members for org ${orgId}`);
      continue;
    }

    if (collectionName === 'assignment_submissions') {
      const assignmentsSnapshot = await db.collection('assignments').where('organizationId', '==', orgId).get();
      const assignmentIds = assignmentsSnapshot.docs.map((doc) => doc.id);
      let totalDeleted = 0;
      for (let i = 0; i < assignmentIds.length; i += 30) {
        const chunk = assignmentIds.slice(i, i + 30);
        const snapshot = await db.collection('assignment_submissions').where('assignmentId', 'in', chunk).get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from assignment_submissions for org ${orgId}`);
      continue;
    }

    if (collectionName === 'messages') {
      const convsSnapshot = await db.collection('conversations').where('organizationId', '==', orgId).get();
      const convIds = convsSnapshot.docs.map((doc) => doc.id);
      let totalDeleted = 0;
      for (let i = 0; i < convIds.length; i += 30) {
        const chunk = convIds.slice(i, i + 30);
        const snapshot = await db.collection('messages').where('conversationId', 'in', chunk).get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from messages for org ${orgId}`);
      continue;
    }

    const snapshot = await db.collection(collectionName).where('organizationId', '==', orgId).get();
    if (!snapshot.empty) {
      const count = await deleteSnapshot(snapshot);
      console.log(`Deleted ${count} from ${collectionName} for org ${orgId}`);
    }
  }

  // Delete exam-related collections
  const examsSnapshot = await db.collection('exams').where('organizationId', '==', orgId).get();
  const examIds = examsSnapshot.docs.map((doc) => doc.id);

  if (examIds.length > 0) {
    const examCollections = ['questions', 'submissions', 'violations', 'exam_attempts', 'exam_stats'];
    for (const collectionName of examCollections) {
      let totalDeleted = 0;
      for (let i = 0; i < examIds.length; i += 30) {
        const chunk = examIds.slice(i, i + 30);
        const snapshot = await db.collection(collectionName).where('examId', 'in', chunk).get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from ${collectionName} for org ${orgId}`);
    }

    const submissionIds: string[] = [];
    for (let i = 0; i < examIds.length; i += 30) {
      const chunk = examIds.slice(i, i + 30);
      const subSnapshot = await db.collection('submissions').where('examId', 'in', chunk).get();
      for (const doc of subSnapshot.docs) submissionIds.push(doc.id);
    }

    if (submissionIds.length > 0) {
      let answersDeleted = 0;
      for (let i = 0; i < submissionIds.length; i += 30) {
        const chunk = submissionIds.slice(i, i + 30);
        const ansSnapshot = await db.collection('answers').where('submissionId', 'in', chunk).get();
        answersDeleted += await deleteSnapshot(ansSnapshot);
      }
      if (answersDeleted > 0) console.log(`Deleted ${answersDeleted} from answers for org ${orgId}`);
    }
  }

  await db.collection('organizations').doc(orgId).delete();
  console.log(`Deleted organization document: ${orgId}`);
}

async function cleanupUserReferences(uid: string): Promise<void> {
  const taSnapshot = await db.collection('teacher_assignments').where('teacherId', '==', uid).get();
  if (!taSnapshot.empty) { await deleteSnapshot(taSnapshot); console.log(`Deleted ${taSnapshot.size} teacher_assignments for user ${uid}`); }

  const gmSnapshot = await db.collection('group_members').where('studentId', '==', uid).get();
  if (!gmSnapshot.empty) { await deleteSnapshot(gmSnapshot); console.log(`Deleted ${gmSnapshot.size} group_members for user ${uid}`); }

  const notifSnapshot = await db.collection('notifications').where('userId', '==', uid).get();
  if (!notifSnapshot.empty) { await deleteSnapshot(notifSnapshot); console.log(`Deleted ${notifSnapshot.size} notifications for user ${uid}`); }

  const codeSnapshot = await db.collection('invite_codes').where('createdBy', '==', uid).get();
  if (!codeSnapshot.empty) { await deleteSnapshot(codeSnapshot); console.log(`Deleted ${codeSnapshot.size} invite_codes for user ${uid}`); }

  const attSnapshot = await db.collection('attendance').where('studentId', '==', uid).get();
  if (!attSnapshot.empty) { await deleteSnapshot(attSnapshot); console.log(`Deleted ${attSnapshot.size} attendance records for user ${uid}`); }

  const convSnapshot = await db.collection('conversations').where('participantIds', 'array-contains', uid).get();
  if (!convSnapshot.empty) {
    const batch = db.batch();
    for (const doc of convSnapshot.docs) {
      const participants = doc.data()['participantIds'] as string[] | undefined;
      if (!participants) continue;
      const updated = participants.filter((id) => id !== uid);
      if (updated.length === 0) { batch.delete(doc.ref); }
      else { batch.update(doc.ref, { participantIds: updated, updatedAt: admin.firestore.FieldValue.serverTimestamp() }); }
    }
    await batch.commit();
    console.log(`Updated/removed ${convSnapshot.size} conversations for user ${uid}`);
  }

  const studentCacheDoc = db.collection('analytics_cache').doc(`student_${uid}`);
  const teacherCacheDoc = db.collection('analytics_cache').doc(`teacher_${uid}`);
  const batch = db.batch();
  const studentCache = await studentCacheDoc.get();
  const teacherCache = await teacherCacheDoc.get();
  if (studentCache.exists) batch.delete(studentCacheDoc);
  if (teacherCache.exists) batch.delete(teacherCacheDoc);
  await batch.commit();
}

async function deleteSnapshot(snapshot: admin.firestore.QuerySnapshot): Promise<number> {
  if (snapshot.empty) return 0;
  const batchPromises: Promise<admin.firestore.WriteResult[]>[] = [];
  let batch = db.batch();
  let opCount = 0;
  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
    opCount++;
    if (opCount === 500) { batchPromises.push(batch.commit()); batch = db.batch(); opCount = 0; }
  }
  if (opCount > 0) batchPromises.push(batch.commit());
  await Promise.all(batchPromises);
  return snapshot.size;
}
