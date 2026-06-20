#!/usr/bin/env python3
"""
Extra safety checks for Phase 1 deletes:
  1. `part '<rel-without-ext>.dart';` directives pointing at any candidate.
  2. `export '<rel-without-ext>';` statements in any lib/test file pointing
     at any candidate (we want to delete barrels themselves, but we need
     to confirm nothing OUTSIDE the delete set exports them).
  3. Spot-check class-name references for the few substantive files
     (so we catch symbol-level use the import graph might miss).
"""

from pathlib import Path
import re
import sys

REPO = Path("/home/z/my-project")
CANDIDATES_FILE = REPO / "scripts" / "phase1-candidates.txt"
SAFE_FILE = REPO / "scripts" / "phase1-safe.txt"


def load_paths(p: Path) -> list[str]:
    out = []
    for raw in p.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        out.append(line)
    return out


def main():
    candidates = load_paths(CANDIDATES_FILE)
    safe = load_paths(SAFE_FILE)
    assert set(safe) == set(candidates), "safe set != candidate set"

    # Build patterns: for each candidate path, look for both `part` and
    # `export` references by basename-without-extension.
    candidate_set = set(candidates)

    part_hits = []
    export_hits = []
    for root in ["lib", "test"]:
        root_path = REPO / root
        if not root_path.exists():
            continue
        for dart_file in root_path.rglob("*.dart"):
            rel_self = dart_file.relative_to(REPO).as_posix()
            try:
                text = dart_file.read_text(errors="ignore")
            except Exception:
                continue
            for m in re.finditer(r"""(?:part|export)\s+['"]([^'"]+)['"]""", text):
                ref = m.group(1)
                # Normalize: if it's a relative path, resolve against the
                # importer's directory.
                if ref.startswith("package:") or ref.startswith("dart:"):
                    continue
                importer_dir = dart_file.parent
                target = (importer_dir / ref).resolve()
                try:
                    rel_target = target.relative_to(REPO).as_posix()
                except ValueError:
                    continue
                if rel_target in candidate_set and rel_target != rel_self:
                    if m.group(0).startswith("part"):
                        part_hits.append((rel_self, rel_target))
                    else:
                        export_hits.append((rel_self, rel_target))

    print(f"part-directive hits pointing at candidates: {len(part_hits)}")
    for h in part_hits:
        print(f"  {h[0]}  -> part '{h[1]}'")
    print(f"export-statement hits pointing at candidates: {len(export_hits)}")
    for h in export_hits:
        print(f"  {h[0]}  -> export '{h[1]}'")

    # Spot-check: for the substantive (non-stub) files, list the unique
    # class names defined in each, then grep lib/test for any reference
    # to those names outside the candidate set itself.
    print("\n--- Spot-check: symbol-level references for substantive files ---")
    substantive = [
        "lib/features/organizations/domain/organization_model.dart",
        "lib/features/organizations/providers/organization_providers.dart",
        "lib/features/assignments/data/assignment_repository.dart",
        "lib/features/assignments/domain/assignment_model.dart",
        "lib/features/assignments/providers/assignment_providers.dart",
        "lib/features/auth/data/auth_repository.dart",
        "lib/features/auth/domain/auth_model.dart",
        "lib/features/auth/domain/auth_state.dart",
        "lib/features/exams/data/exam_repository.dart",
        "lib/features/exams/domain/exam_model.dart",
        "lib/features/classes/domain/class_model.dart",
        "lib/features/students/domain/student_model.dart",
        "lib/features/submissions/data/submission_repository.dart",
        "lib/features/submissions/domain/submission_model.dart",
        "lib/features/submissions/providers/submission_providers.dart",
    ]
    candidate_paths = set(candidates)
    issues = 0
    for path in substantive:
        abs_path = REPO / path
        if not abs_path.exists():
            continue
        text = abs_path.read_text(errors="ignore")
        # Find class/enum/mixin/typedef declarations.
        syms = set()
        for m in re.finditer(
            r"""^\s*(?:abstract\s+)?(?:class|enum|mixin|typedef)\s+(\w+)""",
            text, re.MULTILINE,
        ):
            syms.add(m.group(1))
        # Also catch top-level function names.
        for m in re.finditer(
            r"""^\s*(?:final\s+)?(\w+)\s+\w+\s*\([^)]*\)\s*(?:async\s*)?\{""",
            text, re.MULTILINE,
        ):
            syms.add(m.group(1))
        if not syms:
            continue
        # Search lib/ and test/ for any reference to these symbols.
        for sym in syms:
            # Use word-boundary regex.
            pat = re.compile(r"\b" + re.escape(sym) + r"\b")
            for root in ["lib", "test"]:
                root_path = REPO / root
                if not root_path.exists():
                    continue
                for dart_file in root_path.rglob("*.dart"):
                    rel_self = dart_file.relative_to(REPO).as_posix()
                    # Skip the candidate file itself.
                    if rel_self in candidate_paths:
                        continue
                    try:
                        other_text = dart_file.read_text(errors="ignore")
                    except Exception:
                        continue
                    if pat.search(other_text):
                        print(
                            f"  SYMBOL '{sym}' from {path} ALSO appears in "
                            f"{rel_self}"
                        )
                        issues += 1
    print(f"\nTotal symbol-level cross-references found: {issues}")
    if issues == 0 and not part_hits and not export_hits:
        print("ALL CLEAR — no part, export, or symbol-level cross-refs.")


if __name__ == "__main__":
    main()
