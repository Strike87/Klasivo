#!/usr/bin/env python3
"""
Phase 5+ (Items 1-4) post-change verification.

Confirms:
  1. Zero dangling import/export/part references to:
     - lib/infrastructure/ (21 deleted files)
     - lib/features/auth/providers/auth_notifier_provider.dart (moved)
     - lib/features/exams/providers/exam_notifier_provider.dart (moved)
     - lib/features/exams/domain/exam_{instance,stats,template}_model.dart (moved)
     - lib/features/staff_approval/domain/{staff_application_model,staff_approval_status,staff_type}.dart (moved)
     - lib/features/staff_approval/domain/domain.dart (deleted - broken barrel)
     - lib/features/staff_approval/staff_approval.dart (deleted - broken barrel)
  2. No symbol-level references to deleted classes (AuthUser, ExamDocument,
     FirestoreAnalyticsRepository, etc.) in live code.
  3. The 3 modified files compile-check: question_bank_service.dart,
     question_bank_screen.dart, exam_service.dart.
"""
from pathlib import Path
import re
import sys

REPO = Path("/home/z/my-project")

# All paths whose references should now be ZERO in live code
DELETED_PATHS = [
    # lib/infrastructure/ (21 files)
    "lib/infrastructure/firebase/firebase.dart",
    "lib/infrastructure/firebase/firebase_config.dart",
    "lib/infrastructure/firebase/firebase_options.dart",
    "lib/infrastructure/firebase/firebase_repository.dart",
    "lib/infrastructure/notifications/fcm_service.dart",
    "lib/infrastructure/notifications/notification_service.dart",
    "lib/infrastructure/notifications/notifications.dart",
    "lib/infrastructure/repositories/analytics_repository.dart",
    "lib/infrastructure/repositories/assignment_repository.dart",
    "lib/infrastructure/repositories/attendance_repository.dart",
    "lib/infrastructure/repositories/auth_repository.dart",
    "lib/infrastructure/repositories/exam_repository.dart",
    "lib/infrastructure/repositories/messaging_repository.dart",
    "lib/infrastructure/repositories/repositories.dart",
    "lib/infrastructure/sync_engine/conflict_resolver.dart",
    "lib/infrastructure/sync_engine/offline_exam_service.dart",
    "lib/infrastructure/sync_engine/offline_manager.dart",
    "lib/infrastructure/sync_engine/sync_engine.dart",
    "lib/infrastructure/sync_engine/sync_engine_service.dart",
    "lib/infrastructure/sync_engine/sync_orchestrator.dart",
    "lib/infrastructure/sync_engine/sync_queue_service.dart",
    # moved files (original lib/ paths)
    "lib/features/auth/providers/auth_notifier_provider.dart",
    "lib/features/exams/providers/exam_notifier_provider.dart",
    "lib/features/exams/domain/exam_instance_model.dart",
    "lib/features/exams/domain/exam_stats_model.dart",
    "lib/features/exams/domain/exam_template_model.dart",
    "lib/features/staff_approval/domain/staff_application_model.dart",
    "lib/features/staff_approval/domain/staff_approval_status.dart",
    "lib/features/staff_approval/domain/staff_type.dart",
    "lib/features/staff_approval/domain/domain.dart",
    "lib/features/staff_approval/staff_approval.dart",
]

# Patterns: each path tail (minus "lib/" prefix)
PATTERNS = []
for path in DELETED_PATHS:
    tail = path[4:] if path.startswith("lib/") else path
    PATTERNS.append(tail)

DIRECTIVE_RE = re.compile(
    r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]",
    re.MULTILINE,
)

dangling = []
files_scanned = 0

for dart_file in list((REPO / "lib").rglob("*.dart")) + list((REPO / "test").rglob("*.dart")):
    files_scanned += 1
    try:
        text = dart_file.read_text(encoding="utf-8")
    except Exception as e:
        print(f"  ! could not read {dart_file}: {e}")
        continue
    for m in DIRECTIVE_RE.finditer(text):
        ref = m.group(1)
        for tail in PATTERNS:
            if ref.endswith(tail) or ref.endswith(tail.replace("lib/", "")):
                rel = dart_file.relative_to(REPO)
                line_no = text[: m.start()].count("\n") + 1
                dangling.append((str(rel), line_no, ref, tail))

print(f"Check 1: Import/export/part references")
print(f"  Scanned {files_scanned} Dart files under lib/ and test/")
print(f"  Searched {len(PATTERNS)} deleted/moved path patterns")
print()

if dangling:
    print(f"  ❌ FOUND {len(dangling)} DANGLING REFERENCES:")
    for rel, ln, ref, tail in dangling:
        print(f"    {rel}:{ln}: {ref}  (matches {tail})")
    sys.exit(1)
else:
    print(f"  ✅ ZERO dangling references.")

