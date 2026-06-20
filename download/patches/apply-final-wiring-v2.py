#!/usr/bin/env python3
# ============================================================================
# Klasivo - Final Wiring v2 (corrected)
# ============================================================================
# Applies Steps 1-3 only. Step 4 (StatefulShellRoute) is SKIPPED - needs
# manual TeacherShell refactoring. See audit notes.
#
#   1. owner_register_screen.dart  -> registerOwnerViaCF
#   2. parent_register_screen.dart -> registerParentViaCF
#   3. syncClaims.ts               -> roleVersion increment (FIXED paren counting)
#
# BEFORE RUNNING:
#   - Verify registerOwnerViaCF exists on AuthService
#   - Verify registerParentViaCF exists on AuthService
#   - Verify 'db' (Firestore handle) is in scope in syncClaims.ts
#     (otherwise change inserted code to use admin.firestore().collection(...))
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-final-wiring-v2.py
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

if not Path("lib/main.dart").exists():
    print("ERROR: Run from Klasivo repo root."); sys.exit(1)

print("=" * 70)
print("KLASIVO - Final Wiring v2 (corrected)")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except: pass
print()

status = subprocess.check_output(["git","status","--porcelain"],text=True).strip()
if status:
    print("ERROR: Working tree has uncommitted changes. Run: git stash"); sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-final-wiring-v2-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup: {backup}\n")

fixes = []

# ============================================================================
# 1. Update owner_register_screen.dart to call registerOwnerViaCF
# ============================================================================
print("=" * 70)
print("1. Update owner_register_screen.dart")
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
        # Try the most specific pattern first: ref.read(...).registerOwner(
        pattern_specific = re.compile(r"ref\.read\([^)]+\)\.registerOwner\(", re.DOTALL)
        match = pattern_specific.search(content)
        if match:
            content = content[:match.start()] + "ref.read(authServiceProvider).registerOwnerViaCF(" + content[match.end():]
            changed = True
            print("  [OK] Replaced ref.read(...).registerOwner( with ViaCF")
        else:
            # Generic fallback: rename X.registerOwner( -> X.registerOwnerViaCF( (first occurrence only)
            pattern_generic = re.compile(r"(\b\w+\.)(registerOwner)\(", re.DOTALL)
            new_content, n = pattern_generic.subn(r"\1registerOwnerViaCF(", content, count=1)
            if n > 0:
                content = new_content
                changed = True
                print(f"  [OK] Replaced X.registerOwner( with X.registerOwnerViaCF( ({n} occurrence)")

    if changed:
        owner_screen.write_text(content, encoding="utf-8")
        fixes.append("1. owner_register_screen -> ViaCF")
    elif "registerOwnerViaCF(" not in content:
        print("  [!] Could not find registerOwner call - manual fix needed")
else:
    print("  [!] owner_register_screen.dart not found")
print()

# ============================================================================
# 2. Update parent_register_screen.dart to call registerParentViaCF
# ============================================================================
print("=" * 70)
print("2. Update parent_register_screen.dart")
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
        pattern_specific = re.compile(r"ref\.read\([^)]+\)\.registerParent\(", re.DOTALL)
        match = pattern_specific.search(content)
        if match:
            content = content[:match.start()] + "ref.read(authServiceProvider).registerParentViaCF(" + content[match.end():]
            changed = True
            print("  [OK] Replaced ref.read(...).registerParent( with ViaCF")
        else:
            pattern_generic = re.compile(r"(\b\w+\.)(registerParent)\(", re.DOTALL)
            new_content, n = pattern_generic.subn(r"\1registerParentViaCF(", content, count=1)
            if n > 0:
                content = new_content
                changed = True
                print(f"  [OK] Replaced X.registerParent( with X.registerParentViaCF( ({n} occurrence)")

    if changed:
        parent_screen.write_text(content, encoding="utf-8")
        fixes.append("2. parent_register_screen -> ViaCF")
    elif "registerParentViaCF(" not in content:
        print("  [!] Could not find registerParent call - manual fix needed")
else:
    print("  [!] parent_register_screen.dart not found")
print()

# ============================================================================
# 3. syncClaims.ts: add roleVersion increment (FIXED paren counting)
# ============================================================================
print("=" * 70)
print("3. syncClaims.ts: add roleVersion increment")
print("=" * 70)
print()

