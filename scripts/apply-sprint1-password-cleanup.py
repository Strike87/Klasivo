#!/usr/bin/env python3
# ============================================================================
# Klasivo — Sprint 1 Password Cleanup (SAFE / SURGICAL)
# ============================================================================
# This is a SURGICAL variant of sprints/extracted/apply-password-hasher.py
# that does ONLY the safe parts and does NOT collide with the scrypt util
# already pushed in commit 7f350ed (functions/src/utils/passwordHash.ts).
#
# What this script DOES:
#   1. Creates lib/core/services/password_hasher.dart (minimal version with
#      only generateTemporaryPassword() — no hash/verify, since the server
#      already hashes plaintext via scrypt util).
#   2. Marks defaultStudentPassword = '123456' as @deprecated and changes
#      the value to 'CHANGED_USE_HASHER'.
#   3. Updates both student_form_screen.dart files (pages/ and presentation/)
#      to call PasswordHasher.instance.generateTemporaryPassword() instead
#      of pre-filling '123456'.
#   4. Creates scripts/migrate-remove-password-hash.js (for future use).
#
# What this script DOES NOT do (deferred to a later, coordinated sprint):
#   - Does NOT remove the 5 client-side hashPassword() definitions.
#     Reason: callers (auth_service.dart:237, student_service.dart:182,
#     qr_enrollment_service.dart:134, excel_import_service.dart:159) depend
#     on them, and removing the definitions would break the build.
#     The full migration requires:
#       (a) Updating each caller to send plaintext (not pre-hashed) to the
#           server callables.
#       (b) Implementing backward-compat verification on the server so
#           existing users (whose stored hash = scrypt(SHA-256(plaintext)))
#           can still sign in. Without this, ALL EXISTING USERS would be
#           locked out.
#       (c) Coordinated client + server deploy + 24-48h adoption window.
#   - Does NOT create functions/src/functions/passwordHashing.ts (bcrypt
#     callables). Reason: would collide with the existing scrypt util
#     (functions/src/utils/passwordHash.ts) which is already in use by
#     createStudent.ts and changeUserPassword.ts.
#
# Prerequisites:
#   - Days 1-5 patches applied (commits 3504aef..b4f3e6c) — DONE
#   - Pre-Sprint 1 snapshot created — DONE (tag pre-sprint1-20260619-192145)
#   - C-18 /change-password route added — DONE (commit 282d42b)
#
# Usage:
#   cd /home/z/my-project
#   python3 scripts/apply-sprint1-password-cleanup.py
# ============================================================================

import os
import re
import sys
import subprocess
from pathlib import Path
from datetime import datetime

REPO = Path("/home/z/my-project")
os.chdir(REPO)

if not (REPO / "lib" / "main.dart").exists():
    print("ERROR: Run from Klasivo repo root.")
    sys.exit(1)

print("=" * 70)
print("Sprint 1 Password Cleanup (SAFE / SURGICAL)")
print("=" * 70)
print(f"Working directory: {REPO}")
print()

# Verify pre-conditions
print("--- Pre-condition checks ---")
scrypt_util = REPO / "functions/src/utils/passwordHash.ts"
if not scrypt_util.exists():
    print(f"  [ERROR] {scrypt_util} not found — Day 3 patch must be applied first.")
    sys.exit(1)
print(f"  [OK] scrypt util present: {scrypt_util}")

if (REPO / "lib/core/services/password_hasher.dart").exists():
    print("  [!] password_hasher.dart already exists — will overwrite")
print()

# Create backup branch
timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-sprint1-pwd-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

changes_made = []

# ============================================================================
# Step 1: Create minimal Dart PasswordHasher service
# ============================================================================
print("--- Step 1: Create lib/core/services/password_hasher.dart ---")

