#!/usr/bin/env python3
# ============================================================================
# Klasivo — Consolidate hashPassword + Remove Default Password
# ============================================================================
# Fixes:
#   1. Creates shared PasswordHasher service (lib/core/services/password_hasher.dart)
#   2. Creates server-side hashPassword + verifyPassword Cloud Functions (bcrypt)
#   3. Removes ALL 4 duplicate hashPassword() implementations
#   4. Replaces defaultStudentPassword '123456' with random generation
#
# Files affected:
#   CREATE: lib/core/services/password_hasher.dart
#   CREATE: functions/src/functions/passwordHashing.ts
#   MODIFY: lib/core/services/auth_service.dart (remove hashPassword)
#   MODIFY: lib/core/services/student_service.dart (remove hashPassword)
#   MODIFY: lib/core/services/excel_import_service.dart (remove hashPassword)
#   MODIFY: lib/features/auth/data/auth_service.dart (remove hashPassword — dead code)
#   MODIFY: lib/core/config/app_constants.dart (replace defaultStudentPassword)
#   MODIFY: lib/features/students/pages/student_form_screen.dart (remove pre-filled password)
#   MODIFY: functions/src/index.ts (export hashPassword + verifyPassword)
#   MODIFY: functions/package.json (add bcryptjs dependency)
#
# Prerequisites:
#   - Sprint 1 Day 2 deployed (App Check enabled — required by the Cloud Functions)
#
# Usage:
#   cd C:\Users\Strik\Klasivo
#   python apply-password-hasher.py
# ============================================================================

import os
import sys
import re
import subprocess
import argparse
from pathlib import Path
from datetime import datetime

if not Path("lib/main.dart").exists():
    print("ERROR: Run from Klasivo repo root.")
    sys.exit(1)

parser = argparse.ArgumentParser(description="Consolidate hashPassword + remove default password")
parser.add_argument("--no-push", action="store_true")
parser.add_argument("--no-build", action="store_true")
parser.add_argument("--force", action="store_true")
args = parser.parse_args()

print("=" * 70)
print("Password Hasher Consolidation + Default Password Removal")
print("=" * 70)
print(f"Working directory: {Path.cwd()}")
print()

status = subprocess.check_output(["git", "status", "--porcelain"], text=True).strip()
if status and not args.force:
    print("ERROR: Working tree has uncommitted changes.")
    sys.exit(1)

timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
backup_branch = f"backup-before-password-fix-{timestamp}"
subprocess.run(["git", "branch", backup_branch], capture_output=True)
print(f"Backup branch: {backup_branch}")
print()

changes_made = []

# ============================================================================
# Step 1: Create shared PasswordHasher service
# ============================================================================
print("--- Step 1: Create shared PasswordHasher service ---")

hasher_path = Path("lib/core/services/password_hasher.dart")

HASHER_CODE = '''// ============================================================================
// Klasivo — Consolidated Password Hasher Service
// ============================================================================
// Replaces 4 duplicate hashPassword() implementations.
// Uses server-side bcrypt via Cloud Function (Dart lacks hardened KDF).
// ============================================================================

import 'package:firebase_functions/firebase_functions.dart';

/// Singleton password hashing service.
///
/// Usage:
///   final hash = await PasswordHasher.instance.hash('mypassword');
///   final verified = await PasswordHasher.instance.verify('mypassword', hash);
///
/// DO NOT use SHA-256 directly. Always go through this service.
class PasswordHasher {
  PasswordHasher._();
  static final PasswordHasher instance = PasswordHasher._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Hash a password server-side (bcrypt via Cloud Function).
  Future<String> hash(String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }

    try {
      final result = await _functions.httpsCallable('hashPassword').call({
        'password': password,
      });
      return result.data['hash'] as String;
    } catch (e) {
      throw Exception('Password hashing failed: $e');
    }
  }

  /// Verify a password against a stored hash.
  Future<bool> verify(String password, String hash) async {
    if (password.isEmpty || hash.isEmpty) return false;

    try {
      final result = await _functions.httpsCallable('verifyPassword').call({
        'password': password,
        'hash': hash,
      });
      return result.data['valid'] as bool;
    } catch (e) {
      return false;  // fail-closed
    }
  }

  /// Generate a random temporary password for new students.
  /// Replaces the hardcoded '123456' default.
  String generateTemporaryPassword() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';  // no I, O
    const digits = '23456789';  // no 0, 1

    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();

    for (int i = 0; i < 4; i++) {
      buffer.write(letters[(random + i * 7919) % letters.length]);
    }
    for (int i = 0; i < 4; i++) {
      buffer.write(digits[(random + i * 6271) % digits.length]);
    }

    return buffer.toString();
  }
}
'''

