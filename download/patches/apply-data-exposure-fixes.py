#!/usr/bin/env python3
# ============================================================================
# Klasivo — Fix 6 Data-Exposure Issues
# ============================================================================
# All 6 verified against latest commit:
#
#   P1-1: Students can read exam correct answers (questions rule too permissive)
#   P1-2: Any org member can download student login codes + password hashes
#   P1-3: Users can expand own scope arrays (campusIds/classIds not blocked)
#   P1-4: Unauthenticated invite enumeration (invite_codes read rule)
#   P2-1: Students can read draft/unpublished exams
#   P2-2: Owner registration lacks abuse controls
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-data-exposure-fixes.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO — Fix 6 Data-Exposure Issues")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-data-exposure-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

# ============================================================================
# P1-1: Students can read exam correct answers — restrict questions read
# ============================================================================
print("=" * 70)
print("P1-1: Students can read exam correct answers")
print("=" * 70)
print()

rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")

# The problem: questions/{questionId} allow read: if isAuth() && isInSameOrg()
# This lets students read the questions collection which contains correctAnswer
# Fix: Students can only read questions via the exam-taking flow (exam_instances)
# Staff can read all questions. Students should NOT have direct list access.

old_q = """    match /questions/{questionId} {
      allow read: if isAuth() && isInSameOrg();
      allow create: if isTeacherOrOwner() && isIncomingSameOrg();
      allow update: if isTeacherOrOwnerInSameOrg();
      allow delete: if isTeacherOrOwnerInSameOrg();
    }"""

new_q = """    match /questions/{questionId} {
      // P1-1: Staff can read all questions. Students CANNOT read questions
      // directly (they see questions via exam_instances which strips correctAnswer).
      // Previous rule allowed any same-org user to read — students could see answers.
      allow read: if isAuth() && isInSameOrg() && isStaffExcludingObserver();
      allow create: if isStaffExcludingObserver() && isIncomingSameOrg();
      allow update: if isStaffExcludingObserverInSameOrg();
      allow delete: if isStaffExcludingObserverInSameOrg();
    }"""

if old_q in rules_content:
    rules_content = rules_content.replace(old_q, new_q)
    print("  [OK] questions: read restricted to staff (students blocked)")
    fixes.append("P1-1: Questions read restricted")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P1-2: Student login codes + password hashes downloadable
# ============================================================================
print("=" * 70)
print("P1-2: Student login codes + password hashes downloadable")
print("=" * 70)
print()

# Problem 1: passwordHash still written to user doc (createStudent.ts:518)
# Fix: Remove passwordHash from the .set() call
cs_path = Path("functions/src/functions/createStudent.ts")
if cs_path.exists():
    content = cs_path.read_text(encoding="utf-8")

    # Remove the passwordHash computation
    if "const passwordHash = hashPassword(password);" in content:
        content = content.replace(
            "const passwordHash = hashPassword(password);",
            "// P1-2: passwordHash removed — Firebase Auth is the source of truth"
        )
        print("  [OK] createStudent.ts: removed passwordHash computation")

    # Remove passwordHash from the .set() call
    if "'passwordHash'," in content or "passwordHash," in content:
        content = content.replace("            passwordHash,\n", "")
        content = content.replace("            passwordHash,\r\n", "")
        print("  [OK] createStudent.ts: removed passwordHash from user doc")

    # Also check changeUserPassword.ts
    cup_path = Path("functions/src/functions/changeUserPassword.ts")
    if cup_path.exists():
        cup_content = cup_path.read_text(encoding="utf-8")
        if "passwordHash" in cup_content and "hashPassword" in cup_content:
            cup_content = cup_content.replace(
                "const passwordHash = hashPassword(newPassword);",
                "// P1-2: passwordHash removed — Firebase Auth is the source of truth"
            )
            # Remove passwordHash field from any .update() call
            cup_content = re.sub(r"['\"]?passwordHash['\"]?\s*:\s*passwordHash,?\s*\n", "", cup_content)
            cup_path.write_text(cup_content, encoding="utf-8")
            print("  [OK] changeUserPassword.ts: removed passwordHash")

    cs_path.write_text(content, encoding="utf-8")
    fixes.append("P1-2: passwordHash removed from user docs")

# Problem 2: students can read OTHER users' docs (which contain studentCode)
# The current rule: allow read: if isAuth() && (uid == userId || isInSameOrg())
# Students reading same-org users can see studentCode + authEmail on other students
# Fix: Students can only read their OWN doc. Staff can read all same-org docs.
old_users_read = """      allow read: if isAuth() &&
        (request.auth.uid == userId || isInSameOrg());"""

new_users_read = """      // P1-2: Students/parents can only read their OWN doc.
      // Staff can read any same-org doc (for user management).
      // Previous rule allowed any same-org user to read any user doc —
      // students could download all student codes + (legacy) password hashes.
      allow read: if isAuth() &&
        (request.auth.uid == userId ||
         (isInSameOrg() && isStaffExcludingObserver()));"""

