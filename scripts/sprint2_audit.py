#!/usr/bin/env python3
"""
Sprint 2 Audit — verifies Sprint 2 (RBAC Infrastructure) is production-grade
before starting Sprint 3 (Scope Enforcement + Teacher Approval + Assignment API).

Run from the repo root on Windows:
    python scripts/sprint2_audit.py

Or from anywhere:
    python C:\\Users\\Strik\\Klasivo\\scripts\\sprint2_audit.py

The script is read-only — it does not modify any files. It only:
  - Reads source files
  - Runs `flutter analyze`, `tsc --noEmit`, and `flutter test` (read-only)
  - Prints a report with PASS / FAIL / WARN / EXEMPT for each audit item

Output is also saved to sprint2_audit_report.txt in the repo root.

v2 (2026-06-24): False-positive reduction
  - Item 3: restrict syncClaims scan to actual CF files (skip utils/, services/, templates/)
  - Item 5: 3-tier exemption model — trigger CFs / register CFs / inline boundary checks
  - Item 7: distinguish expected Sprint 3B gaps (WARN) from regressions (FAIL)
  - Summary: explicit "true failures vs exempted" breakdown
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from datetime import datetime

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Resolve repo root: script lives in <repo>/scripts/sprint2_audit.py
REPO = Path(__file__).resolve().parent.parent
FUNCTIONS_SRC = REPO / "functions" / "src"
FUNCTIONS_DIR = FUNCTIONS_SRC / "functions"   # actual CF source files only
LIB_DIR = REPO / "lib"
TEST_DIR = REPO / "test"

REPORT_FILE = REPO / "sprint2_audit_report.txt"

# Extensions we scan for code patterns
CODE_EXTS = {".ts", ".dart", ".js"}

# Org-scoped collections (CFs touching these should call verifyOrgBoundary)
ORG_SCOPED_COLLECTIONS = {
    "users", "classes", "submissions", "attendance", "parent_links",
    "organizations", "assignments", "exams", "grades", "gradebook",
    "invites", "invite_codes", "audit_logs", "announcements", "messages",
    "campuses", "stages", "notifications", "student_links",
}

# ─── v2: Exemption rules for Item 5 ─────────────────────────────────────────

# Trigger CFs have no `request.auth` — they fire on Auth/Firestore/Schedule events.
# These cannot call verifyOrgBoundary because there is no caller to verify.
# Note: pattern is anchored on `.auth.user().` (not `functions.auth.user().`) so it
# also matches `functions.runWith({...}).auth.user().onCreate(...)` — the form used
# by onUserCreated.ts and onUserDeleted.ts which set runWith options first.
# The `\s*` between `user()` and `.onCreate` allows the dot to land on a new line
# (Klasivo's CFs format `functions.runWith({...}).auth.user()` and `.onCreate(...)`
# on separate lines for readability).
TRIGGER_PATTERNS = [
    r"\.auth\.user\(\)\s*\.(?:onCreate|onDelete)",
    r"\bonDocumentCreated\b",
    r"\bonDocumentUpdated\b",
    r"\bonDocumentWritten\b",
    r"\bonDocumentDeleted\b",
    r"\bonSchedule\b",
    r"\bonPublish\b",
    r"\bonObjectFinalized\b",
    r"\bonObjectMetadataUpdated\b",
    r"\bonObjectArchived\b",
    r"\bonObjectDeleted\b",
    r"\bonValueWritten\b",
    r"\bonValueCreated\b",
]

# Registration / link CFs: caller has no organization yet (they're creating one
# or being linked into one). Cannot verify an org boundary that doesn't exist.
REGISTER_CF_NAMES = {
    "registerOwner.ts",
    "registerParent.ts",
    "registerTeacher.ts",
    "redeemInviteCode.ts",
    "linkParent.ts",
    "linkParentToStudent.ts",
    "createStudent.ts",        # creates a new student — caller is staff, but target is brand-new
}

# Inline boundary check patterns — equivalent to verifyOrgBoundary but written
# by hand. We accept these as PASS with a WARN suggesting helper consolidation.
INLINE_BOUNDARY_PATTERNS = [
    # callerOrgId !== someVar   (the canonical inline form)
    r"callerOrgId\s*(?:!==|!=)\s*\w+",
    # something.organizationId !== callerOrgId
    r"\w+\.organizationId\s*(?:!==|!=)\s*callerOrgId",
    # callerOrgId === someVar inside a negated guard (rare but valid)
    r"if\s*\(\s*!\s*\(?\s*callerOrgId\s*(?:===|==)\s*\w+",
]

# ─── v2: Exemption rules for Item 7 ─────────────────────────────────────────

# Screens known to be planned for Sprint 3B "wire-up" work. They are unwired
# today by design — flagging them as FAIL would obscure real regressions.
SPRINT_3B_PLANNED_SCREENS = {
    "people_hub_screen.dart",
    "role_matrix_screen.dart",
    "user_detail_screen.dart",
    "scope_assignment_screen.dart",
    "effective_permissions_screen.dart",
    "permission_override_screen.dart",
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

class Report:
    def __init__(self):
        self.lines: list[str] = []
        self.passed = 0
        self.failed = 0
        self.warned = 0
        self.exempted = 0   # v2: tracked separately from PASS so the summary
                            # shows how many checks were "ok-but-exempted"

    def h(self, msg: str):
        line = f"\n{'='*72}\n  {msg}\n{'='*72}"
        print(line)
        self.lines.append(line)

    def sub(self, msg: str):
        line = f"\n--- {msg} ---"
        print(line)
        self.lines.append(line)

    def pass_(self, msg: str):
        self.passed += 1
        line = f"  [PASS] {msg}"
        print(line)
        self.lines.append(line)

    def fail(self, msg: str):
        self.failed += 1
        line = f"  [FAIL] {msg}"
        print(line)
        self.lines.append(line)

    def warn(self, msg: str):
        self.warned += 1
        line = f"  [WARN] {msg}"
        print(line)
        self.lines.append(line)

    def exempt(self, msg: str):
        """v2: A check that would have FAILED but is exempted by a documented rule.
        Counts toward a separate `exempted` bucket so users can audit the rules."""
        self.exempted += 1
        line = f"  [EXEMPT] {msg}"
        print(line)
        self.lines.append(line)

    def info(self, msg: str):
        line = f"  {msg}"
        print(line)
        self.lines.append(line)

    def save(self):
        REPORT_FILE.write_text("\n".join(self.lines), encoding="utf-8")
        print(f"\nReport saved to: {REPORT_FILE}")

R = Report()

# ---------------------------------------------------------------------------
# File scanning utilities
# ---------------------------------------------------------------------------

def iter_code_files(root: Path):
    """Yield all code files under root."""
    if not root.exists():
        return
    for p in root.rglob("*"):
        if p.is_file() and p.suffix in CODE_EXTS:
            # Skip node_modules, build artifacts, .dart_tool
            parts = p.parts
            if any(skip in parts for skip in ("node_modules", ".dart_tool", "build", ".git")):
                continue
            yield p

def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        return []

def grep_in_file(path: Path, pattern: str, flags=0) -> list[tuple[int, str]]:
    """Return list of (line_number, line_text) matches in a single file."""
    matches = []
    rx = re.compile(pattern, flags)
    for i, line in enumerate(read_lines(path), 1):
        if rx.search(line):
            matches.append((i, line.rstrip()))
    return matches

def grep_across(root: Path, pattern: str, flags=0) -> list[tuple[Path, int, str]]:
    """Return list of (path, line_number, line_text) matches across all code files under root."""
    results = []
    for p in iter_code_files(root):
        for line_no, line in grep_in_file(p, pattern, flags):
            results.append((p, line_no, line))
    return results

def list_cf_files() -> list[Path]:
    """List all Cloud Function source files (only files under functions/src/functions/)."""
    if not FUNCTIONS_DIR.exists():
        return []
    return sorted(FUNCTIONS_DIR.glob("*.ts"))

def list_index_exports() -> dict[str, Path]:
    """Parse functions/src/index.ts to find all exported CFs and their source files."""
    index = FUNCTIONS_SRC / "index.ts"
    exports = {}
    if not index.exists():
        return exports
    for line in read_lines(index):
        m = re.match(r"\s*export\s+\{\s*(\w+)\s*\}\s*from\s*['\"](.+)['\"]\s*;", line)
        if m:
            name, rel = m.group(1), m.group(2)
            exports[name] = (index.parent / rel).with_suffix(".ts")
    return exports

def is_trigger_cf(content: str) -> bool:
    """v2: detect if a CF file uses a trigger-based signature (no request.auth)."""
    for pat in TRIGGER_PATTERNS:
        if re.search(pat, content):
            return True
    return False

def has_inline_boundary_check(content: str) -> str | None:
    """v2: detect inline org-boundary check patterns. Returns the matched pattern or None."""
    for pat in INLINE_BOUNDARY_PATTERNS:
        m = re.search(pat, content)
        if m:
            return m.group(0)
    return None

def find_org_scoped_collection_access(content: str) -> set[str]:
    """v2.1: Find ACTUAL Firestore access to org-scoped collections.

    Previous versions used `\b{col}\b` which matched collection names in
    comments and string literals (e.g. "users but blocks script abuse" in
    sendContactForm.ts triggered a false `users` access hit).

    This function only matches real access patterns:
      - .collection('users')  /  .collection("users")
      - .doc('users/<id>')    /  .doc("users/<id>")
      - collectionGroup('users') / collectionGroup("users")
    """
    touched = set()
    for col in ORG_SCOPED_COLLECTIONS:
        # Match .collection('col') or .collection("col") with optional whitespace
        pat_collection = rf"\.collection\(\s*['\"]{re.escape(col)}['\"]\s*\)"
        # Match .doc('col/...') or .doc("col/...")
        pat_doc = rf"\.doc\(\s*['\"]{re.escape(col)}/"
        # Match collectionGroup('col') or collectionGroup("col")
        pat_group = rf"collectionGroup\(\s*['\"]{re.escape(col)}['\"]\s*\)"
        if (re.search(pat_collection, content)
                or re.search(pat_doc, content)
                or re.search(pat_group, content)):
            touched.add(col)
    return touched

# ---------------------------------------------------------------------------
# Audit Item 1: Deploy status (manual check — script just reminds)
# ---------------------------------------------------------------------------

def audit_item_1_deploy():
    R.h("Item 1: Registration CFs + Rules Deploy Status")
    R.info("This script CANNOT verify deploy status. You must manually confirm:")
    R.info("  1. Run: firebase deploy --only firestore:rules")
    R.info("  2. Run: firebase deploy --only functions:linkParent,functions:registerParent,")
    R.info("         functions:registerOwner,functions:redeemInviteCode,functions:registerTeacher,")
    R.info("         functions:onUserCreated")
    R.info("  3. Run: firebase functions:list  (confirm all 6 CFs are deployed)")
    R.warn("Manual verification required — deploy is not auditable from a script.")

# ---------------------------------------------------------------------------
# Audit Item 2: Smoke test (manual check — script just reminds)
# ---------------------------------------------------------------------------

def audit_item_2_smoke():
    R.h("Item 2: End-to-End Registration Smoke Test (Manual)")
    R.info("This script CANNOT run smoke tests. You must manually test:")
    R.info("  a. Register a new OWNER  → confirm org doc created, claims minted")
    R.info("  b. Register a new TEACHER (via invite code) → confirm role:teacher, orgId set")
    R.info("  c. Register a new PARENT (no studentCode) → confirm organizationId:'' ")
    R.info("     then link via 8-char code → confirm organizationId populated + claims re-minted")
    R.info("  d. Create a STUDENT via staff → confirm STU-XXXXXX code generated")
    R.info("  e. As the linked parent, read /parent/results → confirm no permission-denied")
    R.warn("Manual smoke test required — cannot be automated without real Firebase project.")

# ---------------------------------------------------------------------------
# Audit Item 3: syncClaims wiring   (v2: scan ONLY actual CF files)
# ---------------------------------------------------------------------------

def audit_item_3_sync_claims():
    R.h("Item 3: syncClaims — Is It Actually Called When Claims Change?")

    # 3a. Find syncClaims definition
    sync_claims_matches = grep_across(FUNCTIONS_SRC, r"export\s+(const|function)\s+syncClaims|export\s*\{\s*syncClaims\s*\}")
    if not sync_claims_matches:
        R.fail("syncClaims is not exported from any file under functions/src/")
        return

    sync_claims_file = sync_claims_matches[0][0]
    R.info(f"syncClaims defined in: {sync_claims_file.relative_to(REPO)}")

    # 3b. Is syncClaims registered in index.ts?
    index_exports = list_index_exports()
    if "syncClaims" in index_exports:
        R.pass_(f"syncClaims is exported via index.ts")
    else:
        # Check if it's a trigger (onCall, onDocumentCreated, etc.) instead of exported
        sc_content = sync_claims_file.read_text(encoding="utf-8", errors="ignore")
        if re.search(r"\bonCall\b|\bonDocumentCreated\b|\bonWrite\b|\bonUpdate\b", sc_content):
            R.pass_("syncClaims is a trigger (auto-invoked)")
        else:
            R.warn("syncClaims is neither exported in index.ts nor a trigger — may be dead code")

    # 3c. v2: Find all places that call setCustomUserClaims — but ONLY inside
    # actual CF files. Helpers in utils/ (e.g. rbac.ts:buildCustomClaims) do
    # not call setCustomUserClaims themselves; they only build the claims
    # object that a CF later passes to setCustomUserClaims. The previous
    # version of this audit falsely flagged rbac.ts as a "CF that mints claims
    # but doesn't call syncClaims".
    claims_calls = grep_across(FUNCTIONS_DIR, r"setCustomUserClaims\s*\(")
    R.info(f"Found {len(claims_calls)} setCustomUserClaims call sites (CF files only):")
    for path, line_no, line in claims_calls:
        R.info(f"  {path.relative_to(REPO)}:{line_no}")

    # 3d. For each CF that mints claims, check if syncClaims is also called nearby
    R.sub("Checking if syncClaims is invoked after each setCustomUserClaims")
    cf_files_with_claims = set()
    for path, line_no, _ in claims_calls:
        cf_files_with_claims.add(path)

    sync_claims_callers = grep_across(FUNCTIONS_SRC, r"syncClaims\s*\(")
    sync_claims_caller_files = {p for p, _, _ in sync_claims_callers}

    for cf_file in sorted(cf_files_with_claims):
        rel = cf_file.relative_to(REPO)
        if cf_file in sync_claims_caller_files:
            R.pass_(f"{rel}: calls syncClaims after minting claims")
        else:
            content = cf_file.read_text(encoding="utf-8", errors="ignore")
            # v2.1: registration/link CFs mint claims for brand-new users who
            # get them on first sign-in — no client-side syncClaims listener
            # exists yet. Exempt them (downgrade FAIL → WARN with clear reason).
            if cf_file.name in REGISTER_CF_NAMES:
                R.warn(f"{rel}: registration/link CF — claims minted for new user (picked up on first sign-in, no syncClaims needed)")
            elif "roleVersion" in content or "forceRefresh" in content or "refreshToken" in content:
                R.warn(f"{rel}: mints claims but doesn't call syncClaims (may rely on roleVersion client refresh)")
            else:
                R.fail(f"{rel}: mints claims with setCustomUserClaims but never calls syncClaims — claims may not propagate")

# ---------------------------------------------------------------------------
# Audit Item 4: rbac role hierarchy usage
# ---------------------------------------------------------------------------

def audit_item_4_rbac_hierarchy():
    R.h("Item 4: rbac.ts Role Hierarchy — Is Every CF Using It?")

    rbac_file = FUNCTIONS_SRC / "utils" / "rbac.ts"
    if not rbac_file.exists():
        # Try alternate locations
        rbac_matches = list(FUNCTIONS_SRC.rglob("rbac.ts"))
        if rbac_matches:
            rbac_file = rbac_matches[0]
        else:
            R.fail("rbac.ts not found under functions/src/")
            return

    R.info(f"rbac.ts at: {rbac_file.relative_to(REPO)}")

    # 4a. Find role hierarchy helper functions
    rbac_content = rbac_file.read_text(encoding="utf-8", errors="ignore")
    hierarchy_fns = re.findall(r"export\s+(?:const|function)\s+(\w*(?:[Hh]ierarchy|[Rr]ole[A-Z]\w*|hasRole|isRole|role[A-Z]\w*)\w*)", rbac_content)
    hierarchy_fns = list(set(hierarchy_fns))
    if hierarchy_fns:
        R.info(f"Role-hierarchy helpers found: {', '.join(hierarchy_fns)}")
    else:
        R.warn("No role-hierarchy helpers detected by name — check rbac.ts manually")

    # 4b. Find raw role comparisons in CFs (anti-pattern)
    raw_role_checks = grep_across(FUNCTIONS_DIR, r"role\s*===\s*['\"](owner|admin|teacher|parent|student|super_admin)['\"]")
    # Also catch role in array form
    raw_role_checks += grep_across(FUNCTIONS_DIR, r"\.role\s*(===|==|in)\s*")

    R.info(f"Found {len(raw_role_checks)} raw role check sites in CFs:")
    for path, line_no, line in raw_role_checks[:20]:  # cap output
        R.info(f"  {path.relative_to(REPO)}:{line_no}: {line.strip()[:100]}")
    if len(raw_role_checks) > 20:
        R.info(f"  ... and {len(raw_role_checks) - 20} more")

    # 4c. Find usage of rbac helpers in CFs
    if hierarchy_fns:
        helper_usage = 0
        for fn in hierarchy_fns:
            helper_usage += len(grep_across(FUNCTIONS_DIR, rf"\b{fn}\s*\("))
        R.info(f"rbac helper functions are called {helper_usage} times across CFs")

        if len(raw_role_checks) > helper_usage:
            R.warn(f"Raw role checks ({len(raw_role_checks)}) outnumber rbac helper calls ({helper_usage}) — consider centralizing")
        else:
            R.pass_(f"rbac helpers used more than raw role checks ({helper_usage} vs {len(raw_role_checks)})")
    else:
        if raw_role_checks:
            R.warn(f"{len(raw_role_checks)} raw role checks exist but no hierarchy helpers found — hard to maintain")

# ---------------------------------------------------------------------------
# Audit Item 5: verifyOrgBoundary usage   (v2: 3-tier exemption model)
# ---------------------------------------------------------------------------

def audit_item_5_org_boundary():
    R.h("Item 5: verifyOrgBoundary — Is It Called in Every Org-Scoped CF?")

    # 5a. Find verifyOrgBoundary definition
    vob_matches = grep_across(FUNCTIONS_SRC, r"export\s+(?:const|function)\s+verifyOrgBoundary|export\s*\{\s*verifyOrgBoundary\s*\}")
    if not vob_matches:
        R.fail("verifyOrgBoundary is not defined or exported under functions/src/")
        return

    vob_file = vob_matches[0][0]
    R.info(f"verifyOrgBoundary defined in: {vob_file.relative_to(REPO)}")

    # 5b. List all CFs and check which touch org-scoped collections
    cf_files = list_cf_files()
    if not cf_files:
        R.fail(f"No CF files found in {FUNCTIONS_DIR}")
        return

    R.info(f"Scanning {len(cf_files)} CF files for org-scoped collection access...")

    org_scoped_cfs = []
    non_org_cfs = []
    for cf in cf_files:
        content = cf.read_text(encoding="utf-8", errors="ignore")
        # v2.1: use real Firestore access detection instead of bare word match —
        # this eliminates false positives where collection names appear in
        # comments or unrelated string literals (e.g. sendContactForm.ts:25
        # mentions "users" in a rate-limit comment).
        touched = find_org_scoped_collection_access(content)
        if touched:
            org_scoped_cfs.append((cf, touched, content))
        else:
            non_org_cfs.append(cf)

    R.info(f"{len(org_scoped_cfs)} CFs touch org-scoped collections, {len(non_org_cfs)} don't")

    # 5c. v2: For each org-scoped CF, classify it into one of:
    #   (1) TRIGGER CF      → exempt (no caller to verify)
    #   (2) REGISTER/LINK CF → exempt (caller has no org yet)
    #   (3) Uses verifyOrgBoundary → PASS
    #   (4) Inline boundary check → PASS + WARN (consolidate to helper)
    #   (5) Nothing → FAIL
    R.sub("Checking each org-scoped CF for verifyOrgBoundary (or equivalent)")
    missing_vob = []
    exempt_trigger = 0
    exempt_register = 0
    inline_checked = 0

    for cf, touched, content in sorted(org_scoped_cfs, key=lambda x: x[0].name):
        # (1) Trigger CFs (Auth/Firestore/Schedule events — no request.auth)
        if is_trigger_cf(content):
            R.exempt(f"{cf.name}: trigger CF (no caller to verify) — touches {', '.join(sorted(touched))}")
            exempt_trigger += 1
            continue

        # (2) Registration / link CFs (caller has no org yet)
        if cf.name in REGISTER_CF_NAMES:
            R.exempt(f"{cf.name}: registration/link CF (caller has no org yet) — touches {', '.join(sorted(touched))}")
            exempt_register += 1
            continue

        # (3) Uses verifyOrgBoundary helper
        if "verifyOrgBoundary" in content:
            R.pass_(f"{cf.name}: calls verifyOrgBoundary (touches {', '.join(sorted(touched))})")
            continue

        # (4) Inline boundary check (callerOrgId !== X pattern)
        inline_match = has_inline_boundary_check(content)
        if inline_match:
            R.pass_(f"{cf.name}: uses inline boundary check (`{inline_match}`) — touches {', '.join(sorted(touched))})")
            R.warn(f"  → consider consolidating to verifyOrgBoundary() helper for consistency")
            inline_checked += 1
            continue

        # (5) Real failure — no boundary check at all
        R.fail(f"{cf.name}: touches {', '.join(sorted(touched))} but does NOT call verifyOrgBoundary or use an inline boundary check")
        missing_vob.append(cf.name)

    # 5d. Summary (info only — individual CFs already PASS/FAIL'd above)
    R.sub("Item 5 summary")
    if exempt_trigger:
        R.info(f"  {exempt_trigger} trigger CF(s) exempted (no caller to verify)")
    if exempt_register:
        R.info(f"  {exempt_register} registration/link CF(s) exempted (caller has no org yet)")
    if inline_checked:
        R.info(f"  {inline_checked} CF(s) use inline boundary check (PASS + WARN for consolidation)")

    if missing_vob:
        R.info(f"  → {len(missing_vob)} CF(s) truly missing verifyOrgBoundary — listed above as FAIL: {', '.join(missing_vob)}")
    else:
        R.pass_("All org-scoped CFs either call verifyOrgBoundary, use inline checks, or are exempted by rule")

# ---------------------------------------------------------------------------
# Audit Item 6: Build checks (tsc + flutter analyze)
# ---------------------------------------------------------------------------

def run_cmd(cmd: list[str], cwd: Path, timeout: int = 180) -> tuple[int, str]:
    try:
        result = subprocess.run(
            cmd, cwd=str(cwd), capture_output=True, text=True,
            timeout=timeout, shell=(os.name == "nt")
        )
        return result.returncode, (result.stdout + result.stderr)
    except subprocess.TimeoutExpired:
        return -1, "TIMEOUT"
    except FileNotFoundError as e:
        return -2, f"Command not found: {e}"
    except Exception as e:
        return -3, str(e)

def audit_item_6_builds():
    R.h("Item 6: Build Checks — tsc + flutter analyze")

    # 6a. TypeScript compile check
    R.sub("Running: tsc --noEmit in functions/")
    functions_dir = REPO / "functions"
    if not (functions_dir / "tsconfig.json").exists():
        R.fail("functions/tsconfig.json not found")
    else:
        code, output = run_cmd(["npx", "tsc", "--noEmit"], cwd=functions_dir, timeout=180)
        if code == 0:
            R.pass_("TypeScript compiles clean (0 errors)")
        elif code == -2:
            R.warn("npx/tsc not found — install Node.js + run `npm install` in functions/")
        else:
            # v2.1: distinguish "real TS errors" from "tsc exited non-zero for other reasons"
            # (e.g. npx install prompt, deprecation warnings, missing tsconfig)
            error_lines = [l for l in output.splitlines() if "error TS" in l]
            if error_lines:
                R.fail(f"TypeScript has {len(error_lines)} errors")
                for line in error_lines[:10]:
                    R.info(f"  {line.strip()[:120]}")
                if len(error_lines) > 10:
                    R.info(f"  ... and {len(error_lines) - 10} more")
            else:
                # tsc exited non-zero but produced no `error TS` lines — show the
                # actual output so the user can see why (npx prompt, etc.)
                R.fail(f"tsc exited with code {code} but no `error TS` lines found — see output below")
                # Show first 10 non-empty lines (skip npm/npx noise)
                meaningful_lines = [l for l in output.splitlines() if l.strip()]
                for line in meaningful_lines[:10]:
                    R.info(f"  {line.strip()[:120]}")
                if len(meaningful_lines) > 10:
                    R.info(f"  ... and {len(meaningful_lines) - 10} more")

    # 6b. Flutter analyze
    R.sub("Running: flutter analyze")
    code, output = run_cmd(["flutter", "analyze"], cwd=REPO, timeout=300)
    if code == 0:
        R.pass_("flutter analyze clean (0 issues)")
    elif code == -2:
        R.warn("flutter not found on PATH — install Flutter SDK")
    else:
        # Count issues
        issue_lines = [l for l in output.splitlines() if re.search(r"\.dart:\d+:\d+\s+", l)]
        errors = [l for l in issue_lines if "error •" in l]
        warnings = [l for l in issue_lines if "warning •" in l]
        infos = [l for l in issue_lines if "info •" in l]
        if errors:
            R.fail(f"flutter analyze: {len(errors)} errors, {len(warnings)} warnings, {len(infos)} infos")
            for line in errors[:10]:
                R.info(f"  {line.strip()[:120]}")
        else:
            R.warn(f"flutter analyze: 0 errors, {len(warnings)} warnings, {len(infos)} infos (non-blocking)")

# ---------------------------------------------------------------------------
# Audit Item 7: Sprint 3B unwired screens   (v2: allowlist Sprint 3B gaps)
# ---------------------------------------------------------------------------

def audit_item_7_unwired_screens():
    R.h("Item 7: Sprint 3B — Screens That Exist But Aren't Routed")

    # 7a. Find user_management screens
    um_dir = LIB_DIR / "features" / "user_management"
    if not um_dir.exists():
        R.warn(f"No user_management directory at {um_dir.relative_to(REPO)}")
        return

    screen_files = list(um_dir.rglob("*_screen.dart")) + list(um_dir.rglob("*_page.dart"))
    if not screen_files:
        R.warn("No screen files (*_screen.dart or *_page.dart) found in user_management/")
        return

    R.info(f"Found {len(screen_files)} screen files in user_management/")
    R.info(f"Sprint 3B planned-screens allowlist: {', '.join(sorted(SPRINT_3B_PLANNED_SCREENS))}")

    # 7b. Find route definitions
    route_patterns = [
        r"GoRoute\s*\(",
        r"MaterialPageRoute\s*\(",
        r"ShellRoute\s*\(",
        r"StatefulShellRoute\s*\(",
    ]
    route_files = []
    for pat in route_patterns:
        route_files += grep_across(LIB_DIR, pat)
    # Also check main.dart
    main_dart = REPO / "lib" / "main.dart"
    if main_dart.exists():
        for pat in route_patterns:
            route_files += grep_in_file(main_dart, pat)
    # Deduplicate
    route_files = list(set(route_files))

    # 7c. For each screen, check if its class name appears in any route file
    R.sub("Checking each screen for route references")
    unwired_regressions = []     # v2: TRUE failures — not in allowlist
    unwired_planned = []         # v2: WARN only — Sprint 3B planned gap

    for screen in sorted(screen_files):
        # Extract class name from file
        content = screen.read_text(encoding="utf-8", errors="ignore")
        class_match = re.search(r"class\s+(\w+)\s+(?:extends|implements|with\s)", content)
        if not class_match:
            continue
        class_name = class_match.group(1)

        # Search for class name across lib/ (route references, navigator pushes)
        usages = grep_across(LIB_DIR, rf"\b{class_name}\b")
        # Filter out the definition file itself
        usages = [(p, n, l) for p, n, l in usages if p != screen]

        if usages:
            R.pass_(f"{screen.name} (class {class_name}): referenced {len(usages)} time(s)")
        else:
            # v2: classify as "planned gap" (WARN) or "regression" (FAIL)
            if screen.name in SPRINT_3B_PLANNED_SCREENS:
                R.warn(f"{screen.name} (class {class_name}): unwired — EXPECTED Sprint 3B gap (not a regression)")
                unwired_planned.append((screen.name, class_name))
            else:
                R.fail(f"{screen.name} (class {class_name}): NOT referenced anywhere — unwired REGRESSION")
                unwired_regressions.append((screen.name, class_name))

    # 7d. Summary (info only — individual screens already PASS/WARN/FAIL'd above)
    R.sub("Item 7 summary")
    if unwired_planned:
        R.info(f"  {len(unwired_planned)} planned Sprint 3B gap(s) — wire up in Sprint 3B:")
        for name, cls in unwired_planned:
            R.info(f"    • {name} ({cls})")
    if unwired_regressions:
        R.info(f"  → {len(unwired_regressions)} regression(s) — listed above as FAIL:")
        for name, cls in unwired_regressions:
            R.info(f"    • {name} ({cls})")
    if not unwired_planned and not unwired_regressions:
        R.pass_("All user_management screens are referenced somewhere")

# ---------------------------------------------------------------------------
# Audit Item 8: Integration tests
# ---------------------------------------------------------------------------

def audit_item_8_tests():
    R.h("Item 8: Integration Tests — Do They Pass?")

    # 8a. Check test files exist
    test_files = [
        TEST_DIR / "integration" / "auth_flow_test.dart",
        TEST_DIR / "integration" / "registration_contract_test.dart",
    ]
    existing_tests = [t for t in test_files if t.exists()]
    missing_tests = [t for t in test_files if not t.exists()]

    if missing_tests:
        for t in missing_tests:
            R.warn(f"Test file not found: {t.relative_to(REPO)}")
    if not existing_tests:
        R.fail("No integration test files found — cannot run tests")
        return

    R.info(f"Running {len(existing_tests)} test file(s)...")

    # 8b. Run flutter test
    test_paths = [str(t.relative_to(REPO)) for t in existing_tests]
    code, output = run_cmd(["flutter", "test"] + test_paths, cwd=REPO, timeout=300)

    if code == -2:
        R.warn("flutter not found on PATH — install Flutter SDK")
        return

    # Parse output for pass/fail counts
    if code == 0:
        # Look for "All tests passed!" or "+N -N"
        m = re.search(r"All tests passed!|(\d+ -\d+)", output)
        if m:
            R.pass_(f"Integration tests passed ({m.group(0)})")
        else:
            R.pass_("Integration tests passed (exit code 0)")
    else:
        # Find failure summary
        fail_match = re.search(r"Some tests failed|(\d+) -(\d+)", output)
        if fail_match:
            R.fail(f"Integration tests failed: {fail_match.group(0)}")
        else:
            R.fail(f"Integration tests failed (exit code {code})")

        # Show last 20 lines of output for context
        lines = output.splitlines()
        R.info("Last 20 lines of test output:")
        for line in lines[-20:]:
            R.info(f"  {line.strip()[:120]}")

# ---------------------------------------------------------------------------
# Audit Item 9 (bonus): TODO/FIXME/HACK in registration code
# ---------------------------------------------------------------------------

def audit_item_9_todos():
    R.h("Item 9 (bonus): TODO/FIXME/HACK in Registration Code")

    reg_files = [
        FUNCTIONS_SRC / "functions" / "registerOwner.ts",
        FUNCTIONS_SRC / "functions" / "registerTeacher.ts",
        FUNCTIONS_SRC / "functions" / "registerParent.ts",
        FUNCTIONS_SRC / "functions" / "redeemInviteCode.ts",
        FUNCTIONS_SRC / "functions" / "linkParent.ts",
        FUNCTIONS_SRC / "functions" / "linkParentToStudent.ts",
        FUNCTIONS_SRC / "functions" / "onUserCreated.ts",
        FUNCTIONS_SRC / "functions" / "syncClaims.ts",
        LIB_DIR / "core" / "services" / "auth_service.dart",
        LIB_DIR / "core" / "services" / "parent_link_service.dart",
    ]

    total_todos = 0
    for f in reg_files:
        if not f.exists():
            continue
        matches = grep_in_file(f, r"\b(TODO|FIXME|HACK|XXX|TEMP|WORKAROUND)\b", re.IGNORECASE)
        if matches:
            for line_no, line in matches:
                R.warn(f"{f.relative_to(REPO)}:{line_no}: {line.strip()[:120]}")
                total_todos += 1

    if total_todos == 0:
        R.pass_("No TODO/FIXME/HACK markers in registration code")
    else:
        R.warn(f"{total_todos} TODO/FIXME/HACK marker(s) found — review above")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print(f"Sprint 2 Audit (v2 — false-positive reduced) — {datetime.now().isoformat(timespec='seconds')}")
    print(f"Repo: {REPO}")

    if not (FUNCTIONS_SRC.exists() and LIB_DIR.exists()):
        print(f"ERROR: Cannot find functions/src or lib/ under {REPO}")
        print("Run this script from the repo root, or adjust REPO at the top of the file.")
        sys.exit(1)

    audit_item_1_deploy()
    audit_item_2_smoke()
    audit_item_3_sync_claims()
    audit_item_4_rbac_hierarchy()
    audit_item_5_org_boundary()
    audit_item_6_builds()
    audit_item_7_unwired_screens()
    audit_item_8_tests()
    audit_item_9_todos()

    R.h("SUMMARY")
    R.info(f"Passed:       {R.passed}")
    R.info(f"Exempted:     {R.exempted}   (ok-but-exempted — see EXEMPT lines above)")
    R.info(f"Failed:       {R.failed}     (TRUE failures — must fix before Sprint 3)")
    R.info(f"Warnings:     {R.warned}")
    R.info(f"Total checks: {R.passed + R.exempted + R.failed + R.warned}")

    print()
    if R.failed == 0 and R.warned == 0:
        print("*** Sprint 2 is solid — safe to start Sprint 3 ***")
    elif R.failed == 0:
        print("*** Sprint 2 has warnings/exemptions but no true failures — review before Sprint 3 ***")
    else:
        print(f"*** Sprint 2 has {R.failed} true failure(s) — FIX THESE before starting Sprint 3 ***")

    R.save()

if __name__ == "__main__":
    main()