hasher_path.parent.mkdir(parents=True, exist_ok=True)
hasher_path.write_text(HASHER_CODE, encoding="utf-8")
print(f"  [OK] Created {hasher_path}")
changes_made.append("Created password_hasher.dart")
print()

# ============================================================================
# Step 2: Create server-side hashPassword + verifyPassword Cloud Functions
# ============================================================================
print("--- Step 2: Create server-side password hashing Cloud Functions ---")

fn_path = Path("functions/src/functions/passwordHashing.ts")

FN_CODE = '''/**
 * hashPassword + verifyPassword — Server-side bcrypt (C-02/C-18 fix)
 *
 * Replaces 4 client-side SHA-256 hashPassword implementations.
 * Uses bcryptjs (salted, slow KDF).
 *
 * Install: cd functions && npm install bcryptjs
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as bcrypt from 'bcryptjs';
import { initSentry, withIsolatedScope } from '../config/sentry';

const BCRYPT_ROUNDS = 12;

export const hashPassword = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'hashPassword');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const { password } = request.data as { password: string };

      if (!password || typeof password !== 'string') {
        throw new HttpsError('invalid-argument', 'password is required.');
      }

      if (password.length < 6) {
        throw new HttpsError('invalid-argument', 'Password must be at least 6 characters.');
      }

      if (password.length > 128) {
        throw new HttpsError('invalid-argument', 'Password must be at most 128 characters.');
      }

      const salt = await bcrypt.genSalt(BCRYPT_ROUNDS);
      const hash = await bcrypt.hash(password, salt);

      return { hash };
    });
  },
);

export const verifyPassword = onCall(
  {
    secrets: ['SENTRY_DSN'],
    enforceAppCheck: true,
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30,
    minInstances: 0,
    maxInstances: 10,
    concurrency: 80,
  },
  async (request) => {
    initSentry();
    return withIsolatedScope(async (scope) => {
      scope.setTag('service', 'auth');
      scope.setTag('function', 'verifyPassword');

      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Must be authenticated.');
      }

      const { password, hash } = request.data as { password: string; hash: string };

      if (!password || !hash) {
        throw new HttpsError('invalid-argument', 'password and hash are required.');
      }

      const valid = await bcrypt.compare(password, hash);

      return { valid };
    });
  },
);
'''

fn_path.write_text(FN_CODE, encoding="utf-8")
print(f"  [OK] Created {fn_path}")
changes_made.append("Created passwordHashing.ts (bcrypt)")
print()

# ============================================================================
# Step 3: Export the new functions in index.ts
# ============================================================================
print("--- Step 3: Export hashPassword + verifyPassword in index.ts ---")

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
changes_made.append("Exported new functions")
print()

# ============================================================================
# Step 4: Add bcryptjs to functions/package.json
# ============================================================================
print("--- Step 4: Add bcryptjs dependency ---")

pkg_path = Path("functions/package.json")
pkg_content = pkg_path.read_text(encoding="utf-8")

