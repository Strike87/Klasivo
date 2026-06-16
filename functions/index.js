/**
 * Klasivo — Firebase Cloud Functions
 *
 * Functions:
 *   Auth Triggers:
 *     onUserDelete          — Cascade-delete org data when an owner is removed
 *     onUserCreate          — Send welcome email when a new user signs up
 *
 *   Callable Functions (HTTPS):
 *     sendWelcomeEmail      — Manually trigger a welcome email
 *     sendContactForm       — Forward a contact-form submission to the team
 *     sendTeacherInvitation — Invite a teacher to join a school
 *     sendSchoolAnnouncement — Broadcast an announcement to members
 *
 *   Note: Firebase Auth handles Email Verification & Password Reset
 *   emails natively — no custom functions needed for those.
 */

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const {
  sendWelcomeEmail,
  sendContactFormNotification,
  sendTeacherInvitation,
  sendSchoolAnnouncement,
} = require('./services/emailService');

admin.initializeApp();

const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════
// Auth Triggers
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
 * Send a welcome email when a new Firebase Auth user is created.
 * Runs with RESEND_API_KEY secret access.
 *
 * This is a fire-and-forget email — if Resend is not configured the
 * function logs a warning but does NOT throw (user creation must not fail).
 */
exports.onUserCreate = functions
  .runWith({ secrets: ['RESEND_API_KEY'] })
  .auth.user()
  .onCreate(async (user) => {
    const uid = user.uid;
    const email = user.email;
    const displayName = user.displayName || email.split('@')[0];

    console.log(`New user created: ${uid} (${email})`);

    try {
      // Look up the user's role from Firestore (may not exist yet if the
      // Flutter app hasn't written the profile). Default to 'teacher'.
      const userDoc = await db.collection('users').doc(uid).get();
      const role = userDoc.exists ? (userDoc.data().role || 'teacher') : 'teacher';

      const result = await sendWelcomeEmail(email, displayName, role);
      if (result.success) {
        console.log(`Welcome email sent to ${email} (role: ${role})`);
      } else {
        console.warn(`Welcome email failed for ${email}: ${result.error}`);
      }
    } catch (err) {
      // Non-critical — do NOT re-throw; user creation must succeed
      console.warn(`Welcome email error for ${email}:`, err.message);
    }
  });

// ═══════════════════════════════════════════════════════════════
// Callable Functions (HTTPS)
// ═══════════════════════════════════════════════════════════════

/**
 * Send a welcome email manually.
 *
 * Call from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendWelcomeEmail').call({
 *     email: 'user@example.com',
 *     name: 'Ahmed',
 *     role: 'teacher', // optional, defaults to 'teacher'
 *   });
 */
exports.sendWelcomeEmail = functions
  .runWith({ secrets: ['RESEND_API_KEY'] })
  .https.onCall(async (data, context) => {
    // ── Auth check ──
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }

    // ── Input validation ──
    const { email, name, role } = data || {};
    if (!email || !name) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: email, name'
      );
    }

    if (!isValidEmail(email)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email address.');
    }

    const validRoles = ['teacher', 'student', 'parent'];
    if (role && !validRoles.includes(role)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid role. Must be one of: ${validRoles.join(', ')}`
      );
    }

    // ── Send ──
    const result = await sendWelcomeEmail(email, name, role || 'teacher');
    if (!result.success) {
      throw new functions.https.HttpsError('internal', result.error);
    }

    return { success: true, id: result.id };
  });

/**
 * Forward a contact-form submission to the Klasivo support team.
 *
 * Call from the Klasivo website (no auth required — public form):
 *   FirebaseFunctions.instance.httpsCallable('sendContactForm').call({
 *     name: 'Ahmed',
 *     email: 'ahmed@example.com',
 *     subject: 'Question about pricing',
 *     message: 'Hello, ...',
 *   });
 */
exports.sendContactForm = functions
  .runWith({ secrets: ['RESEND_API_KEY'] })
  .https.onCall(async (data, context) => {
    // Note: No auth required — this is a public contact form.
    // Rate limiting is handled by Firebase Functions quotas.

    // ── Input validation ──
    const { name, email, subject, message } = data || {};
    if (!name || !email || !subject || !message) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: name, email, subject, message'
      );
    }

    if (!isValidEmail(email)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email address.');
    }

    if (message.length > 5000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message must be under 5,000 characters.'
      );
    }

    // ── Sanitise ──
    const sanitised = {
      name: sanitizeText(name, 100),
      email: email.trim().toLowerCase(),
      subject: sanitizeText(subject, 200),
      message: sanitizeText(message, 5000),
    };

    // ── Send ──
    const result = await sendContactFormNotification(sanitised);
    if (!result.success) {
      throw new functions.https.HttpsError('internal', result.error);
    }

    return { success: true, id: result.id };
  });

/**
 * Send a teacher invitation email.
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
exports.sendTeacherInvitation = functions
  .runWith({ secrets: ['RESEND_API_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }

    const { email, teacherName, schoolName, inviterName, inviteCode, orgId } = data || {};
    if (!email || !teacherName || !schoolName || !inviterName || !inviteCode || !orgId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: email, teacherName, schoolName, inviterName, inviteCode, orgId'
      );
    }

    if (!isValidEmail(email)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email address.');
    }

    const result = await sendTeacherInvitation({
      email: email.trim().toLowerCase(),
      teacherName: sanitizeText(teacherName, 100),
      schoolName: sanitizeText(schoolName, 150),
      inviterName: sanitizeText(inviterName, 100),
      inviteCode: sanitizeText(inviteCode, 20),
      orgId: sanitizeText(orgId, 50),
    });

    if (!result.success) {
      throw new functions.https.HttpsError('internal', result.error);
    }

    return { success: true, id: result.id };
  });

/**
 * Send a school announcement email to one or more recipients.
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
exports.sendSchoolAnnouncement = functions
  .runWith({ secrets: ['RESEND_API_KEY'] })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
    }

    const { to, schoolName, title, message, senderName, senderRole, priority } = data || {};
    if (!to || !schoolName || !title || !message || !senderName || !senderRole) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields: to, schoolName, title, message, senderName, senderRole'
      );
    }

    // Validate recipients
    const recipients = Array.isArray(to) ? to : [to];
    if (recipients.length === 0 || recipients.length > 50) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Recipients must be between 1 and 50 email addresses.'
      );
    }
    for (const email of recipients) {
      if (!isValidEmail(email)) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Invalid email address: ${email}`
        );
      }
    }

    // Validate priority
    const validPriorities = ['urgent', 'important', 'normal'];
    const safePriority = validPriorities.includes(priority) ? priority : 'normal';

    // Validate message length
    if (message.length > 10000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message must be under 10,000 characters.'
      );
    }

    const result = await sendSchoolAnnouncement({
      to: recipients.map(e => e.trim().toLowerCase()),
      schoolName: sanitizeText(schoolName, 150),
      title: sanitizeText(title, 200),
      message: sanitizeText(message, 10000),
      senderName: sanitizeText(senderName, 100),
      senderRole: sanitizeText(senderRole, 50),
      priority: safePriority,
    });

    if (!result.success) {
      throw new functions.https.HttpsError('internal', result.error);
    }

    return { success: true, id: result.id };
  });

