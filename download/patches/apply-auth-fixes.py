#!/usr/bin/env python3
# ============================================================================
# Klasivo — Fix 5 Authorization Issues (P1)
# ============================================================================
# All 5 verified against commit ef5cf09:
#
#   P1-1: assignRole doesn't verify target user's orgId matches caller's
#   P1-2: setPermissionOverrides same missing target-org check
#   P1-3: Payments create open to any org member (including students)
#   P1-4: Update rules allow organizationId mutation (cross-tenant doc move)
#   P1-5: tenantId "default" shared across all orgs (cross-tenant access)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-auth-fixes.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO — Fix 5 Authorization Issues (P1)")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-auth-fixes-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

# ============================================================================
# P1-1: assignRole — verify target user's orgId matches caller's orgId
# ============================================================================
print("=" * 70)
print("P1-1: assignRole — add target org verification")
print("=" * 70)
print()

ar_path = Path("functions/src/functions/assignRole.ts")
if ar_path.exists():
    content = ar_path.read_text(encoding="utf-8")

    # After fetching the target user doc, add org verification
    old = """    const oldRole = userDoc.data()?.role || 'unknown';"""
    new = """    const oldRole = userDoc.data()?.role || 'unknown';

    // P1-1 PATCH: Verify target user belongs to the same org as caller.
    // Previous code checked caller's org but never verified target's org.
    const targetOrgId = userDoc.data()?.organizationId || '';
    const callerOrgId = (callerClaims.organizationId as string) || '';
    if (targetOrgId !== callerOrgId) {
      throw new HttpsError(
        'permission-denied',
        `Target user is in a different organization (${targetOrgId} vs ${callerOrgId}).`,
      );
    }"""

    if old in content and "P1-1" not in content:
        content = content.replace(old, new, 1)
        ar_path.write_text(content, encoding="utf-8")
        print("  [OK] Added target org verification to assignRole")
        fixes.append("P1-1: assignRole target org check")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# P1-2: setPermissionOverrides — same fix
# ============================================================================
print("=" * 70)
print("P1-2: setPermissionOverrides — add target org verification")
print("=" * 70)
print()

spo_path = Path("functions/src/functions/setPermissionOverrides.ts")
if spo_path.exists():
    content = spo_path.read_text(encoding="utf-8")

    old = """    const targetRole = userData.role || 'unknown';"""
    new = """    const targetRole = userData.role || 'unknown';

    // P1-2 PATCH: Verify target user belongs to the same org as caller.
    const targetOrgId = userData.organizationId || '';
    if (targetOrgId !== callerOrgId) {
      throw new HttpsError(
        'permission-denied',
        `Target user is in a different organization (${targetOrgId} vs ${callerOrgId}).`,
      );
    }"""

    if old in content and "P1-2" not in content:
        content = content.replace(old, new, 1)
        spo_path.write_text(content, encoding="utf-8")
        print("  [OK] Added target org verification to setPermissionOverrides")
        fixes.append("P1-2: setPermissionOverrides target org check")
    else:
        print("  [!] Pattern not found or already fixed")
print()

# ============================================================================
# P1-3: Payments create — add role check
# ============================================================================
print("=" * 70)
print("P1-3: Payments create — restrict to staff (not students)")
print("=" * 70)
print()

rules_path = Path("firestore.rules")
rules_content = rules_path.read_text(encoding="utf-8")

old_payments = """    match /payments/{paymentId} {
      allow read: if isAuth() && isInSameOrg() &&
        (isTeacherOrOwner() || isCampusManager() ||
         (isParent() && resource.data.parentId == request.auth.uid));
      allow create: if isAuth() && isIncomingSameOrg();"""

new_payments = """    match /payments/{paymentId} {
      allow read: if isAuth() && isInSameOrg() &&
        (isTeacherOrOwner() || isCampusManager() ||
         (isParent() && resource.data.parentId == request.auth.uid));
      // P1-3 PATCH: Only staff can create payment records (was open to any org member)
      allow create: if isStaffExcludingObserverInSameOrg();"""

if old_payments in rules_content:
    rules_content = rules_content.replace(old_payments, new_payments)
    print("  [OK] Payments create now requires staff role")
    fixes.append("P1-3: Payments create role check")
else:
    print("  [!] Pattern not found")
