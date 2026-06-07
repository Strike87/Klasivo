const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

/**
 * Cascade delete all teacher data when a Firebase Auth user is deleted.
 *
 * Collections directly owned by teacher (via teacherId field):
 *   - students, classes, exams, stages, grades, groups, question_bank
 *
 * Collections indirectly owned (via examId -> exams.teacherId):
 *   - questions, submissions, answers, violations, exam_instances, exam_stats
 *
 * Collections owned via userId:
 *   - notifications
 *
 * Collections owned via document ID:
 *   - users (document ID = auth UID)
 */
exports.onUserDelete = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  console.log(`Cascade delete started for user: ${uid}`);

  try {
    // 1. Delete directly-owned collections (teacherId = uid)
    const directCollections = [
      'students',
      'classes',
      'exams',
      'stages',
      'grades',
      'groups',
      'question_bank',
    ];

    // Collect exam IDs before deleting exams (needed for indirect collections)
    let examIds = [];

    for (const collectionName of directCollections) {
      const snapshot = await db.collection(collectionName)
        .where('teacherId', '==', uid)
        .get();

      if (collectionName === 'exams') {
        examIds = snapshot.docs.map(doc => doc.id);
      }

      if (!snapshot.empty) {
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
        console.log(`Deleted ${snapshot.size} docs from ${collectionName} for user ${uid}`);
      }
    }

    // 2. Delete indirectly-owned collections (linked via examId)
    if (examIds.length > 0) {
      const indirectCollections = [
        'questions',
        'submissions',
        'violations',
        'exam_instances',
        'exam_stats',
      ];

      for (const collectionName of indirectCollections) {
        let totalDeleted = 0;

        // Process examIds in chunks of 30 (Firestore 'in' query limit)
        for (let i = 0; i < examIds.length; i += 30) {
          const chunk = examIds.slice(i, i + 30);

          const snapshot = await db.collection(collectionName)
            .where('examId', 'in', chunk)
            .get();

          if (!snapshot.empty) {
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
            totalDeleted += snapshot.size;
          }
        }

        if (totalDeleted > 0) {
          console.log(`Deleted ${totalDeleted} docs from ${collectionName} for user ${uid}`);
        }
      }

      // 3. Delete answers linked to submissions (answers -> submissionId -> submissions.examId)
      // We need to find submissions first, then delete their answers
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

          if (!ansSnapshot.empty) {
            const batchPromises = [];
            let batch = db.batch();
            let opCount = 0;

            for (const doc of ansSnapshot.docs) {
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
            answersDeleted += ansSnapshot.size;
          }
        }
        if (answersDeleted > 0) {
          console.log(`Deleted ${answersDeleted} docs from answers for user ${uid}`);
        }
      }
    }

    // 4. Delete notifications (userId = uid)
    const notifSnapshot = await db.collection('notifications')
      .where('userId', '==', uid)
      .get();

    if (!notifSnapshot.empty) {
      const batchPromises = [];
      let batch = db.batch();
      let opCount = 0;

      for (const doc of notifSnapshot.docs) {
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
      console.log(`Deleted ${notifSnapshot.size} docs from notifications for user ${uid}`);
    }

    // 5. Delete user document (document ID = uid)
    const userDocRef = db.collection('users').doc(uid);
    const userDoc = await userDocRef.get();
    if (userDoc.exists) {
      await userDocRef.delete();
      console.log(`Deleted user document for ${uid}`);
    }

    console.log(`Cascade delete completed for user: ${uid}`);
    return null;
  } catch (error) {
    console.error(`Cascade delete FAILED for user ${uid}:`, error);
    throw error;
  }
});
