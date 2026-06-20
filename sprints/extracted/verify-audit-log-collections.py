#!/usr/bin/env python3
# ============================================================================
# Klasivo — Audit Log Collection Name Verification
# ============================================================================
# Investigates whether auditLogCollection ('audit_log') and
# auditLogsCollection ('audit_logs') are both used, and whether
# any code path writes to one and reads from the other (silent data loss).
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python verify-audit-log-collections.py
# ============================================================================

import os
import sys
import re
from pathlib import Path
from collections import defaultdict

if not Path("lib").exists():
    print("ERROR: Run from Klasivo repo root.")
    sys.exit(1)

print("=" * 70)
print("Audit Log Collection Name Verification")
print("=" * 70)
print()

# ============================================================================
# Step 1: Find all references to both collection names
# ============================================================================
print("--- Step 1: Find all references to audit_log vs audit_logs ---")
print()

references = {
    'audit_log (singular)': [],
    'audit_logs (plural)': [],
    'auditLogCollection': [],
    'auditLogsCollection': [],
}

# Search all Dart and TypeScript files
for file_path in list(Path("lib").rglob("*.dart")) + list(Path("functions").rglob("*.ts")):
    if "node_modules" in str(file_path):
        continue
    try:
        content = file_path.read_text(encoding="utf-8")
        lines = content.split("\n")

        for i, line in enumerate(lines, 1):
            stripped = line.strip()

            # Skip comments
            if stripped.startswith("//") or stripped.startswith("*"):
                continue

            # Check for each pattern
            if "audit_log" in line and "audit_logs" not in line:
                # Singular (but not plural)
                if "'audit_log'" in line or '"audit_log"' in line:
                    references['audit_log (singular)'].append((str(file_path), i, stripped))

            if "audit_logs" in line:
                if "'audit_logs'" in line or '"audit_logs"' in line:
                    references['audit_logs (plural)'].append((str(file_path), i, stripped))

            if "auditLogCollection" in line and "auditLogsCollection" not in line:
                references['auditLogCollection'].append((str(file_path), i, stripped))

            if "auditLogsCollection" in line:
                references['auditLogsCollection'].append((str(file_path), i, stripped))

    except Exception:
        pass

# Print results
for pattern, refs in references.items():
    print(f"  {pattern}: {len(refs)} reference(s)")
    for path, line_num, line in refs[:5]:
        print(f"    {path}:{line_num}")
        print(f"      {line}")
    if len(refs) > 5:
        print(f"    ... and {len(refs) - 5} more")
    print()

# ============================================================================
# Step 2: Find the constant definitions
# ============================================================================
print("--- Step 2: Find constant definitions ---")
print()

constants_file = Path("lib/core/config/app_constants.dart")
if constants_file.exists():
    content = constants_file.read_text(encoding="utf-8")
    lines = content.split("\n")

    for i, line in enumerate(lines, 1):
        if "auditLog" in line.lower() and "Collection" in line:
            print(f"  {constants_file}:{i}")
            print(f"    {line.strip()}")
            # Show context (2 lines before and after)
            start = max(0, i - 3)
            end = min(len(lines), i + 2)
            print(f"    Context:")
            for j in range(start, end):
                marker = ">>>" if j == i - 1 else "   "
                print(f"    {marker} {j+1}: {lines[j]}")
            print()
else:
    print(f"  [!] {constants_file} not found")

# ============================================================================
# Step 3: Find all writes to audit log collections
# ============================================================================
print("--- Step 3: Find all WRITES to audit log collections ---")
print()

writes = []
for file_path in list(Path("lib").rglob("*.dart")) + list(Path("functions").rglob("*.ts")):
    if "node_modules" in str(file_path):
        continue
    try:
        content = file_path.read_text(encoding="utf-8")
        lines = content.split("\n")

        for i, line in enumerate(lines, 1):
            # Look for .add( or .set( or .doc().set( patterns near audit_log
            if ("audit_log" in line or "auditLog" in line or "auditLogs" in line):
                if any(op in line for op in ['.add(', '.set(', '.create(']):
                    writes.append((str(file_path), i, line.strip()))
    except Exception:
        pass

if writes:
    print(f"  Found {len(writes)} write operations:")
    for path, line_num, line in writes[:10]:
        print(f"    {path}:{line_num}")
        print(f"      {line}")
    if len(writes) > 10:
        print(f"    ... and {len(writes) - 10} more")
else:
    print("  No write operations found (may be using a service abstraction)")
print()

# ============================================================================
# Step 4: Find all reads from audit log collections
# ============================================================================
print("--- Step 4: Find all READS from audit log collections ---")
print()

reads = []
for file_path in list(Path("lib").rglob("*.dart")) + list(Path("functions").rglob("*.ts")):
    if "node_modules" in str(file_path):
        continue
    try:
        content = file_path.read_text(encoding="utf-8")
        lines = content.split("\n")

        for i, line in enumerate(lines, 1):
            if ("audit_log" in line or "auditLog" in line or "auditLogs" in line):
                if any(op in line for op in ['.get(', '.snapshots(', '.where(', '.orderBy(']):
                    reads.append((str(file_path), i, line.strip()))
    except Exception:
        pass

if reads:
    print(f"  Found {len(reads)} read operations:")
    for path, line_num, line in reads[:10]:
        print(f"    {path}:{line_num}")
        print(f"      {line}")
    if len(reads) > 10:
        print(f"    ... and {len(reads) - 10} more")
else:
    print("  No read operations found (may be using a service abstraction)")
print()

# ============================================================================
# Step 5: Find the AuditLogService
# ============================================================================
print("--- Step 5: Find AuditLogService implementation ---")
print()

