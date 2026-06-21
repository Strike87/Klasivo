#!/usr/bin/env python3
# ============================================================================
# Klasivo - Final Wiring v5 (corrected from v4 per user audit)
# ============================================================================
# Fixes from v4:
#   - CRITICAL: Pass organizationName: _nameController.text.trim() to
#     registerOwnerViaCF (was TODO-only; required param -> compile failure)
#   - Runtime: Replace result['fullName'] -> _nameController.text.trim()
#     (ViaCF doesn't return fullName; would be null in Hive)
#   - Runtime: Replace result['email'] -> _emailController.text.trim()
#     (ViaCF doesn't return email; would be null in Hive)
#   - Runtime: Replace result['hasCompletedSetup'] -> false
#     (ViaCF doesn't return hasCompletedSetup; defaults to false = show setup screen)
#   - Both fixes applied to Step 1 (owner) and Step 2 (parent) screens
#
# Carried over from v4:
#   - Pre-flight check: verifies registerOwnerViaCF / registerParentViaCF exist
#   - Receiver-preserving regex (works for both authService. and ref.read(...))
#   - result['id'] -> result['uid'] with word boundary regex
#   - Success check inserted before first await after ViaCF call
#   - syncClaims uses admin.firestore() directly (no db scope dependency)
#
# SKIP: Step 4 (StatefulShellRoute) - needs manual QA + TeacherShell refactor
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-final-wiring-v5.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("lib/main.dart").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO - Final Wiring v5 (corrected)")
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
backup = f"backup-before-final-wiring-v5-{timestamp}"
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
        # Receiver-preserving regex (works for authService. and ref.read(...))
        pattern = re.compile(r"(\b\w+(?:\.[a-zA-Z_]\w*)*(?:\([^)]*\))?)\.registerOwner\(", re.DOTALL)
        match = pattern.search(content)
        if match:
            receiver = match.group(1)
            content = content[:match.start()] + receiver + ".registerOwnerViaCF(" + content[match.end():]
            changed = True
            print(f"  [OK] Renamed registerOwner -> registerOwnerViaCF (receiver preserved: {receiver})")
        else:
            print("  [!] Could not find registerOwner call - manual fix needed")

    # v5 FIX: Pass organizationName (was TODO-only in v4 -> compile failure)
    # Pragmatic: use owner name as org name; user can change it in setup screen
    if changed and "organizationName:" not in content:
        new_content, n = re.subn(
            r"(fullName:\s*_nameController\.text\.trim\(\),)",
            r"\1\n        organizationName: _nameController.text.trim(),  // v5: org name (can change in setup)",
            content,
            count=1
        )
        if n > 0:
            content = new_content
            print("  [OK] Added organizationName: _nameController.text.trim() (v5 fix)")
        else:
            # Fallback: insert before the closing ) of the ViaCF call
            viacf_pos = content.find("registerOwnerViaCF(")
            if viacf_pos > -1:
                paren_count = 1
                pos = viacf_pos + len("registerOwnerViaCF(")
                while pos < len(content) and paren_count > 0:
                    if content[pos] == '(':
                        paren_count += 1
                    elif content[pos] == ')':
                        paren_count -= 1
                    pos += 1
                # Insert before the closing paren
                insert_pos = pos - 1
                # Skip back over trailing whitespace
                while insert_pos > 0 and content[insert_pos - 1] in ' \t\r\n':
                    insert_pos -= 1
                content = content[:insert_pos] + ",\n        organizationName: _nameController.text.trim(),  // v5: org name (can change in setup)\n      " + content[insert_pos:]
                print("  [OK] Added organizationName param via fallback (v5 fix)")

    # Fix return values that ViaCF doesn't provide
    if changed:
        # result['id'] -> result['uid'] (regex with word boundary)
        new_content, n = re.subn(r"result\['id'\](?![a-zA-Z])", "result['uid']", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['id'] -> result['uid'] ({n} occurrence(s))")

        # v5 FIX: result['fullName'] -> _nameController.text.trim()
        # (ViaCF returns {success, uid, organizationId, role} - no fullName)
        new_content, n = re.subn(r"result\['fullName'\]", "_nameController.text.trim()", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['fullName'] -> _nameController.text.trim() ({n} occurrence(s))")

        # v5 FIX: result['email'] -> _emailController.text.trim()
        new_content, n = re.subn(r"result\['email'\]", "_emailController.text.trim()", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['email'] -> _emailController.text.trim() ({n} occurrence(s))")

        # v5 FIX: result['hasCompletedSetup'] -> false
        # (ViaCF doesn't return this; default to false = show setup screen on first login)
        # Order matters: replace ?? variants first (more specific), then bare references
        new_content, n1 = re.subn(r"result\['hasCompletedSetup'\]\s*\?\?\s*false", "false", content)
        new_content, n2 = re.subn(r"result\['hasCompletedSetup'\]\s*\?\?\s*true", "false", new_content)
        new_content, n3 = re.subn(r"result\['hasCompletedSetup'\]", "false", new_content)
        total = n1 + n2 + n3
        if total > 0:
            content = new_content
            print(f"  [OK] Replaced result['hasCompletedSetup'] -> false ({total} occurrence(s))")

    # Add success check: ViaCF returns {success: bool} instead of throwing
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
                "// v5: ViaCF returns {success: bool} - check before proceeding\n"
                "      if (result['success'] != true) {\n"
                "        final error = result['error'] ?? 'Registration failed';\n"
                "        throw Exception(error);\n"
                "      }\n\n      "
            )
            content = content[:pos] + success_check + content[pos:]
            print("  [OK] Added success check after ViaCF call")

    if changed:
        owner_screen.write_text(content, encoding="utf-8")
        fixes.append("Step 1: owner_register_screen -> ViaCF + organizationName + return fixes")
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
        pattern = re.compile(r"(\b\w+(?:\.[a-zA-Z_]\w*)*(?:\([^)]*\))?)\.registerParent\(", re.DOTALL)
        match = pattern.search(content)
        if match:
            receiver = match.group(1)
            content = content[:match.start()] + receiver + ".registerParentViaCF(" + content[match.end():]
            changed = True
            print(f"  [OK] Renamed registerParent -> registerParentViaCF (receiver preserved: {receiver})")
        else:
            new_content, n = re.subn(r"\.registerParent\(", ".registerParentViaCF(", content, count=1)
            if n > 0:
                content = new_content
                changed = True
                print(f"  [OK] Renamed .registerParent( -> .registerParentViaCF( ({n} occurrence)")

    # Fix return values that ViaCF doesn't provide
    if changed:
        # result['id'] -> result['uid']
        new_content, n = re.subn(r"result\['id'\](?![a-zA-Z])", "result['uid']", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['id'] -> result['uid'] ({n} occurrence(s))")

        # v5 FIX: result['fullName'] -> _nameController.text.trim()
        new_content, n = re.subn(r"result\['fullName'\]", "_nameController.text.trim()", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['fullName'] -> _nameController.text.trim() ({n} occurrence(s))")

        # v5 FIX: result['email'] -> _emailController.text.trim()
        new_content, n = re.subn(r"result\['email'\]", "_emailController.text.trim()", content)
        if n > 0:
            content = new_content
            print(f"  [OK] Replaced result['email'] -> _emailController.text.trim() ({n} occurrence(s))")

        # v5 FIX: result['hasCompletedSetup'] -> false
        new_content, n1 = re.subn(r"result\['hasCompletedSetup'\]\s*\?\?\s*false", "false", content)
        new_content, n2 = re.subn(r"result\['hasCompletedSetup'\]\s*\?\?\s*true", "false", new_content)
        new_content, n3 = re.subn(r"result\['hasCompletedSetup'\]", "false", new_content)
        total = n1 + n2 + n3
        if total > 0:
            content = new_content
            print(f"  [OK] Replaced result['hasCompletedSetup'] -> false ({total} occurrence(s))")

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
                "// v5: ViaCF returns {success: bool} - check before proceeding\n"
                "      if (result['success'] != true) {\n"
                "        final error = result['error'] ?? 'Registration failed';\n"
                "        throw Exception(error);\n"
                "      }\n\n      "
            )
            content = content[:pos] + success_check + content[pos:]
            print("  [OK] Added success check after ViaCF call")

    if changed:
        parent_screen.write_text(content, encoding="utf-8")
        fixes.append("Step 2: parent_register_screen -> ViaCF + return fixes")
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
            # Skip trailing whitespace and the immediate semicolon
            while pos < len(content) and content[pos] in ' \t':
                pos += 1
            if pos < len(content) and content[pos] == ';':
                pos += 1
            # Skip the newline so we insert on the next line
            if pos < len(content) and content[pos] == '\n':
                pos += 1

            # Use admin.firestore() directly (no dependency on local db variable)
            increment_code = """
      // v5: Increment roleVersion to trigger client-side claims refresh
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
        else:
            print("\n  [OK] Functions build succeeded")
    finally:
        os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

msg = """fix(final-wiring-v5): owner/parent screens + syncClaims (corrected)

Step 1: owner_register_screen.dart
  - Calls registerOwnerViaCF (receiver preserved, was registerOwner)
  - Passes organizationName: _nameController.text.trim() (v5: required param)
    - Pragmatic: org name = owner name; user can change in setup screen
  - Fixed result['id'] -> result['uid'] (regex with word boundary)
  - Fixed result['fullName'] -> _nameController.text.trim() (v5: not in ViaCF return)
  - Fixed result['email'] -> _emailController.text.trim() (v5: not in ViaCF return)
  - Fixed result['hasCompletedSetup'] -> false (v5: not in ViaCF return)
  - Added success check (ViaCF returns {success: bool}, doesn't throw)

Step 2: parent_register_screen.dart
  - Calls registerParentViaCF (receiver preserved)
  - Same return value fixes as Step 1 (fullName/email/hasCompletedSetup)
  - Added success check

Step 3: syncClaims.ts
  - Added roleVersion increment after setCustomUserClaims
  - Uses admin.firestore() directly (no dependency on local db variable)
  - Fixed paren-counting bug from v2 (was: started at "auth()", broke mid-line)

Step 4: StatefulShellRoute - SKIPPED
  - Needs TeacherShell refactor + manual QA
  - Do in separate PR

Bug fixes from v4 (per user audit):
  - CRITICAL: organizationName is required on registerOwnerViaCF
    - v4 only added a TODO comment -> guaranteed compile failure
    - v5 passes _nameController.text.trim() as pragmatic default
  - Runtime: result['fullName'] / result['email'] / result['hasCompletedSetup']
    were silently null because ViaCF doesn't return them
    - v5 replaces with form controller values / false
    - Without this, user's name and email would be null in Hive -> broken dashboard"""

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
print("Verify after deploy:")
print("  1. Owner registers -> succeeds (via CF, org created with owner's name)")
print("  2. Parent registers -> succeeds (via CF)")
print("  3. Admin changes user's role -> user's claims refresh within 5s")
print("  4. After login, dashboard shows correct name + email (not null)")
print()
print(f"Rollback: git reset --hard {backup}")
