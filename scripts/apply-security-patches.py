#!/usr/bin/env python3
# ============================================================================
# Klasivo — Combined Security Patches Runner
# ============================================================================
# Applies 5 patch scripts in order, stripping per-script commit/build/push.
# Leaves the working tree dirty for inspection. Does NOT commit, does NOT push.
#
# Order:
#   1. apply-auth-fixes.py            (5 P1 authorization issues)
#   2. apply-7-auth-fixes.py          (5 P1 + 2 P2 more auth issues)
#   3. apply-data-exposure-fixes-v2.py (6 data-exposure issues, supersedes v1)
#   4. apply-exam-flow-fixes.py       (5 exam-flow issues, creates gradeSubmission CF)
#   5. apply-rbac-fixes.py            (7 RBAC issues)
# ============================================================================

import os, sys, re, subprocess
from pathlib import Path
from datetime import datetime

ROOT = Path("/home/z/my-project")
PATCHES_DIR = ROOT / "download" / "patches"

SCRIPTS = [
    "apply-auth-fixes.py",
    "apply-7-auth-fixes.py",
    "apply-data-exposure-fixes-v2.py",
    "apply-exam-flow-fixes.py",
    "apply-rbac-fixes.py",
]

# 1. Pre-flight: working tree must be clean
r = subprocess.run(["git","status","--porcelain"], cwd=ROOT, capture_output=True, text=True)
if r.stdout.strip():
    print("[RUNNER] ERROR: Working tree not clean. Commit or stash first.")
    print(r.stdout)
    sys.exit(1)
print("[RUNNER] Pre-flight OK: working tree clean.\n")

# 2. Create one backup branch for all 5 patch sets
timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-security-patches-{timestamp}"
subprocess.run(["git","branch",backup], capture_output=True, cwd=ROOT)
print(f"[RUNNER] Backup branch: {backup}\n")

# 3. Apply each patch script (strip everything from "# Summary + Build + Commit" onward)
all_fixes = []
for script_name in SCRIPTS:
    script_path = PATCHES_DIR / script_name
    if not script_path.exists():
        print(f"[RUNNER] ERROR: {script_name} not found")
        continue

    content = script_path.read_text(encoding="utf-8")

    # Strip everything from "# Summary + Build + Commit" onward
    marker = "# Summary + Build + Commit"
    idx = content.find(marker)
    if idx == -1:
        print(f"[RUNNER] WARNING: Could not find summary marker in {script_name}")
        print(f"[RUNNER]   Looking for: {marker!r}")
        continue

    # Walk back to the start of the comment block (the `# ===` line above the marker)
    # so we don't leave a dangling `# ===` decoration.
    patch_only = content[:idx]
    # Strip trailing `# ===...` decoration
    patch_only = patch_only.rstrip()
    while patch_only.endswith("# " + "=" * 69) or patch_only.endswith("# " + "=" * 70):
        patch_only = patch_only[:patch_only.rfind("# " + "=" * 69)].rstrip()
    patch_only += "\n"

    print(f"\n{'#' * 78}")
    print(f"# [RUNNER] Applying {script_name}")
    print(f"{'#' * 78}\n")

    # Exec the patch portion in a shared namespace
    ns = {
        "__name__": script_name[:-3],
        "__file__": str(script_path),
        "Path": Path,
        "os": os,
        "sys": sys,
        "re": re,
        "subprocess": subprocess,
        "datetime": datetime,
    }
    # Change cwd to ROOT for the duration of this script
    old_cwd = os.getcwd()
    os.chdir(ROOT)
    try:
        exec(compile(patch_only, str(script_path), "exec"), ns)
        fixes = ns.get("fixes", [])
        all_fixes.extend([(script_name, f) for f in fixes])
    except Exception as e:
        import traceback
        print(f"[RUNNER] ERROR in {script_name}: {e}")
        traceback.print_exc()
    finally:
        os.chdir(old_cwd)

# 4. Summary
print(f"\n{'#' * 78}")
print(f"# [RUNNER] ALL PATCHES APPLIED")
print(f"{'#' * 78}\n")
print(f"Total fixes applied: {len(all_fixes)}")
for script, fix in all_fixes:
    print(f"  [{script}]  {fix}")
print()

# 5. Show git status
print(f"{'=' * 78}")
print(f"[RUNNER] Git status (working tree)")
print(f"{'=' * 78}")
r = subprocess.run(["git","status","--short"], cwd=ROOT, capture_output=True, text=True)
print(r.stdout if r.stdout.strip() else "  (no changes — all patches may have been skipped)")
print()

# 6. Show diff stats
print(f"{'=' * 78}")
print(f"[RUNNER] Diff stats")
print(f"{'=' * 78}")
r = subprocess.run(["git","diff","--stat","HEAD"], cwd=ROOT, capture_output=True, text=True)
print(r.stdout if r.stdout.strip() else "  (no diff)")
r = subprocess.run(["git","diff","--cached","--stat","HEAD"], cwd=ROOT, capture_output=True, text=True)
if r.stdout.strip():
    print("[STAGED]")
    print(r.stdout)
print()

# 7. Instructions
print(f"{'=' * 78}")
print(f"[RUNNER] Next steps")
print(f"{'=' * 78}")
print(f"  Review:     git diff HEAD")
print(f"  Commit:     git add -A && git commit -m '<message>'")
print(f"  Rollback:   git reset --hard {backup}")
print()
