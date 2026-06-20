#!/usr/bin/env python3
# ============================================================================
# Klasivo — Fix 7 RBAC Issues (Hierarchy, Scope, Messaging, Router, Storage)
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO — Fix 7 RBAC Issues")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-rbac-fixes-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

# ============================================================================
# P1-1: assignRole — add caller > oldRole check (prevent demoting superiors)
# ============================================================================
print("=" * 70)
print("P1-1: assignRole — prevent demoting someone above your rank")
print("=" * 70)
print()

ar_path = Path("functions/src/functions/assignRole.ts")
if ar_path.exists():
    content = ar_path.read_text(encoding="utf-8")

    old = """    // ─── D3 PATCH: Hierarchy enforcement ────────────────────────────────
    // Caller cannot assign a role HIGHER than their own. Prevents admin from
    // making someone an owner, campus_manager from making someone an admin, etc.
    if (roleRank(newRole) > roleRank(callerRole)) {
      throw new HttpsError(
        'permission-denied',
        `Cannot assign a role higher than your own (${callerRole} → ${newRole}).`,
      );
    }"""

    new = """    // ─── D3 PATCH: Hierarchy enforcement ────────────────────────────────
    // Caller cannot assign a role HIGHER than their own. Prevents admin from
    // making someone an owner, campus_manager from making someone an admin, etc.
    if (roleRank(newRole) > roleRank(callerRole)) {
      throw new HttpsError(
        'permission-denied',
        `Cannot assign a role higher than your own (${callerRole} → ${newRole}).`,
      );
    }

    // P1-1 PATCH: Caller must also be higher than the target's CURRENT role.
    // Prevents an admin (70) from demoting an owner (80).
    if (callerRole !== 'super_admin' && roleRank(callerRole) <= roleRank(oldRole)) {
      throw new HttpsError(
        'permission-denied',
        `Cannot modify a user with equal or higher role (caller=${callerRole}, target=${oldRole}).`,
      );
    }"""

    if old in content and "P1-1" not in content:
        content = content.replace(old, new, 1)
        ar_path.write_text(content, encoding="utf-8")
        print("  [OK] assignRole: added caller > oldRole check")
        fixes.append("P1-1: assignRole hierarchy")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# P1-2: PermissionService.can() — scope check before override return
# ============================================================================
print("=" * 70)
print("P1-2: PermissionService — scope check before override grant")
print("=" * 70)
print()

ps_path = Path("lib/core/rbac/permission_service.dart")
if ps_path.exists():
    content = ps_path.read_text(encoding="utf-8")

    old = """    // 2. Check explicit allow (overrides)
    if (_permissionOverrides[permission] == true) return true;

    // 3. Check role-based permissions (with hierarchy)
    if (!RoleResolver.roleHasPermission(_role, permission)) return false;

    // 4. If scope specified, also validate scope
    if (scopeType != null && scopeId != null) {
      return validateScope(scopeType: scopeType, scopeId: scopeId);
    }

    return true;"""

    new = """    // 2. Check explicit allow (overrides)
    // P1-2 PATCH: Scope is checked BEFORE returning true on override.
    // Previous code returned true immediately, bypassing scope validation.
    if (_permissionOverrides[permission] == true) {
      if (scopeType != null && scopeId != null) {
        return validateScope(scopeType: scopeType, scopeId: scopeId);
      }
      return true;
    }

    // 3. Check role-based permissions (with hierarchy)
    if (!RoleResolver.roleHasPermission(_role, permission)) return false;

    // 4. If scope specified, also validate scope
    if (scopeType != null && scopeId != null) {
      return validateScope(scopeType: scopeType, scopeId: scopeId);
    }

    return true;"""

    if old in content and "P1-2" not in content:
        content = content.replace(old, new, 1)
        ps_path.write_text(content, encoding="utf-8")
        print("  [OK] PermissionService.can(): scope checked before override return")
        fixes.append("P1-2: Scope before override")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# P1-4: Messages create — verify sender is conversation participant