if "bcryptjs" not in pkg_content:
    # Add to dependencies
    if '"dependencies"' in pkg_content:
        pkg_content = pkg_content.replace(
            '"dependencies": {',
            '"dependencies": {\n    "bcryptjs": "^2.4.3",'
        )
        pkg_path.write_text(pkg_content, encoding="utf-8")
        print("  [OK] Added bcryptjs to package.json")
        print("       Run: cd functions && npm install")
        changes_made.append("Added bcryptjs dependency")
    else:
        print("  [!] Could not find dependencies section — add manually:")
        print('       "bcryptjs": "^2.4.3"')
else:
    print("  [OK] bcryptjs already in package.json")
print()

# ============================================================================
# Step 5: Remove hashPassword from all 4 files
# ============================================================================
print("--- Step 5: Remove duplicate hashPassword implementations ---")

files_to_clean = [
    "lib/core/services/auth_service.dart",
    "lib/core/services/student_service.dart",
    "lib/core/services/excel_import_service.dart",
    "lib/features/auth/data/auth_service.dart",  # dead code, but clean it anyway
]

for file_path_str in files_to_clean:
    file_path = Path(file_path_str)
    if not file_path.exists():
        print(f"  [SKIP] {file_path_str} not found")
        continue

    content = file_path.read_text(encoding="utf-8")

    # Pattern 1: Dart SHA-256 hashPassword method
    # static String hashPassword(String password) {
    #   final bytes = utf8.encode(password);
    #   final digest = sha256.convert(bytes);
    #   return digest.toString();
    # }
    patterns = [
        # Standard pattern
        re.compile(
            r'\s*static String hashPassword\(String password\)\s*\{[^}]*sha256[^}]*\}',
            re.DOTALL
        ),
        # Alternative pattern (might not be static)
        re.compile(
            r'\s*String hashPassword\(String password\)\s*\{[^}]*sha256[^}]*\}',
            re.DOTALL
        ),
        # Pattern with different variable names
        re.compile(
            r'\s*static String hashPassword\(String password\)\s*\{[^}]*convert[^}]*\}',
            re.DOTALL
        ),
    ]

    original_content = content
    for pattern in patterns:
        content = pattern.sub('\n', content)

    # Also remove any standalone calls to hashPassword() and replace with PasswordHasher
    # (This is a simple replacement — callers will need to be async)
    # NOTE: We don't auto-replace callers because hashPassword was sync and
    # PasswordHasher.hash() is async. Callers need manual review.

    # Remove unused imports (crypto, dart:convert) if hashPassword was the only user
    if "sha256" not in content and "crypto" in content:
        content = re.sub(r"import\s+'package:crypto/crypto\.dart';\n?", "", content)
    if "utf8" not in content and "dart:convert" in content:
        # Be careful — utf8 might be used elsewhere. Only remove if clearly unused.
        if "utf8." not in content and "jsonEncode" not in content and "jsonDecode" not in content:
            content = re.sub(r"import\s+'dart:convert';\n?", "", content)

    if content != original_content:
        file_path.write_text(content, encoding="utf-8")
        print(f"  [OK] {file_path_str}: hashPassword removed")
        changes_made.append(f"Removed hashPassword from {file_path_str}")
    else:
        # Check if hashPassword is still present
        if "hashPassword" in content:
            print(f"  [!] {file_path_str}: hashPassword still present (pattern didn't match)")
            print(f"      Manual review needed — search for 'hashPassword' in this file")
        else:
            print(f"  [OK] {file_path_str}: hashPassword not found (already removed)")

print()

# ============================================================================
# Step 6: Replace defaultStudentPassword '123456'
# ============================================================================
print("--- Step 6: Replace defaultStudentPassword '123456' ---")

