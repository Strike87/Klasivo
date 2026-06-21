#!/usr/bin/env python3
# ============================================================================
# Klasivo — Fix Student Shell Routing (Linux-adapted, non-interactive)
# ============================================================================
# ROOT CAUSE: Only /student is inside StudentShell. All other student routes
# (/student/exams, /student/results, /student/settings, /student/scan-qr,
# /student/notifications) are OUTSIDE the shell. When students navigate to
# these, StudentShell is disposed. Navigating back can land on /dashboard
# which always shows OwnerDashboard → students see teacher/owner actions.
#
# FIX: Move ALL /student/* routes inside the StudentShell ShellRoute.
# Remove the duplicate top-level copies.
#
# Adapted from the user-supplied Windows-targeted script for the Linux
# sandbox at /home/z/my-project. Non-interactive (no `input()` prompt).
#
# Usage:
#   cd /home/z/my-project
#   python3 scripts/apply-student-shell-fix.py
# ============================================================================

import os
import sys
import re
import subprocess
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path("/home/z/my-project")
os.chdir(REPO_ROOT)

if not (REPO_ROOT / "lib/main.dart").exists():
    print("ERROR: lib/main.dart not found at", REPO_ROOT)
    sys.exit(1)

print("=" * 60)
print("Fix: Move student routes inside StudentShell (Linux-adapted)")
print("=" * 60)
print(f"Working directory: {Path.cwd()}")

try:
    print(f"Current commit: {subprocess.check_output(['git','rev-parse','--short','HEAD'],text=True).strip()}")
except Exception:
    pass
print()

# Don't error on dirty tree — just inform. We'll stage only the files we change.
status = subprocess.check_output(["git","status","--porcelain"],text=True).strip()
if status:
    print(f"[!] Working tree has {len(status.splitlines())} dirty file(s).")
    print("    (Proceeding — will stage only lib/main.dart for the commit.)\n")

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup = f"backup-before-student-shell-{timestamp}"
subprocess.run(["git","branch",backup],capture_output=True)
print(f"Backup branch: {backup}\n")

main_path = Path("lib/main.dart")
content = main_path.read_text(encoding="utf-8")

# ============================================================================
# Step 1: Find the current StudentShell block (only wraps /student)
# ============================================================================
old_shell = """      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const StudentDashboard(),
          ),
        ],
      ),"""

new_shell = """      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            builder: (context, state) => const StudentDashboard(),
          ),
          GoRoute(
            path: '/student/settings',
            builder: (context, state) => const StudentSettingsScreen(),
          ),
          GoRoute(
            path: '/student/exams',
            builder: (context, state) => const StudentExamListScreen(),
            routes: [
              GoRoute(
                path: ':examId/take',
                builder: (context, state) {
                  final examId = state.pathParameters['examId']!;
                  return ExamTakingScreen(examId: examId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/student/results',
            builder: (context, state) => const StudentResultsScreen(),
            routes: [
              GoRoute(
                path: ':submissionId',
                builder: (context, state) {
                  final submissionId = state.pathParameters['submissionId']!;
                  return StudentResultDetailScreen(submissionId: submissionId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/student/scan-qr',
            builder: (context, state) => const QrScanScreen(),
          ),
          GoRoute(
            path: '/student/notifications',
            builder: (context, state) => const NotificationCenterScreen(),
          ),
        ],
      ),"""

if old_shell not in content:
    print("[!] Could not find the StudentShell block (exact match). Trying flexible search...")
    pattern = re.compile(
        r"ShellRoute\(\s*"
        r"builder:\s*\(context,\s*state,\s*child\)\s*=>\s*StudentShell\(child:\s*child\),\s*"
        r"routes:\s*\[\s*"
        r"GoRoute\(\s*"
        r"path:\s*'/student',\s*"
        r"builder:\s*\(context,\s*state\)\s*=>\s*const\s+StudentDashboard\(\),\s*"
        r"\),\s*"
        r"\],\s*"
        r"\),",
        re.DOTALL
    )
    match = pattern.search(content)
    if match:
        old_shell = match.group(0)
        print("  [OK] Found StudentShell block (flexible match)")
    else:
        print("  [ERROR] Could not find StudentShell block at all.")
        print("  The code may have already been fixed, or the pattern differs.")
        sys.exit(1)

# Step 2: Replace the old shell with the new one (all routes inside)
content = content.replace(old_shell, new_shell)
print("[OK] Replaced StudentShell block — all student routes now inside")

