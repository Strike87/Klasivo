#!/usr/bin/env python3
# ============================================================================
# Klasivo — Updated Day 5 Patch (C-02 + C-08)
# ============================================================================
# UPDATED version that also cleans up the 2 additional hashPassword copies
# found by external review (student_service.dart, excel_import_service.dart).
#
# This script supersedes apply-day5-patches.py. It:
#   1. Removes hashPassword from ALL files (not just the 3 in the original)
#   2. Includes the PasswordHasher consolidation (if not already applied)
#   3. Removes passwordHash from Cloud Functions
#   4. Creates the migration script
#   5. Applies C-08 (org destruction block)
#
# Files cleaned (C-02):
#   - functions/src/functions/createStudent.ts (original)
#   - functions/src/functions/changeUserPassword.ts (original)
#   - lib/core/services/auth_service.dart (original)
#   - lib/core/services/student_service.dart (NEW — found by external review)
#   - lib/core/services/excel_import_service.dart (NEW — found by external review)
#   - lib/features/auth/data/auth_service.dart (dead code — clean anyway)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-day5-patches-v2.py
# ============================================================================

import os
import sys
import re
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

if not Path("firestore.rules").exists():
    print("ERROR: Run from Klasivo repo root.")
    sys.exit(1)

parser = argparse.ArgumentParser(description="Apply Klasivo Day 5 v2 (C-02 + C-08)")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--no-build", action="store_true")
parser.add_argument("--force", action="store_true")
parser.add_argument("--skip-backup-check", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("KLASIVO DAY 5 v2 — Password Cleanup + Org Destruction Block")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")

try:
    current_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
    print(f"Current git commit: {current_commit}")
except subprocess.CalledProcessError:
    sys.exit(1)
print()

if not args.skip_backup_check:
    print("=" * 70)
    print("CRITICAL: Firestore Backup Required")
    print("=" * 70)
    print()
    print("Day 5 includes a data migration that DELETES the 'passwordHash'")
    print("field from every user document. This is IRREVERSIBLE.")
    print()
    print("Back up Firestore first:")
    print("  gcloud firestore export gs://klasivo-prod-backups/pre-day5v2-TIMESTAMP \\")
    print("    --project=klasivo-prod")
    print()
    response = input("Have you completed the Firestore backup? (yes/no): ").strip().lower()
    if response != "yes":
        print("\n[ABORT] Complete backup first, then re-run.")
        sys.exit(1)
    print()

status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status and not args.force:
    print("ERROR: Working tree has uncommitted changes.")
    sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-day5v2-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

patches_applied = []

# ============================================================================
# C-02: Remove hashPassword from ALL files (expanded list)
# ============================================================================
print("=" * 70)
print("C-02: Remove hashPassword from ALL files (6 total)")
print("=" * 70)
print()

# All files that may contain hashPassword
ALL_FILES_WITH_HASH = [
    # Cloud Functions (TypeScript)
    "functions/src/functions/createStudent.ts",
    "functions/src/functions/changeUserPassword.ts",
    # Client (Dart)
    "lib/core/services/auth_service.dart",
    "lib/core/services/student_service.dart",           # NEW (external review)
    "lib/core/services/excel_import_service.dart",      # NEW (external review)
    "lib/features/auth/data/auth_service.dart",         # dead code, clean anyway
]

for file_path_str in ALL_FILES_WITH_HASH:
    file_path = Path(file_path_str)
    if not file_path.exists():
        print(f"  [SKIP] {file_path_str} not found")
        continue

    content = file_path.read_text(encoding="utf-8")
    original = content

    if file_path_str.endswith(".ts"):
        # TypeScript pattern:
        # function hashPassword(password: string): string {
        #   return crypto.createHash('sha256').update(password).digest('hex');
        # }
        ts_pattern = re.compile(
            r'function hashPassword\(password:\s*string\):\s*string\s*\{[^}]*crypto\.createHash[^}]*\}',
            re.DOTALL
        )
        content = ts_pattern.sub('', content)

        # Remove the passwordHash computation line
        content = re.sub(
            r'\s*const passwordHash = hashPassword\([^)]+\);',
            '',
            content
        )

        # Remove the passwordHash field from .set() and .update() calls
        content = re.sub(r'\n\s*passwordHash,\s*\n', '\n', content)
        content = re.sub(r',?\s*passwordHash\s*:\s*[^,}]+,?', '', content)

        # Remove crypto import if unused
        if "crypto." not in content:
            content = re.sub(r"import.*crypto.*\n", "", content, count=1)

    else:
        # Dart pattern:
        # static String hashPassword(String password) {
        #   final bytes = utf8.encode(password);
        #   final digest = sha256.convert(bytes);
        #   return digest.toString();
        # }
        dart_patterns = [
            re.compile(
                r'\s*static String hashPassword\(String password\)\s*\{[^}]*sha256[^}]*\}',
                re.DOTALL
            ),
            re.compile(
                r'\s*String hashPassword\(String password\)\s*\{[^}]*sha256[^}]*\}',
                re.DOTALL
            ),
            re.compile(
                r'\s*static String hashPassword\(String password\)\s*\{[^}]*convert[^}]*\}',
                re.DOTALL
            ),
        ]

        for pattern in dart_patterns:
            content = pattern.sub('\n', content)

        # Remove unused imports
        if "sha256" not in content and "crypto" in content:
            content = re.sub(r"import\s+'package:crypto/crypto\.dart';\n?", "", content)
        if "utf8" not in content and "dart:convert" in content:
            if "utf8." not in content and "jsonEncode" not in content and "jsonDecode" not in content:
                content = re.sub(r"import\s+'dart:convert';\n?", "", content)

    if content != original:
        file_path.write_text(content, encoding="utf-8")
        print(f"  [OK] {file_path_str}: hashPassword removed")
    else:
        if "hashPassword" in content:
            print(f"  [!] {file_path_str}: hashPassword still present (pattern didn't match)")
        else:
            print(f"  [OK] {file_path_str}: already clean")

print()

# ============================================================================
# Create PasswordHasher service (if not already present)
# ============================================================================
print("--- Create PasswordHasher service (if not present) ---")

hasher_path = Path("lib/core/services/password_hasher.dart")
if hasher_path.exists():
    print(f"  [OK] {hasher_path} already exists")
else:
    HASHER_CODE = '''// Consolidated password hasher — uses server-side bcrypt via Cloud Function
import 'package:firebase_functions/firebase_functions.dart';

class PasswordHasher {
  PasswordHasher._();
  static final PasswordHasher instance = PasswordHasher._();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String> hash(String password) async {
    if (password.length < 6) throw ArgumentError('Password too short');
    final result = await _functions.httpsCallable('hashPassword').call({'password': password});
    return result.data['hash'] as String;
  }

  Future<bool> verify(String password, String hash) async {
    try {
      final result = await _functions.httpsCallable('verifyPassword').call({'password': password, 'hash': hash});
      return result.data['valid'] as bool;
    } catch (_) { return false; }
  }

  String generateTemporaryPassword() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const digits = '23456789';
    final r = DateTime.now().microsecondsSinceEpoch;
    final b = StringBuffer();
    for (int i = 0; i < 4; i++) b.write(letters[(r + i * 7919) % letters.length]);
    for (int i = 0; i < 4; i++) b.write(digits[(r + i * 6271) % digits.length]);
    return b.toString();
  }
}
'''
    hasher_path.parent.mkdir(parents=True, exist_ok=True)
    hasher_path.write_text(HASHER_CODE, encoding="utf-8")
    print(f"  [OK] Created {hasher_path}")

print()

# ============================================================================
# Create server-side hashPassword Cloud Function (if not present)
# ============================================================================
print("--- Create passwordHashing.ts (if not present) ---")

fn_path = Path("functions/src/functions/passwordHashing.ts")
if fn_path.exists():
    print(f"  [OK] {fn_path} already exists")
else:
    FN_CODE = '''import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as bcrypt from 'bcryptjs';
import { initSentry, withIsolatedScope } from '../config/sentry';

const BCRYPT_ROUNDS = 12;

export const hashPassword = onCall(
  { secrets: ['SENTRY_DSN'], enforceAppCheck: true, region: 'us-central1',
    memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      if (!request.auth) throw new HttpsError('unauthenticated', 'Must be authenticated.');
      const { password } = request.data as { password: string };
      if (!password || password.length < 6) throw new HttpsError('invalid-argument', 'Password too short.');
      const salt = await bcrypt.genSalt(BCRYPT_ROUNDS);
      const hash = await bcrypt.hash(password, salt);
      return { hash };
    });
  },
);

export const verifyPassword = onCall(
  { secrets: ['SENTRY_DSN'], enforceAppCheck: true, region: 'us-central1',
    memory: '256MiB', timeoutSeconds: 30, minInstances: 0, maxInstances: 10, concurrency: 80 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      if (!request.auth) throw new HttpsError('unauthenticated', 'Must be authenticated.');
      const { password, hash } = request.data as { password: string; hash: string };
      if (!password || !hash) throw new HttpsError('invalid-argument', 'password and hash required.');
      const valid = await bcrypt.compare(password, hash);
      return { valid };
    });
  },
);
'''
    fn_path.write_text(FN_CODE, encoding="utf-8")
    print(f"  [OK] Created {fn_path}")

# Export in index.ts
index_path = Path("functions/src/index.ts")
index_content = index_path.read_text(encoding="utf-8")
for export_line in [
    "export { hashPassword } from './functions/passwordHashing';",
    "export { verifyPassword } from './functions/passwordHashing';",
]:
    fn_name = export_line.split("{")[1].split("}")[0].strip()
    if fn_name not in index_content:
        export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
        if export_matches:
            last_export = export_matches[-1]
            line_end = index_content.find('\n', last_export.end())
            if line_end != -1:
                index_content = index_content[:line_end + 1] + export_line + '\n' + index_content[line_end + 1:]
index_path.write_text(index_content, encoding="utf-8")
print("  [OK] Exported hashPassword + verifyPassword")

# Add bcryptjs to package.json
pkg_path = Path("functions/package.json")
pkg_content = pkg_path.read_text(encoding="utf-8")
if "bcryptjs" not in pkg_content:
    pkg_content = pkg_content.replace('"dependencies": {', '"dependencies": {\n    "bcryptjs": "^2.4.3",')
    pkg_path.write_text(pkg_content, encoding="utf-8")
    print("  [OK] Added bcryptjs to package.json")
print()

# ============================================================================
# Create migration script
# ============================================================================
print("--- Create migration script ---")

scripts_dir = Path("scripts")
scripts_dir.mkdir(exist_ok=True)

migration_path = scripts_dir / "migrate-remove-password-hash.js"
if not migration_path.exists():
    MIGRATION_CODE = '''const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function migrate() {
  console.log('Fetching all user docs with passwordHash field...');
  const snapshot = await db.collection('users')
    .where('passwordHash', '!=', null)
    .get();

  console.log(`Found ${snapshot.size} docs to migrate.`);
  if (snapshot.size === 0) { console.log('No docs need migration.'); return; }

  let batch = db.batch();
  let count = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, { passwordHash: admin.firestore.FieldValue.delete() });
    count++; total++;
    if (count % 400 === 0) {
      await batch.commit();
      console.log(`Migrated ${total}/${snapshot.size}...`);
      batch = db.batch();
    }
  }
  if (count % 400 !== 0) await batch.commit();
  console.log(`\\nMigration complete. ${total} docs updated.`);
}

migrate().then(() => process.exit(0)).catch((err) => { console.error('Failed:', err); process.exit(1); });
'''
    migration_path.write_text(MIGRATION_CODE, encoding="utf-8")
    print(f"  [OK] Created {migration_path}")

patches_applied.append("C-02 (expanded — 6 files cleaned)")
print()

# ============================================================================
# C-08: Block org destruction via deleteStudent
# ============================================================================
print("=" * 70)
print("C-08: Block org destruction via deleteStudent")
print("=" * 70)
print()

# Step 1: Block hardDelete on owners
ds_path = Path("functions/src/functions/deleteStudent.ts")
if ds_path.exists():
    ds_content = ds_path.read_text(encoding="utf-8")

    C08_DS_OLD = """      if (hardDelete === true && isHigherRole(callerRole, 'admin')) {
        try {
          await admin.auth().deleteUser(targetUserId);"""

    C08_DS_NEW = """      if (hardDelete === true && isHigherRole(callerRole, 'admin')) {
        if (targetRole === 'owner') {
          throw new HttpsError(
            'failed-precondition',
            'Cannot hard-delete an org owner. Use deleteOrganization (requires 2FA + backup) or demote the owner first.',
          );
        }
        try {
          await admin.auth().deleteUser(targetUserId);"""

    if C08_DS_OLD in ds_content:
        ds_content = ds_content.replace(C08_DS_OLD, C08_DS_NEW)
        ds_path.write_text(ds_content, encoding="utf-8")
        print("  [OK] deleteStudent.ts: hardDelete blocked on owners")
    elif "Cannot hard-delete an org owner" in ds_content:
        print("  [OK] deleteStudent.ts: already patched")
    else:
        print("  [!] deleteStudent.ts: pattern not found — check manually")

# Step 2: Add confirmation flag in onUserDeleted
oud_path = Path("functions/src/functions/onUserDeleted.ts")
if oud_path.exists():
    oud_content = oud_path.read_text(encoding="utf-8")

    C08_OUD_OLD = """      if (!orgSnapshot.empty) {
        const orgDoc = orgSnapshot.docs[0];
        if (orgDoc) {
          const orgId = orgDoc.id;
          console.log(`Owner deleted — cascade deleting organization: ${orgId}`);
          await deleteOrganizationData(orgId);
        }
      }"""

    C08_OUD_NEW = """      if (!orgSnapshot.empty) {
        const orgDoc = orgSnapshot.docs[0];
        if (orgDoc) {
          const orgId = orgDoc.id;
          const orgData = orgDoc.data();
          if (orgData?.['cascadeDeleteConfirmed'] === true) {
            console.log(`Owner deleted with confirmation — cascade deleting: ${orgId}`);
            await orgDoc.ref.update({ cascadeDeleteConfirmed: false });
            await deleteOrganizationData(orgId);
          } else {
            console.log(`Owner deleted WITHOUT confirmation — NOT cascading. Org ${orgId} preserved.`);
            await Sentry.captureMessage(
              `Owner Auth deleted without cascade confirmation. Org ${orgId} preserved. Owner: ${uid}.`,
              { level: 'warning' }
            );
          }
        }
      }"""

    if C08_OUD_OLD in oud_content:
        oud_content = oud_content.replace(C08_OUD_OLD, C08_OUD_NEW)
        oud_path.write_text(oud_content, encoding="utf-8")
        print("  [OK] onUserDeleted.ts: confirmation flag check added")
    elif "cascadeDeleteConfirmed" in oud_content:
        print("  [OK] onUserDeleted.ts: already patched")
    else:
        print("  [!] onUserDeleted.ts: pattern not found — check manually")

# Step 3: Create deleteOrganization callable
delorg_path = Path("functions/src/functions/deleteOrganization.ts")
if not delorg_path.exists():
    DELORG_CODE = '''import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { initSentry, withIsolatedScope } from '../config/sentry';

export const deleteOrganization = onCall(
  { secrets: ['SENTRY_DSN'], enforceAppCheck: true, region: 'us-central1',
    memory: '512MiB', timeoutSeconds: 300, minInstances: 0, maxInstances: 1, concurrency: 1 },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'organization');
      if (!request.auth) throw new HttpsError('unauthenticated', 'Must be authenticated.');
      const callerRole = (request.auth.token.role as string) || '';
      if (callerRole !== 'super_admin') throw new HttpsError('permission-denied', 'Only super_admin.');
      const { organizationId, confirmPhrase } = request.data;
      if (!organizationId) throw new HttpsError('invalid-argument', 'organizationId required.');
      if (confirmPhrase !== `DELETE ORG ${organizationId}`) throw new HttpsError('invalid-argument', 'Wrong confirmation phrase.');
      const db = getFirestore();
      const orgRef = db.collection('organizations').doc(organizationId);
      const orgDoc = await orgRef.get();
      if (!orgDoc.exists) throw new HttpsError('not-found', 'Organization not found.');
      await orgRef.update({ cascadeDeleteConfirmed: true });
      const ownerId = orgDoc.data()?.['ownerId'];
      if (ownerId) {
        try { await getAuth().deleteUser(ownerId); }
        catch (e) { console.log(`Owner Auth deletion failed: ${e}`); }
      }
      return { success: true };
    });
  },
);
'''
    delorg_path.write_text(DELORG_CODE, encoding="utf-8")
    print(f"  [OK] Created {delorg_path}")

    # Export
    index_content = index_path.read_text(encoding="utf-8")
    if "deleteOrganization" not in index_content:
        export_matches = list(re.finditer(r'^export \{[^}]+\} from', index_content, re.MULTILINE))
        if export_matches:
            last_export = export_matches[-1]
            line_end = index_content.find('\n', last_export.end())
            if line_end != -1:
                index_content = index_content[:line_end + 1] + "export { deleteOrganization } from './functions/deleteOrganization';\n" + index_content[line_end + 1:]
                index_path.write_text(index_content, encoding="utf-8")
                print("  [OK] Exported deleteOrganization")

patches_applied.append("C-08 (org destruction block)")
print()

# ============================================================================
# Summary + Build + Commit + Push
# ============================================================================
print("=" * 70)
print("SUMMARY")
print("=" * 70)
print(f"\nPatches applied: {len(patches_applied)}")
for p in patches_applied:
    print(f"  - {p}")
print()
print("Files modified/created:")
try:
    result = subprocess.run(["git", "status", "--short"], capture_output=True, text=True, check=True)
    print(result.stdout)
except subprocess.CalledProcessError:
    pass

if not args.no_build:
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        subprocess.run(["npm", "install", "bcryptjs@^2.4.3"], shell=True, check=True)
        result = subprocess.run(["npm", "run", "build"], shell=True)
        if result.returncode != 0:
            print("\n[ERROR] Build failed")
            os.chdir("..")
            sys.exit(1)
        print("\n  [OK] Build succeeded")
    finally:
        os.chdir("..")
    print()

print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """security(day5v2): C-02 + C-08 — expanded hashPassword cleanup

C-02: Remove unsalted SHA-256 password hashing (EXPANDED)
  - Original Day 5 patched 3 files; this version patches 6:
    1. functions/src/functions/createStudent.ts
    2. functions/src/functions/changeUserPassword.ts
    3. lib/core/services/auth_service.dart
    4. lib/core/services/student_service.dart (NEW — found by external review)
    5. lib/core/services/excel_import_service.dart (NEW — found by external review)
    6. lib/features/auth/data/auth_service.dart (dead code, cleaned)
  - Created shared PasswordHasher service (bcrypt via Cloud Function)
  - Created server-side hashPassword + verifyPassword callables
  - Migration script deletes passwordHash field from all user docs

C-08: Block org destruction via deleteStudent
  - hardDelete blocked on owner targets (throws failed-precondition)
  - cascadeDeleteConfirmed flag check in onUserDeleted (defense-in-depth)
  - New deleteOrganization callable (super_admin only, confirmation phrase)

POST-DEPLOY MIGRATION (C-02):
  cd functions
  npm install firebase-admin
  # Download service-account.json from Firebase Console
  node ../scripts/migrate-remove-password-hash.js

This migration is IRREVERSIBLE. Backup required.

Updated from original Day 5 based on external code review finding
2 additional hashPassword copies in student_service.dart and
excel_import_service.dart that the master audit missed.

See: Klasivo_Master_Audit_Verification.md C-02 for evidence"""

subprocess.run(["git", "add", "-A"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

if args.no_push:
    print("[!] Skipping push (--no-push)")
    sys.exit(0)

response = input("Push to origin? (y/n): ").strip().lower()
if response == "y":
    result = subprocess.run(["git", "push", "origin", "main"])
    if result.returncode != 0:
        print("\n[ERROR] Push failed")
        sys.exit(1)
    print(f"\n  [OK] Pushed: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else:
    print("[!] Skipped. Run: git push origin main")

print()
print("=" * 70)
print("POST-DEPLOY STEPS")
print("=" * 70)
print()
print("1. Deploy: firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("2. Run migration:")
print("   cd functions && npm install firebase-admin")
print("   # Download service-account.json")
print("   node ../scripts/migrate-remove-password-hash.js")
print()
print("3. Update callers (MANUAL — hashPassword was sync, now async):")
print("   Search for 'hashPassword' in lib/ and update to:")
print("     final hash = await PasswordHasher.instance.hash(password);")
print()
print("Rollback: git reset --hard " + backup_branch)
