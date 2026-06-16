/**
 * Klasivo — Create Student (Callable Function)
 *
 * Creates a student account via Admin SDK, bypassing Firestore client-side
 * security rules. This is the ONLY way owners/teachers should create
 * student accounts — the client must never write directly to users/{studentUid}.
 *
 * Flow:
 *   Owner/Teacher → createStudent callable →
 *     1. Validate caller role & org membership
 *     2. Verify class belongs to caller's org
 *     3. Create Firebase Auth account (Admin SDK)
 *     4. Generate unique student code
 *     5. Create Firestore user document (Admin SDK — bypasses rules)
 *     6. Send welcome email to real email (if provided, after doc confirmed)
 *     7. Update class student count
 *     8. Send teacher notifications
 *     9. Audit log
 *
 * Rollback: If any step fails after Auth account creation, the Auth account
 * is deleted to prevent orphaned accounts.
 *
 * Security:
 *   - Only owner, admin, or teacher may call
 *   - Caller must belong to same organization as target class
 *   - Firestore rules remain strict: `allow create: if request.auth.uid == userId`
 *   - Admin SDK writes bypass rules entirely
 */

import { onCall, CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import * as Sentry from '@sentry/node';

import { verifyOrgBoundary, STAFF_ROLES, type KlasivoRole } from '../utils/rbac';
import { initSentry, withIsolatedScope } from '../config/sentry';
import { queueEmail } from '../services/queueService';

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

interface CreateStudentData {
  organizationId: string;
  classId: string;
  fullName: string;
  password: string;
  email?: string;
  phone?: string;
}

interface CreateStudentResult {
  uid: string;
  studentCode: string;
}

// Roles allowed to create students
const STUDENT_CREATION_ROLES: KlasivoRole[] = [
  'super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
  'academic_supervisor', 'teacher', 'assistant_teacher',
];

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

function hashPassword(password: string): string {
  return crypto.createHash('sha256').update(password).digest('hex');
}

/**
 * Generate a unique student code (STU-XXXXXX format).
 * Retries until it finds one that doesn't exist yet.
 */
async function generateStudentCode(
  db: admin.firestore.Firestore,
  organizationId: string,
): Promise<string> {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const maxAttempts = 10;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    let code = 'STU-';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    const snapshot = await db
      .collection('users')
      .where('studentCode', '==', code)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return code;
    }
  }

  throw new HttpsError(
    'internal',
    'Failed to generate a unique student code after 10 attempts.',
  );
}

/**
 * Generate an internal email for Firebase Auth.
 * Students never see this email — they log in with their studentCode.
 * Format: student_{code}@students.klasivo.app
 */
function generateAuthEmail(studentCode: string): string {
  const cleanCode = studentCode.replaceAll('-', '').toLowerCase();
  return `student_${cleanCode}@students.klasivo.app`;
}

/**
 * Send FCM notifications to teachers assigned to the class.
 * Non-critical: failures are logged but do not block student creation.
 */