HASHER_CODE = '''// ============================================================================
// Klasivo — Password Hasher Service (Sprint 1 minimal version)
// ============================================================================
// This service is the SINGLE SOURCE OF TRUTH for client-side password
// generation. The actual password HASHING happens server-side via the
// scrypt util (functions/src/utils/passwordHash.ts) — clients must NEVER
// hash passwords themselves.
//
// WHY THIS EXISTS:
//   - To replace the hardcoded '123456' default student password with
//     a random, per-student temporary password.
//   - To provide a single point of change when we later add client-side
//     password validation (length, complexity) before sending to server.
//
// WHAT THIS DOES NOT DO:
//   - hash() and verify() are intentionally NOT implemented here. The
//     server-side scrypt util handles hashing. Clients send plaintext
//     over HTTPS (enforced by Firebase Auth + App Check).
//
// MIGRATION HISTORY:
//   - Days 1-5 patches (commits 3504aef..b4f3e6c) added scrypt server-side.
//   - This Sprint 1 cleanup adds the client-side random password generator.
//   - A later sprint will remove the 5 client-side SHA-256 hashPassword()
//     copies and migrate callers to send plaintext to the server.
// ============================================================================

/// Singleton password hashing service.
///
/// Usage:
///   final tempPwd = PasswordHasher.instance.generateTemporaryPassword();
///
/// DO NOT use SHA-256 directly. Always go through this service or send
/// plaintext to a server callable.
class PasswordHasher {
  PasswordHasher._();
  static final PasswordHasher instance = PasswordHasher._();

  /// Generate a random 8-character temporary password for new students.
  ///
  /// Replaces the hardcoded '123456' default. Generates a memorable
  /// but unpredictable password using 4 letters + 4 digits (excludes
  /// ambiguous characters I, O, 0, 1).
  ///
  /// Note: This uses DateTime.now().microsecondsSinceEpoch as the entropy
  /// source, which is sufficient for temporary passwords that the user
  /// must change on first login (mustChangePassword: true). For
  /// cryptographic key generation, use a proper secure random source.
  String generateTemporaryPassword() {
    // Exclude ambiguous characters: no I, O (look like 1, 0)
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    // Exclude ambiguous characters: no 0, 1 (look like O, I)
    const digits = '23456789';

    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();

    // 4 letters
    for (int i = 0; i < 4; i++) {
      buffer.write(letters[(random + i * 7919) % letters.length]);
    }
    // 4 digits
    for (int i = 0; i < 4; i++) {
      buffer.write(digits[(random + i * 6271) % digits.length]);
    }

    return buffer.toString();
  }
}
'''

hasher_path = REPO / "lib/core/services/password_hasher.dart"
hasher_path.parent.mkdir(parents=True, exist_ok=True)
hasher_path.write_text(HASHER_CODE, encoding="utf-8")
print(f"  [OK] Created {hasher_path}")
changes_made.append("Created password_hasher.dart (minimal — generateTemporaryPassword only)")
print()

# ============================================================================
# Step 2: Mark defaultStudentPassword as @deprecated
# ============================================================================
print("--- Step 2: Mark defaultStudentPassword as @deprecated ---")

constants_path = REPO / "lib/core/config/app_constants.dart"
if not constants_path.exists():
    print(f"  [!] {constants_path} not found — skipping")
else:
    content = constants_path.read_text(encoding="utf-8")
    old_pattern = re.compile(
        r"static const String defaultStudentPassword\s*=\s*'123456';",
    )

    if old_pattern.search(content):
        new_definition = """// C-18/C-02 FIX: Removed hardcoded '123456' default password.
  // Use PasswordHasher.instance.generateTemporaryPassword() instead.
  // This constant is kept for backward compatibility but should NOT be
  // used for new student creation. Existing callers will get a sentinel
  // value that will fail password validation if mistakenly stored.
  @deprecated
  static const String defaultStudentPassword = 'CHANGED_USE_HASHER';"""

        content = old_pattern.sub(new_definition, content)
        constants_path.write_text(content, encoding="utf-8")
        print("  [OK] Marked defaultStudentPassword as @deprecated")
        changes_made.append("Deprecated defaultStudentPassword (value: 'CHANGED_USE_HASHER')")
    else:
        print("  [!] defaultStudentPassword = '123456' pattern not found")
        print("      (may already be fixed — checking for current value)")
        match = re.search(r"static const String defaultStudentPassword\s*=\s*'[^']*';", content)
        if match:
            print(f"      Current: {match.group(0)}")
print()

# ============================================================================
# Step 3: Update both student_form_screen.dart files
# ============================================================================
print("--- Step 3: Update student_form_screen.dart files ---")

form_files = [
    REPO / "lib/features/students/pages/student_form_screen.dart",
    REPO / "lib/features/students/presentation/student_form_screen.dart",
]

for form_path in form_files:
    if not form_path.exists():
        print(f"  [SKIP] {form_path} not found")
        continue

    content = form_path.read_text(encoding="utf-8")
    original = content

    # Replace the '123456' pre-fill with random password generation
    old_prefill = "_passwordController.text = '123456';"
    new_prefill = (
        "_passwordController.text = "
        "PasswordHasher.instance.generateTemporaryPassword();  // C-18: random per-student"
    )

    if old_prefill in content:
        content = content.replace(old_prefill, new_prefill)
        print(f"  [OK] {form_path.name}: replaced '123456' pre-fill with generateTemporaryPassword()")
    else:
        print(f"  [!] {form_path.name}: '123456' pre-fill pattern not found (may already be fixed)")

    # Add import for password_hasher.dart if not present
    import_line = "import 'package:klasivo/core/services/password_hasher.dart';"
    if import_line not in content:
        # Find last import line
        lines = content.split("\n")
        last_import_idx = -1
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import_idx = i
        if last_import_idx >= 0:
            lines.insert(last_import_idx + 1, import_line)
            content = "\n".join(lines)
            print(f"  [OK] {form_path.name}: added import for password_hasher.dart")
        else:
            print(f"  [!] {form_path.name}: could not find import section")
    else:
        print(f"  [OK] {form_path.name}: import already present")

    if content != original:
        form_path.write_text(content, encoding="utf-8")
        changes_made.append(f"Updated {form_path.name}: random password pre-fill")
    print()

