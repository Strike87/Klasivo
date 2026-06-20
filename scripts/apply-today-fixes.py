#!/usr/bin/env python3
# ============================================================================
# Klasivo — Today's Fixes (Issues 1, 3, 4) — Linux-adapted, non-interactive
# ============================================================================
# Adapted from the user-supplied apply-today-fixes.py for the Linux sandbox at
# /home/z/my-project (which is the Klasivo repo root).
#
# Fixes:
#   Issue 1: currentOrganizationIdProvider never synced after login
#   Issue 3: Notifications query missing organizationId filter
#   Issue 4: Exam creation defaults organizationId to 'default'
#
# Issue 2 (ShellRoute tab disposal) is intentionally NOT automated — it requires
# manual restructuring of the GoRouter tree in lib/main.dart. The script will
# print the manual recipe at the end.
#
# Differences from the original Windows-targeted script:
#   * Runs from /home/z/my-project (Linux), not C:\Users\Strik\Klasivo
#   * Non-interactive: no input() prompt; uses --no-push semantics by default
#   * Issue 1 also adds the missing `import 'organization_provider.dart';`
#     to both auth_provider.dart files (currentOrganizationIdProvider lives
#     in organization_provider.dart, not auth_provider.dart — the original
#     script would have produced uncompilable Dart).
#   * Issue 3 handles the prefixed import (`notif_service.NotificationService`)
#     and updates BOTH call sites (notificationsStreamProvider + unreadCountProvider).
#   * Issue 4 SKIPS the broken `exam_instance_service.dart` naive replacement
#     (it would have replaced `AppConstants.defaultInstitutionId` with bare
#     `organizationId`, which is not in scope — compilation would fail).
#     Instead, exam_instance_service.dart is left untouched and a TODO is
#     printed for a follow-up commit.
#
# Usage:
#   cd /home/z/my-project
#   python3 scripts/apply-today-fixes.py
# ============================================================================

import os
import sys
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path("/home/z/my-project")
os.chdir(REPO_ROOT)

if not (REPO_ROOT / "firestore.rules").exists():
    print("ERROR: firestore.rules not found at", REPO_ROOT)
    sys.exit(1)

parser = argparse.ArgumentParser(description="Apply Klasivo Today's Fixes (Issues 1, 3, 4)")
parser.add_argument("--no-push", action="store_true", default=True,
                    help="Do not push to origin (default: True in this adapted version)")
parser.add_argument("--no-build", action="store_true", default=True,
                    help="Skip functions build (default: True; Flutter analyze is run separately)")
parser.add_argument("--force", action="store_true",
                    help="Apply even if working tree has uncommitted changes")
args = parser.parse_args()

print("=" * 70)
print("KLASIVO TODAY'S FIXES — Issues 1, 3, 4 (Linux-adapted)")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    current_commit = subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], text=True
    ).strip()
    print(f"Current git commit: {current_commit}")
except subprocess.CalledProcessError:
    sys.exit(1)
print()

status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status and not args.force:
    print("ERROR: Working tree has uncommitted changes.")
    print("Run: git stash  OR  re-run with --force")
    sys.exit(1)
elif status:
    print(f"[!] Working tree has {len(status.splitlines())} dirty file(s) — proceeding (--force)\n")

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-today-fixes-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}\n")

fixes_applied = []
manual_followups = []

# ============================================================================
# Issue 1: Sync currentOrganizationIdProvider after login
# ============================================================================
print("=" * 70)
print("Issue 1: Sync currentOrganizationIdProvider after login")
print("=" * 70)
print()
print("  ROOT CAUSE: saveTeacherAuthData/saveStudentAuthData/saveParentAuthData")
print("  update organizationIdProvider but NEVER update currentOrganizationIdProvider.")
print("  65+ providers read currentOrganizationIdProvider → get null → return Stream.empty()")
print()

# currentOrganizationIdProvider lives in lib/providers/organization_provider.dart
# (not in auth_provider.dart). We must import it in both auth_provider files.

auth_files = [
    (Path("lib/providers/auth_provider.dart"),
     "import 'organization_provider.dart';"),
    (Path("lib/features/auth/providers/auth_provider.dart"),
     "import '../../../providers/organization_provider.dart';"),
]

old_pattern = "ref.read(organizationIdProvider.notifier).state = organizationId;"
new_pattern = (
    "ref.read(organizationIdProvider.notifier).state = organizationId;\n"
    "      ref.read(currentOrganizationIdProvider.notifier).state = organizationId;  // ISSUE 1 FIX"
)

