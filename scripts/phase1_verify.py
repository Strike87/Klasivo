#!/usr/bin/env python3
"""
Phase 1 verification script.

For each candidate file in scripts/phase1-candidates.txt:
  1. Verify the file still exists (someone may have already deleted it).
  2. Search lib/ for any `import '<rel-path-without-extension>'` references.
  3. Also search test/ for the same.

Outputs:
  - safe-to-delete.txt  — files with zero import references
  - has-references.txt  — files with new references (must be skipped)
  - missing.txt         — files that don't exist anymore
"""

from pathlib import Path
import re
import subprocess
import sys

REPO = Path("/home/z/my-project")
CANDIDATES_FILE = REPO / "scripts" / "phase1-candidates.txt"
OUT_SAFE = REPO / "scripts" / "phase1-safe.txt"
OUT_REFS = REPO / "scripts" / "phase1-has-refs.txt"
OUT_MISSING = REPO / "scripts" / "phase1-missing.txt"


def load_candidates():
    paths = []
    for raw in CANDIDATES_FILE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        paths.append(line)
    return paths


def import_pattern(rel_path: str) -> str:
    """
    Build the regex pattern to match an import of `rel_path`.
    Dart import paths omit the .dart extension when referenced from
    elsewhere in the package, so we strip the extension and anchor on
    the path.
    """
    no_ext = re.sub(r"\.dart$", "", rel_path)
    # Escape regex metachars in the path.
    escaped = re.escape(no_ext)
    # Match `import '<...>/<no_ext>';` OR `import "<...>/<no_ext>";`.
    # Allow any prefix (the importer may use a relative path with
    # varying `../` depth, or a package: import).
    return re.compile(r"""import\s+['"][^'"]*""" + escaped + r"""['"]""")


def search_imports(rel_path: str) -> list[str]:
    """Return list of files (under lib/ and test/) that import this path."""
    pat = import_pattern(rel_path)
    hits = []
    for root in ["lib", "test"]:
        root_path = REPO / root
        if not root_path.exists():
            continue
        for dart_file in root_path.rglob("*.dart"):
            try:
                text = dart_file.read_text(errors="ignore")
            except Exception:
                continue
            if pat.search(text):
                # Don't count the file itself.
                if dart_file.relative_to(REPO).as_posix() == rel_path:
                    continue
                hits.append(dart_file.relative_to(REPO).as_posix())
    return hits


def main():
    candidates = load_candidates()
    safe = []
    refs = []
    missing = []

    for rel_path in candidates:
        abs_path = REPO / rel_path
        if not abs_path.exists():
            missing.append(rel_path)
            continue
        hits = search_imports(rel_path)
        if hits:
            refs.append((rel_path, hits))
        else:
            safe.append(rel_path)

    OUT_SAFE.write_text("\n".join(safe) + "\n")
    OUT_REFS.write_text(
        "\n".join(f"{p}\n  imported by: {', '.join(h)}" for p, h in refs) + "\n"
        if refs else ""
    )
    OUT_MISSING.write_text("\n".join(missing) + "\n" if missing else "")

    print(f"Total candidates: {len(candidates)}")
    print(f"Safe to delete:   {len(safe)}")
    print(f"Has references:   {len(refs)}")
    print(f"Missing:          {len(missing)}")
    if refs:
        print("\n--- Files with references (SKIP) ---")
        for p, h in refs:
            print(f"  {p}")
            for hh in h:
                print(f"      imported by: {hh}")
    if missing:
        print("\n--- Missing files ---")
        for p in missing:
            print(f"  {p}")


if __name__ == "__main__":
    main()