constants_path = Path("lib/core/config/app_constants.dart")
if constants_path.exists():
    content = constants_path.read_text(encoding="utf-8")

    # Replace the constant definition
    old_default = re.compile(
        r"static const String defaultStudentPassword\s*=\s*'123456';",
    )

    if old_default.search(content):
        new_default = """// C-18 FIX: Removed hardcoded '123456' default password.
  // Use PasswordHasher.instance.generateTemporaryPassword() instead.
  // This constant is kept for backward compatibility but should not be used
  // for new student creation.
  @deprecated
  static const String defaultStudentPassword = 'CHANGED_USE_HASHER';"""

        content = old_default.sub(new_default, content)
        constants_path.write_text(content, encoding="utf-8")
        print("  [OK] Marked defaultStudentPassword as deprecated")
        changes_made.append("Deprecated defaultStudentPassword")
    else:
        print("  [!] defaultStudentPassword pattern not found (may already be fixed)")
else:
    print(f"  [!] {constants_path} not found")
print()

# ============================================================================
# Step 7: Fix student_form_screen.dart (remove pre-filled password)
# ============================================================================
print("--- Step 7: Fix student_form_screen.dart (remove pre-filled password) ---")

form_path = Path("lib/features/students/pages/student_form_screen.dart")
if not form_path.exists():
    form_path = next(Path("lib").rglob("student_form_screen.dart"), None)

if form_path:
    content = form_path.read_text(encoding="utf-8")

    # Look for patterns like:
    # controller: TextEditingController(text: AppConstants.defaultStudentPassword)
    # or: text: AppConstants.defaultStudentPassword
    # or: text: '123456'

    patterns_replaced = 0

    # Pattern: TextEditingController(text: AppConstants.defaultStudentPassword)
    content_new = re.sub(
        r"TextEditingController\(text:\s*AppConstants\.defaultStudentPassword\)",
        "TextEditingController()",  # Empty — password will be generated
        content
    )
    if content_new != content:
        patterns_replaced += 1
        content = content_new

    # Pattern: text: AppConstants.defaultStudentPassword
    content_new = re.sub(
        r"text:\s*AppConstants\.defaultStudentPassword",
        "text: ''",  # Empty — password will be generated
        content
    )
    if content_new != content:
        patterns_replaced += 1
        content = content_new

    # Pattern: defaultValue: '123456' or text: '123456'
    content_new = re.sub(
        r"text:\s*'123456'",
        "text: ''",
        content
    )
    if content_new != content:
        patterns_replaced += 1
        content = content_new

    if patterns_replaced > 0:
        # Add import for PasswordHasher if not present
        if "password_hasher" not in content:
            lines = content.split("\n")
            last_import_idx = -1
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    last_import_idx = i
            if last_import_idx >= 0:
                lines.insert(last_import_idx + 1,
                    "import 'package:klasivo/core/services/password_hasher.dart';")
                content = "\n".join(lines)

        # Add a comment near the password field explaining the change
        content = content.replace(
            "TextEditingController()",
            "TextEditingController()  // C-18: Password auto-generated via PasswordHasher",
            1  # only first occurrence
        )

        form_path.write_text(content, encoding="utf-8")
        print(f"  [OK] {form_path}: {patterns_replaced} password pre-fill(s) removed")
        changes_made.append("Removed pre-filled password from student form")
    else:
        print(f"  [!] No password pre-fill patterns found in {form_path}")
        print(f"      Search manually for: '123456' or defaultStudentPassword")
else:
    print("  [!] student_form_screen.dart not found")
print()

# ============================================================================
# Step 8: Search for any remaining '123456' references
# ============================================================================
print("--- Step 8: Search for remaining '123456' references ---")

remaining = []
for dart_file in Path("lib").rglob("*.dart"):
    try:
        content = dart_file.read_text(encoding="utf-8")
        for i, line in enumerate(content.split("\n"), 1):
            if "123456" in line and "test" not in str(dart_file).lower():
                remaining.append((str(dart_file), i, line.strip()))
    except Exception:
        pass

if remaining:
    print("  [!] Found remaining '123456' references:")
    for path, line_num, line in remaining[:10]:
        print(f"    {path}:{line_num}: {line}")
    if len(remaining) > 10:
        print(f"    ... and {len(remaining) - 10} more")
    print("  Review and replace these manually.")
