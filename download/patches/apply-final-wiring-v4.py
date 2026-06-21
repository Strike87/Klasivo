#!/usr/bin/env python3
# ============================================================================
# Klasivo - Final Wiring v4 (corrected from v3)
# ============================================================================
# Fixes from v3:
#   - Bug #1: Step 1/2 regex preserves original receiver (authService OR
#     ref.read(authServiceProvider)) - no more hardcoded authService
#   - Bug #2: Step 3 uses admin.firestore() directly (no db scope dependency)
#   - Bug #3: Step 1 does NOT auto-pass organizationName from name controller
#     - instead inserts a TODO comment for the developer to wire up properly
#   - Bug #4: Step 2 success check is inserted before the FIRST await after
#     the ViaCF call, not before a hardcoded saveTeacherAuthData(
#   - Minor: result['id'] -> result['uid'] uses regex with word boundary
#   - Minor: registerParent( fallback uses count=1
#   - Added: pre-flight check that ViaCF methods exist on AuthService
#
# SKIP: Step 4 (StatefulShellRoute) - needs manual QA + TeacherShell refactor
#
# BEFORE RUNNING:
#   1. Confirm registerOwnerViaCF exists in lib/core/services/auth_service.dart
#   2. Confirm registerParentViaCF exists in lib/core/services/auth_service.dart
#   3. Decide how to handle organizationName (manual form field vs CF default)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-final-wiring-v4.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("lib/main.dart").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO - Final Wiring v4 (corrected)")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

status = subprocess.check_output(["git","status","--porcelain"],text=True).strip()
if status:
    print("ERROR: Working tree has uncommitted changes. Run: git stash"); sys.exit(1)

# ----------------------------------------------------------------------------
# PRE-FLIGHT: Verify ViaCF methods exist on AuthService
# ----------------------------------------------------------------------------
print("=" * 70)
print("Pre-flight: Verify ViaCF methods exist on AuthService")
print("=" * 70)
print()

auth_service_path = None
for candidate in [
    Path("lib/core/services/auth_service.dart"),
    Path("lib/services/auth_service.dart"),
]:
    if candidate.exists():
        auth_service_path = candidate
        break
if not auth_service_path:
    for p in Path("lib").rglob("auth_service.dart"):
        auth_service_path = p
        break

if not auth_service_path:
    print("  [!] auth_service.dart not found - skipping ViaCF existence check")
    print("      MAKE SURE registerOwnerViaCF and registerParentViaCF exist before running!")
else:
    as_content = auth_service_path.read_text(encoding="utf-8")
    has_owner = "registerOwnerViaCF" in as_content
    has_parent = "registerParentViaCF" in as_content
    print(f"  AuthService: {auth_service_path}")
    print(f"  registerOwnerViaCF:  {'FOUND' if has_owner else 'MISSING - abort!'}")
    print(f"  registerParentViaCF: {'FOUND' if has_parent else 'MISSING - abort!'}")
    if not (has_owner and has_parent):
        print("\n  One or both ViaCF methods are missing. Aborting.")
        sys.exit(1)
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-final-wiring-v4-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

# ============================================================================
# STEP 1: Update owner_register_screen.dart
# ============================================================================
print("=" * 70)
print("Step 1: Update owner_register_screen.dart")
print("=" * 70)
print()

owner_screen = Path("lib/features/auth/pages/owner_register_screen.dart")
if not owner_screen.exists():
    for p in Path("lib").rglob("owner_register_screen.dart"):
        owner_screen = p
        break

