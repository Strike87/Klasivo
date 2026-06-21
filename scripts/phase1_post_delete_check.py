#!/usr/bin/env python3
"""
Post-delete verification for Phase 1.

For each deleted file, scan lib/ and test/ for any remaining `import`
or `export` statement that still references it. Any hit = a dangling
reference that would cause a `Target of URI doesn't exist` error in
`dart analyze`.
"""
from pathlib import Path
import re

REPO = Path("/home/z/my-project")
DELETE_LIST = REPO / "scripts" / "phase1-final-delete.txt"


def main():
    deleted = [line.strip() for line in DELETE_LIST.read_text().splitlines()
               if line.strip() and not line.startswith("#")]

    # Verify all are actually deleted.
    not_deleted = [p for p in deleted if (REPO / p).exists()]
    print(f"Files in delete list:        {len(deleted)}")
    print(f"Still present in worktree:   {len(not_deleted)}")
    for p in not_deleted:
        print(f"  STILL PRESENT: {p}")

    # For each, scan for any remaining import/export reference.
    print("\nScanning lib/ and test/ for dangling import/export references...")
    pat_import_export = re.compile(
        r"""(?:import|export|part)\s+['"]([^'"]+)['"]"""
    )
    deleted_set = set(deleted)
    # Build basename index for fast lookup.
    by_basename = {}
    for p in deleted:
        b = Path(p).name
        by_basename.setdefault(b, []).append(p)

    dangling = []
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
            for m in pat_import_export.finditer(text):
                ref = m.group(1)
                if ref.startswith("package:") or ref.startswith("dart:"):
                    continue
                # Resolve relative to importer dir.
                target = (dart_file.parent / ref).resolve()
                try:
                    rel_target = target.relative_to(REPO).as_posix()
                except ValueError:
                    continue
                if rel_target in deleted_set:
                    dangling.append((rel_self, rel_target, m.group(0)))

    print(f"\nDangling references found: {len(dangling)}")
    for importer, target, stmt in dangling:
        print(f"  {importer}")
        print(f"    -> {stmt}  (target {target} was deleted)")

    # Bracket-balance sanity check on every remaining .dart file in lib/.
    # (No file should be left in a broken-bracket state after the deletes.)
    print("\nBracket-balance check on remaining lib/**/*.dart files...")
    bracket_issues = []
    for dart_file in (REPO / "lib").rglob("*.dart"):
        try:
            text = dart_file.read_text(errors="ignore")
        except Exception:
            continue
        # Strip strings (raw + regular + multiline) and comments.
        # Simplification: just count brackets in code that remains
        # after stripping // line comments, /* */ block comments, and
        # 'string' / "string" / """triple""" literals.
        # This is approximate; the goal is to catch gross imbalance.
        stripped = text
        # Strip /* */ block comments (multiline-aware).
        stripped = re.sub(r"/\*[\s\S]*?\*/", "", stripped)
        # Strip // line comments.
        stripped = re.sub(r"//[^\n]*", "", stripped)
        # Strip triple-quoted strings first (greedy across newlines).
        stripped = re.sub(r'"""[\s\S]*?"""', '""', stripped)
        stripped = re.sub(r"'''[\\s\\S]*?'''", "''", stripped)
        # Strip single-line strings.
        stripped = re.sub(r'"(?:\\.|[^"\\])*"', '""', stripped)
        stripped = re.sub(r"'(?:\\.|[^'\\])*'", "''", stripped)
        # Count brackets.
        for opener, closer in [("(", ")"), ("{", "}"), ("[", "]")]:
            delta = stripped.count(opener) - stripped.count(closer)
            if delta != 0:
                rel = dart_file.relative_to(REPO).as_posix()
                bracket_issues.append((rel, opener, closer, delta))
                break

    print(f"Files with bracket imbalance: {len(bracket_issues)}")
    for rel, opener, closer, delta in bracket_issues:
        print(f"  {rel}: {opener}{closer} delta={delta}")

    if not dangling and not bracket_issues and not not_deleted:
        print("\n✅ ALL POST-DELETE CHECKS PASS")
    else:
        print("\n❌ ISSUES FOUND — see above")


if __name__ == "__main__":
    main()