service_files = list(Path("lib").rglob("*audit*log*service*.dart")) + \
                list(Path("functions").rglob("*audit*log*service*.ts")) + \
                list(Path("lib").rglob("*audit_log_service*"))

if service_files:
    for sf in service_files:
        print(f"  Found: {sf}")
        content = sf.read_text(encoding="utf-8")
        lines = content.split("\n")

        # Find collection reference
        for i, line in enumerate(lines, 1):
            if "collection" in line.lower() and "audit" in line.lower():
                print(f"    Line {i}: {line.strip()}")

        # Find which constant it uses
        if "auditLogCollection" in content:
            print(f"    -> Uses: auditLogCollection (singular)")
        if "auditLogsCollection" in content:
            print(f"    -> Uses: auditLogsCollection (plural)")
        if "'audit_log'" in content or '"audit_log"' in content:
            print(f"    -> Uses: 'audit_log' literal (singular)")
        if "'audit_logs'" in content or '"audit_logs"' in content:
            print(f"    -> Uses: 'audit_logs' literal (plural)")
        print()
else:
    print("  [!] No AuditLogService file found")
print()

# ============================================================================
# Step 6: Find Firestore rules for audit_logs
# ============================================================================
print("--- Step 6: Check firestore.rules for audit_log(s) ---")
print()

rules_path = Path("firestore.rules")
if rules_path.exists():
    content = rules_path.read_text(encoding="utf-8")
    lines = content.split("\n")

    for i, line in enumerate(lines, 1):
        if "audit_log" in line and "match" in line:
            print(f"  {rules_path}:{i}")
            print(f"    {line.strip()}")
            # Show the full match block
            for j in range(i, min(len(lines), i + 6)):
                print(f"    {j+1}: {lines[j]}")
            print()

# ============================================================================
# Step 7: Find Firestore indexes for audit_logs
# ============================================================================
print("--- Step 7: Check firestore.indexes.json for audit_log(s) ---")
print()

indexes_path = Path("firestore.indexes.json")
if indexes_path.exists():
    content = indexes_path.read_text(encoding="utf-8")

    # Find all collectionGroup references
    for match in re.finditer(r'"collectionGroup":\s*"(audit_log[a-z_]*)"', content):
        collection = match.group(1)
        # Find line number
        pos = match.start()
        line_num = content[:pos].count('\n') + 1
        print(f"  Index on collection: {collection} (line {line_num})")

    if "audit_log" not in content:
        print("  [!] No audit_log indexes found")
print()

# ============================================================================
# Step 8: Analysis and verdict
# ============================================================================
print("=" * 70)
print("ANALYSIS")
print("=" * 70)
print()

singular_writes = sum(1 for _, _, line in writes if "audit_log'" in line and "audit_logs" not in line)
plural_writes = sum(1 for _, _, line in writes if "audit_logs" in line)
singular_reads = sum(1 for _, _, line in reads if "audit_log'" in line and "audit_logs" not in line)
plural_reads = sum(1 for _, _, line in reads if "audit_logs" in line)

print(f"  Writes to 'audit_log' (singular):  {singular_writes}")
print(f"  Writes to 'audit_logs' (plural):   {plural_writes}")
print(f"  Reads from 'audit_log' (singular): {singular_reads}")
print(f"  Reads from 'audit_logs' (plural):  {plural_reads}")
print()

if singular_writes > 0 and plural_reads > 0:
    print("  [CRITICAL] SILENT DATA LOSS DETECTED!")
    print("  Some code writes to 'audit_log' (singular)")
    print("  Other code reads from 'audit_logs' (plural)")
    print("  Audit entries written to the wrong collection will NOT appear in the UI.")
    print()
    print("  FIX:")
    print("    1. Standardize on 'audit_logs' (plural — matches Firestore convention)")
    print("    2. Update app_constants.dart: change auditLogCollection to 'audit_logs'")
    print("    3. Migrate existing docs: copy from audit_log to audit_logs")
    print("    4. Verify firestore.rules has rules for audit_logs (not just audit_log)")

elif singular_writes > 0 and plural_reads == 0:
    print("  [WARNING] Only singular 'audit_log' is used for both writes and reads.")
    print("  This is consistent (no data loss), but the firestore.rules likely")
    print("  has 'audit_logs' (plural) — verify the rules match the actual collection.")
    print()
    print("  RECOMMENDATION: Standardize on 'audit_logs' (plural) for consistency")

elif plural_writes > 0 and singular_reads == 0:
    print("  [OK] Only plural 'audit_logs' is used — consistent.")
    print("  No data loss risk. The singular constant may be unused dead code.")

elif singular_writes == 0 and plural_writes == 0:
    print("  [INFO] No direct writes found — audit logging likely goes through a")
    print("  Cloud Function or service abstraction. Verify the service uses the")
    print("  correct collection name.")

else:
    print("  [OK] No conflicts detected — collection names appear consistent.")

print()
print("=" * 70)
print("RECOMMENDED FIX (if conflict detected)")
print("=" * 70)
print()
print("If the analysis above shows a conflict:")
print()
print("1. Edit lib/core/config/app_constants.dart:")
print("   - Change: static const String auditLogCollection = 'audit_log';")
print("   - To:     static const String auditLogCollection = 'audit_logs';")
print("   (Or remove the singular constant and use auditLogsCollection everywhere)")
print()
print("2. Migrate existing data (run once via Admin SDK):")
print("   - Read all docs from 'audit_log' collection")
print("   - Write them to 'audit_logs' collection")
print("   - Delete the 'audit_log' collection")
print()
print("3. Verify firestore.rules has the match block for 'audit_logs/{logId}'")
print("   (not 'audit_log/{logId}')")
print()
print("4. Verify firestore.indexes.json has indexes on 'audit_logs'")
print("   (not 'audit_log')")