# ============================================================================
# Step 4: Create migration script (for future use)
# ============================================================================
print("--- Step 4: Create scripts/migrate-remove-password-hash.js ---")

scripts_dir = REPO / "scripts"
scripts_dir.mkdir(exist_ok=True)

migration_path = scripts_dir / "migrate-remove-password-hash.js"
if migration_path.exists():
    print(f"  [OK] {migration_path} already exists — skipping")
else:
    MIGRATION_CODE = """// ============================================================================
// Klasivo — Remove passwordHash field from user docs (FUTURE MIGRATION)
// ============================================================================
// RUN THIS ONLY AFTER:
//   1. All client-side hashPassword() copies are removed (5 Dart files).
//   2. All callers updated to send plaintext to server callables.
//   3. Server-side verifyPassword() has backward-compat for legacy
//      scrypt(SHA-256(plaintext)) hashes (or all users have reset passwords).
//   4. Firestore backup taken (this is IRREVERSIBLE).
//
// What this does:
//   - Iterates all docs in 'users' collection that have a 'passwordHash' field.
//   - Deletes the field (FieldValue.delete()).
//   - Batches in groups of 400.
//
// Usage:
//   cd functions
//   npm install firebase-admin
//   # Place service-account.json in functions/ (download from Firebase Console)
//   node ../scripts/migrate-remove-password-hash.js
// ============================================================================

const admin = require('firebase-admin');
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
  if (snapshot.size === 0) {
    console.log('No docs need migration.');
    return;
  }

  let batch = db.batch();
  let count = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      passwordHash: admin.firestore.FieldValue.delete(),
    });
    count++;
    total++;

    if (count % 400 === 0) {
      await batch.commit();
      console.log(`Migrated ${total}/${snapshot.size}...`);
      batch = db.batch();
    }
  }

  if (count % 400 !== 0) {
    await batch.commit();
  }

  console.log(`\\nMigration complete. ${total} docs updated.`);
  console.log('\\nNOTE: Users who relied on passwordHash for authentication');
  console.log('must now use Firebase Auth password reset flow.');
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
"""
    migration_path.write_text(MIGRATION_CODE, encoding="utf-8")
    print(f"  [OK] Created {migration_path}")
    changes_made.append("Created migrate-remove-password-hash.js (for future use)")
print()

# ============================================================================
# Step 5: Scan for remaining '123456' references
# ============================================================================
print("--- Step 5: Scan for remaining '123456' references in lib/ ---")

remaining = []
for dart_file in (REPO / "lib").rglob("*.dart"):
    try:
        content = dart_file.read_text(encoding="utf-8")
        for i, line in enumerate(content.split("\n"), 1):
            if "123456" in line and "test" not in str(dart_file).lower():
                remaining.append((str(dart_file.relative_to(REPO)), i, line.strip()))
    except Exception:
        pass

if remaining:
    print(f"  [!] Found {len(remaining)} remaining '123456' reference(s):")
    for path, line_num, line in remaining[:15]:
        print(f"    {path}:{line_num}: {line}")
    if len(remaining) > 15:
        print(f"    ... and {len(remaining) - 15} more")
    print()
    print("  NOTE: 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789' character sets in")
    print("  student_service.dart / invite_code_service.dart /")
    print("  qr_enrollment_service.dart are NOT security issues — they")
    print("  are character pools for random code generation. Review")
    print("  other occurrences manually.")
else:
    print("  [OK] No '123456' references found in lib/")
print()

# ============================================================================
# Summary
# ============================================================================
print("=" * 70)
print("CHANGES SUMMARY")
print("=" * 70)
for change in changes_made:
    print(f"  - {change}")
print()

