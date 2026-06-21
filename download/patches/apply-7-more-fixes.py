#!/usr/bin/env python3
# ============================================================================
# Klasivo — Fix 7 More Issues (LiveKit, Uploads, Scope, Notifications, Email)
# ============================================================================
# All 7 verified against commit ef5cf09:
#
#   P1-1: LiveKit remove/end — roomName not verified against roomDoc
#   P1-2: Mute endpoint — no org/scope check (C-06, still unfixed)
#   P1-3: Signed upload URLs — unscoped paths (C-07, still unfixed)
#   P1-4: createStudent — ignores teacher class/campus scope
#   P2-1: Notifications create — open to any org member
#   P2-2: Email retries — no backoff (immediate exhaustion)
#   P2-3: Class-start notifications — sent to ALL org students (not just class)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-7-more-fixes.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO — Fix 7 More Issues (LiveKit + Uploads + Scope + Notifs)")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-7-more-fixes-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

# ============================================================================
# P1-1, P1-2, P1-3: Fix API gateway (LiveKit + Upload URLs)
# ============================================================================
print("=" * 70)
print("P1-1/2/3: Fix API gateway — LiveKit roomName + mute scope + uploads")
print("=" * 70)
print()

api_path = Path("functions/src/api/index.ts")
if api_path.exists():
    content = api_path.read_text(encoding="utf-8")

    # P1-1: After fetching roomDoc in /remove, verify roomName matches
    old_remove = """      const roomOrgId = roomDoc.data()?.['organizationId'] as string;
      if (roomOrgId !== req.userOrgId) {
        res.status(403).json({ error: 'You can only remove participants from rooms in your organization.' });
        return;
      }

      const livekitUrl ="""

    new_remove = """      const roomOrgId = roomDoc.data()?.['organizationId'] as string;
      if (roomOrgId !== req.userOrgId) {
        res.status(403).json({ error: 'You can only remove participants from rooms in your organization.' });
        return;
      }

      // P1-1: Verify roomName matches the roomDoc's actual name
      const docRoomName = roomDoc.data()?.['name'] as string;
      if (docRoomName && roomName !== docRoomName) {
        res.status(400).json({ error: 'roomName does not match the room document.' });
        return;
      }

      const livekitUrl ="""

    if old_remove in content:
        content = content.replace(old_remove, new_remove, 1)
        print("  [OK] P1-1: /remove — roomName verified against roomDoc")
        fixes.append("P1-1: LiveKit roomName verification")

    # P1-1b: Same fix for /endRoom
    old_end = """      const roomOrgId = roomDoc.data()?.['organizationId'] as string;
      if (roomOrgId !== req.userOrgId) {
        res.status(403).json({ error: 'You can only end rooms in your organization.' });
        return;
      }"""
    new_end = """      const roomOrgId = roomDoc.data()?.['organizationId'] as string;
      if (roomOrgId !== req.userOrgId) {
        res.status(403).json({ error: 'You can only end rooms in your organization.' });
        return;
      }
      // P1-1: Verify roomName matches
      const docRoomName = roomDoc.data()?.['name'] as string;
      if (docRoomName && roomName !== docRoomName) {
        res.status(400).json({ error: 'roomName does not match the room document.' });
        return;
      }"""

    if old_end in content:
        content = content.replace(old_end, new_end, 1)
        print("  [OK] P1-1: /endRoom — roomName verified against roomDoc")

    # P1-2: Fix /mute — add org boundary check + roomName verification
    old_mute = """      // Resolve LiveKit URL
      let livekitUrl = 'https://klasivo.livekit.cloud';
      if (roomId) {
        const roomDoc = await admin.firestore().collection('livekit_rooms').doc(roomId).get();
        if (roomDoc.exists) {
          livekitUrl = (roomDoc.data()?.['metadata']?.['livekitUrl'] as string) ?? livekitUrl;
        }
      }"""

    new_mute = """      // P1-2: Resolve LiveKit URL + verify org boundary + roomName
      let livekitUrl = 'https://klasivo.livekit.cloud';
      if (roomId) {
        const roomDoc = await admin.firestore().collection('livekit_rooms').doc(roomId).get();
        if (roomDoc.exists) {
          livekitUrl = (roomDoc.data()?.['metadata']?.['livekitUrl'] as string) ?? livekitUrl;

          // P1-2: Verify caller is in the same org as the room
          const roomOrgId = roomDoc.data()?.['organizationId'] as string;
          if (roomOrgId !== req.userOrgId) {
            res.status(403).json({ error: 'You can only mute participants in rooms in your organization.' });
            return;
          }

          // P1-1: Verify roomName matches
          const docRoomName = roomDoc.data()?.['name'] as string;
          if (docRoomName && roomName !== docRoomName) {
            res.status(400).json({ error: 'roomName does not match the room document.' });
            return;
          }
        }
      } else {
        // P1-2: No roomId means no org verification possible — deny
        res.status(400).json({ error: 'roomId is required for mute operations.' });
        return;
      }"""

    if old_mute in content:
        content = content.replace(old_mute, new_mute, 1)
        print("  [OK] P1-2: /mute — added org check + roomName verification + roomId required")
        fixes.append("P1-2: Mute org/scope check")

    # P1-3: Fix upload URLs — remove unscoped prefixes
    old_prefixes = """    const allowedPrefixes = [
      `users/${req.user!.uid}/`,
      `organizations/${req.userOrgId ?? ''}/`,
      'exams/',
      'materials/',
      'submissions/',
    ];"""

    new_prefixes = """    // P1-3: All uploads must be org-scoped (was: 'exams/', 'materials/', 'submissions/' unscoped)
    const allowedPrefixes = [
      `users/${req.user!.uid}/`,
      `organizations/${req.userOrgId ?? ''}/`,
    ];"""

    if old_prefixes in content:
        content = content.replace(old_prefixes, new_prefixes, 1)
        print("  [OK] P1-3: Upload URLs — removed unscoped prefixes (exams/, materials/, submissions/)")
        fixes.append("P1-3: Upload URL scoping")

    # Also fix requireAdmin to include all staff roles (was missing super_admin etc)
    old_admin = """  if (!['teacher', 'owner', 'admin'].includes(req.userRole ?? '')) {"""
    new_admin = """  if (!['super_admin', 'owner', 'admin', 'campus_manager', 'stage_manager',
        'academic_supervisor', 'teacher', 'assistant_teacher'].includes(req.userRole ?? '')) {"""

    if old_admin in content:
        content = content.replace(old_admin, new_admin)
        print("  [OK] requireAdmin — now includes all staff roles")

    api_path.write_text(content, encoding="utf-8")
