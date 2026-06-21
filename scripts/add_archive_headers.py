#!/usr/bin/env python3
"""Prepend ARCHITECTURE-REFERENCE warning headers to the 6 smaller moved files."""
from pathlib import Path

BASE = Path("/home/z/my-project/docs/architecture-reference")

HEADER = """// ═══════════════════════════════════════════════════════════════════════════════
// ⚠️  ARCHITECTURE REFERENCE — NOT COMPILED, NOT WIRED INTO THE APP  ⚠️
// ─────────────────────────────────────────────────────────────────────────────
// This file was MOVED here from lib/features/{src}/ as part of the Sprint 1
// scaffold cleanup (Phase 5+). It is preserved as a DESIGN REFERENCE for a
// future typed-model migration, but it is NOT included in the Flutter build
// (this directory is outside `lib/`).
//
// Before relying on this as the design source for a migration, verify field
// shapes match what the live service actually writes to Firestore. See
// download/scaffold-investigation-report.md for full context.
// ═══════════════════════════════════════════════════════════════════════════════

"""

SOURCES = {
    "exams/domain/exam_instance_model.dart": "exams/domain",
    "exams/domain/exam_stats_model.dart": "exams/domain",
    "exams/domain/exam_template_model.dart": "exams/domain",
    "staff_approval/domain/staff_application_model.dart": "staff_approval/domain",
    "staff_approval/domain/staff_approval_status.dart": "staff_approval/domain",
    "staff_approval/domain/staff_type.dart": "staff_approval/domain",
}

for rel, src in SOURCES.items():
    p = BASE / rel
    text = p.read_text(encoding="utf-8")
    # Skip if already has the warning header
    if "ARCHITECTURE REFERENCE" in text[:500]:
        print(f"  (skip — already has header) {rel}")
        continue
    header = HEADER.replace("{src}", src)
    p.write_text(header + text, encoding="utf-8")
    print(f"  ✅ prepended header to {rel}")
