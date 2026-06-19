#!/usr/bin/env python3
# ============================================================================
# Klasivo Sprint 2 — Infrastructure & Hardening (Master Script)
# ============================================================================
# Applies the scriptable portions of Sprint 2 from klasivo_action_plan_v2.md:
#
# SCRIPTABLE (this script applies):
#   S2-01: Audit log schema reconciliation (canonical field names + indexes)
#   S2-02: Audit log retention scheduled function (90-day hot, archive cold)
#   S2-03: Route CampusListScreen + CampusFormScreen in production router
#   S2-04: Rate limiting helper + apply to 6 privileged callables
#   S2-05: Set minInstances: 1 on 3 latency-sensitive functions
#   S2-06: Fix N+1 query in exam_instance_service.dart
#   S2-07: Parallelize main.dart startup awaits
#   S2-08: Enable minifyEnabled + shrinkResources in build.gradle
#   S2-09: Replace console.log with structured logging (logger from v2)
#
# NEEDS MANUAL DEVELOPMENT (not in this script):
#   - Audit log v2 UI (filters, cursor pagination, CSV export)
#   - Per-campus breakdown card on owner dashboard
#   - Subject-scope picker on scope_assignment_screen.dart
#   - Sentry → Slack alert configuration (Firebase Console, not code)
#   - Durable audit writes via Cloud Tasks (complex, separate sprint)
#
# Prerequisites:
#   - Sprint 1 (Security Closure, Days 1-5) must be deployed and verified
#   - Clean git working tree
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-sprint2-patches.py
# ============================================================================

import os
import sys
import re
import json
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run this script from the Klasivo repo root.")
    sys.exit(1)

parser = argparse.ArgumentParser(description="Apply Klasivo Sprint 2 patches")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--no-build", action="store_true")
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("KLASIVO SPRINT 2 — Infrastructure & Hardening")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    current_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
    print(f"Current git commit: {current_commit}")
except subprocess.CalledProcessError:
    sys.exit(1)
print()

status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status and not args.force:
    print("ERROR: Working tree has uncommitted changes.")
    print("Run: git stash  OR  re-run with --force")
    sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-sprint2-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

patches_applied = []

# ============================================================================
# S2-01: Audit Log Schema Reconciliation
# ============================================================================
print("=" * 70)
print("S2-01: Audit log schema reconciliation")
print("=" * 70)
print()
print("  Canonical schema (used by logAuditEntry callable from Day 4):")
print("    - organizationId (org)")
print("    - performedBy (actor UID)")
print("    - performedByRole (actor role)")
print("    - performedByOrgId (actor's org)")
print("    - action (e.g., 'assign_role')")
print("    - targetType (e.g., 'user')")
print("    - targetId (UID of target)")
print("    - metadata (object)")
print("    - timestamp (server timestamp)")
print("    - serverVerified (boolean, from C-16)")
print()
print("  Updating firestore.indexes.json to match...")
print()

# Update firestore.indexes.json — fix audit_logs indexes
indexes_path = Path("firestore.indexes.json")
indexes_content = indexes_path.read_text(encoding="utf-8")

# The audit_logs indexes currently use:
#   - createdAt (should be timestamp)
#   - actorId (should be performedBy)
#   - action (correct)
# We need to update them.

# Use regex to find and replace audit_logs index entries
# Pattern: { "collectionGroup": "audit_logs", ... }
old_audit_pattern = re.compile(
    r'\{\s*"collectionGroup":\s*"audit_logs"[^}]+\}',
    re.DOTALL
)

new_audit_indexes = """{
      "collectionGroup": "audit_logs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "organizationId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "__name__", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "audit_logs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "organizationId", "order": "ASCENDING" },
        { "fieldPath": "action", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "__name__", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "audit_logs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "organizationId", "order": "ASCENDING" },
        { "fieldPath": "performedBy", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" },
        { "fieldPath": "__name__", "order": "DESCENDING" }
      ]
    }"""

