const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * Cascade delete all organization data when a Firebase Auth user (owner) is deleted.
 * Also handles cleanup when any user is deleted.
 */
exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  console.log(`User deleted: ${uid}`);

  try {
    // 1. Check if this user is an owner of any organization
    const orgSnapshot = await db.collection('organizations')
      .where('ownerId', '==', uid)
      .limit(1)
      .get();

    if (!orgSnapshot.empty) {
      // This user is an organization owner - delete the entire organization
      const orgId = orgSnapshot.docs[0].id;
      console.log(`Owner deleted - cascade deleting organization: ${orgId}`);
      await deleteOrganizationData(orgId);
    } else {
      // This user is a teacher or student - clean up their references
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
  } catch (error) {
    console.error(`Cascade delete FAILED for user ${uid}:`, error);
    throw error;
  }
});

/**
 * Delete all data belonging to an organization
 */
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
    'notifications',
  ];

  for (const collectionName of collectionsToClean) {
    let field = 'organizationId';

    // Some collections don't have organizationId directly
    if (collectionName === 'group_members') {
      // Delete group members by finding groups in this org
      const groupsSnapshot = await db.collection('groups')
        .where('organizationId', '==', orgId)
        .get();
      const groupIds = groupsSnapshot.docs.map(doc => doc.id);

      let totalDeleted = 0;
      for (let i = 0; i < groupIds.length; i += 30) {
        const chunk = groupIds.slice(i, i + 30);
        const snapshot = await db.collection('group_members')
          .where('groupId', 'in', chunk)
          .get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from group_members for org ${orgId}`);
      continue;
    }

    if (collectionName === 'assignment_submissions') {
      // Delete by finding assignments in this org
      const assignmentsSnapshot = await db.collection('assignments')
        .where('organizationId', '==', orgId)
        .get();
      const assignmentIds = assignmentsSnapshot.docs.map(doc => doc.id);

      let totalDeleted = 0;
      for (let i = 0; i < assignmentIds.length; i += 30) {
        const chunk = assignmentIds.slice(i, i + 30);
        const snapshot = await db.collection('assignment_submissions')
          .where('assignmentId', 'in', chunk)
          .get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from assignment_submissions for org ${orgId}`);
      continue;
    }

    const snapshot = await db.collection(collectionName)
      .where(field, '==', orgId)
      .get();

    if (!snapshot.empty) {
      const count = await deleteSnapshot(snapshot);
      console.log(`Deleted ${count} from ${collectionName} for org ${orgId}`);
    }
  }

  // Also delete exam-related collections (questions, submissions, answers, violations, exam_attempts, exam_stats)
  const examsSnapshot = await db.collection('exams')
    .where('organizationId', '==', orgId)
    .get();
  const examIds = examsSnapshot.docs.map(doc => doc.id);

  if (examIds.length > 0) {
    const examCollections = ['questions', 'submissions', 'violations', 'exam_attempts', 'exam_stats'];
    for (const collectionName of examCollections) {
      let totalDeleted = 0;
      for (let i = 0; i < examIds.length; i += 30) {
        const chunk = examIds.slice(i, i + 30);
        const snapshot = await db.collection(collectionName)
          .where('examId', 'in', chunk)
          .get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from ${collectionName} for org ${orgId}`);
    }

    // Delete answers (linked via submissionId)
    let submissionIds = [];
    for (let i = 0; i < examIds.length; i += 30) {
      const chunk = examIds.slice(i, i + 30);
      const subSnapshot = await db.collection('submissions')
        .where('examId', 'in', chunk)
        .get();
      submissionIds.push(...subSnapshot.docs.map(doc => doc.id));
    }

    if (submissionIds.length > 0) {
      let answersDeleted = 0;
      for (let i = 0; i < submissionIds.length; i += 30) {
        const chunk = submissionIds.slice(i, i + 30);
        const ansSnapshot = await db.collection('answers')
          .where('submissionId', 'in', chunk)
          .get();
        answersDeleted += await deleteSnapshot(ansSnapshot);
      }
      if (answersDeleted > 0) console.log(`Deleted ${answersDeleted} from answers for org ${orgId}`);
    }
  }

  // Delete the organization document
  await db.collection('organizations').doc(orgId).delete();
  console.log(`Deleted organization document: ${orgId}`);
}

/**
 * Clean up references when a teacher or student is deleted
 */
async function cleanupUserReferences(uid) {
  // Delete teacher assignments
  const taSnapshot = await db.collection('teacher_assignments')
    .where('teacherId', '==', uid)
    .get();
  if (!taSnapshot.empty) {
    await deleteSnapshot(taSnapshot);
    console.log(`Deleted ${taSnapshot.size} teacher_assignments for user ${uid}`);
  }

  // Delete group memberships
  const gmSnapshot = await db.collection('group_members')
    .where('studentId', '==', uid)
    .get();
  if (!gmSnapshot.empty) {
    await deleteSnapshot(gmSnapshot);
    console.log(`Deleted ${gmSnapshot.size} group_members for user ${uid}`);
  }

  // Delete notifications
  const notifSnapshot = await db.collection('notifications')
    .where('userId', '==', uid)
    .get();
  if (!notifSnapshot.empty) {
    await deleteSnapshot(notifSnapshot);
    console.log(`Deleted ${notifSnapshot.size} notifications for user ${uid}`);
  }

  // Delete invite codes created by this user
  const codeSnapshot = await db.collection('invite_codes')
    .where('createdBy', '==', uid)
    .get();
  if (!codeSnapshot.empty) {
    await deleteSnapshot(codeSnapshot);
    console.log(`Deleted ${codeSnapshot.size} invite_codes for user ${uid}`);
  }
}

/**
 * Delete all documents in a snapshot using batched writes
 */
async function deleteSnapshot(snapshot) {
  if (snapshot.empty) return 0;

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