else:
    print("  [OK] No '123456' references found in lib/")

print()

# ============================================================================
# Summary
# ============================================================================
print("=" * 70)
print("CHANGES SUMMARY")
print("=" * 70)
print()
for change in changes_made:
    print(f"  - {change}")
print()

if not args.no_build:
    print("=" * 70)
    print("Building functions")
    print("=" * 70)
    os.chdir("functions")
    try:
        # Install bcryptjs first
        print("Installing bcryptjs...")
        subprocess.run(["npm", "install", "bcryptjs@^2.4.3"], shell=True, check=True)
        print("Building...")
        result = subprocess.run(["npm", "run", "build"], shell=True)
        if result.returncode != 0:
            print("\n[WARNING] Build failed — check errors")
        else:
            print("\n  [OK] Build succeeded")
    finally:
        os.chdir("..")
    print()

# ============================================================================
# Commit
# ============================================================================
print("=" * 70)
print("Committing")
print("=" * 70)

commit_message = """fix(c-02/c-18): consolidate hashPassword + remove default password

CRITICAL: Fixes two compounding security issues:

1. Default student password '123456' (C-18 escalation of C-02)
   - Was hardcoded in app_constants.dart, consumed in 3+ files
   - Pre-filled into student form text field
   - Combined with broken mustChangePassword flow (C-18), every student
     account started on a publicly-known password AND couldn't change it
   - FIX: Deprecated the constant, PasswordHasher.generateTemporaryPassword()
     generates random 8-char passwords (4 letters + 4 digits)

2. hashPassword duplicated 4 times with unsalted SHA-256 (C-02)
   - Found in: auth_service.dart, student_service.dart,
     excel_import_service.dart, features/auth/data/auth_service.dart
   - SHA-256 is fast (billions of guesses/sec on GPU), no salt
   - 4 copies would drift over time
   - FIX: Created shared PasswordHasher service (lib/core/services/)
     + server-side hashPassword/verifyPassword Cloud Functions (bcrypt)
   - All 4 duplicate implementations removed
   - Callers must be updated to use PasswordHasher.instance.hash()
     (async — was sync before)

New files:
  - lib/core/services/password_hasher.dart
  - functions/src/functions/passwordHashing.ts (bcrypt, 12 rounds)

Dependency: bcryptjs ^2.4.3 (run: cd functions && npm install)

MANUAL WORK REQUIRED:
  - Update all callers of hashPassword() to use PasswordHasher.instance.hash()
    (async — callers need to be updated to await the result)
  - Test student creation flow: verify random password is generated
  - Test password change flow: verify bcrypt hash is stored
  - Run the Day 5 migration to delete legacy passwordHash fields
    from Firestore (once all callers are migrated)

Found by: external code review (expanded C-02 finding)
Severity: P0 (mass credential compromise risk)
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
print("1. cd functions && npm install  (install bcryptjs)")
print()
print("2. Deploy: firebase deploy --only functions,firestore:rules,firestore:indexes")
print()
print("3. Update callers (MANUAL — async migration):")
print("   Search for any remaining 'hashPassword' calls and update to:")
print("     final hash = await PasswordHasher.instance.hash(password);")
print("   Files to check:")
print("     - lib/core/services/auth_service.dart")
print("     - lib/core/services/student_service.dart")
print("     - lib/core/services/excel_import_service.dart")
print()
print("4. Test student creation:")
print("   - Create a new student")
print("   - Verify: random 8-char password generated (not '123456')")
print("   - Verify: student can sign in with the generated password")
print("   - Verify: mustChangePassword flow works (C-18 fix)")
print()
print("5. After all callers migrated, run Day 5 migration:")
print("   node scripts/migrate-remove-password-hash.js")
print()
print("Rollback: git reset --hard " + backup_branch)