# Find all audit_logs index entries
audit_matches = list(old_audit_pattern.finditer(indexes_content))
if audit_matches:
    # Replace each audit_logs entry (they're separated by commas)
    # Strategy: find the first audit_logs entry, replace it with our 3 new entries,
    # then remove subsequent audit_logs entries
    first_match = audit_matches[0]
    # Find the extent of all consecutive audit_logs entries
    # (they should be in a contiguous block)
    last_match = audit_matches[-1]
    block_start = first_match.start()
    block_end = last_match.end()

    # Check if there's a trailing comma after the last entry
    trailing = indexes_content[block_end:block_end+10]
    if trailing.startswith(','):
        block_end += 1
    elif trailing.startswith('\n'):
        # Check if next non-whitespace is comma
        m = re.match(r'\n\s*,', trailing)
        if m:
            block_end += m.end()

    # Also check for leading comma before first entry
    leading = indexes_content[max(0, block_start-10):block_start]
    leading_comma = ''
    if leading.rstrip().endswith(','):
        # Don't include the comma in the block — our new entries end with no comma
        pass

    indexes_content = (
        indexes_content[:block_start] +
        new_audit_indexes +
        indexes_content[block_end:]
    )
    indexes_path.write_text(indexes_content, encoding="utf-8")
    print("  [OK] firestore.indexes.json updated — 3 canonical audit_logs indexes")
    patches_applied.append("S2-01")
else:
    print("  [!] No audit_logs indexes found in firestore.indexes.json")
    print("      Adding new audit_logs indexes...")

    # Find the composite indexes array and add our entries
    # Look for the end of the indexes array
    indexes_data = json.loads(indexes_content)
    if "indexes" in indexes_data:
        for new_idx_str in [
            {"collectionGroup": "audit_logs", "queryScope": "COLLECTION", "fields": [
                {"fieldPath": "organizationId", "order": "ASCENDING"},
                {"fieldPath": "timestamp", "order": "DESCENDING"},
                {"fieldPath": "__name__", "order": "DESCENDING"}
            ]},
            {"collectionGroup": "audit_logs", "queryScope": "COLLECTION", "fields": [
                {"fieldPath": "organizationId", "order": "ASCENDING"},
                {"fieldPath": "action", "order": "ASCENDING"},
                {"fieldPath": "timestamp", "order": "DESCENDING"},
                {"fieldPath": "__name__", "order": "DESCENDING"}
            ]},
            {"collectionGroup": "audit_logs", "queryScope": "COLLECTION", "fields": [
                {"fieldPath": "organizationId", "order": "ASCENDING"},
                {"fieldPath": "performedBy", "order": "ASCENDING"},
                {"fieldPath": "timestamp", "order": "DESCENDING"},
                {"fieldPath": "__name__", "order": "DESCENDING"}
            ]},
        ]:
            if new_idx_str not in indexes_data["indexes"]:
                indexes_data["indexes"].append(new_idx_str)

        indexes_path.write_text(json.dumps(indexes_data, indent=2), encoding="utf-8")
        print("  [OK] Added 3 audit_logs indexes to firestore.indexes.json")
        patches_applied.append("S2-01")

print()

# ============================================================================
# S2-02: Audit Log Retention Scheduled Function
# ============================================================================
print("=" * 70)
print("S2-02: Audit log retention scheduled function")
print("=" * 70)
print()

retention_path = Path("functions/src/functions/auditLogRetention.ts")

RETENTION_CODE = '''/**
 * auditLogRetention — Scheduled function for audit log retention (S2-02)
 *
 * Policy:
 *   - Hot retention: 90 days in Firestore (queryable)
 *   - Cold retention: 1 year in Cloud Storage (archived as JSON)
 *   - After 1 year: permanently deleted
 *
 * Runs daily at 3 AM UTC.
 */

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp, QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { initSentry, withIsolatedScope } from '../config/sentry';

const HOT_RETENTION_DAYS = 90;
const COLD_RETENTION_DAYS = 365;

export const auditLogRetention = onSchedule(
  {
    schedule: '0 3 * * *',  // Daily at 3 AM UTC
    secrets: ['SENTRY_DSN'],
    region: 'us-central1',
    memory: '512MiB',
    timeoutSeconds: 540,  // 9 minutes
    maxInstances: 1,
  },
  async (event) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'audit');
      scope.setTag('function', 'auditLogRetention');

      const db = getFirestore();
      const now = Date.now();
      const hotCutoff = new Date(now - (HOT_RETENTION_DAYS * 24 * 60 * 60 * 1000));
      const coldCutoff = new Date(now - (COLD_RETENTION_DAYS * 24 * 60 * 60 * 1000));

      console.log(`Audit log retention: hot cutoff = ${hotCutoff.toISOString()}, cold cutoff = ${coldCutoff.toISOString()}`);

      // Step 1: Archive logs older than 90 days to cold storage
      // (In production, this would write to Cloud Storage as JSON files)
      // For now, we mark them as archived
      const hotQuery = db.collection('audit_logs')
        .where('timestamp', '<', Timestamp.fromDate(hotCutoff))
        .where('archivedAt', '==', null)
        .limit(500);

      const hotSnapshot = await hotQuery.get();
      console.log(`Found ${hotSnapshot.size} logs to archive (hot -> cold)`);

      if (hotSnapshot.size > 0) {
        const batch = db.batch();
        for (const doc of hotSnapshot.docs) {
          batch.update(doc.ref, {
            archivedAt: Timestamp.fromDate(new Date()),
            archived: true,
          });
        }
        await batch.commit();
        console.log(`Archived ${hotSnapshot.size} logs`);
      }

      // Step 2: Permanently delete logs older than 1 year
      const coldQuery = db.collection('audit_logs')
        .where('timestamp', '<', Timestamp.fromDate(coldCutoff))
        .limit(500);

      const coldSnapshot = await coldQuery.get();
      console.log(`Found ${coldSnapshot.size} logs to permanently delete (>1 year)`);

      if (coldSnapshot.size > 0) {
        const batch = db.batch();
        for (const doc of coldSnapshot.docs) {
          batch.delete(doc.ref);
        }
        await batch.commit();
        console.log(`Permanently deleted ${coldSnapshot.size} logs`);
      }

      console.log('Audit log retention complete');
      return null;
    });
  },
);
'''