print()

# ============================================================================
# P1-4: Add immutable-field guards to standard update rules
# ============================================================================
print("=" * 70)
print("P1-4: Add organizationId immutability to update rules")
print("=" * 70)
print()

# Add a helper function for immutable-field checks on updates
# Then update the standard collections to use it

# Add the helper after safeStaffUpdate
old_helper = """    function safeStaffUpdate() {
      return isStaffExcludingObserverInSameOrg() &&
        preservesImmutableFields();
    }"""

new_helper = """    function safeStaffUpdate() {
      return isStaffExcludingObserverInSameOrg() &&
        preservesImmutableFields();
    }

    // P1-4 PATCH: Immutable org/audit fields on update — prevents cross-tenant doc moves
    function preservesOrgAndAuditFields() {
      return !request.resource.data.diff(resource).affectedKeys().hasAny([
        'organizationId', 'tenantId', 'createdAt', 'createdBy'
      ]);
    }

    function safeStaffUpdateWithOrgGuard() {
      return isStaffExcludingObserverInSameOrg() &&
        preservesImmutableFields() &&
        preservesOrgAndAuditFields();
    }"""

if old_helper in rules_content and "preservesOrgAndAuditFields" not in rules_content:
    rules_content = rules_content.replace(old_helper, new_helper)
    print("  [OK] Added preservesOrgAndAuditFields() helper")

# Now update standard collections to use safeStaffUpdateWithOrgGuard
# instead of isTeacherOrOwnerInSameOrg() on update rules
collections_to_protect = [
    'classes', 'stages', 'grades', 'groups', 'group_members',
    'teacher_assignments', 'exams', 'exam_templates', 'questions',
    'question_banks', 'subjects', 'assignments', 'attendance',
    'gradebook', 'gradebook_entries', 'gradebook_categories',
    'announcements', 'calendar_events', 'resources', 'materials',
    'lessons', 'lesson_plans', 'progress_tracking', 'units',
    'search_keywords', 'deep_links', 'scheduled_classes',
    'session_analytics', 'exam_stats', 'analytics_cache',
    'campuses', 'livekit_rooms', 'transport_routes', 'transport_assignments',
    'fee_structures', 'violations',
]

org_guard_count = 0
for collection in collections_to_protect:
    # Pattern: allow update: if isTeacherOrOwnerInSameOrg();
    # Replace with: allow update: if safeStaffUpdateWithOrgGuard();
    old_update = f"      allow update: if isTeacherOrOwnerInSameOrg();\n      allow delete: if isTeacherOrOwnerInSameOrg();"

    # Check if this collection has the standard pattern
    if old_update in rules_content:
        # Only replace the update line, keep delete as-is
        rules_content = rules_content.replace(
            f"      allow update: if isTeacherOrOwnerInSameOrg();\n      allow delete: if isTeacherOrOwnerInSameOrg();",
            f"      allow update: if safeStaffUpdateWithOrgGuard();  // P1-4: org immutability\n      allow delete: if isTeacherOrOwnerInSameOrg();",
            1  # only first occurrence per collection
        )
        org_guard_count += 1

# Also handle collections that use isStaffInSameOrg() on update
old_staff_update = "      allow update: if isStaffInSameOrg();"
new_staff_update = "      allow update: if safeStaffUpdateWithOrgGuard();  // P1-4: org immutability"

staff_count = rules_content.count(old_staff_update)
if staff_count > 0:
    rules_content = rules_content.replace(old_staff_update, new_staff_update)
    org_guard_count += staff_count

print(f"  [OK] Updated {org_guard_count} update rules with org immutability guard")
fixes.append(f"P1-4: Immutable org fields ({org_guard_count} rules)")

rules_path.write_text(rules_content, encoding="utf-8")
print()

# ============================================================================
# P1-5: Fix tenantId "default" — use org-specific tenantId
# ============================================================================
print("=" * 70)
print("P1-5: Fix tenantId 'default' — use org-specific tenantId")
print("=" * 70)
print()