sc_path = Path("functions/src/functions/syncClaims.ts")
if sc_path.exists():
    content = sc_path.read_text(encoding="utf-8")

    if "roleVersion" in content and "FieldValue.increment" in content:
        print("  [OK] Already has roleVersion increment")
    else:
        # FIXED: search just for "setCustomUserClaims(" - start counting AFTER that paren
        # (Original script counted from "await admin.auth()..." and broke at auth() )
        old_claims = "setCustomUserClaims("
        if old_claims in content:
            call_start = content.find(old_claims)
            # Position right after "setCustomUserClaims("
            pos = call_start + len(old_claims)
            paren_count = 1  # already inside the call's parens
            while pos < len(content) and paren_count > 0:
                if content[pos] == '(':
                    paren_count += 1
                elif content[pos] == ')':
                    paren_count -= 1
                pos += 1
            # pos is now right after the closing ) of setCustomUserClaims(...)
            # Skip trailing whitespace and the semicolon
            while pos < len(content) and content[pos] in ' \t':
                pos += 1
            if pos < len(content) and content[pos] == ';':
                pos += 1
            insert_pos = pos

            # Verify 'db' is in scope (used in the inserted code)
            if not re.search(r"\bconst\s+db\s*=|\bdb\.collection", content):
                print("  [!] WARNING: 'db' variable not detected in syncClaims.ts")
                print("      Inserted code uses `db.collection('users')...`.")
                print("      If 'db' is not defined, change it to `admin.firestore().collection('users')...`")
                print("      or add `const db = admin.firestore();` near the top.")
                print()

            increment_code = """

      // 3. Increment roleVersion to trigger client-side claims refresh
      // (rbacInitProvider listener picks this up and calls getIdTokenResult(true))
      await db.collection('users').doc(targetUserId).set(
        { roleVersion: admin.firestore.FieldValue.increment(1) },
        { merge: true }
      );"""

            content = content[:insert_pos] + increment_code + content[insert_pos:]
            sc_path.write_text(content, encoding="utf-8")
            print("  [OK] syncClaims.ts: added roleVersion increment after setCustomUserClaims(...)")
            fixes.append("3. syncClaims roleVersion")
        else:
            print("  [!] Could not find setCustomUserClaims call")
else:
    print("  [!] syncClaims.ts not found")
print()

# ============================================================================
# Step 4 - SKIPPED (needs manual refactoring of TeacherShell)
# ============================================================================
print("=" * 70)
print("4. StatefulShellRoute conversion - SKIPPED")
print("=" * 70)
print()
print("  This step requires manual refactoring of TeacherShell:")
print("    1. Change param type Widget child -> StatefulNavigationShell navigationShell")
print("    2. Call navigationShell.goBranch(index) on tab tap")
print("    3. Use navigationShell.currentIndex for active tab highlight")
print()
print("  Then convert each ShellRoute -> StatefulShellRoute.indexedStack")
print("  with one StatefulBranch per tab.")
print()
print("  Do this AFTER deploying steps 1-3 and verifying they work.")
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

if fixes:
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        r = subprocess.run(["npm","run","build"],shell=True)
        if r.returncode != 0:
            print("\n[WARNING] Functions build failed - check errors")
        else:
            print("\n  [OK] Functions build succeeded")
    finally:
        os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

msg = """fix(final-wiring-v2): owner/parent screens + syncClaims (Step 4 deferred)

1. owner_register_screen.dart  - calls registerOwnerViaCF instead of registerOwner
2. parent_register_screen.dart - calls registerParentViaCF instead of registerParent
3. syncClaims.ts - added roleVersion increment after setCustomUserClaims(...)
   (triggers client-side claims refresh via rbacInitProvider listener)

Step 4 (StatefulShellRoute) deferred - needs manual TeacherShell refactoring:
  - Accept StatefulNavigationShell (not Widget child)
  - Call navigationShell.goBranch(index) on tab tap
  - Use navigationShell.currentIndex for active tab

After deploy:
  - Test owner registration (uses CF now)
  - Test parent registration (uses CF now)
  - Test role changes - client should refresh claims within 5s"""

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
print(f"Rollback: git reset --hard {backup}")