async function notifyTeachers(
  db: admin.firestore.Firestore,
  studentName: string,
  classId: string,
  organizationId: string,
  createdBy: string,
): Promise<void> {
  try {
    const classDoc = await db.collection('classes').doc(classId).get();
    const className = classDoc.data()?.['name'] || 'class';

    const teachersSnapshot = await db
      .collection('teacher_assignments')
      .where('classId', '==', classId)
      .get();

    const teacherIds: string[] = teachersSnapshot.docs
      .map((d) => d.data()['teacherId'] as string | undefined)
      .filter((id): id is string => id != null);

    // Include the creator if they're not already in the list
    if (createdBy && !teacherIds.includes(createdBy)) {
      teacherIds.push(createdBy);
    }

    // Collect FCM tokens for all teachers
    const tokens: string[] = [];
    for (const teacherId of teacherIds) {
      const teacherDoc = await db.collection('users').doc(teacherId).get();
      const fcmToken = teacherDoc.data()?.['fcmToken'] as string | undefined;
      if (fcmToken) tokens.push(fcmToken);
    }

    if (tokens.length === 0) return;

    const message: admin.messaging.MulticastMessage = {
      notification: {
        title: 'New Student Joined',
        body: `${studentName} has joined ${className}.`,
      },
      data: {
        type: 'student_joined',
        classId,
        organizationId,
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens,
      android: {
        priority: 'high',
        notification: {
          channelId: 'student_activity',
          icon: 'ic_notification',
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `[createStudent] Teacher notification sent: ${response.successCount}/${tokens.length} delivered`,
    );
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.warn(`[createStudent] Teacher notification failed (non-critical): ${msg}`);
    Sentry.captureException(err, {
      tags: { function: 'createStudent', step: 'notify_teachers' },
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Callable Function
// ═══════════════════════════════════════════════════════════════════════════════

export const createStudent = onCall(
  {
    secrets: ['SENTRY_DSN'],
    // enforceAppCheck: true — TEMPORARILY DISABLED
    // Client does not initialize FirebaseAppCheck. Re-enable after adding
    // FirebaseAppCheck.instance.activate() in Flutter main.dart.
    // Tracked as: App Check initialization follow-up
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request: CallableRequest<CreateStudentData>): Promise<CreateStudentResult> => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'student_management');
      scope.setTag('function', 'createStudent');

      // ─── 1. Auth Check ─────────────────────────────────────────────────
      // Diagnostic: log auth + app context before any rejection
      console.log(JSON.stringify({
        message: 'createStudent_auth_context',
        authExists: !!request.auth,
        uid: request.auth?.uid ?? null,
        callerRoleClaim: (request.auth?.token?.role as string) ?? null,
        callerOrgIdClaim: (request.auth?.token?.organizationId as string) ?? null,
        callerScopeAccessLevel: (request.auth?.token?.scopeAccessLevel as string) ?? null,
        tokenAuthTime: request.auth?.token?.auth_time ?? null,
        tokenIssuedAt: request.auth?.token?.iat ?? null,
        appExists: !!request.app,
        appTokenPresent: !!request.app?.token,
        hasData: !!request.data,
        dataKeys: Object.keys(request.data || {}),
      }));

      if (!request.auth) {
        console.error(JSON.stringify({
          message: 'createStudent_rejected_unauthenticated',
          authExists: false,
          appExists: !!request.app,
          appTokenPresent: !!request.app?.token,
          dataKeys: Object.keys(request.data || {}),
        }));
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const callerUid = request.auth.uid;
      const callerRoleClaim = (request.auth.token.role as string) || '';
      const callerOrgIdClaim = (request.auth.token.organizationId as string) || '';
      scope.setUser({ id: callerUid });
      scope.setTag('caller_role_claim', callerRoleClaim);

      // ─── 2. Resolve caller role & org (claim → Firestore fallback) ──────
      // Custom claims may not be set yet for users who registered before
      // the claims-provisioning pipeline was wired into registerOwner /
      // registerTeacher / acceptInvitation. When claims are missing, we fall
      // back to the Firestore user doc as the authoritative source for THIS
      // authorization decision.
      //
      // IMPORTANT: we do NOT mutate the caller's custom claims from inside
      // createStudent. Claims provisioning is a separate security primitive
      // owned by syncClaims(). Mixing the two would:
      //   (a) silently rewrite auth state from a mutation handler,
      //   (b) skip the sync_claims audit-log row,
      //   (c) leave the client unaware its token was stale.
      // Phase 2 (tomorrow) will ensure registerOwner / registerTeacher /
      // acceptInvitation always call setCustomUserClaims, at which point the
      // fallback below becomes a defensive belt-and-suspenders rather than
      // the primary path.
      let callerRole = callerRoleClaim;
      let callerOrgId = callerOrgIdClaim;

      if (!callerRole || !callerOrgId) {
        const db = admin.firestore();
        const callerDoc = await db.collection('users').doc(callerUid).get();

        if (!callerDoc.exists) {
          console.error(JSON.stringify({
            message: 'createStudent_rejected_no_user_doc',
            uid: callerUid,
            callerRoleClaim: callerRoleClaim || null,
            callerOrgIdClaim: callerOrgIdClaim || null,
          }));
          throw new HttpsError(
            'permission-denied',
            'Caller user document not found. Cannot verify role.',
          );
        }

        const callerData = callerDoc.data()!;
        if (!callerRole) {
          callerRole = (callerData['role'] as string) || '';
        }
        if (!callerOrgId) {
          callerOrgId = (callerData['organizationId'] as string) || '';
        }

        console.log(JSON.stringify({
          message: 'createStudent_claims_fallback_used',
          uid: callerUid,
          roleFromClaim: callerRoleClaim || null,
          roleFromFirestore: callerRole,
          orgFromClaim: callerOrgIdClaim || null,
          orgFromFirestore: callerOrgId,
          // Note: claims are NOT auto-synced here. See header comment above.
          claimsSyncRecommended: true,
        }));
      }

      scope.setTag('caller_role', callerRole);
      scope.setTag('caller_org_id', callerOrgId);

      // ─── 2b. Role Check ────────────────────────────────────────────────
      if (!STUDENT_CREATION_ROLES.includes(callerRole as KlasivoRole)) {
        // CRITICAL DIAGNOSTIC: always read the Firestore user doc on rejection,
        // regardless of whether the fallback fired. This lets us distinguish
        // between four root causes:
        //   (a) claim missing + Firestore role missing → registration bug
        //   (b) claim missing + Firestore role present but wrong → data issue
        //   (c) claim present + wrong (e.g., 'parent') + Firestore correct
        //       → claims sync issue (the fallback never fired because the
        //          claim was truthy)
        //   (d) claim present + correct + Firestore correct → impossible
        //       (role check should have passed); indicates deployed code is
        //       stale or wrong Firebase project
        let firestoreSnapshot: Record<string, unknown> | null = null;
        try {
          const diagDoc = await admin.firestore().collection('users').doc(callerUid).get();
          if (diagDoc.exists) {
            const d = diagDoc.data()!;
            firestoreSnapshot = {
              exists: true,
              role: d['role'] ?? null,
              organizationId: d['organizationId'] ?? null,
              fullName: d['fullName'] ?? null,
              isActive: d['isActive'] ?? null,
              hasCompletedSetup: d['hasCompletedSetup'] ?? null,
              fieldNames: Object.keys(d),
            };
          } else {
            firestoreSnapshot = { exists: false };
          }
        } catch (diagErr: unknown) {
          const diagMsg = diagErr instanceof Error ? diagErr.message : String(diagErr);
          firestoreSnapshot = { readError: diagMsg };
        }

        console.error(JSON.stringify({
          message: 'createStudent_rejected_role',
          uid: callerUid,
          // Claim state
          callerRoleClaim: callerRoleClaim || null,
          callerOrgIdClaim: callerOrgIdClaim || null,
          // Resolved state (after optional fallback)
          resolvedCallerRole: callerRole,
          resolvedCallerOrgId: callerOrgId,
          // Whether fallback fired
          fallbackUsed: !callerRoleClaim || !callerOrgIdClaim,
          // Firestore snapshot for cross-reference
          firestoreSnapshot,
          // What would have passed
          allowedRoles: STUDENT_CREATION_ROLES,
          // Diagnosis hints
          diagnosis: {
            claimRoleMissing: !callerRoleClaim,
            claimRoleWrongButPresent:
              !!callerRoleClaim && !STUDENT_CREATION_ROLES.includes(callerRoleClaim as KlasivoRole),
            firestoreRolePresent:
              firestoreSnapshot !== null &&
              typeof firestoreSnapshot === 'object' &&
              'exists' in firestoreSnapshot &&
              firestoreSnapshot.exists === true &&
              'role' in firestoreSnapshot &&
              firestoreSnapshot.role != null,
            firestoreRoleMatchesAllowed:
              firestoreSnapshot !== null &&
              typeof firestoreSnapshot === 'object' &&
              'role' in firestoreSnapshot &&
              typeof firestoreSnapshot.role === 'string' &&
              STUDENT_CREATION_ROLES.includes(firestoreSnapshot.role as KlasivoRole),
          },
        }));
        throw new HttpsError(
          'permission-denied',
          'Only staff members can create student accounts.',
        );
      }

      // ─── 3. Input Validation ───────────────────────────────────────────
      const { organizationId, classId, fullName, password, email, phone } = request.data;

      if (!organizationId || !classId || !fullName || !password) {
        throw new HttpsError(
          'invalid-argument',
          'organizationId, classId, fullName, and password are required.',
        );
      }

      if (password.length < 6) {
        throw new HttpsError(
          'invalid-argument',
          'Password must be at least 6 characters.',
        );
      }

      if (fullName.trim().length < 2) {
        throw new HttpsError(
          'invalid-argument',
          'Full name must be at least 2 characters.',
        );
      }

      // ─── 4. Org Boundary Verification ─────────────────────────────────
      if (!callerOrgId) {
        throw new HttpsError(
          'permission-denied',
          'Caller organization information is required for student creation.',
        );
      }

      if (!verifyOrgBoundary(callerOrgId, organizationId, callerRole)) {
        console.error(JSON.stringify({
          message: 'createStudent_rejected_org_boundary',
          uid: callerUid,
          callerOrgId,
          targetOrgId: organizationId,
          callerRole,
        }));
        throw new HttpsError(
          'permission-denied',
          'You can only create students in your own organization.',
        );
      }

      const db = admin.firestore();
      let studentUid: string | undefined;

      try {
        // ─── 5. Verify Class Belongs to Organization ─────────────────────
        console.log(JSON.stringify({
          message: 'student_creation_started',
          organizationId,
          classId,
          callerUid,
          callerRole,
        }));

        const classDoc = await db.collection('classes').doc(classId).get();
        if (!classDoc.exists) {
          throw new HttpsError('not-found', `Class ${classId} not found.`);
        }

        const classOrgId = classDoc.data()?.['organizationId'] as string | undefined;
        if (classOrgId !== organizationId) {
          throw new HttpsError(
            'permission-denied',
            'Class does not belong to the specified organization.',
          );
        }

        // ─── 6. Generate Student Code ────────────────────────────────────
        const studentCode = await generateStudentCode(db, organizationId);
        const authEmail = generateAuthEmail(studentCode);
        const passwordHash = hashPassword(password);

        // ─── 7. Create Firebase Auth Account (Admin SDK) ─────────────────
        let authUser: admin.auth.UserRecord;
        try {
          authUser = await admin.auth().createUser({
            email: authEmail,
            password: password,
            displayName: fullName,
          });
          studentUid = authUser.uid;

          console.log(JSON.stringify({
            message: 'student_auth_created',
            organizationId,
            classId,
            callerUid,
            studentUid,
          }));
        } catch (authError: unknown) {
          const msg = authError instanceof Error ? authError.message : String(authError);
          console.error(`[createStudent] Firebase Auth creation failed: ${msg}`);
          Sentry.captureException(authError, {
            tags: { function: 'createStudent', step: 'auth_create' },
          });
          throw new HttpsError(
            'internal',
            `Failed to create Firebase Auth account: ${msg}`,
          );
        }

        // ─── 8. Create Firestore User Document (Admin SDK) ──────────────
        try {
          await db.collection('users').doc(studentUid).set({
            organizationId,
            role: 'student',
            fullName: fullName.trim(),
            studentCode,
            authEmail,
            email: email || null,
            phone: phone || null,
            passwordHash,
            classId,
            photoUrl: null,
            isActive: true,
            createdBy: callerUid,
            authProvider: 'student_code',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          console.log(JSON.stringify({
            message: 'student_user_doc_created',
            organizationId,
            classId,
            callerUid,
            studentUid,
          }));
        } catch (docError: unknown) {
          // Rollback: delete the Auth account we just created
          const msg = docError instanceof Error ? docError.message : String(docError);
          console.error(`[createStudent] Firestore user doc creation failed: ${msg}`);
          Sentry.captureException(docError, {
            tags: { function: 'createStudent', step: 'user_doc_create' },
          });

          try {
            await admin.auth().deleteUser(studentUid);
            console.log(`[createStudent] Rolled back Auth account for ${studentUid}`);
          } catch (rollbackError: unknown) {
            // Log but don't throw — we want the original error to surface
            const rbMsg = rollbackError instanceof Error ? rollbackError.message : String(rollbackError);
            console.error(`[createStudent] CRITICAL: Failed to rollback Auth account ${studentUid}: ${rbMsg}`);
            Sentry.captureException(rollbackError, {
              tags: { function: 'createStudent', step: 'auth_rollback', critical: 'true' },
            });
          }

          throw new HttpsError(
            'internal',
            `Failed to create student document: ${msg}`,
            { code: 'student_creation_failed', step: 'user_doc_create' } as any,
          );
        }

        // ─── 9. Send Welcome Email (if real email provided) ──────────────
        // Only send after the Firestore doc is confirmed created.
        // Students without a real email get NO welcome email — their
        // authEmail (@students.klasivo.app) is synthetic and has no mailbox.
        if (email) {
          try {
            const emailResult = await queueEmail({
              type: 'welcome',
              category: 'welcome',
              to: email,
              payload: { name: fullName.trim(), role: 'student' },
              idempotencyKey: `welcome_${studentUid}`,
            });

            if (emailResult.queued) {
              console.log(`[createStudent] Welcome email queued for student's real email: ${email}`);
            } else {
              console.log(`[createStudent] Welcome email already queued for ${email} (reason: ${emailResult.reason})`);
            }
          } catch (emailError: unknown) {
            // Non-critical: email failure must NOT block student creation
            const msg = emailError instanceof Error ? emailError.message : String(emailError);
            console.warn(`[createStudent] Welcome email queue failed (non-critical): ${msg}`);
            Sentry.captureException(emailError, {
              tags: { function: 'createStudent', step: 'welcome_email' },
            });
          }
        } else {
          console.log(`[createStudent] No real email provided — skipping welcome email for student ${studentUid}`);
        }

        // ─── 10. Update Class Student Count ───────────────────────────────
        try {
          const countSnapshot = await db
            .collection('users')
            .where('classId', '==', classId)
            .where('role', '==', 'student')
            .count()
            .get();

          await db.collection('classes').doc(classId).update({
            studentCount: countSnapshot.data().count ?? 0,
          });

          console.log(JSON.stringify({
            message: 'student_enrolled',
            organizationId,
            classId,
            callerUid,
            studentUid,
            studentCount: countSnapshot.data().count ?? 0,
          }));
        } catch (countError: unknown) {
          // Non-critical: count update failure shouldn't block student creation
          const msg = countError instanceof Error ? countError.message : String(countError);
          console.warn(`[createStudent] Class count update failed (non-critical): ${msg}`);
          Sentry.captureException(countError, {
            tags: { function: 'createStudent', step: 'class_count_update' },
          });
        }

        // ─── 11. Audit Log ──────────────────────────────────────────────
        try {
          await db.collection('audit_logs').add({
            organizationId,
            performedBy: callerUid,
            performedByRole: callerRole,
            performedByOrgId: callerOrgId || organizationId,
            userId: callerUid,
            action: 'create_student',
            targetType: 'user',
            targetId: studentUid,
            metadata: {
              studentCode,
              classId,
              authEmail,
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (auditError: unknown) {
          // Non-critical: audit log failure shouldn't block student creation
          const msg = auditError instanceof Error ? auditError.message : String(auditError);
          console.warn(`[createStudent] Audit log failed (non-critical): ${msg}`);
        }

        // ─── 12. Notify Teachers (non-blocking) ─────────────────────────
        // Fire-and-forget: notification failure is non-critical
        notifyTeachers(db, fullName.trim(), classId, organizationId, callerUid).catch(() => {
          // Already handled inside notifyTeachers
        });

        // ─── 12b. (Removed) Auto-sync of caller's custom claims ─────────
        // Previously: if we fell back to Firestore for role/org, we would
        // fire-and-forget a setCustomUserClaims() call here to repair the
        // caller's stale token. That mixed a security-state mutation into
        // a student-creation handler — see step 2 header comment for why it
        // was removed. Claims provisioning is owned by syncClaims() and,
        // in Phase 2, by registerOwner / registerTeacher / acceptInvitation.

        // ─── 13. Success ────────────────────────────────────────────────
        console.log(JSON.stringify({
          message: 'student_creation_completed',
          organizationId,
          classId,
          callerUid,
          studentUid,
          studentCode,
        }));

        return { uid: studentUid, studentCode };

      } catch (error: unknown) {
        // If it's already an HttpsError, rethrow as-is
        if (error instanceof HttpsError) {
          throw error;
        }

        // Wrap unexpected errors
        const msg = error instanceof Error ? error.message : String(error);
        console.error(`[createStudent] Unexpected error: ${msg}`);
        Sentry.captureException(error, {
          tags: { function: 'createStudent', step: 'unexpected' },
        });

        throw new HttpsError(
          'internal',
          `Student creation failed: ${msg}`,
          { code: 'student_creation_failed', step: 'unexpected' } as any,
        );
      }
    }); // withIsolatedScope
  },
);