# Symbol-level check
print()
print(f"Check 2: Symbol-level references to deleted classes")
SYMBOLS = [
    "AuthUser",                        # lib/infrastructure/repositories/auth_repository.dart
    "FirebaseAuthRepository",
    "ExamDocument",                    # lib/infrastructure/repositories/exam_repository.dart
    "QuestionDocument",
    "FirestoreExamRepository",
    "AttendanceRecord",                # lib/infrastructure/repositories/attendance_repository.dart
    "AttendanceSession",
    "FirestoreAttendanceRepository",
    "FirestoreAnalyticsRepository",    # lib/infrastructure/repositories/analytics_repository.dart
    "AssignmentSubmissionData",        # lib/infrastructure/repositories/assignment_repository.dart
    "FirestoreAssignmentRepository",
    "FirestoreMessagingRepository",    # lib/infrastructure/repositories/messaging_repository.dart
    "FirebaseDocument",                # lib/infrastructure/firebase/firebase_repository.dart
    "RepositoryResult",
    "FirebaseRepository",
    "SyncConflict",                    # lib/infrastructure/sync_engine/conflict_resolver.dart
    "ConflictResolution",
    "ConflictResolver",
    "SyncProgress",                    # lib/infrastructure/sync_engine/sync_engine_service.dart
    "SyncEngine",
    "FcmService",                      # lib/infrastructure/notifications/fcm_service.dart
]
issues = 0
for sym in SYMBOLS:
    matches = []
    for dart_file in (REPO / "lib").rglob("*.dart"):
        rel = str(dart_file.relative_to(REPO))
        # Skip the docs/architecture-reference/ dir (those are intentional archives)
        if rel.startswith("docs/"):
            continue
        try:
            text = dart_file.read_text(encoding="utf-8")
        except Exception:
            continue
        if re.search(rf"\b{re.escape(sym)}\b", text):
            matches.append(rel)
    if matches:
        print(f"  ⚠️  {sym}: still referenced in {len(matches)} live files:")
        for m in matches[:5]:
            print(f"        - {m}")
        issues += 1
    else:
        print(f"  ✅ {sym}: 0 live references")

print()
print(f"Check 3: Modified files sanity")
MODIFIED = [
    "lib/core/services/question_bank_service.dart",
    "lib/core/services/exam_service.dart",
    "lib/features/question_bank/pages/question_bank_screen.dart",
]
for rel in MODIFIED:
    p = REPO / rel
    if not p.exists():
        print(f"  ❌ MISSING: {rel}")
        issues += 1
        continue
    text = p.read_text(encoding="utf-8")
    # Verify the security fix landed
    if rel.endswith("question_bank_service.dart"):
        # The PARAMETER must be `required String organizationId` (no default).
        # `defaultInstitutionId` may still appear in explanatory comments only.
        if "required String organizationId" in text:
            # Verify no parameter still has the bad default
            bad_param = re.search(r"String\s+organizationId\s*=\s*AppConstants\.defaultInstitutionId", text)
            if bad_param:
                print(f"  ❌ {rel}: parameter still has defaultInstitutionId default")
                issues += 1
            else:
                print(f"  ✅ {rel}: security fix applied (organizationId required, no default)")
        else:
            print(f"  ❌ {rel}: security fix NOT applied correctly")
            issues += 1
    elif rel.endswith("exam_service.dart"):
        if "createExamInstance" not in text or "NOTE (Sprint 1, Phase 5+ cleanup)" in text:
            # The method body should be gone; only the note should remain
            if "Future<String> createExamInstance" not in text:
                print(f"  ✅ {rel}: createExamInstance dead method removed")
            else:
                print(f"  ❌ {rel}: createExamInstance still present")
                issues += 1
        else:
            print(f"  ❌ {rel}: unexpected state")
            issues += 1
    elif rel.endswith("question_bank_screen.dart"):
        if "currentOrgIdProvider" in text and "organizationId: organizationId" in text:
            print(f"  ✅ {rel}: caller updated to pass organizationId")
        else:
            print(f"  ❌ {rel}: caller NOT updated")
            issues += 1

print()
print(f"Check 4: docs/architecture-reference/ structure")
expected_files = [
    "docs/architecture-reference/README.md",
    "docs/architecture-reference/auth/providers/auth_notifier_provider.dart",
    "docs/architecture-reference/exams/providers/exam_notifier_provider.dart",
    "docs/architecture-reference/exams/domain/exam_instance_model.dart",
    "docs/architecture-reference/exams/domain/exam_stats_model.dart",
    "docs/architecture-reference/exams/domain/exam_template_model.dart",
    "docs/architecture-reference/staff_approval/domain/staff_application_model.dart",
    "docs/architecture-reference/staff_approval/domain/staff_approval_status.dart",
    "docs/architecture-reference/staff_approval/domain/staff_type.dart",
]
for rel in expected_files:
    p = REPO / rel
    if p.exists():
        print(f"  ✅ {rel}")
    else:
        print(f"  ❌ MISSING: {rel}")
        issues += 1

print()
if issues == 0:
    print("✅ ALL CHECKS PASSED — ready to commit.")
else:
    print(f"❌ {issues} ISSUE(S) FOUND — fix before commit.")
    sys.exit(1)