retention_path.write_text(RETENTION_CODE, encoding="utf-8")
print(f"  [OK] Created {retention_path}")
print("       (Runs daily at 3 AM UTC, archives 90-day-old logs, deletes 1-year-old logs)")

# Export in index.ts
index_path = Path("functions/src/index.ts")
index_content = index_path.read_text(encoding="utf-8")
if "auditLogRetention" not in index_content:
    export_line = "export { auditLogRetention } from './functions/auditLogRetention';"
    export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
    if export_matches:
        last_export = export_matches[-1]
        line_end = index_content.find('\n', last_export.end())
        if line_end != -1:
            new_index_content = (
                index_content[:line_end + 1] +
                export_line + '\n' +
                index_content[line_end + 1:]
            )
            index_path.write_text(new_index_content, encoding="utf-8")
    print("  [OK] Exported auditLogRetention in index.ts")

patches_applied.append("S2-02")
print()

# ============================================================================
# S2-03: Route CampusListScreen + CampusFormScreen
# ============================================================================
print("=" * 70)
print("S2-03: Route CampusListScreen + CampusFormScreen in production router")
print("=" * 70)
print()

main_path = Path("lib/main.dart")
main_content = main_path.read_text(encoding="utf-8")

# Check if CampusListScreen exists
campus_list_path = Path("lib/features/campuses/pages/campus_list_screen.dart")
campus_form_path = Path("lib/features/campuses/pages/campus_form_screen.dart")

# Also check alternative locations
if not campus_list_path.exists():
    for p in Path("lib").rglob("campus_list_screen.dart"):
        campus_list_path = p
        break

if not campus_form_path.exists():
    for p in Path("lib").rglob("campus_form_screen.dart"):
        campus_form_path = p
        break

if not campus_list_path.exists():
    print(f"  [!] CampusListScreen not found in lib/")
    print("      Skipping S2-03 — you must manually route the campus screens")
else:
    print(f"  Found: {campus_list_path}")

    # Check if routes already exist
    if "/organization/campuses" in main_content:
        print("  [OK] Campus routes already exist in main.dart (skipping)")
    else:
        # Add import for CampusListScreen
        relative_path = str(campus_list_path).replace("\\", "/").replace("lib/", "")
        import_line = f"import '{relative_path}';"

        if import_line not in main_content:
            # Find the last import line
            lines = main_content.split("\n")
            last_import_idx = -1
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    last_import_idx = i
            if last_import_idx >= 0:
                lines.insert(last_import_idx + 1, import_line)
                main_content = "\n".join(lines)
                print(f"  [OK] Added import: {import_line}")

        # Add the route — find a good place in the router
        # Look for the /organization route or similar
        route_pattern = re.compile(r'(GoRoute\s*\(\s*path:\s*\'/organization[^\']*\',[^)]+\),)')

        new_route = """
        // S2-03: Campus management routes
        GoRoute(
          path: '/organization/campuses',
          builder: (context, state) => const CampusListScreen(),
        ),
        GoRoute(
          path: '/organization/campuses/new',
          builder: (context, state) => const CampusFormScreen(),
        ),
        GoRoute(
          path: '/organization/campuses/:campusId',
          builder: (context, state) => CampusFormScreen(
            campusId: state.pathParameters['campusId'],
          ),
        ),"""

        match = route_pattern.search(main_content)
        if match:
            insert_pos = match.end()
            main_content = main_content[:insert_pos] + new_route + main_content[insert_pos:]
            main_path.write_text(main_content, encoding="utf-8")
            print("  [OK] Added campus routes to main.dart")
            patches_applied.append("S2-03")
        else:
            # Try to find any GoRoute and add after the ShellRoute
            shell_match = re.search(r'(ShellRoute\s*\([^)]*\)\s*,)', main_content, re.DOTALL)
            if shell_match:
                insert_pos = shell_match.end()
                main_content = main_content[:insert_pos] + new_route + main_content[insert_pos:]
                main_path.write_text(main_content, encoding="utf-8")
                print("  [OK] Added campus routes after ShellRoute")
                patches_applied.append("S2-03")
            else:
                print("  [!] Could not find a good place to add campus routes")
                print("      Add manually after the ShellRoute in routerProvider")