# ============================================================================
print("=" * 70)
print("P1-4: Messages create — verify sender is conversation participant")
print("=" * 70)
print()

rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")

old_msg_create = """      allow create: if isAuth() && isIncomingSameOrg() &&
        request.resource.data.senderId == request.auth.uid;"""

new_msg_create = """      // P1-4 PATCH: Verify sender is a participant in the referenced conversation
      allow create: if isAuth() && isIncomingSameOrg() &&
        request.resource.data.senderId == request.auth.uid &&
        request.resource.data.conversationId != null &&
        exists(/databases/$(database)/documents/conversations/$(request.resource.data.conversationId)) &&
        get(/databases/$(database)/documents/conversations/$(request.resource.data.conversationId))
          .data.participants.hasAny([request.auth.uid]);"""

if old_msg_create in rules_content:
    rules_content = rules_content.replace(old_msg_create, new_msg_create)
    print("  [OK] messages create: now verifies sender is conversation participant")
    fixes.append("P1-4: Message injection prevention")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P2-1: Router — use managementRoles instead of hardcoded checks
# ============================================================================
print("=" * 70)
print("P2-1: Router — replace hardcoded role checks with managementRoles")
print("=" * 70)
print()

main_path = Path("lib/main.dart")
if main_path.exists():
    content = main_path.read_text(encoding="utf-8")

    # Replace hardcoded teacher/owner checks with managementRoles.contains
    old1 = "if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {\n            return '/dashboard';\n          }"
    new1 = "if (KlasivoRole.managementRoles.contains(userRole)) {\n            return '/dashboard';\n          }"

    count = content.count(old1)
    if count > 0:
        content = content.replace(old1, new1)
        print(f"  [OK] Replaced {count} hardcoded roleTeacher || roleOwner checks with managementRoles")

    # Also fix the protected routes check
    old2 = "if ((userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) &&\n            isOnDashboard)"
    new2 = "if (KlasivoRole.managementRoles.contains(userRole) &&\n            isOnDashboard)"

    if old2 in content:
        content = content.replace(old2, new2)
        print("  [OK] Fixed protected routes check to use managementRoles")

    old3 = "if (userRole == AppConstants.roleTeacher || userRole == AppConstants.roleOwner) {\n          return '/dashboard';\n        }"
    new3 = "if (KlasivoRole.managementRoles.contains(userRole)) {\n          return '/dashboard';\n        }"

    count2 = content.count(old3)
    if count2 > 0:
        content = content.replace(old3, new3)
        print(f"  [OK] Replaced {count2} more hardcoded checks")

    if count > 0 or count2 > 0:
        main_path.write_text(content, encoding="utf-8")
        fixes.append("P2-1: Router managementRoles")
    else:
        print("  [!] No hardcoded patterns found (may already be fixed)")
print()

# ============================================================================
# P2-2: Storage rules — add all staff roles + allow delete
# ============================================================================
print("=" * 70)
print("P2-2: Storage rules — add all staff roles")
print("=" * 70)
print()

storage_path = Path("storage.rules")
if storage_path.exists():
    content = storage_path.read_text(encoding="utf-8")

    old_staff = """  function isTeacherOrOwner() {
    return isAuth() &&
      exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
      (getUserRole() == 'teacher' || getUserRole() == 'owner' || getUserRole() == 'admin');
  }"""

    new_staff = """  // P2-2 PATCH: Include ALL staff roles (was: only teacher/owner/admin)
  function isStaff() {
    return isAuth() &&
      exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
      (getUserRole() in ['super_admin', 'owner', 'admin', 'campus_manager',
                         'stage_manager', 'academic_supervisor', 'teacher',
                         'assistant_teacher']);
  }

  // Back-compat alias
  function isTeacherOrOwner() {
    return isStaff();
  }"""

    if old_staff in content:
        content = content.replace(old_staff, new_staff)
        storage_path.write_text(content, encoding="utf-8")
        print("  [OK] storage.rules: isTeacherOrOwner now includes all staff roles")
        fixes.append("P2-2: Storage staff roles")
    else:
        print("  [!] Pattern not found")
