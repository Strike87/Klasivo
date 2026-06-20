#!/usr/bin/env python3
# ============================================================================
# Klasivo — Pre-Sprint 1 Snapshot (Rollback Safety Net)
# ============================================================================
# Creates a tagged snapshot of the current state BEFORE Sprint 1 begins.
# This is your emergency rollback point if Sprint 1 changes accidentally:
#   - Lock out teachers
#   - Lock out owners
#   - Break classrooms
#   - Break LiveKit
#   - Break claims synchronization
#
# What this script does:
#   1. Creates a git branch: pre-sprint1-snapshot-<timestamp>
#   2. Creates a git tag: pre-sprint1-<timestamp> (immutable reference)
#   3. Pushes both to GitHub (so they survive even if your laptop dies)
#   4. Copies firestore.rules + firestore.indexes.json + functions/src/ to a
#      backup directory (in case you need to diff without git)
#   5. Prints the exact rollback commands
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python create-pre-sprint1-snapshot.py
# ============================================================================

import os
import sys
import subprocess
import shutil
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root.")
    sys.exit(1)

print("=" * 70)
print("PRE-SPRINT 1 SNAPSHOT — Rollback Safety Net")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")
print()

# Get current commit
try:
    current_commit = subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], text=True
    ).strip()
    current_branch = subprocess.check_output(
        ["git", "branch", "--show-current"], text=True
    ).strip()
    print(f"Current branch: {current_branch}")
    print(f"Current commit: {current_commit}")
except subprocess.CalledProcessError:
    print("ERROR: Not a git repository")
    sys.exit(1)
print()

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
branch_name = f"pre-sprint1-snapshot-{timestamp}"
tag_name = f"pre-sprint1-{timestamp}"

# ============================================================================
# Step 1: Create backup branch
# ============================================================================
print("--- Step 1: Create backup branch ---")

# Check for uncommitted changes
status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status:
    print("  [!] Working tree has uncommitted changes.")
    print("  Committing them to the snapshot branch...")
    # Stash any changes, create branch, pop stash, commit
    subprocess.run(["git", "stash"], check=True)
    subprocess.run(["git", "branch", branch_name], check=True)
    subprocess.run(["git", "checkout", branch_name], check=True)
    subprocess.run(["git", "stash", "pop"], check=False)
    subprocess.run(["git", "add", "-A"], check=True)
    subprocess.run(["git", "commit", "-m", f"snapshot: pre-Sprint 1 state ({timestamp})"], check=False)
    subprocess.run(["git", "checkout", current_branch], check=True)
else:
    subprocess.run(["git", "branch", branch_name], check=True)

print(f"  [OK] Branch created: {branch_name}")
print()

# ============================================================================
# Step 2: Create git tag (immutable reference)
# ============================================================================
print("--- Step 2: Create git tag ---")

subprocess.run(
    ["git", "tag", "-a", tag_name, "-m", f"Pre-Sprint 1 snapshot — rollback point ({timestamp})"],
    check=True
)
print(f"  [OK] Tag created: {tag_name}")
print()

# ============================================================================
# Step 3: Push branch + tag to GitHub
# ============================================================================
print("--- Step 3: Push to GitHub ---")

response = input("Push snapshot branch + tag to origin? (y/n): ").strip().lower()
if response == "y":
    # Push branch
    result = subprocess.run(["git", "push", "origin", branch_name])
    if result.returncode == 0:
        print(f"  [OK] Branch pushed: {branch_name}")
    else:
        print(f"  [!] Branch push failed (may already exist)")

    # Push tag
    result = subprocess.run(["git", "push", "origin", tag_name])
    if result.returncode == 0:
        print(f"  [OK] Tag pushed: {tag_name}")
    else:
        print(f"  [!] Tag push failed")
else:
    print("  [!] Skipped push — snapshot exists locally only")
    print("      (If your laptop dies, the snapshot is lost. Recommend pushing.)")

print()

# ============================================================================
# Step 4: Copy critical files to backup directory
# ============================================================================
print("--- Step 4: Copy critical files to backup directory ---")

backup_dir = Path(f".pre-sprint1-backup-{timestamp}")
backup_dir.mkdir(exist_ok=True)

critical_files = [
    "firestore.rules",
    "firestore.indexes.json",
    "storage.rules",
    "firebase.json",
    ".firebaserc",
]

critical_dirs = [
    "functions/src",
]

for file_path in critical_files:
    if Path(file_path).exists():
        shutil.copy2(file_path, backup_dir / Path(file_path).name)
        print(f"  [OK] Copied: {file_path}")
    else:
        print(f"  [SKIP] {file_path} not found")

for dir_path in critical_dirs:
    if Path(dir_path).exists():
        dest = backup_dir / Path(dir_path).name
        shutil.copytree(dir_path, dest, dirs_exist_ok=True)
        print(f"  [OK] Copied: {dir_path}/")
    else:
        print(f"  [SKIP] {dir_path}/ not found")

print(f"\n  Backup directory: {backup_dir}")
print("  (This is in addition to the git branch/tag — belt and suspenders)")
print()

# ============================================================================
# Step 5: Create a rollback script
# ============================================================================
print("--- Step 5: Create rollback script ---")

rollback_script = backup_dir / "ROLLBACK.bat"
rollback_script.write_text(f"""@echo off
echo === Klasivo Pre-Sprint 1 Rollback ===
echo.
echo This will reset your repo to the pre-Sprint 1 snapshot.
echo ALL Sprint 1 changes will be lost.
echo.
pause
echo.
echo Rolling back to: {current_commit} (tag: {tag_name})
echo.
git checkout main
git reset --hard {tag_name}
git push origin main --force
echo.
echo Deploying the rolled-back state to Firebase...
firebase deploy --only functions,firestore:rules,firestore:indexes
echo.
echo Rollback complete.
pause
""", encoding="utf-8")
print(f"  [OK] Created: {rollback_script}")
print("       (Double-click to run if you need to emergency-roll back)")
print()

# ============================================================================
# Summary
# ============================================================================
print("=" * 70)
print("SNAPSHOT COMPLETE")
print("=" * 70)
print()
print(f"  Git branch:     {branch_name}")
print(f"  Git tag:        {tag_name}")
print(f"  Backup dir:     {backup_dir}")
print(f"  Rollback script:{rollback_script}")
print(f"  Original commit:{current_commit}")
print()
print("ROLLBACK COMMANDS (if Sprint 1 breaks something):")
print()
print("  Option A — Roll back to tag (recommended):")
print(f"    git checkout main")
print(f"    git reset --hard {tag_name}")
print(f"    git push origin main --force")
print(f"    firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("  Option B — Use the rollback script:")
print(f"    Double-click: {rollback_script}")
print()
print("  Option C — Cherry-pick from backup directory:")
print(f"    Copy files from {backup_dir}/ back to repo root")
print()
print("SAFETY: The tag is immutable. Even if you delete the branch,")
print("the tag still points to the pre-Sprint 1 state. As long as the tag")
print("is pushed to GitHub, you can always recover.")
print()
print("=" * 70)
print("NEXT STEPS")
print("=" * 70)
print()
print("Snapshot is done. Now proceed with:")
print()
print("  1. python apply-change-password-route.py     (C-18 fix, 5 min)")
print("  2. python verify-audit-log-collections.py    (read-only check, 5 min)")
print("  3. python apply-password-hasher.py           (1-2 hours)")
print("  4. python apply-day1-patches.py              (Sprint 1 Day 1)")
print("  5. Continue Sprint 1 Days 2-5")
print()
print("If anything breaks during Sprint 1, roll back to the tag and re-assess.")