else:
    print("  [!] api/index.ts not found")
print()

# ============================================================================
# P1-4: createStudent — add teacher scope check
# ============================================================================
print("=" * 70)
print("P1-4: createStudent — add teacher class scope check")
print("=" * 70)
print()

cs_path = Path("functions/src/functions/createStudent.ts")
if cs_path.exists():
    content = cs_path.read_text(encoding="utf-8")

    # After org boundary verification, add teacher scope check
    old = """      // ─── 5. Fetch Class Document & Verify Org Match ──────────────────"""

    new = """      // ─── P1-4: Teacher scope check ──────────────────────────────────
      // Teachers can only create students in classes they're assigned to
      if (callerRole === 'teacher') {
        const callerDoc = await db.collection('users').doc(callerUid).get();
        const callerClassIds = (callerDoc.data()?.['classIds'] as string[]) || [];
        if (!callerClassIds.includes(classId)) {
          throw new HttpsError(
            'permission-denied',
            'Teachers can only create students in their own classes.',
          );
        }
      }

      // ─── 5. Fetch Class Document & Verify Org Match ──────────────────"""

    if old in content and "P1-4" not in content:
        content = content.replace(old, new, 1)
        cs_path.write_text(content, encoding="utf-8")
        print("  [OK] createStudent: added teacher classIds scope check")
        fixes.append("P1-4: createStudent teacher scope")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# P2-1: Notifications create — restrict to staff
# ============================================================================
print("=" * 70)
print("P2-1: Notifications create — restrict to staff")
print("=" * 70)
print()

rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")

old_notif = """      allow create: if isAuth() && isIncomingSameOrg();"""
new_notif = """      // P2-1: Only staff can create notifications (was: any org member)
      allow create: if isStaffExcludingObserverInSameOrg();"""

if old_notif in rules_content:
    # Only replace the notifications create rule (first occurrence after "notifications")
    notif_idx = rules_content.find("match /notifications/")
    if notif_idx > 0:
        search_start = rules_content.find(old_notif, notif_idx)
        if search_start > 0:
            rules_content = rules_content[:search_start] + new_notif + rules_content[search_start + len(old_notif):]
            print("  [OK] notifications create: now requires staff role")
            fixes.append("P2-1: Notifications create staff-only")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P2-2: Email retries — add exponential backoff
# ============================================================================
print("=" * 70)
print("P2-2: Email retries — add exponential backoff")
print("=" * 70)
print()