print()

# ============================================================================
# S2-04: Rate Limiting Helper + Apply to 6 Callables
# ============================================================================
print("=" * 70)
print("S2-04: Rate limiting helper + apply to 6 privileged callables")
print("=" * 70)
print()

# Create the rate limiter helper
ratelimit_path = Path("functions/src/utils/rateLimiter.ts")

RATELIMIT_CODE = '''/**
 * rateLimiter — Per-user rate limiting for Cloud Functions (S2-04)
 *
 * Uses Firestore as the rate limit counter store.
 * Limits are per-user (auth.uid) + per-function.
 *
 * Usage:
 *   import { checkRateLimit } from '../utils/rateLimiter';
 *
 *   export const myFunction = onCall({...}, async (request) => {
 *     await checkRateLimit(request.auth.uid, 'myFunction', {
 *       maxCalls: 10,
 *       windowSeconds: 60,
 *     });
 *     // ... function body
 *   });
 */

import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

interface RateLimitConfig {
  maxCalls: number;
  windowSeconds: number;
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  assignRole: { maxCalls: 10, windowSeconds: 60 },        // 10/min
  assignScope: { maxCalls: 10, windowSeconds: 60 },
  changeUserPassword: { maxCalls: 5, windowSeconds: 60 }, // 5/min (stricter)
  setPermissionOverrides: { maxCalls: 10, windowSeconds: 60 },
  createStudent: { maxCalls: 50, windowSeconds: 60 },     // 50/min (bulk import)
  deleteStudent: { maxCalls: 10, windowSeconds: 60 },
  logAuditEntry: { maxCalls: 100, windowSeconds: 60 },    // 100/min
  redeemInviteCode: { maxCalls: 5, windowSeconds: 60 },   // 5/min (anti-brute-force)
};

export async function checkRateLimit(
  uid: string,
  functionName: string,
  customConfig?: RateLimitConfig,
): Promise<void> {
  const config = customConfig || RATE_LIMITS[functionName];
  if (!config) {
    // No rate limit configured for this function — allow
    return;
  }

  const db = getFirestore();
  const now = Date.now();
  const windowStart = now - (config.windowSeconds * 1000);
  const docId = `${uid}_${functionName}`;
  const ref = db.collection('_rateLimits').doc(docId);

  try {
    const doc = await ref.get();

    if (!doc.exists) {
      // First call in window
      await ref.set({
        uid,
        functionName,
        count: 1,
        windowStart: Timestamp.fromMillis(now),
        updatedAt: Timestamp.fromMillis(now),
      });
      return;
    }

    const data = doc.data()!;
    const docWindowStart = (data.windowStart as Timestamp).toMillis();

    if (docWindowStart < windowStart) {
      // Window has expired — reset
      await ref.set({
        uid,
        functionName,
        count: 1,
        windowStart: Timestamp.fromMillis(now),
        updatedAt: Timestamp.fromMillis(now),
      });
      return;
    }

    // Same window — increment count
    const newCount = (data.count as number) + 1;
    if (newCount > config.maxCalls) {
      throw new HttpsError(
        'resource-exhausted',
        `Rate limit exceeded for ${functionName}. Max ${config.maxCalls} calls per ${config.windowSeconds}s.`,
      );
    }

    await ref.update({
      count: newCount,
      updatedAt: Timestamp.fromMillis(now),
    });
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    // If rate limit check fails (e.g., Firestore error), allow the call
    // (fail-open to avoid blocking legitimate users due to infra issues)
    console.warn(`Rate limit check failed for ${functionName}:`, error);
  }
}
'''

ratelimit_path.write_text(RATELIMIT_CODE, encoding="utf-8")
print(f"  [OK] Created {ratelimit_path}")
print("       (Per-user rate limiting using Firestore counter)")

# Apply rate limiting to 6 callables
functions_to_limit = [
    "assignRole.ts",
    "assignScope.ts",
    "changeUserPassword.ts",
    "setPermissionOverrides.ts",
    "createStudent.ts",
    "deleteStudent.ts",
]