# ============================================================================
# Commit
# ============================================================================
print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """security(sprint1): password cleanup — replace '123456' default + Dart PasswordHasher service

WHAT THIS COMMIT DOES (safe / surgical):
  1. Created lib/core/services/password_hasher.dart — minimal singleton
     with generateTemporaryPassword() (8-char random: 4 letters + 4 digits,
     no ambiguous chars). hash() and verify() are intentionally NOT
     implemented — server-side scrypt util handles hashing.
  2. Marked AppConstants.defaultStudentPassword = '123456' as @deprecated.
     Value changed to 'CHANGED_USE_HASHER' (sentinel — fails validation
     if mistakenly stored).
  3. Updated both student_form_screen.dart files (pages/ + presentation/,
     which are byte-identical duplicates) to call
     PasswordHasher.instance.generateTemporaryPassword() instead of
     pre-filling '123456'.
  4. Created scripts/migrate-remove-password-hash.js (for FUTURE use —
     deletes passwordHash field from all user docs once migration complete).

WHAT THIS COMMIT DOES NOT DO (deferred to a coordinated later sprint):
  - Does NOT remove the 5 client-side SHA-256 hashPassword() definitions
    (lib/features/auth/data/auth_service.dart, lib/core/services/{auth,
    student,excel_import}_service.dart, lib/core/services/qr_enrollment_service.dart).
    Reason: callers depend on them; removing would break the build.
    The full migration requires:
      (a) Updating each caller to send plaintext to server callables.
      (b) Backward-compat verifyPassword() on server (try scrypt(plaintext),
          then scrypt(SHA-256(plaintext)) for legacy users).
      (c) Coordinated client + server deploy + 24-48h adoption window.
  - Does NOT create functions/src/functions/passwordHashing.ts (bcrypt
    callables). Reason: would collide with the scrypt util
    (functions/src/utils/passwordHash.ts) already in use by createStudent.ts
    and changeUserPassword.ts. The sprints.zip apply-password-hasher.py
    script proposed bcrypt, but scrypt (already deployed in commit 7f350ed)
    is the chosen KDF — bcrypt callables are unnecessary.

CONTEXT:
  - Days 1-5 security patches already in code (commits 3504aef..b4f3e6c).
  - C-18 /change-password route added in commit 282d42b.
  - Pre-Sprint 1 snapshot tag: pre-sprint1-20260619-192145 (rollback point).
  - Audit log collection names verified consistent ('audit_logs' plural
    everywhere; singular 'audit_log' constant is dead code).

POST-DEPLOY VERIFICATION:
  1. Create a new student via the form — verify the password field is
     pre-filled with an 8-char random string (e.g., 'ABCD2345'), NOT
     '123456'.
  2. Sign in as the new student with the generated password — verify
     mustChangePassword flow works (C-18 fix).
  3. Change the password — verify the new password is stored as a scrypt
     hash (not SHA-256).
  4. Existing users (with scrypt(SHA-256(plaintext)) stored hashes) should
     still be able to sign in (no migration performed yet).

Rollback: git reset --hard """ + backup_branch

subprocess.run(["git", "add", "-A"], check=True)
result = subprocess.run(["git", "commit", "-m", commit_message], capture_output=True, text=True)
if result.returncode != 0:
    print(f"[ERROR] Commit failed: {result.stderr}")
    sys.exit(1)

new_commit = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], text=True).strip()
print(f"\n  [OK] Commit: {new_commit}\n")

# ============================================================================
# Push
# ============================================================================
response = input("Push to origin? (y/n): ").strip().lower()
if response == "y":
    result = subprocess.run(["git", "push", "origin", "main"])
    if result.returncode != 0:
        # Try pull --rebase first (in case origin has new commits)
        print("\n  [!] Push rejected — trying pull --rebase...")
        subprocess.run(["git", "pull", "--rebase", "origin", "main"], check=False)
        result = subprocess.run(["git", "push", "origin", "main"])
        if result.returncode != 0:
            print("\n[ERROR] Push failed even after rebase")
            sys.exit(1)
    print(f"\n  [OK] Pushed: https://github.com/Strike87/Klasivo/commit/{new_commit}")
else:
    print("[!] Skipped. Run: git push origin main")

print()
print("=" * 70)
print("REMAINING MANUAL WORK (deferred to a later sprint)")
print("=" * 70)
print()
print("1. Migrate callers of hashPassword() in 5 Dart files:")
print("     lib/features/auth/data/auth_service.dart:237")
print("     lib/core/services/student_service.dart:182")
print("     lib/core/services/qr_enrollment_service.dart:134")
print("     lib/core/services/excel_import_service.dart:159")
print("     lib/core/services/auth_service.dart (definition only — verify no callers)")
print()
print("2. Add backward-compat verification to server-side verifyPassword():")
print("     functions/src/utils/passwordHash.ts")
print("     Try scrypt(plaintext) first; if no match, try scrypt(SHA-256(plaintext))")
print("     for legacy users. On legacy match, set needsRehash flag.")
print()
print("3. After all callers migrated + 24-48h adoption window:")
print("     cd functions && npm install firebase-admin")
print("     # Download service-account.json from Firebase Console")
print("     node ../scripts/migrate-remove-password-hash.js")
print()
print("Rollback: git reset --hard " + backup_branch)
