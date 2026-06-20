#!/usr/bin/env python3
"""
Phase 2 post-delete verification.

Confirms zero dangling import/export/part references to the 9 deleted files
across lib/ and test/.
"""
from pathlib import Path
import re
import sys

REPO = Path("/home/z/my-project")

DELETED_FILES = [
    "lib/features/auth/providers/auth_providers.dart",
    "lib/features/auth/data/auth_repository.dart",
    "lib/features/auth/domain/user_model.dart",
    "lib/features/auth/providers/auth_provider.dart",
    "lib/features/organizations/data/organization_repository.dart",
    "lib/features/organizations/domain/organization_model.dart",
    "lib/features/classes/providers/class_provider.dart",
    "lib/features/exams/providers/exam_provider.dart",
    "lib/features/students/providers/student_provider.dart",
]

# Build search patterns for each deleted file. We search for the path tail
# (e.g., "features/auth/providers/auth_providers.dart") in import/export/part
# directives, which is the canonical form Dart uses.
PATTERNS = []
for path in DELETED_FILES:
    # Strip leading "lib/"
    tail = path[4:] if path.startswith("lib/") else path
    PATTERNS.append(tail)

# Regex matches: import '...<tail>';  export '...<tail>';  part '...<tail>';
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
            # Match either "package:klasivo/<tail>" or relative paths ending in <tail>
            if ref.endswith(tail) or ref.endswith(tail.replace("lib/", "")):
                rel = dart_file.relative_to(REPO)
                line_no = text[: m.start()].count("\n") + 1
                dangling.append((str(rel), line_no, ref, tail))

print(f"Scanned {files_scanned} Dart files under lib/ and test/")
print(f"Searched for {len(PATTERNS)} deleted-path patterns")
print()

if dangling:
    print(f"❌ FOUND {len(dangling)} DANGLING REFERENCES:")
    for rel, ln, ref, tail in dangling:
        print(f"  {rel}:{ln}: {ref}  (matches deleted {tail})")
    sys.exit(1)
else:
    print("✅ ZERO dangling references — Phase 2 deletes are clean.")

# Also confirm the 2 kept files still exist
print()
print("Confirming 2 kept files present:")
for kept in [
    "lib/features/organizations/domain/campus_model.dart",
    "lib/features/organizations/providers/campus_provider.dart",
]:
    p = REPO / kept
    print(f"  {'✅' if p.exists() else '❌'} {kept}  ({p.stat().st_size if p.exists() else 0} bytes)")
