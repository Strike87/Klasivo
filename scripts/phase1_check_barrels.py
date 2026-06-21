#!/usr/bin/env python3
"""
Investigate the top-level feature barrel files that re-export the
stubs we want to delete. If a barrel is itself imported anywhere in
lib/ or test/, deleting the stub it exports will leave a dangling
export → potentially a compile error.

Also check: are these top-level barrels themselves in the candidate
delete list? They probably should be.
"""
from pathlib import Path
import re

REPO = Path("/home/z/my-project")

# Top-level feature barrels that re-export candidate stubs.
BARRELS = [
    "lib/features/attendance/attendance.dart",
    "lib/features/academic/academic.dart",
    "lib/features/analytics/analytics.dart",
    "lib/features/messaging/messaging.dart",
    # These domain.dart files are already candidates for deletion
    # (so their exports will vanish with them — no separate concern):
    # "lib/features/students/domain/domain.dart",
    # "lib/features/submissions/domain/domain.dart",
    # "lib/features/auth/domain/domain.dart",
    # "lib/features/exams/domain/domain.dart",
    # "lib/features/classes/domain/domain.dart",
]

for barrel in BARRELS:
    p = REPO / barrel
    print(f"\n=== {barrel} ===")
    if not p.exists():
        print("  MISSING")
        continue
    print(f"  size: {p.stat().st_size} bytes, {len(p.read_text().splitlines())} lines")
    print(f"  contents:")
    for line in p.read_text().splitlines():
        print(f"    | {line}")
    # Check imports of this barrel.
    no_ext = re.sub(r"\.dart$", "", barrel)
    escaped = re.escape(no_ext)
    pat = re.compile(r"""import\s+['"][^'"]*""" + escaped + r"""['"]""")
    hits = []
    for root in ["lib", "test"]:
        root_path = REPO / root
        if not root_path.exists():
            continue
        for dart_file in root_path.rglob("*.dart"):
            rel_self = dart_file.relative_to(REPO).as_posix()
            if rel_self == barrel:
                continue
            try:
                text = dart_file.read_text(errors="ignore")
            except Exception:
                continue
            if pat.search(text):
                hits.append(rel_self)
    print(f"  imported by {len(hits)} file(s):")
    for h in hits:
        print(f"    - {h}")