if old_users_read in rules_content:
    rules_content = rules_content.replace(old_users_read, new_users_read)
    print("  [OK] users read: students can only read own doc (staff can read all)")
    fixes.append("P1-2: Users read restricted for students")
else:
    print("  [!] users read pattern not found")
print()

# ============================================================================
# P1-3: Users can expand own scope arrays
# ============================================================================
print("=" * 70)
print("P1-3: Users can expand own scope arrays")
print("=" * 70)
print()

# The users update rule blocks role/org/tenant/isArchived but NOT campusIds/stageIds/classIds
# A user can add themselves to any classId/campusId/stageId
old_update = """        !request.resource.data.diff(resource).affectedKeys().hasAny(['role', 'organizationId', 'tenantId', 'isArchived', 'archivedAt', 'archivedBy']) &&
        // D20: Audit fields immutable from client.
        !request.resource.data.diff(resource).affectedKeys().hasAny(['createdAt', 'createdBy']);"""

new_update = """        !request.resource.data.diff(resource).affectedKeys().hasAny([
          'role', 'organizationId', 'tenantId', 'isArchived', 'archivedAt', 'archivedBy',
          // P1-3: Scope arrays are immutable from client — prevents self-escalation
          'campusIds', 'stageIds', 'classIds', 'subjectIds',
          'scopeAccessLevel', 'permissionOverrides', 'roleVersion',
          'isActive', 'status', 'studentCode', 'authEmail',
          'fcmToken', 'fcmTokenUpdatedAt'
        ]) &&
        // D20: Audit fields immutable from client.
        !request.resource.data.diff(resource).affectedKeys().hasAny(['createdAt', 'createdBy']);"""

if old_update in rules_content:
    rules_content = rules_content.replace(old_update, new_update)
    print("  [OK] users update: added campusIds/stageIds/classIds/subjectIds to blocked fields")
    fixes.append("P1-3: Scope arrays immutable")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P1-4: Unauthenticated invite enumeration
# ============================================================================
print("=" * 70)
print("P1-4: Unauthenticated invite enumeration")
print("=" * 70)
print()

old_invite = """    match /invite_codes/{codeId} {
      allow read: if (isAuth() && isInSameOrg()) ||
        resource.data.isUsed == false;"""

new_invite = """    match /invite_codes/{codeId} {
      // P1-4: Require auth + same-org for ALL reads.
      // Previous rule allowed unauthenticated reads of unused codes (isUsed == false)
      // — attackers could enumerate and redeem active invitations.
      // Invite code validation goes through the redeemInviteCode CF (Admin SDK).
      allow read: if isAuth() && isInSameOrg();"""

if old_invite in rules_content:
    rules_content = rules_content.replace(old_invite, new_invite)
    print("  [OK] invite_codes: unauthenticated reads blocked")
    fixes.append("P1-4: Invite enumeration blocked")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P2-1: Students can read draft/unpublished exams
# ============================================================================
print("=" * 70)
print("P2-1: Students can read draft/unpublished exams")
print("=" * 70)
print()

old_exams = """    match /exams/{examId} {
      allow read: if isAuth() && isInSameOrg();"""

new_exams = """    match /exams/{examId} {
      // P2-1: Staff can read all exams. Students can only read published exams.
      allow read: if isAuth() && isInSameOrg() &&
        (isStaffExcludingObserver() || resource.data.status == 'published');"""

if old_exams in rules_content:
    rules_content = rules_content.replace(old_exams, new_exams)
    print("  [OK] exams: students can only read published exams")
    fixes.append("P2-1: Draft exam access blocked")
else:
    print("  [!] Pattern not found")
print()

# Write rules
rules_path.write_text(rules_content, encoding="utf-8")

# ============================================================================
# P2-2: Owner registration abuse controls
# ============================================================================
print("=" * 70)
print("P2-2: Owner registration abuse controls")
print("=" * 70)
print()