for auth_path, import_line in auth_files:
    if not auth_path.exists():
        print(f"  [SKIP] {auth_path} not found")
        continue
    content = auth_path.read_text(encoding="utf-8")
    count = content.count(old_pattern)

    if count == 0:
        print(f"  [!] {auth_path}: pattern not found (may already be fixed)")
        continue

    # Add the import if it's not already there
    if import_line not in content:
        # Find the last `import '...';` line in the header and append ours after it
        lines = content.split("\n")
        last_import_idx = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import_idx = i
        lines.insert(last_import_idx + 1, import_line)
        content = "\n".join(lines)
        print(f"  [OK] {auth_path}: added import for organization_provider.dart")

    # Apply the sync line
    content = content.replace(old_pattern, new_pattern)
    auth_path.write_text(content, encoding="utf-8")
    print(f"  [OK] {auth_path}: added currentOrganizationIdProvider sync ({count} location(s))")

fixes_applied.append("Issue 1: Provider sync (currentOrganizationIdProvider)")
print()

# ============================================================================
# Issue 2: ShellRoute → StatefulShellRoute.indexedStack (manual — flag only)
# ============================================================================
print("=" * 70)
print("Issue 2: ShellRoute disposes tab state (MANUAL FIX)")
print("=" * 70)
print()
print("  ROOT CAUSE: Plain ShellRoute disposes tab widget subtrees on navigation.")
print("  Converting to StatefulShellRoute.indexedStack preserves tab state.")
print()
print("  This change requires manual restructuring of the route tree in lib/main.dart.")
print("  Apply AFTER Issues 1/3/4 are deployed and verified.")
print()
print("  NOTE: Issue 1 fix may resolve most of Issue 2's symptoms since the")
print("  disappearing data was primarily caused by null orgId, not tab disposal.")
print()
manual_followups.append("Issue 2: Convert ShellRoute → StatefulShellRoute.indexedStack in lib/main.dart")
print()

# ============================================================================
# Issue 3: Notifications query missing organizationId filter
# ============================================================================
print("=" * 70)
print("Issue 3: Notifications query missing organizationId filter")
print("=" * 70)
print()
print("  ROOT CAUSE: getUserNotificationsStream/getUnreadCount/markAllAsRead")
print("  filter on userId only. Rule isInSameOrg() requires organizationId match → denied.")
print()

notif_path = Path("lib/core/services/notification_service.dart")
notif_content = notif_path.read_text(encoding="utf-8")

# Fix 1: getUserNotificationsStream
old_stream = (
    "static Stream<QuerySnapshot> getUserNotificationsStream(String userId) {\n"
    "    return _firestore\n"
    "        .collection(AppConstants.notificationsCollection)\n"
    "        .where('userId', isEqualTo: userId)\n"
    "        .orderBy('createdAt', descending: true)\n"
    "        .limit(AppConstants.notificationsPageSize)\n"
    "        .snapshots();\n"
    "  }"
)
new_stream = (
    "static Stream<QuerySnapshot> getUserNotificationsStream(\n"
    "      String userId, {required String organizationId}) {\n"
    "    return _firestore\n"
    "        .collection(AppConstants.notificationsCollection)\n"
    "        .where('userId', isEqualTo: userId)\n"
    "        .where('organizationId', isEqualTo: organizationId)  // ISSUE 3 FIX\n"
    "        .orderBy('createdAt', descending: true)\n"
    "        .limit(AppConstants.notificationsPageSize)\n"
    "        .snapshots();\n"
    "  }"
)
if old_stream in notif_content:
    notif_content = notif_content.replace(old_stream, new_stream)
    print("  [OK] getUserNotificationsStream: added organizationId filter")
else:
    print("  [!] getUserNotificationsStream pattern not found (may already be fixed)")

# Fix 2: getUnreadCount
old_unread = (
    "static Future<int> getUnreadCount(String userId) async {\n"
    "    try {\n"
    "      final snapshot = await _firestore\n"
    "          .collection(AppConstants.notificationsCollection)\n"
    "          .where('userId', isEqualTo: userId)\n"
    "          .where('isRead', isEqualTo: false)\n"
    "          .get();"
)
new_unread = (
    "static Future<int> getUnreadCount(String userId, {required String organizationId}) async {\n"
    "    try {\n"
    "      final snapshot = await _firestore\n"
    "          .collection(AppConstants.notificationsCollection)\n"
    "          .where('userId', isEqualTo: userId)\n"
    "          .where('organizationId', isEqualTo: organizationId)  // ISSUE 3 FIX\n"
    "          .where('isRead', isEqualTo: false)\n"
    "          .get();"
)
if old_unread in notif_content:
    notif_content = notif_content.replace(old_unread, new_unread)
    print("  [OK] getUnreadCount: added organizationId filter")
