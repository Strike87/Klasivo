#!/usr/bin/env python3
"""
Phase 1B post-delete verification.

Scans lib/ and test/ for any remaining `import`/`export`/`part` reference
to any of the 63 deleted files. Any hit = a dangling reference that
would cause a "Target of URI doesn't exist" error in `dart analyze`.
"""
from pathlib import Path
import re

REPO = Path("/home/z/my-project")
DELETE_LIST = REPO / "scripts" / "phase1b-final-delete.txt"


def main():
    deleted = [line.strip() for line in DELETE_LIST.read_text().splitlines()
               if line.strip() and not line.startswith("#")]
    print(f"Files in delete list: {len(deleted)}")

    # Verify all are actually deleted from the worktree.
    not_deleted = [p for p in deleted if (REPO / p).exists()]
    print(f"Still present in worktree:   {len(not_deleted)}")
    for p in not_deleted:
        print(f"  STILL PRESENT: {p}")

    # Scan for any remaining import/export/part reference.
    pat = re.compile(r"""(?:import|export|part)\s+['"]([^'"]+)['"]""")
    deleted_set = set(deleted)
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
            for m in pat.finditer(text):
                ref = m.group(1)
                if ref.startswith("package:") or ref.startswith("dart:"):
                    continue
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

    if not dangling and not not_deleted:
        print("\n✅ POST-DELETE CHECKS PASS — zero dangling references.")
    else:
        print("\n❌ ISSUES FOUND — see above")


if __name__ == "__main__":
    main()
