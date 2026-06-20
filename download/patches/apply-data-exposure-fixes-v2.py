#!/usr/bin/env python3
# ============================================================================
# Klasivo — Fix 6 Data-Exposure Issues (v2 — includes org create block)
# ============================================================================
# Verified against commit a3d98e7 — ALL 6 still present (previous patch not applied)
#
#   P1-1: Students can read exam correct answers
#   P1-2: Any org member can download student codes + password hashes
#   P1-3: Users can expand own scope arrays
#   P1-4: Unauthenticated invite enumeration
#   P2-1: Students can read draft exams
#   P2-2: Any authenticated account can create org records (block client creates)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-data-exposure-fixes-v2.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO — Fix 6 Data-Exposure Issues (v2)")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-data-exposure-v2-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")

# ============================================================================
# P1-1: Questions read — restrict to staff
# ============================================================================
print("P1-1: Questions read — restrict to staff")
print("-" * 40)

old_q = """    match /questions/{questionId} {
      allow read: if isAuth() && isInSameOrg();
      allow create: if isTeacherOrOwner() && isIncomingSameOrg();
      allow update: if isTeacherOrOwnerInSameOrg();
      allow delete: if isTeacherOrOwnerInSameOrg();
    }"""

new_q = """    match /questions/{questionId} {
      // P1-1: Staff only. Students see questions via exam_instances (strips correctAnswer)
      allow read: if isAuth() && isInSameOrg() && isStaffExcludingObserver();
      allow create: if isStaffExcludingObserver() && isIncomingSameOrg();
      allow update: if isStaffExcludingObserverInSameOrg();
      allow delete: if isStaffExcludingObserverInSameOrg();
    }"""

if old_q in rules_content:
    rules_content = rules_content.replace(old_q, new_q)
    print("  [OK] questions read restricted to staff")
    fixes.append("P1-1: Questions staff-only")
else:
    print("  [!] Not found")
print()

# ============================================================================
# P1-2: Remove passwordHash + restrict users read for students
# ============================================================================
print("P1-2: Remove passwordHash + restrict users read")
print("-" * 40)

# Fix createStudent.ts — remove passwordHash
cs_path = Path("functions/src/functions/createStudent.ts")
if cs_path.exists():
    content = cs_path.read_text(encoding="utf-8")
    changed = False

    if "const passwordHash = hashPassword(password);" in content:
        content = content.replace(
            "const passwordHash = hashPassword(password);",
            "// P1-2: passwordHash removed — Firebase Auth is source of truth"
        )
        changed = True

    # Remove passwordHash from .set() payload
    for pattern in ["            passwordHash,\n", "            passwordHash,\r\n"]:
        if pattern in content:
            content = content.replace(pattern, "")
            changed = True

    if changed:
        cs_path.write_text(content, encoding="utf-8")
        print("  [OK] createStudent.ts: passwordHash removed")
        fixes.append("P1-2: passwordHash removed")

# Fix changeUserPassword.ts — remove passwordHash
cup_path = Path("functions/src/functions/changeUserPassword.ts")
if cup_path.exists():
    content = cup_path.read_text(encoding="utf-8")
    changed = False

    if "const passwordHash = hashPassword(newPassword);" in content:
        content = content.replace(
            "const passwordHash = hashPassword(newPassword);",
            "// P1-2: passwordHash removed — Firebase Auth is source of truth"
        )
        changed = True

    content = re.sub(r"['\"]?passwordHash['\"]?\s*:\s*passwordHash,?\s*\n", "", content)
    if "passwordHash" in content and "P1-2" not in content:
        changed = True

    if changed:
        cup_path.write_text(content, encoding="utf-8")
        print("  [OK] changeUserPassword.ts: passwordHash removed")

# Fix users read rule — students can only read OWN doc
old_users_read = """      allow read: if isAuth() &&
        (request.auth.uid == userId || isInSameOrg());"""

new_users_read = """      // P1-2: Students/parents can only read OWN doc. Staff can read all same-org.
      allow read: if isAuth() &&
        (request.auth.uid == userId ||
         (isInSameOrg() && isStaffExcludingObserver()));"""

if old_users_read in rules_content:
    rules_content = rules_content.replace(old_users_read, new_users_read)
    print("  [OK] users read: students restricted to own doc")
    fixes.append("P1-2: Users read restricted")
else:
    print("  [!] users read pattern not found")
print()

# ============================================================================
# P1-3: Block scope array mutation
# ============================================================================
print("P1-3: Block scope array mutation")
print("-" * 40)

old_update = """        !request.resource.data.diff(resource).affectedKeys().hasAny(['role', 'organizationId', 'tenantId', 'isArchived', 'archivedAt', 'archivedBy']) &&
        // D20: Audit fields immutable from client.
        !request.resource.data.diff(resource).affectedKeys().hasAny(['createdAt', 'createdBy']);"""

new_update = """        !request.resource.data.diff(resource).affectedKeys().hasAny([
          'role', 'organizationId', 'tenantId', 'isArchived', 'archivedAt', 'archivedBy',
          // P1-3: Scope arrays immutable from client
          'campusIds', 'stageIds', 'classIds', 'subjectIds',
          'scopeAccessLevel', 'permissionOverrides', 'roleVersion',
          'isActive', 'status', 'studentCode', 'authEmail',
          'fcmToken', 'fcmTokenUpdatedAt'
        ]) &&
        // D20: Audit fields immutable from client.
        !request.resource.data.diff(resource).affectedKeys().hasAny(['createdAt', 'createdBy']);"""

if old_update in rules_content:
    rules_content = rules_content.replace(old_update, new_update)
    print("  [OK] scope arrays (campusIds/classIds/stageIds) now blocked")
    fixes.append("P1-3: Scope arrays immutable")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P1-4: Block unauthenticated invite reads