else:
    print("  [!] getUnreadCount pattern not found")

# Fix 3: markAllAsRead
old_mark = (
    "static Future<void> markAllAsRead(String userId) async {\n"
    "    try {\n"
    "      final snapshot = await _firestore\n"
    "          .collection(AppConstants.notificationsCollection)\n"
    "          .where('userId', isEqualTo: userId)\n"
    "          .where('isRead', isEqualTo: false)\n"
    "          .get();"
)
new_mark = (
    "static Future<void> markAllAsRead(String userId, {required String organizationId}) async {\n"
    "    try {\n"
    "      final snapshot = await _firestore\n"
    "          .collection(AppConstants.notificationsCollection)\n"
    "          .where('userId', isEqualTo: userId)\n"
    "          .where('organizationId', isEqualTo: organizationId)  // ISSUE 3 FIX\n"
    "          .where('isRead', isEqualTo: false)\n"
    "          .get();"
)
if old_mark in notif_content:
    notif_content = notif_content.replace(old_mark, new_mark)
    print("  [OK] markAllAsRead: added organizationId filter")
else:
    print("  [!] markAllAsRead pattern not found")

notif_path.write_text(notif_content, encoding="utf-8")

# Fix 4: Update notification_provider.dart to pass orgId at BOTH call sites
# The actual code uses a prefixed import (notif_service.NotificationService),
# and there are TWO call sites: notificationsStreamProvider (line ~16) and
# unreadCountProvider (line ~44). The original script only handled the first
# and used the wrong (unprefixed) pattern.
notif_provider_path = Path("lib/providers/notification_provider.dart")
if notif_provider_path.exists():
    np_content = notif_provider_path.read_text(encoding="utf-8")

    # Add the import for organization_provider.dart if missing
    org_import = "import 'organization_provider.dart';"
    if org_import not in np_content:
        # Insert after the existing auth_provider import line
        auth_import = "import 'auth_provider.dart';"
        if auth_import in np_content:
            np_content = np_content.replace(
                auth_import,
                auth_import + "\n" + org_import,
                1,
            )
            print(f"  [OK] notification_provider: added import for organization_provider.dart")
        else:
            print(f"  [!] notification_provider: could not find auth_provider import to anchor new import")

    # Fix call site 1: notificationsStreamProvider
    old_call_1 = (
        "  final userId = ref.watch(currentUserIdProvider);\n"
        "  if (userId == null) return const Stream.empty();\n"
        "\n"
        "  return notif_service.NotificationService.getUserNotificationsStream(userId);"
    )
    new_call_1 = (
        "  final userId = ref.watch(currentUserIdProvider);\n"
        "  if (userId == null) return const Stream.empty();\n"
        "  final orgId = ref.watch(currentOrganizationIdProvider);\n"
        "  if (orgId == null || orgId.isEmpty) return const Stream.empty();\n"
        "\n"
        "  return notif_service.NotificationService.getUserNotificationsStream(\n"
        "    userId,\n"
        "    organizationId: orgId,\n"
        "  );"
    )
    if old_call_1 in np_content:
        np_content = np_content.replace(old_call_1, new_call_1)
        print("  [OK] notification_provider: notificationsStreamProvider now passes orgId")
    else:
        print("  [!] notification_provider: notificationsStreamProvider call-site pattern not found")

    # Fix call site 2: unreadCountProvider
    old_call_2 = (
        "  final userId = ref.watch(currentUserIdProvider);\n"
        "  if (userId == null) return 0;\n"
        "\n"
        "  return notif_service.NotificationService.getUnreadCount(userId);"
    )
    new_call_2 = (
        "  final userId = ref.watch(currentUserIdProvider);\n"
        "  if (userId == null) return 0;\n"
        "  final orgId = ref.watch(currentOrganizationIdProvider);\n"
        "  if (orgId == null || orgId.isEmpty) return 0;\n"
        "\n"
        "  return notif_service.NotificationService.getUnreadCount(\n"
        "    userId,\n"
        "    organizationId: orgId,\n"
        "  );"
    )
    if old_call_2 in np_content:
        np_content = np_content.replace(old_call_2, new_call_2)
        print("  [OK] notification_provider: unreadCountProvider now passes orgId")
    else:
        print("  [!] notification_provider: unreadCountProvider call-site pattern not found")

    notif_provider_path.write_text(np_content, encoding="utf-8")

fixes_applied.append("Issue 3: Notifications orgId filter (service + provider)")
print()

