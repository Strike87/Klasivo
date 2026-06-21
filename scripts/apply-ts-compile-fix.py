#!/usr/bin/env python3
# ============================================================================
# Klasivo — Emergency Fix: TypeScript Compile Errors (Linux-adapted)
# ============================================================================
# Fixes 6 TypeScript compile errors blocking `firebase deploy`:
#
#   passwordHash.ts:79,80,82,83 — `const [k, v] = part.split('=')` can produce
#     undefined values under strict mode. Fix: use indexOf + substring with
#     explicit null checks.
#
#   rateLimiter.ts:101 — `firstRequestAt` is read on line 101 but is only
#     assigned in two of the three branches. Fix: initialize the declaration
#     AND assign it in the missing (within-window) else branch.
#
# Adapted from the user-supplied Windows script for the Linux sandbox at
# /home/z/my-project. Non-interactive (no `cd C:\Users\Strik\Klasivo`).
#
# Usage:
#   cd /home/z/my-project
#   python3 scripts/apply-ts-compile-fix.py
# ============================================================================

import sys
from pathlib import Path

REPO_ROOT = Path("/home/z/my-project")
import os
os.chdir(REPO_ROOT)

if not (REPO_ROOT / "functions/src/utils/passwordHash.ts").exists():
    print("ERROR: functions/src/utils/passwordHash.ts not found at", REPO_ROOT)
    sys.exit(1)

print("=" * 60)
print("Emergency Fix: TypeScript Compile Errors (Linux-adapted)")
print("=" * 60)
print()

# ============================================================================
# Fix 1: passwordHash.ts — Array destructuring undefined checks
# ============================================================================
print("--- Fix 1: passwordHash.ts (lines 77-83) ---")

ph_path = Path("functions/src/utils/passwordHash.ts")
ph_content = ph_path.read_text(encoding="utf-8")

# The exact pattern from the actual file (verified 2026-06-20)
old_block = """    for (const part of parts.slice(1, 4)) {
      const [k, v] = part.split('=');
      params[k] = parseInt(v, 10);
      if (isNaN(params[k])) return false;
    }
    const salt = Buffer.from(parts[4], 'hex');
    const expectedHash = Buffer.from(parts[5], 'hex');"""

new_block = """    for (const part of parts.slice(1, 4)) {
      const eqIdx = part.indexOf('=');
      if (eqIdx === -1) return false;
      const k = part.substring(0, eqIdx);
      const v = part.substring(eqIdx + 1);
      if (!k || !v) return false;
      params[k] = parseInt(v, 10);
      if (isNaN(params[k])) return false;
    }
    if (!parts[4] || !parts[5]) return false;
    const salt = Buffer.from(parts[4], 'hex');
    const expectedHash = Buffer.from(parts[5], 'hex');"""

if old_block in ph_content:
    ph_content = ph_content.replace(old_block, new_block)
    ph_path.write_text(ph_content, encoding="utf-8")
    print("  [OK] Fixed passwordHash.ts — replaced array destructuring with indexOf+substring")
    print("       Added null check for parts[4] and parts[5] before Buffer.from")
else:
    print("  [!] Exact pattern not found — attempting flexible match")
    # Flexible: just fix the destructuring + add the parts[4]/parts[5] guard
    old_flexible = """      const [k, v] = part.split('=');
      params[k] = parseInt(v, 10);
      if (isNaN(params[k])) return false;"""
    new_flexible = """      const eqIdx = part.indexOf('=');
      if (eqIdx === -1) return false;
      const k = part.substring(0, eqIdx);
      const v = part.substring(eqIdx + 1);
      if (!k || !v) return false;
      params[k] = parseInt(v, 10);
      if (isNaN(params[k])) return false;"""
    fixed = False
    if old_flexible in ph_content:
        ph_content = ph_content.replace(old_flexible, new_flexible)
        fixed = True

    # Add the parts[4]/parts[5] guard before Buffer.from (if not already present)
    if "if (!parts[4] || !parts[5]) return false;" not in ph_content:
        ph_content = ph_content.replace(
            "const salt = Buffer.from(parts[4], 'hex');",
            "if (!parts[4] || !parts[5]) return false;\n    const salt = Buffer.from(parts[4], 'hex');"
        )
        fixed = True

    if fixed:
        ph_path.write_text(ph_content, encoding="utf-8")
        print("  [OK] Fixed passwordHash.ts (flexible match)")
    else:
        print("  [!] Could not find pattern — manual fix needed")
        sys.exit(1)

print()

# ============================================================================
# Fix 2: rateLimiter.ts — Variable used before assignment
# ============================================================================
print("--- Fix 2: rateLimiter.ts (line 61 declaration + line 89 else branch) ---")

rl_path = Path("functions/src/utils/rateLimiter.ts")
rl_content = rl_path.read_text(encoding="utf-8")

# Fix 2a: Initialize the declaration (defense-in-depth)
old_decl = "  let firstRequestAt: number;"
new_decl = "  let firstRequestAt: number = now;  // TS fix: initialized to avoid 'used before assigned'"

if old_decl in rl_content:
    rl_content = rl_content.replace(old_decl, new_decl)
    print("  [OK] Fixed rateLimiter.ts line 61 — firstRequestAt initialized to 'now'")
else:
    print("  [!] Declaration pattern not found (may already be initialized)")

# Fix 2b: Assign firstRequestAt in the within-window else branch
# The actual code (verified 2026-06-20) has this exact block
old_else = """      // Within window — increment atomically
      newCount = (data.count || 0) + 1;
      await docRef.update({"""

new_else = """      // Within window — increment atomically
      newCount = (data.count || 0) + 1;
      firstRequestAt = firstMs;  // TS fix: assign before use at line 101
      await docRef.update({"""

if old_else in rl_content:
    rl_content = rl_content.replace(old_else, new_else)
    print("  [OK] Fixed rateLimiter.ts — firstRequestAt = firstMs in within-window branch")
else:
    print("  [!] Else-branch pattern not found (may already be fixed)")

rl_path.write_text(rl_content, encoding="utf-8")

print()
print("=" * 60)
print("FIXES COMPLETE")
print("=" * 60)
print()
print("Verifying with tsc --noEmit (next step)...")