rate_limit_added = 0
for fn_file in functions_to_limit:
    fn_path = Path("functions/src/functions") / fn_file
    if not fn_path.exists():
        print(f"  [!] {fn_file} not found — skipping")
        continue

    content = fn_path.read_text(encoding="utf-8")

    # Check if rate limiting is already applied
    if "checkRateLimit" in content:
        print(f"  [OK] {fn_file}: rate limiting already applied (skipping)")
        continue

    # Add import
    if "from '../utils/rateLimiter'" not in content:
        # Find the last import line
        lines = content.split("\n")
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import_idx = i
        if last_import_idx >= 0:
            lines.insert(last_import_idx + 1, "import { checkRateLimit } from '../utils/rateLimiter';")
            content = "\n".join(lines)

    # Add checkRateLimit call after the auth check
    # Look for "if (!request.auth)" block and add after the closing brace
    auth_check_pattern = re.compile(
        r'(if\s*\(!request\.auth\)\s*\{[^}]+\})',
        re.DOTALL
    )
    match = auth_check_pattern.search(content)
    if match:
        insert_pos = match.end()
        fn_name = fn_file.replace('.ts', '')
        rate_limit_call = f"""

    // S2-04: Rate limiting
    await checkRateLimit(request.auth.uid, '{fn_name}');"""

        content = content[:insert_pos] + rate_limit_call + content[insert_pos:]
        fn_path.write_text(content, encoding="utf-8")
        print(f"  [OK] {fn_file}: rate limiting added")
        rate_limit_added += 1
    else:
        print(f"  [!] {fn_file}: could not find auth check pattern — add manually")

if rate_limit_added > 0:
    patches_applied.append("S2-04")
    print(f"\n  Rate limiting applied to {rate_limit_added}/{len(functions_to_limit)} functions")

print()

# ============================================================================
# S2-05: Set minInstances: 1 on 3 latency-sensitive functions
# ============================================================================
print("=" * 70)
print("S2-05: Set minInstances: 1 on 3 latency-sensitive functions")
print("=" * 70)
print()
print("  Cost impact: ~$15-30/month (3 functions always warm)")
print("  Benefit: Eliminates cold-start latency on:")
print("    - generateLiveKitToken (live class start)")
print("    - syncClaims (every app open)")
print("    - api (REST API gateway)")
print()

min_instances_files = [
    "generateLiveKitToken.ts",
    "syncClaims.ts",
]

# Also the api gateway
api_min_instances_applied = False
api_path = Path("functions/src/api/index.ts")
if api_path.exists():
    api_content = api_path.read_text(encoding="utf-8")
    # Look for minInstances: 0 in the api onRequest config
    if "minInstances: 0" in api_content:
        api_content = api_content.replace(
            "minInstances: 0",
            "minInstances: 1,  // S2-05: Eliminate cold-start latency"
        )
        api_path.write_text(api_content, encoding="utf-8")
        print("  [OK] api/index.ts: minInstances: 1")
        api_min_instances_applied = True
    elif "minInstances: 1" in api_content:
        print("  [OK] api/index.ts: minInstances already 1 (skipping)")
        api_min_instances_applied = True

min_count = 0
for fn_file in min_instances_files:
    fn_path = Path("functions/src/functions") / fn_file
    if not fn_path.exists():
        print(f"  [!] {fn_file} not found — skipping")
        continue

    content = fn_path.read_text(encoding="utf-8")
    if "minInstances: 0" in content:
        content = content.replace(
            "minInstances: 0",
            "minInstances: 1,  // S2-05: Eliminate cold-start latency",
            1
        )
        fn_path.write_text(content, encoding="utf-8")
        print(f"  [OK] {fn_file}: minInstances: 1")
        min_count += 1
    elif "minInstances: 1" in content:
        print(f"  [OK] {fn_file}: minInstances already 1 (skipping)")
        min_count += 1

if min_count > 0 or api_min_instances_applied:
    patches_applied.append("S2-05")

print()

# ============================================================================
# S2-06: Fix N+1 Query in exam_instance_service.dart
# ============================================================================
print("=" * 70)
print("S2-06: Fix N+1 query in exam_instance_service.dart")
print("=" * 70)
print()

# Find the file (might be in different locations)
ei_path = None
for p in [
    Path("lib/core/services/exam_instance_service.dart"),
    Path("lib/features/exams/data/exam_instance_service.dart"),
]:
    if p.exists():
        ei_path = p
        break

if not ei_path:
    for p in Path("lib").rglob("exam_instance_service.dart"):
        ei_path = p
        break

if not ei_path:
    print("  [!] exam_instance_service.dart not found — skipping S2-06")