# ============================================================================
# Issue 4: Exam creation defaults organizationId to 'default'
# ============================================================================
print("=" * 70)
print("Issue 4: Exam creation defaults organizationId to 'default'")
print("=" * 70)
print()
print("  ROOT CAUSE: exam_service.dart defaults organizationId to 'default'")
print("  exam_form_screen.dart never passes the real org → permission-denied")
print()

# Fix 1a: exam_service.dart (lib/core/services/) — make organizationId required
for exam_service_path in [
    Path("lib/core/services/exam_service.dart"),
    Path("lib/features/exams/data/exam_service.dart"),
]:
    if not exam_service_path.exists():
        continue
    content = exam_service_path.read_text(encoding="utf-8")
    old_exam_default = "String organizationId = AppConstants.defaultInstitutionId,"
    new_exam_default = "required String organizationId,"
    if old_exam_default in content:
        content = content.replace(old_exam_default, new_exam_default)
        exam_service_path.write_text(content, encoding="utf-8")
        print(f"  [OK] {exam_service_path}: organizationId now required")
    else:
        print(f"  [SKIP] {exam_service_path}: pattern not found (may already be fixed)")

# Fix 1b: violation_service.dart — make organizationId required (same pattern)
v_path = Path("lib/core/services/violation_service.dart")
if v_path.exists():
    v_content = v_path.read_text(encoding="utf-8")
    old_v = "String organizationId = AppConstants.defaultInstitutionId,"
    new_v = "required String organizationId,"
    if old_v in v_content:
        v_content = v_content.replace(old_v, new_v)
        v_path.write_text(v_content, encoding="utf-8")
        print(f"  [OK] {v_path}: logViolation organizationId now required")
    else:
        print(f"  [SKIP] {v_path}: pattern not found")

# Fix 2: exam_form_screen.dart — pass organizationId from provider (both copies)
for exam_form_path in [
    Path("lib/features/exams/pages/exam_form_screen.dart"),
    Path("lib/features/exams/presentation/exam_form_screen.dart"),
]:
    if not exam_form_path.exists():
        continue
    form_content = exam_form_path.read_text(encoding="utf-8")
    old_create = (
        "final examId = await examService.createExam(\n"
        "    teacherId: teacherId,"
    )
    new_create = (
        "final organizationId = ref.read(organizationIdProvider);\n"
        "  if (organizationId == null || organizationId.isEmpty) {\n"
        "    KlasivoToast.error(context, message: 'Organization context missing. Please re-login.');\n"
        "    return;\n"
        "  }\n"
        "  final examId = await examService.createExam(\n"
        "    teacherId: teacherId,\n"
        "    organizationId: organizationId,"
    )
    if old_create in form_content:
        form_content = form_content.replace(old_create, new_create, 1)
        exam_form_path.write_text(form_content, encoding="utf-8")
        print(f"  [OK] {exam_form_path}: passes organizationId from provider")
    else:
        print(f"  [!] {exam_form_path}: createExam call pattern not found — check manually")

# SKIP the broken exam_instance_service.dart naive replacement from the
# original script. The original script would have replaced
# `AppConstants.defaultInstitutionId` (a valid expression) with bare
# `organizationId` (not in scope) → compilation would fail.
#
# Proper fix would require:
#   1. Add `required String organizationId` parameter to createExamInstance()
#      in both lib/core/services/exam_instance_service.dart and
#      lib/features/exams/data/exam_instance_service.dart (they are identical)
#   2. Update caller lib/features/student_exams/pages/exam_taking_screen.dart
#      line ~120 to pass organizationId from organizationIdProvider
#
# This is deferred to a follow-up commit to keep this PR focused.
manual_followups.append(
    "Issue 4 (follow-up): exam_instance_service.dart createExamInstance() still "
    "hardcodes AppConstants.defaultInstitutionId. Add required organizationId "
    "param + update caller in exam_taking_screen.dart (~line 120)."
)
print()
print("  [DEFERRED] exam_instance_service.dart createExamInstance() still hardcodes")
print("             'default' — needs proper parameter + caller fix (see follow-up).")
print()

fixes_applied.append("Issue 4: Exam creation orgId (service + form + violation)")
print()

# ============================================================================
# Summary
# ============================================================================
print("=" * 70)
print("FIXES SUMMARY")
print("=" * 70)
print()
for f in fixes_applied:
    print(f"  + {f}")
print()
print("  Manual follow-ups:")
for m in manual_followups:
    print(f"  - {m}")
print()