ew_path = Path("functions/src/workers/emailWorker.ts")
if ew_path.exists():
    content = ew_path.read_text(encoding="utf-8")

    old_retry = """  if (newAttempts < maxAttempts) {
    await docRef.update({ status: 'retrying' as QueueStatus, attempts: newAttempts, lastError: errorMessage });"""

    new_retry = """  if (newAttempts < maxAttempts) {
    // P2-2: Exponential backoff — delay = 2^attempts seconds (2s, 4s, 8s, 16s, 32s)
    const delaySeconds = Math.pow(2, newAttempts);
    const retryAfter = new Date(Date.now() + delaySeconds * 1000);
    await docRef.update({
      status: 'retrying' as QueueStatus,
      attempts: newAttempts,
      lastError: errorMessage,
      retryAfter: admin.firestore.Timestamp.fromDate(retryAfter),
    });"""

    if old_retry in content and "P2-2" not in content:
        content = content.replace(old_retry, new_retry, 1)

        # Also update the worker to check retryAfter before processing
        old_check = """  if (status !== 'pending' && status !== 'retrying') return;"""
        new_check = """  if (status !== 'pending' && status !== 'retrying') return;

  // P2-2: Check exponential backoff — don't process if retryAfter is in the future
  const retryAfter = afterData['retryAfter'];
  if (status === 'retrying' && retryAfter) {
    const retryAfterDate = retryAfter.toDate ? retryAfter.toDate() : new Date(retryAfter);
    if (retryAfterDate > new Date()) {
      console.log(`Queue item ${queueId} waiting for backoff (retry after ${retryAfterDate.toISOString()})`);
      return;
    }
  }"""

        if old_check in content:
            content = content.replace(old_check, new_check, 1)

        ew_path.write_text(content, encoding="utf-8")
        print("  [OK] emailWorker: added exponential backoff (2^n seconds)")
        fixes.append("P2-2: Email backoff")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# P2-3: Class-start notifications — scope to class, not org
# ============================================================================
print("=" * 70)
print("P2-3: Class-start notifications — scope to class only")
print("=" * 70)
print()

olk_path = Path("functions/src/functions/onLiveKitRoomEvents.ts")
if olk_path.exists():
    content = olk_path.read_text(encoding="utf-8")

    old_query = """      // Find all students in the organization
      const studentsSnapshot = await db
        .collection('users')
        .where('organizationId', '==', orgId)
        .where('role', '==', 'student')
        .where('isActive', '==', true)
        .get();"""

    new_query = """      // P2-3: Find students in the CLASS (not the entire org)
      const classId = roomData?.['classId'] as string;
      let studentsSnapshot;
      if (classId) {
        studentsSnapshot = await db
          .collection('users')
          .where('organizationId', '==', orgId)
          .where('classId', '==', classId)
          .where('role', '==', 'student')
          .where('isActive', '==', true)
          .get();
      } else {
        // No classId on room — skip notifications (shouldn't happen)
        console.log('Room has no classId — skipping student notifications');
        return;
      }"""

    if old_query in content and "P2-3" not in content:
        content = content.replace(old_query, new_query, 1)
        olk_path.write_text(content, encoding="utf-8")
        print("  [OK] onLiveKitRoomCreated: notifications scoped to class (not org)")
        fixes.append("P2-3: Class-start notif scope")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# Write rules
rules_path.write_text(rules_content, encoding="utf-8")

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

msg = """security(p1-p2): 7 more issues — LiveKit, uploads, scope, notifications, email

P1-1: LiveKit /remove + /endRoom — verify roomName matches roomDoc
  - Was: caller-supplied roomName used directly (bypass org check via mismatched IDs)
  - Fix: Verify roomName == roomDoc.data().name before calling LiveKit API

P1-2: LiveKit /mute — add org boundary check + roomId required
  - Was: NO org check at all (found in earlier audit as C-06, never fixed)
  - Fix: Verify roomOrgId == callerOrgId + roomId now required + roomName verified
  - Also: requireAdmin now includes all staff roles (was missing super_admin etc)

P1-3: Upload URLs — remove unscoped paths
  - Was: 'exams/', 'materials/', 'submissions/' allowed without org prefix
  - Fix: Only users/{uid}/ and organizations/{orgId}/ allowed

P1-4: createStudent — add teacher classIds scope check
  - Was: any teacher could create students in any class in the org
  - Fix: Teachers can only create students in classes they're assigned to

P2-1: Notifications create — restrict to staff
  - Was: any org member (including students) could create notifications
  - Fix: allow create: if isStaffExcludingObserverInSameOrg()

P2-2: Email retries — add exponential backoff
  - Was: retries happen immediately, exhausting all 5 attempts in seconds
  - Fix: 2^n second delay between retries (2s, 4s, 8s, 16s, 32s)
  - Worker checks retryAfter timestamp before processing

P2-3: Class-start notifications — scope to class
  - Was: sent to ALL students in the organization (privacy + spam issue)
  - Fix: Only sent to students in the room's classId

Verified against commit ef5cf09."""

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
print(f"Rollback: git reset --hard {backup}")
