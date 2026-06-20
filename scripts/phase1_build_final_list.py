#!/usr/bin/env python3
"""
Phase 1 final delete list builder.

Combines:
  - 61 candidates from phase1-candidates.txt (per report's DELETE verdicts)
  - 4 orphan top-level feature barrels (necessary extension to prevent
    dangling-export errors after stub deletion)

Outputs:
  - phase1-final-delete.txt  — full list of files to git rm
  - phase1-loc-count.txt     — total LOC count for commit message
"""
from pathlib import Path

REPO = Path("/home/z/my-project")
CANDIDATES_FILE = REPO / "scripts" / "phase1-candidates.txt"
OUT_FINAL = REPO / "scripts" / "phase1-final-delete.txt"
OUT_LOC = REPO / "scripts" / "phase1-loc-count.txt"

# 4 orphan top-level feature barrels that re-export stubs we're deleting.
# Each has 0 importers (verified). Each re-exports 5 files: 4 of which are
# in our DELETE list (domain/data/application/providers), 1 of which
# (presentation/presentation.dart) is NOT being deleted per user's step 6.
# Leaving these 4 barrels in place would leave 16 dangling `export`
# statements → 16 "Target of URI doesn't exist" errors in `dart analyze`.
EXTENSION_BARRELS = [
    "lib/features/academic/academic.dart",
    "lib/features/analytics/analytics.dart",
    "lib/features/attendance/attendance.dart",
    "lib/features/messaging/messaging.dart",
]


def load_candidates():
    paths = []
    for raw in CANDIDATES_FILE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        paths.append(line)
    return paths


def main():
    candidates = load_candidates()
    final = candidates + EXTENSION_BARRELS

    # Verify all files exist and count LOC.
    total_loc = 0
    per_file_loc = []
    missing = []
    for rel in final:
        p = REPO / rel
        if not p.exists():
            missing.append(rel)
            continue
        loc = len(p.read_text(errors="ignore").splitlines())
        total_loc += loc
        per_file_loc.append((rel, loc))

    OUT_FINAL.write_text("\n".join(final) + "\n")
    OUT_LOC.write_text(
        f"Total files: {len(final)}\n"
        f"Total LOC:   {total_loc}\n"
        f"Missing:     {len(missing)}\n\n"
        + "\n".join(f"{loc:5d}  {rel}" for rel, loc in per_file_loc)
        + "\n"
    )

    print(f"Final delete list: {len(final)} files, {total_loc} LOC")
    if missing:
        print(f"MISSING ({len(missing)}):")
        for m in missing:
            print(f"  {m}")


if __name__ == "__main__":
    main()