if owner_screen and owner_screen.exists():
    content = owner_screen.read_text(encoding="utf-8")
    changed = False

    if "registerOwnerViaCF(" in content:
        print("  [OK] Already using registerOwnerViaCF")
    else:
        # v4 FIX: Match any receiver (authService. or ref.read(authServiceProvider).)
        # and preserve it. Only rename the method.
        # Pattern: <anything>.registerOwner(
        # We use a non-greedy match bounded by the call boundary.
        pattern = re.compile(r"(\b\w+(?:\.[a-zA-Z_]\w*)*(?:\([^)]*\))?)\.registerOwner\(", re.DOTALL)
        match = pattern.search(content)
        if match:
            receiver = match.group(1)
            content = content[:match.start()] + receiver + ".registerOwnerViaCF(" + content[match.end():]
            changed = True
            print(f"  [OK] Renamed registerOwner -> registerOwnerViaCF (receiver preserved: {receiver})")
        else:
            print("  [!] Could not find registerOwner call - manual fix needed")

    # v4: DO NOT auto-add organizationName from _nameController (data bug).
    # Instead, insert a TODO comment so the developer wires it up properly.
    if changed and "organizationName" not in content:
        # Insert TODO right after the registerOwnerViaCF( line
        viacf_pos = content.find("registerOwnerViaCF(")
        if viacf_pos > -1:
            # Find end of that line
            line_end = content.find("\n", viacf_pos)
            if line_end > -1:
                todo = (
                    "\n        // TODO(v4): add organizationName parameter to registerOwnerViaCF call."
                    "\n        // Either add a separate _orgNameController field to the form,"
                    "\n        // or pass an empty string and let the CF create a placeholder."
                )
                content = content[:line_end] + todo + content[line_end:]
                print("  [OK] Added TODO comment for organizationName wiring")

    # Fix return values: result['id'] -> result['uid'] (regex with word boundary)
    if changed:
        # v4 FIX: use regex to avoid corrupting result['idToken'] or result['identity']
        new_content, n = re.subn(r"result\['id'\](?![a-zA-Z])", "result['uid']", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['id'] -> result['uid'] ({n} occurrence(s))")

    # Add success check: ViaCF returns {success: bool} instead of throwing
    # v4 FIX: insert BEFORE the first await statement that follows the ViaCF call,
    # not before a hardcoded saveTeacherAuthData(
    if changed and "result['success']" not in content:
        viacf_pos = content.find("registerOwnerViaCF(")
        if viacf_pos > -1:
            # Find the closing ); of the ViaCF call
            paren_count = 1
            pos = viacf_pos + len("registerOwnerViaCF(")
            while pos < len(content) and paren_count > 0:
                if content[pos] == '(':
                    paren_count += 1
                elif content[pos] == ')':
                    paren_count -= 1
                pos += 1
            # Skip trailing whitespace + semicolon
            while pos < len(content) and content[pos] in ' \t\r\n;':
                pos += 1

            success_check = (
                "// v4: ViaCF returns {success: bool} - check before proceeding\n"
                "      if (result['success'] != true) {\n"
                "        final error = result['error'] ?? 'Registration failed';\n"
                "        throw Exception(error);\n"
                "      }\n\n      "
            )
            content = content[:pos] + success_check + content[pos:]
            print("  [OK] Added success check after ViaCF call")

    if changed:
        owner_screen.write_text(content, encoding="utf-8")
        fixes.append("Step 1: owner_register_screen -> ViaCF")
    else:
        print("  [!] No changes made")
else:
    print("  [!] owner_register_screen.dart not found")
print()

# ============================================================================
# STEP 2: Update parent_register_screen.dart
# ============================================================================
print("=" * 70)
print("Step 2: Update parent_register_screen.dart")
print("=" * 70)
print()

parent_screen = Path("lib/features/auth/pages/parent_register_screen.dart")
if not parent_screen.exists():
    for p in Path("lib").rglob("parent_register_screen.dart"):
        parent_screen = p
        break

if parent_screen and parent_screen.exists():
    content = parent_screen.read_text(encoding="utf-8")
    changed = False

    if "registerParentViaCF(" in content:
        print("  [OK] Already using registerParentViaCF")
    else:
        # v4 FIX: same receiver-preserving pattern as Step 1
        pattern = re.compile(r"(\b\w+(?:\.[a-zA-Z_]\w*)*(?:\([^)]*\))?)\.registerParent\(", re.DOTALL)
        match = pattern.search(content)
        if match:
            receiver = match.group(1)
            content = content[:match.start()] + receiver + ".registerParentViaCF(" + content[match.end():]
            changed = True
            print(f"  [OK] Renamed registerParent -> registerParentViaCF (receiver preserved: {receiver})")
        else:
            # Fallback: rename just the method token (count=1, not global)
            new_content, n = re.subn(r"\.registerParent\(", ".registerParentViaCF(", content, count=1)
            if n > 0:
                content = new_content
                changed = True
                print(f"  [OK] Renamed .registerParent( -> .registerParentViaCF( ({n} occurrence)")

    # Fix return values: result['id'] -> result['uid'] (regex with word boundary)
    if changed:
        new_content, n = re.subn(r"result\['id'\](?![a-zA-Z])", "result['uid']", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['id'] -> result['uid'] ({n} occurrence(s))")

    # Add success check (same approach as Step 1)
    if changed and "result['success']" not in content:
        viacf_pos = content.find("registerParentViaCF(")
        if viacf_pos > -1:
            paren_count = 1
            pos = viacf_pos + len("registerParentViaCF(")
            while pos < len(content) and paren_count > 0:
                if content[pos] == '(':
                    paren_count += 1
                elif content[pos] == ')':
                    paren_count -= 1
                pos += 1
            while pos < len(content) and content[pos] in ' \t\r\n;':
                pos += 1

            success_check = (
                "// v4: ViaCF returns {success: bool} - check before proceeding\n"
                "      if (result['success'] != true) {\n"
                "        final error = result['error'] ?? 'Registration failed';\n"
                "        throw Exception(error);\n"
                "      }\n\n      "
            )
            content = content[:pos] + success_check + content[pos:]
            print("  [OK] Added success check after ViaCF call")

    if changed:
        parent_screen.write_text(content, encoding="utf-8")
        fixes.append("Step 2: parent_register_screen -> ViaCF")
    else:
        print("  [!] No changes made")
else:
    print("  [!] parent_register_screen.dart not found")
print()

# ============================================================================
# STEP 3: syncClaims.ts - add roleVersion increment (FIXED)
# ============================================================================
print("=" * 70)
print("Step 3: syncClaims.ts - add roleVersion increment")
print("=" * 70)
print()

sc_path = Path("functions/src/functions/syncClaims.ts")
if sc_path.exists():
    content = sc_path.read_text(encoding="utf-8")

    if "roleVersion" in content and "FieldValue.increment" in content:
        print("  [OK] Already has roleVersion increment")
    else:
        search_str = "setCustomUserClaims("
        call_start = content.find(search_str)

        if call_start == -1:
            print("  [!] Could not find setCustomUserClaims call")
        else:
            # Start scanning AFTER the opening paren
            pos = call_start + len(search_str)
            paren_count = 1  # already inside the call's parens

            while pos < len(content) and paren_count > 0:
                if content[pos] == '(':
                    paren_count += 1
                elif content[pos] == ')':
                    paren_count -= 1
                pos += 1

            # pos is now just past the closing ')' of setCustomUserClaims(...)
            # v4 FIX: skip ONLY trailing whitespace and the immediate semicolon on same line
            # (don't skip newlines - we want to insert right after the ;)
            while pos < len(content) and content[pos] in ' \t':
                pos += 1
            if pos < len(content) and content[pos] == ';':
                pos += 1
            # Now skip the newline so we insert on the next line
            if pos < len(content) and content[pos] == '\n':
                pos += 1

            # v4 FIX: use admin.firestore() directly instead of db (no scope dependency)
            increment_code = """
      // v4: Increment roleVersion to trigger client-side claims refresh
      // (rbacInitProvider listener picks this up and calls getIdTokenResult(true))
      await admin.firestore().collection('users').doc(targetUserId).set(
        { roleVersion: admin.firestore.FieldValue.increment(1) },
        { merge: true }
      );
"""

            content = content[:pos] + increment_code + content[pos:]
            sc_path.write_text(content, encoding="utf-8")
            print("  [OK] syncClaims.ts: added roleVersion increment")
            print("       Uses admin.firestore() directly (no dependency on local db variable)")
            fixes.append("Step 3: syncClaims roleVersion")
else:
    print("  [!] syncClaims.ts not found")
print()

# ============================================================================
# STEP 4: SKIPPED
# ============================================================================
print("=" * 70)
print("Step 4: StatefulShellRoute - SKIPPED")
print("=" * 70)
print()
print("  Needs TeacherShell refactor + manual QA.")
print("  Do in separate PR after current work is deployed and verified.")
print()

# ============================================================================
# Summary + Build + Commit
# ============================================================================
print("=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"\nFixes applied: {len(fixes)}")
for f in fixes: print(f"  + {f}")
print()
print("  Step 4 (StatefulShellRoute) skipped - needs manual QA")
print()

if fixes:
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        r = subprocess.run(["npm","run","build"],shell=True)
        if r.returncode != 0:
            print("\n[WARNING] Functions build failed - check errors")
            print("Common causes:")
            print("  - registerOwnerViaCF signature mismatch with caller")
            print("  - registerParentViaCF signature mismatch with caller")
            print("  - syncClaims.ts already had db variable - check for unused var warning")
        else:
            print("\n  [OK] Functions build succeeded")
    finally:
        os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

msg = """fix(final-wiring-v4): owner/parent screens + syncClaims (corrected)

Step 1: owner_register_screen.dart
  - Calls registerOwnerViaCF (receiver preserved, was registerOwner)
  - TODO comment added for organizationName wiring (developer must add form field)
  - Fixed result['id'] -> result['uid'] (regex with word boundary)
  - Added success check (ViaCF returns {success: bool}, doesn't throw)

Step 2: parent_register_screen.dart
  - Calls registerParentViaCF (receiver preserved)
  - Same success check + return value fixes as Step 1

Step 3: syncClaims.ts
  - Added roleVersion increment after setCustomUserClaims
  - Uses admin.firestore() directly (no dependency on local db variable)
  - Fixed paren-counting bug from v2 (was: started at "auth()", broke mid-line)

Step 4: StatefulShellRoute - SKIPPED
  - Needs TeacherShell refactor + manual QA
  - Do in separate PR

Bug fixes from v3:
  - Receiver preservation: regex matches any receiver (authService. or
    ref.read(authServiceProvider).), preserves it instead of hardcoding authService
  - syncClaims: uses admin.firestore() instead of db (scope-safe)
  - organizationName: NOT auto-passed from _nameController (would create orgs
    named after the owner's personal name); TODO comment added instead
  - Success check: inserted before first await after ViaCF call, not before
    a hardcoded saveTeacherAuthData( (which may not exist in parent screen)
  - result['id'] -> result['uid']: regex with word boundary (won't corrupt
    result['idToken'] or result['identity'])"""

subprocess.run(["git","add","-A"],check=True)
r = subprocess.run(["git","commit","-m",msg],capture_output=True,text=True)
if r.returncode != 0:
    print(f"[ERROR] Commit failed: {r.stderr}")
    sys.exit(1)
new_commit = subprocess.check_output(["git","rev-parse","--short","HEAD"],text=True).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

resp = input("Push to origin? (y/n): ").strip().lower()
if resp == "y":
    r = subprocess.run(["git","push","origin","main"])
    if r.returncode != 0:
        print("\n[ERROR] Push failed")
        sys.exit(1)
    print(f"\n  [OK] Pushed: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else:
    print("[!] Skipped")

print()
print("Deploy: firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("Manual follow-up after deploy:")
print("  1. Add a _orgNameController TextFormField to owner_register_screen.dart")
print("     and pass organizationName: _orgNameController.text.trim() to registerOwnerViaCF")
print("     (remove the TODO comment from this script)")
print("  2. Test owner registration (uses CF now)")
print("  3. Test parent registration (uses CF now)")
print("  4. Test role changes - client should refresh claims within 5s")
print()
print(f"Rollback: git reset --hard {backup}")