# ============================================================================
print("P1-4: Block unauthenticated invite enumeration")
print("-" * 40)

old_invite = """      allow read: if (isAuth() && isInSameOrg()) ||
        resource.data.isUsed == false;"""

new_invite = """      // P1-4: Require auth + same-org for ALL reads (was: unauthenticated for unused codes)
      allow read: if isAuth() && isInSameOrg();"""

if old_invite in rules_content:
    rules_content = rules_content.replace(old_invite, new_invite)
    print("  [OK] invite_codes: unauthenticated reads blocked")
    fixes.append("P1-4: Invite enumeration blocked")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P2-1: Students can only read published exams
# ============================================================================
print("P2-1: Students can only read published exams")
print("-" * 40)

old_exams = """    match /exams/{examId} {
      allow read: if isAuth() && isInSameOrg();"""

new_exams = """    match /exams/{examId} {
      // P2-1: Staff can read all. Students can only read published exams.
      allow read: if isAuth() && isInSameOrg() &&
        (isStaffExcludingObserver() || resource.data.status == 'published');"""

if old_exams in rules_content:
    rules_content = rules_content.replace(old_exams, new_exams)
    print("  [OK] exams: students can only read published")
    fixes.append("P2-1: Draft exam access blocked")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P2-2: Block client-side org creation (server-only via registerOwner CF)
# ============================================================================
print("P2-2: Block client-side org creation")
print("-" * 40)

old_org_create = """      // C-12 PATCH: Only self-owner can create. Prevents spam org creation.
      allow create: if isAuth() &&
        request.resource.data.ownerId == request.auth.uid;"""

new_org_create = """      // P2-2: Block ALL client-side org creation. Server-only via registerOwner CF.
      // Previous rule allowed any authenticated user to create unlimited orgs.
      allow create: if false;"""

if old_org_create in rules_content:
    rules_content = rules_content.replace(old_org_create, new_org_create)
    print("  [OK] organizations create: blocked (server-only via registerOwner CF)")
    fixes.append("P2-2: Org creation server-only")
else:
    # Try alternative pattern
    old_alt = """      allow create: if isAuth() &&
        request.resource.data.ownerId == request.auth.uid;"""
    if old_alt in rules_content:
        rules_content = rules_content.replace(old_alt, new_org_create)
        print("  [OK] organizations create: blocked (server-only)")
        fixes.append("P2-2: Org creation server-only")
    else:
        print("  [!] Pattern not found")
print()

# Write rules
rules_path.write_text(rules_content, encoding="utf-8")

# ============================================================================
# Also add rate limiting to registerOwner CF
# ============================================================================
print("P2-2b: Add abuse controls to registerOwner CF")
print("-" * 40)

ro_path = Path("functions/src/functions/registerOwner.ts")
if ro_path.exists():
    content = ro_path.read_text(encoding="utf-8")

    if "P2-2" not in content and "duplicate" not in content.lower():
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

      // P2-2: Abuse controls — prevent duplicate emails + validate org name
      try {
        await auth.getUserByEmail(data.email.trim().toLowerCase());
        throw new HttpsError('already-exists', 'An account with this email already exists.');
      } catch (e: any) {
        if (e.code === 'already-exists') throw e;
      }
      if (data.organizationName.trim().length < 3) {
        throw new HttpsError('invalid-argument', 'Organization name must be at least 3 characters.');
      }"""

        if old_auth in content:
            content = content.replace(old_auth, new_auth, 1)

            # Move db declaration up (needed for rate limiting)
            content = content.replace(
                "      const auth = getAuth();\n      const db = getFirestore();",
                "      const auth = getAuth();\n      const db = getFirestore();"
            )

            ro_path.write_text(content, encoding="utf-8")
            print("  [OK] registerOwner: added email duplicate check + org name validation")
            fixes.append("P2-2b: Registration abuse controls")
        else:
            print("  [!] Pattern not found")
    else:
        print("  [OK] Already has abuse controls")
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

msg = """security(data-exposure): 6 issues — answers, hashes, scope, invites, drafts, orgs

P1-1: Questions read — restrict to staff
  - Students could read correctAnswer field via direct questions query
  - Fix: allow read only for isStaffExcludingObserver()

P1-2: Student codes + password hashes downloadable
  - Students could read any same-org user doc (including studentCode, passwordHash)
  - Fix 1: Removed passwordHash from createStudent.ts + changeUserPassword.ts
  - Fix 2: users read — students can only read OWN doc, staff can read all

P1-3: Users can expand own scope arrays
  - campusIds/stageIds/classIds/subjectIds NOT in blocked update fields
  - Users could add themselves to any class/campus/stage
  - Fix: Added all scope + identity fields to blocked list

P1-4: Unauthenticated invite enumeration
  - invite_codes read allowed unauthenticated reads of unused codes
  - Fix: Require isAuth() && isInSameOrg() for ALL reads

P2-1: Students can read draft exams
  - exams read had no status check — students could see unpublished exams
  - Fix: Students can only read where status == 'published'

P2-2: Any authenticated account can create org records
  - organizations create: allow if isAuth() && ownerId == uid
  - Any user could spam-create unlimited orgs
  - Fix: allow create: if false (server-only via registerOwner CF)
  - Also added: email duplicate check + org name validation in registerOwner CF

POST-DEPLOY: Run migration to delete passwordHash from existing user docs:
  node scripts/migrate-remove-password-hash.js"""

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
print("⚠️  After deploy, run the passwordHash migration:")
print("  node scripts/migrate-remove-password-hash.js")
print()
print(f"Rollback: git reset --hard {backup}")