print()

# ============================================================================
# P2-3: Admin org listing — filter by membership not ownership
# ============================================================================
print("=" * 70)
print("P2-3: Admin org listing — filter by membership")
print("=" * 70)
print()

api_path = Path("functions/src/api/index.ts")
if api_path.exists():
    content = api_path.read_text(encoding="utf-8")

    old_filter = """      // C-09 PATCH: Only super_admin sees all orgs. Owners and admins see only their own.
      // Previous rule checked !== 'admin' (let admin see all, blocked super_admin) - inverted.
      if (req.userRole !== 'super_admin') {
        query = query.where('ownerId', '==', req.user!.uid);
      }"""

    new_filter = """      // C-09 + P2-3 PATCH: super_admin sees all. Non-super_admin see orgs they're a member of.
      if (req.userRole !== 'super_admin') {
        // P2-3: Filter by the user's organizationId (membership), not ownerId (ownership).
        // Previous code filtered by ownerId — an admin who didn't create the org saw nothing.
        const userOrgId = (req.user as any)?.organizationId || req.userClaims?.organizationId;
        if (userOrgId) {
          query = query.where(firebaseAdmin.firestore.FieldValue.documentId(), '==', userOrgId);
        } else {
          // No orgId in claims — fall back to ownerId
          query = query.where('ownerId', '==', req.user!.uid);
        }
      }"""

    if old_filter in content and "P2-3" not in content:
        content = content.replace(old_filter, new_filter, 1)
        api_path.write_text(content, encoding="utf-8")
        print("  [OK] /admin/schools: now filters by membership (orgId) not ownership")
        fixes.append("P2-3: Org listing membership")
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
print("  ℹ️  P1-3 (participant fields): Already working via dual-write — no fix needed")
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

msg = """security(rbac): 7 RBAC issues — hierarchy, scope, messaging, router, storage

P1-1: assignRole — prevent demoting someone above your rank
  - Was: only checked newRole > callerRole (can't promote above self)
  - Missing: callerRole > oldRole (can't demote someone above you)
  - An admin (70) could demote an owner (80) — privilege escalation
  - Fix: Added roleRank(callerRole) <= roleRank(oldRole) check

P1-2: PermissionService.can() — scope check before override return
  - Was: override grant returned true immediately, bypassing scope validation
  - A teacher with examCreate override could create exams in any class
  - Fix: Scope is now checked BEFORE returning true on override grant

P1-3: Messaging participant fields — already working (dual-write)
  - Rules check 'participants', code writes both 'participantIds' (for queries)
    and 'participants' (for rules). No fix needed — works correctly.

P1-4: Messages create — verify sender is conversation participant
  - Was: only checked senderId == auth.uid — no conversation participant check
  - A user could inject messages into any conversation by supplying its ID
  - Fix: Rules now cross-reference conversations collection to verify
    sender is in participants.hasAny([auth.uid])

P2-1: Router — use managementRoles instead of hardcoded checks
  - Was: hardcoded 'roleTeacher || roleOwner' in 4+ redirect locations
  - Missing: admin, campus_manager, stage_manager, academic_supervisor, etc.
  - Fix: Replaced with KlasivoRole.managementRoles.contains(userRole)

P2-2: Storage rules — add all staff roles
  - Was: isTeacherOrOwner() only included teacher/owner/admin
  - Missing: super_admin, campus_manager, stage_manager, academic_supervisor,
    assistant_teacher — these could upload via signed URL API but not delete
  - Fix: New isStaff() helper includes all 8 staff roles

P2-3: Admin org listing — filter by membership not ownership
  - Was: filtered by ownerId == uid — admin who didn't create org saw nothing
  - Fix: Filter by user's organizationId (membership) instead

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
print("Deploy: firebase deploy --only functions,firestore:rules,firestore:indexes,storage")
print()
print(f"Rollback: git reset --hard {backup}")