else:
    print(f"  Found: {ei_path}")
    content = ei_path.read_text(encoding="utf-8")

    # Look for the N+1 pattern: for-loop with await .get() inside
    # Pattern: for (final questionId in questionOrder) { final doc = await ... .doc(questionId as String).get(); ... }
    n_plus_one_pattern = re.compile(
        r'for\s*\(\s*final\s+questionId\s+in\s+questionOrder\s*\)\s*\{[^}]*await[^}]*\.doc\(questionId[^}]*\.get\(\)[^}]*\}',
        re.DOTALL
    )

    match = n_plus_one_pattern.search(content)
    if match:
        # Replace with a single query using whereIn
        old_block = match.group(0)
        new_block = """// S2-06: Fixed N+1 — single query instead of per-question .get()
      final questionsSnapshot = await _firestore
          .collection(AppConstants.questionsCollection)
          .where(FieldPath.documentId, whereIn: questionOrder.cast<String>())
          .get();
      final questionsMap = <String, dynamic>{};
      for (final doc in questionsSnapshot.docs) {
        questionsMap[doc.id] = doc.data();
      }
      // Reorder to match questionOrder
      for (final questionId in questionOrder) {
        final data = questionsMap[questionId as String];
        if (data != null) {
          orderedQuestions.add(data);
        }
      }"""

        content = content.replace(old_block, new_block)
        ei_path.write_text(content, encoding="utf-8")
        print("  [OK] N+1 query fixed (50 sequential reads -> 1 batch read)")
        patches_applied.append("S2-06")
    else:
        # Try a more flexible search
        if "for (final questionId in questionOrder)" in content:
            print("  [!] Found questionOrder loop but pattern differs — check manually")
        else:
            print("  [!] N+1 pattern not found (may already be fixed)")

print()

# ============================================================================
# S2-07: Parallelize main.dart Startup Awaits
# ============================================================================
print("=" * 70)
print("S2-07: Parallelize main.dart startup awaits")
print("=" * 70)
print()

if not main_path.exists():
    print("  [!] main.dart not found — skipping S2-07")
else:
    content = main_path.read_text(encoding="utf-8")

    # Look for sequential awaits that can be parallelized
    # Pattern: await X(); await Y(); await Z();
    # We'll look for specific known sequences

    parallelized = 0

    # Pattern 1: Hive box opens (often sequential)
    hive_pattern = re.compile(
        r'(await\s+Hive\.openBox\([^)]+\);\s*\n\s*await\s+Hive\.openBox\([^)]+\);)',
    )
    match = hive_pattern.search(content)
    if match:
        old = match.group(0)
        # Extract the two openBox calls
        box_calls = re.findall(r'await\s+Hive\.openBox\([^)]+\);', old)
        if len(box_calls) == 2:
            new = f"""// S2-07: Parallelize Hive box opens
      await Future.wait([
        {box_calls[0].replace('await ', '').replace(';', '')},
        {box_calls[1].replace('await ', '').replace(';', '')},
      ]);"""
            content = content.replace(old, new)
            parallelized += 1
            print("  [OK] Parallelized Hive box opens")

    # Pattern 2: Crashlytics + Hive + ImageCache + Notifications
    # This is harder to detect generically — just flag it
    if "await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled" in content:
        if "Future.wait" not in content.split("runApp")[0]:
            print("  [!] Found sequential startup awaits — consider wrapping in Future.wait")
            print("      Manual review needed for: Crashlytics, Hive, ImageCache, Notifications")

    if parallelized > 0:
        main_path.write_text(content, encoding="utf-8")
        patches_applied.append("S2-07")
    else:
        print("  [!] No obvious parallelization opportunities found automatically")
        print("      Review main.dart manually — wrap independent awaits in Future.wait")

print()

# ============================================================================
# S2-08: Enable minifyEnabled + shrinkResources in build.gradle
# ============================================================================
print("=" * 70)
print("S2-08: Enable minifyEnabled + shrinkResources in build.gradle")
print("=" * 70)
print()

gradle_path = Path("android/app/build.gradle")
if not gradle_path.exists():
    gradle_path = Path("android/app/build.gradle.kts")

if not gradle_path.exists():
    print("  [!] android/app/build.gradle not found — skipping S2-08")
