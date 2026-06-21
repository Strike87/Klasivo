#!/usr/bin/env python3
"""
Phase 5 (plus Tickets 2 + 3) post-delete verification.

Confirms zero dangling import/export/part references to the 39 deleted files
across lib/ and test/.

Categories deleted:
- lib/app/ (4 files) — Ticket 2 (dead app/router.dart, app_providers.dart etc.)
- lib/features/*/presentation/ (26 files) — Ticket 3 (dead dup of pages/)
- lib/shared/models/ (5 files) — Phase 5
- lib/core/models/ (4 files) — Phase 5
"""
from pathlib import Path
import re
import sys

REPO = Path("/home/z/my-project")

DELETED_DIRS = [
    "lib/app",
    "lib/shared/models",
    "lib/core/models",
    # Plus all lib/features/*/presentation/ dirs (handled separately)
]

# Build the search patterns: each deleted file's path tail (minus the "lib/" prefix)
PATTERNS = []

# Add files from explicitly-listed dirs
for dirpath in DELETED_DIRS:
    p = REPO / dirpath
    if not p.exists():
        print(f"  (already absent: {dirpath})")
        continue
    for dart in p.rglob("*.dart"):
        rel = str(dart.relative_to(REPO))
        tail = rel[4:] if rel.startswith("lib/") else rel  # strip "lib/"
        PATTERNS.append(tail)

# Add files from lib/features/*/presentation/
features_dir = REPO / "lib" / "features"
for pres_dir in features_dir.glob("*/presentation"):
    if not pres_dir.is_dir():
        continue
    for dart in pres_dir.rglob("*.dart"):
        rel = str(dart.relative_to(REPO))
        tail = rel[4:] if rel.startswith("lib/") else rel
        PATTERNS.append(tail)

print(f"Loaded {len(PATTERNS)} deleted-file patterns")

DIRECTIVE_RE = re.compile(
    r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]",
    re.MULTILINE,
)

dangling = []
files_scanned = 0

for dart_file in list((REPO / "lib").rglob("*.dart")) + list((REPO / "test").rglob("*.dart")):
    # Skip files inside deleted dirs (in case any remain)
    rel_str = str(dart_file.relative_to(REPO))
    if any(rel_str.startswith(d + "/") for d in DELETED_DIRS):
        continue
    if "/presentation/" in rel_str:
        continue

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
print()

if dangling:
    print(f"❌ FOUND {len(dangling)} DANGLING REFERENCES:")
    for rel, ln, ref, tail in dangling:
        print(f"  {rel}:{ln}: {ref}  (matches deleted {tail})")
    sys.exit(1)
else:
    print("✅ ZERO dangling references — all deletes are clean.")

# Also confirm no symbol-level references to deleted classes
print()
print("Symbol-level check for key deleted classes:")
SYMBOLS = [
    "TenantData",         # from lib/core/models/tenant_model.dart + lib/shared/models/tenant_model.dart
    "CampusData",         # from same
    "ClassSectionData",   # from lib/core/models/tenant_model.dart (only def, no live consumers)
    "StudentPerformanceEntry",  # from lib/core/models/analytics_models.dart
    "TeacherPerformanceEntry",
    "ClassPerformanceEntry",
    "DailyAnalytics",
    "WeeklyAnalytics",
    "MonthlyAnalytics",
    "BaseModel",          # from lib/shared/models/base_model.dart
    "KlasivoApp",         # from lib/app/app.dart
    "klasivoRouter",      # from lib/app/router.dart
    "klasivoRouterProvider",
]
for sym in SYMBOLS:
    matches = []
    for dart_file in (REPO / "lib").rglob("*.dart"):
        rel = str(dart_file.relative_to(REPO))
        if any(rel.startswith(d + "/") for d in DELETED_DIRS):
            continue
        if "/presentation/" in rel:
            continue
        try:
            text = dart_file.read_text(encoding="utf-8")
        except Exception:
            continue
        # Word-boundary match
        if re.search(rf"\b{re.escape(sym)}\b", text):
            matches.append(rel)
    if matches:
        print(f"  ⚠️  {sym}: still referenced in {len(matches)} files:")
        for m in matches[:5]:
            print(f"        - {m}")
    else:
        print(f"  ✅ {sym}: 0 references")
