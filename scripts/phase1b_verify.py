#!/usr/bin/env python3
"""
Phase 1B pre-delete verification.

Same checks as phase1_verify.py + phase1_verify_extra.py, but operating
on the 63-file list (Phase 1A's 65 minus the 2 deferred files:
  - lib/features/auth/data/auth_repository.dart
  - lib/features/organizations/domain/organization_model.dart
)

Additional check specific to Path B:
  - The 2 deferred files are now KEPT. Do they import anything in the
    63-file delete set? If so, deleting the 63 will create new dangling
    references in the 2 deferred files.
"""
from pathlib import Path
import re

REPO = Path("/home/z/my-project")
LIST_FILE = REPO / "scripts" / "phase1b-final-delete.txt"

DEFERRED = [
    "lib/features/auth/data/auth_repository.dart",
    "lib/features/organizations/domain/organization_model.dart",
]


def load_list():
    paths = []
    for raw in LIST_FILE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        paths.append(line)
    return paths


def import_pattern(rel_path: str) -> re.Pattern:
    no_ext = re.sub(r"\.dart$", "", rel_path)
    escaped = re.escape(no_ext)
    return re.compile(r"""import\s+['"][^'"]*""" + escaped + r"""['"]""")


def search_imports(rel_path: str, exclude_self: bool = True) -> list[str]:
    pat = import_pattern(rel_path)
    hits = []
    for root in ["lib", "test"]:
        root_path = REPO / root
        if not root_path.exists():
            continue
        for dart_file in root_path.rglob("*.dart"):
            rel_self = dart_file.relative_to(REPO).as_posix()
            if exclude_self and rel_self == rel_path:
                continue
            try:
                text = dart_file.read_text(errors="ignore")
            except Exception:
                continue
            if pat.search(text):
                hits.append(rel_self)
    return hits


def main():
    delete_list = load_list()
    print(f"Files in delete list: {len(delete_list)}")
    assert len(delete_list) == 63, f"Expected 63, got {len(delete_list)}"

    # Check 1: each file in delete_list must exist and have 0 external
    # `import` references.
    print("\n=== Check 1: external `import` references to each candidate ===")
    safe_count = 0
    refs_count = 0
    for rel in delete_list:
        if not (REPO / rel).exists():
            print(f"  MISSING: {rel}")
            continue
        hits = search_imports(rel)
        if hits:
            refs_count += 1
            print(f"  HAS REFS: {rel}")
            for h in hits:
                print(f"      imported by: {h}")
        else:
            safe_count += 1
    print(f"\n  safe={safe_count}, with-refs={refs_count}")

    # Check 2: do the 2 DEFERRED (kept) files import anything in the
    # delete list?
    print("\n=== Check 2: deferred files import any of the 63? ===")
    delete_set = set(delete_list)
    cascading = []
    for d in DEFERRED:
        p = REPO / d
        if not p.exists():
            print(f"  DEFERRED file MISSING: {d}")
            continue
        text = p.read_text(errors="ignore")
        for m in re.finditer(r"""(?:import|export|part)\s+['"]([^'"]+)['"]""", text):
            ref = m.group(1)
            if ref.startswith("package:") or ref.startswith("dart:"):
                continue
            target = (p.parent / ref).resolve()
            try:
                rel_target = target.relative_to(REPO).as_posix()
            except ValueError:
                continue
            if rel_target in delete_set:
                cascading.append((d, rel_target, m.group(0)))
    if cascading:
        print(f"  ⚠️  CASCADING dangling refs found: {len(cascading)}")
        for d, t, stmt in cascading:
            print(f"    {d}")
            print(f"      -> {stmt}  (target {t} is in delete list)")
    else:
        print("  ✅ No cascading refs from deferred files.")

    # Check 3: do any files in delete list import each other in a way
    # that would leave a dangling ref in a kept file? (The post-delete
    # check covers this; just flagging it here for visibility.)
    print("\n=== Check 3: inter-candidate imports (informational) ===")
    inter = []
    for rel in delete_list:
        p = REPO / rel
        if not p.exists():
            continue
        text = p.read_text(errors="ignore")
        for m in re.finditer(r"""(?:import|export|part)\s+['"]([^'"]+)['"]""", text):
            ref = m.group(1)
            if ref.startswith("package:") or ref.startswith("dart:"):
                continue
            target = (p.parent / ref).resolve()
            try:
                rel_target = target.relative_to(REPO).as_posix()
            except ValueError:
                continue
            if rel_target in delete_set and rel_target != rel:
                inter.append((rel, rel_target, m.group(0)))
    if inter:
        print(f"  {len(inter)} inter-candidate imports (all will be deleted together — OK):")
        for src, tgt, stmt in inter:
            print(f"    {src} -> {tgt}")
    else:
        print("  No inter-candidate imports.")

    # Check 4: `export` and `part` references to any candidate from
    # OUTSIDE the delete list (this is what caught the 4 orphan barrels
    # in Phase 1A).
    print("\n=== Check 4: external `export`/`part` references to candidates ===")
    pat_import_export = re.compile(
        r"""(?:import|export|part)\s+['"]([^'"]+)['"]"""
    )
    external = []
    for root in ["lib", "test"]:
        root_path = REPO / root
        if not root_path.exists():
            continue
        for dart_file in root_path.rglob("*.dart"):
            rel_self = dart_file.relative_to(REPO).as_posix()
            if rel_self in delete_set:
                continue
            try:
                text = dart_file.read_text(errors="ignore")
            except Exception:
                continue
            for m in pat_import_export.finditer(text):
                ref = m.group(1)
                if ref.startswith("package:") or ref.startswith("dart:"):
                    continue
                target = (dart_file.parent / ref).resolve()
                try:
                    rel_target = target.relative_to(REPO).as_posix()
                except ValueError:
                    continue
                if rel_target in delete_set:
                    external.append((rel_self, rel_target, m.group(0)))
    if external:
        print(f"  ⚠️  EXTERNAL references to candidates: {len(external)}")
        for src, tgt, stmt in external:
            print(f"    {src}")
            print(f"      -> {stmt}  (target {tgt} is in delete list)")
    else:
        print("  ✅ No external `export`/`part` references to candidates.")

    # Tally
    all_clear = (
        refs_count == 0 and
        not cascading and
        not external
    )
    print("\n=== FINAL ===")
    if all_clear:
        print("✅ ALL CHECKS PASS — safe to git rm all 63 files.")
    else:
        print("❌ ISSUES FOUND — see above.")


if __name__ == "__main__":
    main()