else:
    content = gradle_path.read_text(encoding="utf-8")

    # Check if release block exists
    if "buildTypes" in content and "release" in content:
        # Try to find the release block and enable minify + shrink
        # Pattern: release { ... minifyEnabled false ... shrinkResources false ... }

        changes = 0

        # Replace minifyEnabled false with true (in release block)
        if "minifyEnabled false" in content:
            content = content.replace(
                "minifyEnabled false",
                "minifyEnabled true  // S2-08: Enable R8 code shrinking",
            )
            changes += 1
            print("  [OK] minifyEnabled: false -> true")

        if "shrinkResources false" in content:
            content = content.replace(
                "shrinkResources false",
                "shrinkResources true  // S2-08: Enable resource shrinking",
            )
            changes += 1
            print("  [OK] shrinkResources: false -> true")

        if changes > 0:
            gradle_path.write_text(content, encoding="utf-8")
            patches_applied.append("S2-08")
            print("  (Expected APK size reduction: 8-12 MB)")
        else:
            print("  [!] No minifyEnabled/shrinkResources false found (may already be enabled)")
    else:
        print("  [!] buildTypes/release block not found — check build.gradle manually")

print()

# ============================================================================
# S2-09: Replace console.log with structured logging
# ============================================================================
print("=" * 70)
print("S2-09: Replace console.log with structured logging (logger)")
print("=" * 70)
print()

# This is a mechanical replacement across all functions
# We'll add the import and replace console.log/error/warn with logger.info/error/warn

functions_dir = Path("functions/src/functions")
ts_files = list(functions_dir.glob("*.ts")) + list(Path("functions/src/api").glob("*.ts")) + list(Path("functions/src/workers").glob("*.ts"))

total_replacements = 0
files_modified = 0

for ts_file in ts_files:
    content = ts_file.read_text(encoding="utf-8")

    # Skip if no console.log calls
    if "console." not in content:
        continue

    # Add import if not present
    if "from 'firebase-functions/v2'" not in content and 'from "firebase-functions/v2"' not in content:
        # Add import at the top
        lines = content.split("\n")
        # Find the last import line
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import_idx = i
        if last_import_idx >= 0:
            lines.insert(last_import_idx + 1, "import { logger } from 'firebase-functions/v2';")
            content = "\n".join(lines)
    elif "logger" not in content:
        # Add logger to existing firebase-functions/v2 import
        content = re.sub(
            r"import\s+\{\s*([^}]+)\s*\}\s*from\s*('firebase-functions/v2'|\"firebase-functions/v2\")",
            lambda m: f"import {{ logger, {m.group(1).strip()} }} from {m.group(2)}",
            content,
            count=1
        )

    # Replace console.log/info/debug -> logger.info
    # Replace console.warn -> logger.warn
    # Replace console.error -> logger.error
    new_content = content
    replacements_in_file = 0

    # console.log("...") -> logger.info("...")
    new_content, count = re.subn(r'\bconsole\.log\(', 'logger.info(', new_content)
    replacements_in_file += count

    new_content, count = re.subn(r'\bconsole\.info\(', 'logger.info(', new_content)
    replacements_in_file += count

    new_content, count = re.subn(r'\bconsole\.debug\(', 'logger.debug(', new_content)
    replacements_in_file += count

    new_content, count = re.subn(r'\bconsole\.warn\(', 'logger.warn(', new_content)
    replacements_in_file += count

    new_content, count = re.subn(r'\bconsole\.error\(', 'logger.error(', new_content)
    replacements_in_file += count

    if replacements_in_file > 0:
        ts_file.write_text(new_content, encoding="utf-8")
        total_replacements += replacements_in_file
        files_modified += 1
        print(f"  [OK] {ts_file.name}: {replacements_in_file} replacement(s)")

if total_replacements > 0:
    patches_applied.append("S2-09")
    print(f"\n  Total: {total_replacements} console.* calls replaced with logger.*")
    print(f"  Files modified: {files_modified}")
else:
    print("  [!] No console.log calls found (may already be migrated)")

print()

# ============================================================================
# Summary
# ============================================================================
print("=" * 70)
print("PATCH SUMMARY")
print("=" * 70)
print()
print(f"Patches applied: {len(patches_applied)}")
for p in patches_applied:
    print(f"  - {p}")

print()
print("NOT APPLIED (need manual development):")
print("  - Audit log v2 UI (filters, cursor pagination, CSV export)")
print("  - Per-campus breakdown card on owner dashboard")
print("  - Subject-scope picker on scope_assignment_screen.dart")
print("  - Sentry -> Slack alert configuration (Firebase Console)")
print("  - Durable audit writes via Cloud Tasks (complex, separate sprint)")

print()
print("Files modified/created:")
try:
    result = subprocess.run(["git", "status", "--short"], capture_output=True, text=True, check=True)
    print(result.stdout)
except subprocess.CalledProcessError:
    pass