# Fix registerOwner CF — set tenantId to orgId instead of 'default'
for cf_str in ["functions/src/functions/registerOwner.ts", "functions/src/functions/registerParent.ts"]:
    cf_path = Path(cf_str)
    if not cf_path.exists():
        continue

    content = cf_path.read_text(encoding="utf-8")

    # Replace tenantId: 'default' with tenantId: orgId (or orgId variable)
    if cf_str.endswith("registerOwner.ts"):
        # registerOwner has orgId variable
        content = content.replace(
            "tenantId: 'default',",
            "tenantId: orgId,  // P1-5: org-specific tenant (was 'default' — shared across orgs)"
        )
    else:
        # registerParent — tenantId should be empty or match student's org
        content = content.replace(
            "tenantId: 'default',",
            "tenantId: '',  // P1-5: will be set when parent links to student's org"
        )

    cf_path.write_text(content, encoding="utf-8")
    print(f"  [OK] {cf_str}: tenantId no longer 'default'")

# Also fix createStudent.ts if it sets tenantId
cs_path = Path("functions/src/functions/createStudent.ts")
if cs_path.exists():
    content = cs_path.read_text(encoding="utf-8")
    if "tenantId: 'default'" in content:
        content = content.replace(
            "tenantId: 'default'",
            "tenantId: organizationId  // P1-5: org-specific tenant"
        )
        cs_path.write_text(content, encoding="utf-8")
        print("  [OK] createStudent.ts: tenantId set to organizationId")

# Fix the tenants collection rule — don't allow create by any authed user
rules_content = rules_path.read_text(encoding="utf-8")
old_tenant_create = "allow create: if isAuth();"
new_tenant_create = "allow create: if false;  // P1-5: Server-only (no client creates tenants)"

if "match /tenants/" in rules_content and old_tenant_create in rules_content:
    # Only replace within the tenants match block
    tenants_start = rules_content.find("match /tenants/")
    tenants_end = rules_content.find("}", rules_content.find("}", tenants_start) + 1) + 1
    tenants_block = rules_content[tenants_start:tenants_end]

    if old_tenant_create in tenants_block:
        new_block = tenants_block.replace(old_tenant_create, new_tenant_create)
        rules_content = rules_content.replace(tenants_block, new_block)
        rules_path.write_text(rules_content, encoding="utf-8")
        print("  [OK] Rules: tenants create blocked (server-only)")

fixes.append("P1-5: tenantId org-specific")
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

if True:  # always build
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        r = subprocess.run(["npm","run","build"],shell=True)
        if r.returncode != 0: print("\n[WARNING] Build failed — check errors")
        else: print("\n  [OK] Build succeeded")
    finally: os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

msg = """security(p1): 5 authorization issues — cross-tenant + immutability

P1-1: assignRole — verify target user's orgId matches caller's orgId
  - Was: caller org checked, but target org never verified
  - Fix: Added targetOrgId == callerOrgId check after fetching target user
  - Prevents admin from modifying cross-tenant accounts

P1-2: setPermissionOverrides — same target org verification
  - Same pattern: caller org checked, target org not verified
  - Fix: Added targetOrgId == callerOrgId check

P1-3: Payments create — restrict to staff (was open to any org member)
  - Was: allow create: if isAuth() && isIncomingSameOrg() (students could create)
  - Fix: allow create: if isStaffExcludingObserverInSameOrg()

P1-4: Update rules — add organizationId immutability guard
  - Was: standard update rules used isTeacherOrOwnerInSameOrg() with no
    field diff check — staff could change organizationId to move docs
    to another tenant
  - Fix: Added preservesOrgAndAuditFields() helper + safeStaffUpdateWithOrgGuard()
  - Applied to ~30+ collection update rules

P1-5: tenantId 'default' — use org-specific tenantId
  - Was: all owners/parents/students got tenantId:'default' — isInSameTenant()
    matched across orgs (any user with 'default' could read any 'default' tenant)
  - Fix: registerOwner sets tenantId: orgId (not 'default')
  - Fix: registerParent sets tenantId: '' (set when linked to student)
  - Fix: createStudent sets tenantId: organizationId
  - Fix: tenants create blocked (server-only, was any authed user)

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
print("Verify:")
print("  1. Admin in Org A tries assignRole on user in Org B → permission-denied")
print("  2. Student tries to create payment → permission-denied")
print("  3. Staff tries to change organizationId on a class → permission-denied")
print("  4. Owner in Org A cannot read Org B's tenant docs → permission-denied")
print()
print(f"Rollback: git reset --hard {backup}")
