#!/usr/bin/env python3
# ============================================================================
# Klasivo Emergency Fix — C-18: Missing /change-password Route
# ============================================================================
# CRITICAL: Any user with mustChangePassword: true is locked out because
# the router redirects to /change-password but no GoRoute exists.
#
# This script:
#   1. Verifies ChangePasswordScreen exists
#   2. Adds the import to main.dart
#   3. Adds the GoRoute to the router
#   4. Commits and pushes
#
# Time to apply: 5 minutes
# Impact: Prevents ALL student lockouts (every new student hits this)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-change-password-route.py
# ============================================================================

import os
import sys
import re
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

if not Path("lib/main.dart").exists():
    print("ERROR: Run from Klasivo repo root.")
    sys.exit(1)

parser = argparse.ArgumentParser(description="Add missing /change-password route (C-18)")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("C-18 EMERGENCY FIX: Missing /change-password Route")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")
print()

# Verify ChangePasswordScreen exists
screen_path = Path("lib/features/auth/pages/change_password_screen.dart")
if not screen_path.exists():
    # Search for it
    found = list(Path("lib").rglob("change_password_screen.dart"))
    if found:
        screen_path = found[0]
        print(f"Found ChangePasswordScreen at: {screen_path}")
    else:
        print(f"ERROR: change_password_screen.dart not found in lib/")
        print("Cannot apply fix — screen widget doesn't exist.")
        sys.exit(1)
else:
    print(f"Found: {screen_path}")

# Check for uncommitted changes
status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status and not args.force:
    print("ERROR: Working tree has uncommitted changes.")
    print("Run: git stash  OR  re-run with --force")
    sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-c18-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

# Read main.dart
main_path = Path("lib/main.dart")
content = main_path.read_text(encoding="utf-8")

# Check if route already exists
if "/change-password" in content and "GoRoute" in content:
    # Verify it's actually a route, not just a redirect string
    route_pattern = re.search(r"GoRoute\s*\(\s*path:\s*'/change-password'", content)
    if route_pattern:
        print("[OK] /change-password route already exists — no action needed")
        sys.exit(0)

# Step 1: Add import
print("--- Step 1: Add import ---")
relative_path = str(screen_path).replace("\\", "/").replace("lib/", "")
import_line = f"import '{relative_path}';"

if import_line not in content:
    lines = content.split("\n")
    last_import_idx = -1
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import_idx = i
    if last_import_idx >= 0:
        lines.insert(last_import_idx + 1, import_line)
        content = "\n".join(lines)
        print(f"  [OK] Added import: {import_line}")
else:
    print("  [OK] Import already present")

# Step 2: Add the GoRoute
print()
print("--- Step 2: Add /change-password GoRoute ---")

# The route should be OUTSIDE the ShellRoute (no bottom nav for password change)
# Place it near other auth-related routes (login, welcome, etc.)
# Try to find the redirect logic to place the route near it

new_route = """
        // C-18 FIX: /change-password route — was missing, caused hard lockout
        // for any user with mustChangePassword: true
        GoRoute(
          path: '/change-password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),"""

# Strategy: find where other top-level auth routes are (e.g., /login, /welcome, /auth)
# and add after them. If not found, add before the first ShellRoute.

# Try to find /login or /welcome or /auth route
auth_route_match = re.search(
    r"(GoRoute\s*\(\s*path:\s*'/(?:login|welcome|auth|owner-register)[^']*',[^)]+\),)",
    content,
    re.DOTALL
)

if auth_route_match:
    insert_pos = auth_route_match.end()
    content = content[:insert_pos] + new_route + content[insert_pos:]
    print("  [OK] Added /change-password route after auth route")
else:
    # Try to find the redirect logic that references /change-password
    redirect_match = re.search(r"return\s+'/change-password'", content)
    if redirect_match:
        # Find the routes list and add the route there
        # Look for the first GoRoute in the routes list
        first_goroute = re.search(r"(GoRoute\s*\()", content)
        if first_goroute:
            # Find the start of that GoRoute's line
            line_start = content.rfind('\n', 0, first_goroute.start()) + 1
            content = content[:line_start] + new_route.strip() + "\n" + content[line_start:]
            print("  [OK] Added /change-password route before first GoRoute")
    else:
        # Last resort: add before ShellRoute
        shell_match = re.search(r"(ShellRoute\s*\()", content)
        if shell_match:
            line_start = content.rfind('\n', 0, shell_match.start()) + 1
            content = content[:line_start] + new_route.strip() + "\n" + content[line_start:]
            print("  [OK] Added /change-password route before ShellRoute")
        else:
            print("  [!] Could not find insertion point — add manually:")
            print(new_route)

# Write the file
main_path.write_text(content, encoding="utf-8")
print()

# Verify the fix
print("--- Verification ---")
content_check = main_path.read_text(encoding="utf-8")
if re.search(r"GoRoute\s*\(\s*path:\s*'/change-password'", content_check):
    print("  [OK] /change-password GoRoute is now present in main.dart")
else:
    print("  [!] Route may not have been added correctly — verify manually")
    print("  Run: grep -n 'change-password' lib/main.dart")

# Show the diff
print()
print("--- Changes ---")
try:
    result = subprocess.run(
        ["git", "diff", "--stat"],
        capture_output=True, text=True, check=True
    )
    print(result.stdout)
except subprocess.CalledProcessError:
    pass

# Commit
print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """fix(c-18): add missing /change-password route

CRITICAL: Any user with mustChangePassword: true was redirected to
/change-password, but no GoRoute existed for that path. This caused
a hard lockout — users hit "Page not found" and could not navigate
elsewhere because the redirect fires on every route change.

Impact: Every new student (created with default password '123456')
was locked out on first login. This was a launch blocker.

Fix: Added GoRoute pointing at the existing (unused)
ChangePasswordScreen widget at lib/features/auth/pages/change_password_screen.dart

Found by: external code review (not in original master audit)
Severity: P0 (app-breaking)
Effort: 5 minutes"""

subprocess.run(["git", "add", "lib/main.dart"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

# Push
if args.no_push:
    print("[!] Skipping push (--no-push)")
    print("    git push origin main  (when ready)")
else:
    response = input("Push to origin? (y/n): ").strip().lower()
    if response == "y":
        result = subprocess.run(["git", "push", "origin", "main"])
        if result.returncode != 0:
            print("\n[ERROR] Push failed")
            sys.exit(1)
        print(f"\n  [OK] Pushed: https://github.com/Strike87/Klasivo/commit/{new_commit}")
    else:
        print("[!] Skipped. Run: git push origin main")

print()
print("=" * 70)
print("POST-DEPLOY VERIFICATION")
print("=" * 70)
print()
print("1. Deploy: firebase deploy (or flutter build + deploy)")
print()
print("2. Test the fix:")
print("   a. Create a test student (gets default password + mustChangePassword: true)")
print("   b. Sign in as that student")
print("   c. Verify: redirect to /change-password (not 'Page not found')")
print("   d. Verify: ChangePasswordScreen loads")
print("   e. Verify: student can set a new password")
print("   f. Verify: after password change, mustChangePassword is cleared")
print("   g. Verify: student can navigate normally after")
print()
print("Rollback: git reset --hard " + backup_branch)