// ═══════════════════════════════════════════════════════════════
// Helpers — Cascade Delete (existing code, unchanged)
// ═══════════════════════════════════════════════════════════════

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
    'attendance',
    'conversations',
    'messages',
    'analytics_cache',
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

    if (collectionName === 'messages') {
      // Delete messages by finding conversations in this org
      const convsSnapshot = await db.collection('conversations')
        .where('organizationId', '==', orgId)
        .get();
      const convIds = convsSnapshot.docs.map(doc => doc.id);

      let totalDeleted = 0;
      for (let i = 0; i < convIds.length; i += 30) {
        const chunk = convIds.slice(i, i + 30);
        const snapshot = await db.collection('messages')
          .where('conversationId', 'in', chunk)
          .get();
        totalDeleted += await deleteSnapshot(snapshot);
      }
      if (totalDeleted > 0) console.log(`Deleted ${totalDeleted} from messages for org ${orgId}`);
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

  // Delete attendance records for this student
  const attSnapshot = await db.collection('attendance')
    .where('studentId', '==', uid)
    .get();
  if (!attSnapshot.empty) {
    await deleteSnapshot(attSnapshot);
    console.log(`Deleted ${attSnapshot.size} attendance records for user ${uid}`);
  }

  // Remove user from conversations (remove from participantIds)
  const convSnapshot = await db.collection('conversations')
    .where('participantIds', 'array-contains', uid)
    .get();
  if (!convSnapshot.empty) {
    const batch = db.batch();
    for (const doc of convSnapshot.docs) {
      const participants = doc.data()['participantIds'] || [];
      const updated = participants.filter(id => id !== uid);
      if (updated.length === 0) {
        // No participants left - delete the conversation
        batch.delete(doc.ref);
      } else {
        batch.update(doc.ref, { 'participantIds': updated, 'updatedAt': admin.firestore.FieldValue.serverTimestamp() });
      }
    }
    await batch.commit();
    console.log(`Updated/removed ${convSnapshot.size} conversations for user ${uid}`);
  }

  // Delete analytics cache for this user
  const studentCacheDoc = db.collection('analytics_cache').doc(`student_${uid}`);
  const teacherCacheDoc = db.collection('analytics_cache').doc(`teacher_${uid}`);
  const batch = db.batch();
  const studentCache = await studentCacheDoc.get();
  const teacherCache = await teacherCacheDoc.get();
  if (studentCache.exists) batch.delete(studentCacheDoc);
  if (teacherCache.exists) batch.delete(teacherCacheDoc);
  await batch.commit();
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

// ═══════════════════════════════════════════════════════════════
// Helpers — Email Input Validation
// ═══════════════════════════════════════════════════════════════

/**
 * Basic email format validation.
 */
function isValidEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

/**
 * Strip HTML tags and trim whitespace from user-supplied text.
 */
function sanitizeText(text, maxLength = 1000) {
  return text
    .replace(/<[^>]*>/g, '')  // strip HTML tags
    .trim()
    .slice(0, maxLength);
}