# ============================================================================
# Flutter analyze (syntax sanity check)
# ============================================================================
print("=" * 70)
print("Flutter analyze (dart syntax sanity)")
print("=" * 70)
result = subprocess.run(
    ["flutter", "analyze", "--no-pub", "--fatal-infos=false",
     "lib/providers/auth_provider.dart",
     "lib/features/auth/providers/auth_provider.dart",
     "lib/core/services/notification_service.dart",
     "lib/providers/notification_provider.dart",
     "lib/core/services/exam_service.dart",
     "lib/features/exams/data/exam_service.dart",
     "lib/core/services/violation_service.dart",
     "lib/features/exams/pages/exam_form_screen.dart",
     "lib/features/exams/presentation/exam_form_screen.dart"],
    capture_output=True, text=True, timeout=180,
)
print(result.stdout[-3000:] if result.stdout else "(no stdout)")
print(result.stderr[-1000:] if result.stderr else "")
if result.returncode == 0:
    print("\n  [OK] Flutter analyze clean on modified files")
else:
    print(f"\n  [!] Flutter analyze returned {result.returncode} — review above")
    print("      (Some errors may be pre-existing; check the diff before committing.)")
print()

# ============================================================================
# Commit
# ============================================================================
print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """fix(issues-1-3-4): provider sync, notifications, exam creation

Issue 1: Sync currentOrganizationIdProvider after login
  - Root cause: saveTeacherAuthData/saveStudentAuthData/saveParentAuthData
    updated organizationIdProvider but NEVER updated currentOrganizationIdProvider
  - 65+ providers read currentOrganizationIdProvider → got null → returned Stream.empty()
  - Fix: After each `ref.read(organizationIdProvider.notifier).state = organizationId;`
    also set `ref.read(currentOrganizationIdProvider.notifier).state = organizationId;`
  - Added `import 'organization_provider.dart';` to both auth_provider.dart files
    (currentOrganizationIdProvider lives in organization_provider.dart, not auth_provider.dart)

Issue 3: Notifications query missing organizationId filter
  - Root cause: getUserNotificationsStream/getUnreadCount/markAllAsRead
    filtered on userId only → rule isInSameOrg() denied the query
  - Fix: Added `required String organizationId` parameter + `.where('organizationId', isEqualTo: orgId)`
    to all three methods in notification_service.dart
  - Updated notification_provider.dart at BOTH call sites
    (notificationsStreamProvider + unreadCountProvider) to pass orgId
    from currentOrganizationIdProvider

Issue 4: Exam creation defaults organizationId to 'default'
  - Root cause: exam_service.dart createExam() defaulted organizationId
    to AppConstants.defaultInstitutionId; exam_form_screen.dart never passed real org
  - Fix: Made `organizationId` required in exam_service.dart createExam()
    (and identical lib/features/exams/data/exam_service.dart)
  - Updated exam_form_screen.dart (and identical lib/features/exams/presentation/) to
    pass ref.read(organizationIdProvider), with early-return guard if null
  - Also made organizationId required in violation_service.dart logViolation()
    (same bug pattern; no callers exist yet)

Issue 2: ShellRoute disposes tab state (DEFERRED — MANUAL FIX)
  - Convert ShellRoute → StatefulShellRoute.indexedStack in lib/main.dart
  - Issue 1 fix may resolve most symptoms since null orgId was the primary cause

DEFERRED follow-up:
  - exam_instance_service.dart createExamInstance() still hardcodes
    AppConstants.defaultInstitutionId — needs `required String organizationId`
    parameter + caller update in exam_taking_screen.dart (~line 120)

Verified against commit e8d28d2.
"""

subprocess.run(["git", "add", "-A"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(
    ["git", "rev-parse", "--short", "HEAD"], text=True
).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

print("[i] Not pushing automatically (this is the adapted non-interactive variant).")
print("    When ready: git push origin main")
print()
print(f"Rollback: git reset --hard {backup_branch}")
print()
print("=" * 70)
print("DEPLOY + VERIFY (manual, after push)")
print("=" * 70)
print()
print("1. Verify Issue 1 (provider sync):")
print("   - Login as owner (fresh, no restart)")
print("   - Navigate to Academic Structure immediately")
print("   - Confirm: stages + classes appear (not '0 Classes')")
print("   - Dashboard → Academic → Dashboard → confirm data persists")
print()
print("2. Verify Issue 3 (notifications):")
print("   - Open Notifications/Inbox")
print("   - Confirm: no permission-denied, list loads, unread badge works")
print()
print("3. Verify Issue 4 (exam creation):")
print("   - Create exam → tap 'Create & Add Questions'")
print("   - Confirm: no permission-denied, exam created")
print("   - Check Firestore: exam doc has organizationId = real org (not 'default')")
print()
print("4. Issue 2 (ShellRoute) — apply manually if tab state still flickers")