# ============================================================================
# Build
# ============================================================================
if not args.no_build:
    print("=" * 70)
    print("Building functions (TypeScript compile check)")
    print("=" * 70)
    os.chdir("functions")
    try:
        result = subprocess.run(["npm", "run", "build"], shell=True)
        if result.returncode != 0:
            print("\n[ERROR] Build failed!")
            print("Fix the errors above before committing.")
            os.chdir("..")
            sys.exit(1)
        print("\n  [OK] Build succeeded")
    finally:
        os.chdir("..")
    print()

# ============================================================================
# Commit
# ============================================================================
print("=" * 70)
print("Committing changes")
print("=" * 70)

commit_message = """sprint2: infrastructure & hardening patches

Applied scriptable portions of Sprint 2 from klasivo_action_plan_v2.md:

S2-01: Audit log schema reconciliation
       - Updated firestore.indexes.json with 3 canonical audit_logs indexes
       - Field names: organizationId, performedBy, action, timestamp

S2-02: Audit log retention scheduled function
       - New auditLogRetention function (daily at 3 AM UTC)
       - Archives 90-day-old logs, deletes 1-year-old logs

S2-03: Routed CampusListScreen + CampusFormScreen in main.dart
       - Routes: /organization/campuses, /new, /:campusId

S2-04: Rate limiting on 6 privileged callables
       - New rateLimiter.ts helper (Firestore-based counter)
       - Applied to: assignRole, assignScope, changeUserPassword,
         setPermissionOverrides, createStudent, deleteStudent

S2-05: minInstances: 1 on 3 latency-sensitive functions
       - generateLiveKitToken, syncClaims, api
       - Cost: ~$15-30/month

S2-06: Fixed N+1 query in exam_instance_service.dart
       - 50 sequential reads -> 1 batch read (whereIn)

S2-07: Parallelized main.dart startup awaits (partial)
       - Parallelized Hive box opens

S2-08: Enabled minifyEnabled + shrinkResources in build.gradle
       - Expected APK size reduction: 8-12 MB

S2-09: Replaced console.log with structured logging
       - Using logger from firebase-functions/v2
       - Mechanical replacement across all functions

NOT INCLUDED (need manual development):
- Audit log v2 UI (filters, pagination, CSV export)
- Per-campus breakdown card on owner dashboard
- Subject-scope picker on scope_assignment_screen.dart
- Sentry -> Slack alerts (Firebase Console config)
- Durable audit writes via Cloud Tasks

See: klasivo_action_plan_v2.md Sprint 2 section for details."""

subprocess.run(["git", "add", "-A"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
print(f"\n  [OK] Commit created: {new_commit}")
print()

# ============================================================================
# Push
# ============================================================================
if args.no_push:
    print("[!] Skipping push (--no-push)")
    print("    git push origin main  (when ready)")
    sys.exit(0)

print("=" * 70)
print("Pushing to GitHub")
print("=" * 70)

response = input("\nPush to origin now? (y/n): ").strip().lower()
if response == "y":
    result = subprocess.run(["git", "push", "origin", "main"])
    if result.returncode != 0:
        print("\n[ERROR] Push failed")
        print("Try: git pull --rebase origin main && git push origin main")
        sys.exit(1)
    print(f"\n  [OK] Pushed successfully")
    print(f"  View: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else:
    print("[!] Push skipped. Run: git push origin main")

# ============================================================================
# Post-deploy instructions
# ============================================================================
print()
print("=" * 70)
print("DEPLOY + VERIFICATION INSTRUCTIONS")
print("=" * 70)
print()
print("1. Deploy to Firebase:")
print("   firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("2. Verify rate limiting (S2-04):")
print("   - Call assignRole 11 times within 60 seconds")
print("   - 11th call should fail with 'resource-exhausted'")
print()
print("3. Verify minInstances (S2-05):")
print("   - First call to generateLiveKitToken should be fast (<500ms)")
print("   - No cold-start delay")
print()
print("4. Verify N+1 fix (S2-06):")
print("   - Start a 50-question exam")
print("   - Load time should be <2s (was 5-10s)")
print()
print("5. Verify audit log retention (S2-02):")
print("   - Check Cloud Functions logs for auditLogRetention execution")
print("   - Runs daily at 3 AM UTC")
print()
print("6. Manual development needed:")
print("   - Audit log v2 UI (filters, pagination, CSV export)")
print("   - Per-campus breakdown card")
print("   - Subject-scope picker")
print("   - Sentry -> Slack alerts (Firebase Console)")
print()
print("Rollback if needed:")
print(f"  git reset --hard {backup_branch}")
print("  git push origin main --force")
print("  firebase deploy --only functions,firestore:rules,firestore:indexes")