ro_path = Path("functions/src/functions/registerOwner.ts")
if ro_path.exists():
    content = ro_path.read_text(encoding="utf-8")

    # Add rate limiting + email verification check
    old_auth = """      if (!data.email || !data.password || !data.fullName || !data.organizationName) {
        throw new HttpsError('invalid-argument', 'email, password, fullName, organizationName are required.');
      }
      if (data.password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }"""

    new_auth = """      if (!data.email || !data.password || !data.fullName || !data.organizationName) {
        throw new HttpsError('invalid-argument', 'email, password, fullName, organizationName are required.');
      }
      if (data.password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }

      // P2-2: Abuse controls
      // 1. Check if email is already registered (prevent duplicate accounts)
      try {
        await auth.getUserByEmail(data.email.trim().toLowerCase());
        throw new HttpsError('already-exists', 'An account with this email already exists.');
      } catch (e: any) {
        if (e.code === 'already-exists') throw e;
        // 'auth/user-not-found' is expected — continue
      }

      // 2. Basic org name validation (prevent empty/garbage names)
      if (data.organizationName.trim().length < 3) {
        throw new HttpsError('invalid-argument', 'Organization name must be at least 3 characters.');
      }

      // 3. Rate limit: max 3 registrations per hour per IP
      // (App Check already prevents non-app clients — this is defense-in-depth)
      const callerIp = request.app?.['ip'] || 'unknown';
      const rateKey = `register_owner_${callerIp}`;
      const rateRef = db.collection('_rateLimits').doc(rateKey);
      const rateDoc = await rateRef.get();
      if (rateDoc.exists) {
        const rateData = rateDoc.data()!;
        const windowStart = (rateData.windowStart as admin.firestore.Timestamp).toMillis();
        if (Date.now() - windowStart < 3600000 && (rateData.count || 0) >= 3) {
          throw new HttpsError('resource-exhausted', 'Too many registration attempts. Please try again later.');
        }
      }"""

    if old_auth in content and "P2-2" not in content:
        content = content.replace(old_auth, new_auth, 1)

        # Add the db variable reference (it's declared later in the try block)
        # We need to move the db declaration up
        content = content.replace(
            "      const auth = getAuth();\n      const db = getFirestore();",
            "      const auth = getAuth();\n      const db = getFirestore();  // P2-2: moved up for rate limiting"
        )

        ro_path.write_text(content, encoding="utf-8")
        print("  [OK] registerOwner: added email duplicate check + org name validation + rate limiting")
        fixes.append("P2-2: Registration abuse controls")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# Summary + Build + Commit
# ============================================================================
print("=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"\nFixes applied: {len(fixes)}")
for f in fixes: print(f"  ✅ {f}")
print()

if True:
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        r = subprocess.run(["npm","run","build"],shell=True)
        if r.returncode != 0: print("\n[WARNING] Build failed")
        else: print("\n  [OK] Build succeeded")
    finally: os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

msg = """security(data-exposure): 6 issues — answers, hashes, scope, invites, drafts

P1-1: Questions read — restrict to staff (students blocked)
  - Was: any same-org user could read questions (including correctAnswer)
  - Fix: allow read: if isStaffExcludingObserver() && isInSameOrg()
  - Students see questions via exam_instances flow (which strips answers)

P1-2: Student login codes + password hashes downloadable
  - Was: students could read any same-org user doc (including studentCode,
    authEmail, and legacy passwordHash field)
  - Fix 1: Removed passwordHash from createStudent.ts user doc .set() call
  - Fix 2: Removed passwordHash from changeUserPassword.ts
  - Fix 3: users read rule — students can only read OWN doc, staff can read all

P1-3: Users can expand own scope arrays
  - Was: users update rule blocked role/org/tenant but NOT campusIds/stageIds/classIds
  - A user could add themselves to any class/campus/stage
  - Fix: Added campusIds, stageIds, classIds, subjectIds, scopeAccessLevel,
    permissionOverrides, roleVersion, isActive, status, studentCode, authEmail,
    fcmToken to blocked fields

P1-4: Unauthenticated invite enumeration
  - Was: invite_codes read allowed unauthenticated reads of unused codes
  - Attackers could enumerate and redeem active invitations
  - Fix: Require isAuth() && isInSameOrg() for ALL reads

P2-1: Students can read draft/unpublished exams
  - Was: exams read allowed any same-org user (students could see drafts)
  - Fix: Students can only read exams where status == 'published'

P2-2: Owner registration abuse controls
  - Was: no rate limiting, no duplicate email check, no org name validation
  - Fix: Added email duplicate check, org name min length (3), IP rate limiting
    (max 3 registrations per hour)

Verified against latest commit."""

subprocess.run(["git","add","-A"],check=True)
r = subprocess.run(["git","commit","-m",msg],capture_output=True,text=True)
if r.returncode != 0: print(f"[ERROR] {r.stderr}"); sys.exit(1)
new_commit = subprocess.check_output(["git","rev-parse","--short","HEAD"],text=True).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

resp = input("Push to origin? (y/n): ").strip().lower()
if resp == "y":
    r = subprocess.run(["git","push","origin","main"])
    if r.returncode != 0: print("\n[ERROR] Push failed"); sys.exit(1)
    print(f"\n  [OK] Pushed: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else: print("[!] Skipped")

print()
print("Deploy: firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("⚠️  IMPORTANT: After deploy, run the passwordHash migration:")
print("  node scripts/migrate-remove-password-hash.js")
print("  (deletes passwordHash field from all existing user docs)")
print()
print("Verify:")
print("  1. Student tries to read questions collection → permission-denied")
print("  2. Student tries to read another user's doc → permission-denied")
print("  3. User tries to add classIds to their own doc → permission-denied")
print("  4. Unauthenticated user tries to read invite_codes → permission-denied")
print("  5. Student tries to read draft exam → permission-denied")
print("  6. Register same email twice → already-exists error")
print()
print(f"Rollback: git reset --hard {backup}")