# ============================================================================
# Step 3: Remove the old top-level student routes (they're now duplicates)
# ============================================================================
old_routes_to_remove = [
    # /student/settings block (with comment)
    """      // ─── Student Settings Route ──────────────────────────────────────
      GoRoute(
        path: '/student/settings',
        builder: (context, state) => const StudentSettingsScreen(),
      ),

""",
    # /student/exams, /student/results, /student/scan-qr, /student/notifications
    # all grouped under the "Student Deep Routes" comment
    """      // ─── Student Deep Routes (outside shell for full-screen) ─────────
      GoRoute(
        path: '/student/exams',
        builder: (context, state) => const StudentExamListScreen(),
        routes: [
          GoRoute(
            path: ':examId/take',
            builder: (context, state) {
              final examId = state.pathParameters['examId']!;
              return ExamTakingScreen(examId: examId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/student/results',
        builder: (context, state) => const StudentResultsScreen(),
        routes: [
          GoRoute(
            path: ':submissionId',
            builder: (context, state) {
              final submissionId = state.pathParameters['submissionId']!;
              return StudentResultDetailScreen(submissionId: submissionId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/student/scan-qr',
        builder: (context, state) => const QrScanScreen(),
      ),
      GoRoute(
        path: '/student/notifications',
        builder: (context, state) => const NotificationCenterScreen(),
      ),
""",
]

removed = 0
for old_route in old_routes_to_remove:
    if old_route in content:
        content = content.replace(old_route, "")
        removed += 1
        print(f"  [OK] Removed duplicate top-level student route block #{removed}")

if removed == 0:
    print("  [!] No duplicate route blocks matched exactly. Manual review needed.")
    print("      Inspect lib/main.dart for leftover /student/* routes outside StudentShell.")

main_path.write_text(content, encoding="utf-8")
print()

# ============================================================================
# Verification
# ============================================================================
print("--- Verification ---")
new_content = main_path.read_text(encoding="utf-8")

# Count /student route references and check that they are all inside the shell
student_route_lines = [i+1 for i, line in enumerate(new_content.split("\n"))
                      if "path: '/student" in line]
print(f"  /student route references in file: {len(student_route_lines)}")
print(f"  Line numbers: {student_route_lines}")

# Find the StudentShell block span
shell_start = new_content.find("StudentShell(child: child)")
if shell_start < 0:
    print("  [ERROR] StudentShell not found in new file!")
    sys.exit(1)

# Find the matching closing ), for the ShellRoute( that contains StudentShell
# Walk forward counting ShellRoute( opens and matching ), closes
shellroute_open = new_content.rfind("ShellRoute(", 0, shell_start)
depth = 0
i = shellroute_open
shell_close = -1
while i < len(new_content):
    if new_content[i:i+10] == "ShellRoute(":
        depth += 1
        i += 10
        continue
    if new_content[i:i+2] == ")," or new_content[i:i+3] == "),\n":
        # Could be end of ShellRoute — but we need to count properly
        pass
    if new_content[i] == "(":
        depth += 1
    elif new_content[i] == ")":
        depth -= 1
        if depth == 0:
            shell_close = i
            break
    i += 1

if shell_close < 0:
    print("  [!] Could not determine ShellRoute block end (verification step skipped)")
    shell_block = new_content[shell_start:]
else:
    shell_block = new_content[shell_start:shell_close]
    student_in_shell = shell_block.count("path: '/student")
    print(f"  StudentShell block span: chars {shell_start}..{shell_close}")
    print(f"  /student routes inside StudentShell: {student_in_shell}")
    if student_in_shell >= 6:
        print("  [OK] All 6 student routes are inside StudentShell")
    else:
        print(f"  [!] Expected 6 student routes in shell, found {student_in_shell}")

# Check for any /student routes outside the shell
total = len(student_route_lines)
if shell_close > 0:
    outside = sum(1 for ln in student_route_lines
                  if ln > new_content[:shell_close].count("\n") + 1)
    # Lines after shell_close
    shell_close_line = new_content[:shell_close].count("\n") + 1
    outside_routes = [ln for ln in student_route_lines if ln > shell_close_line]
    if outside_routes:
        print(f"  [!] {len(outside_routes)} /student route(s) STILL OUTSIDE shell at lines: {outside_routes}")
    else:
        print("  [OK] No /student routes remain outside StudentShell")

print()
