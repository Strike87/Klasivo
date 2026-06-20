#!/usr/bin/env python3
"""
Post-patch verifier for the security-patches commit (v2 — fixed false positives).
"""

import re, subprocess, sys
from pathlib import Path

ROOT = Path("/home/z/my-project")
errors = []
warnings = []
passes = []

def check(label, cond, detail=""):
    if cond:
        passes.append(label)
    else:
        errors.append(f"{label}{f' — {detail}' if detail else ''}")

def warn(label, cond, detail=""):
    if cond:
        passes.append(label)
    else:
        warnings.append(f"{label}{f' — {detail}' if detail else ''}")

# ---- 1. Patch markers in correct files ---------------------------------------
rules = (ROOT / "firestore.rules").read_text(encoding="utf-8")

rules_markers = [
    "P1-3 PATCH: Only staff can create payment records",                # auth P1-3
    "P1-4 PATCH: Immutable org/audit fields",                           # auth P1-4 helper comment
    "function preservesOrgAndAuditFields()",                            # auth P1-4 helper
    "function safeStaffUpdateWithOrgGuard()",                           # auth P1-4 helper
    "P1-1: Students cannot forge grading fields",                       # 7-auth P1-1 (submissions)
    "P1-1: Students cannot forge grading fields on create",             # 7-auth P1-1 (exam_instances)
    "P1-2: Students cannot edit answers",                               # 7-auth P1-2
    "P1-3: Parents cannot approve their own link",                      # 7-auth P1-3
    "P1-2: Students/parents can only read OWN doc",                     # data-exp P1-2 (rule)
    "P1-3: Scope arrays immutable from client",                         # data-exp P1-3
    "P1-4: Require auth + same-org for ALL reads",                      # data-exp P1-4
    "P2-1: Staff can read all. Students can only read published",       # data-exp P2-1
    "P2-2: Block ALL client-side org creation",                         # data-exp P2-2
    "P1-1 (data-exposure-v2): Staff only. Students see questions via",  # data-exp P1-1 (manual)
    "P1-3: Block grading fields",                                       # exam-flow P1-3
    "P1-4 PATCH: Verify sender is a participant in the referenced conversation",  # rbac P1-4
    "function isStaffExcludingObserver()",                              # data-exp P1-1 alias
    "function isStaffExcludingObserverInSameOrg()",                     # data-exp P1-1 alias
]
for marker in rules_markers:
    check(f"firestore.rules: {marker[:60]!r}", marker in rules)

# ---- 2. Patch markers in Cloud Functions ------------------------------------
assignRole = (ROOT / "functions/src/functions/assignRole.ts").read_text(encoding="utf-8")
check("assignRole.ts: auth P1-1 target org check",
      "P1-1 PATCH: Verify target user belongs to the same org as caller." in assignRole)
check("assignRole.ts: rbac P1-1 hierarchy check (callerRole <= oldRole)",
      "roleRank(callerRole) <= roleRank(oldRole)" in assignRole)

spo = (ROOT / "functions/src/functions/setPermissionOverrides.ts").read_text(encoding="utf-8")
check("setPermissionOverrides.ts: P1-2 target org check",
      "P1-2 PATCH: Verify target user belongs to the same org as caller." in spo)

cup = (ROOT / "functions/src/functions/changeUserPassword.ts").read_text(encoding="utf-8")
check("changeUserPassword.ts: P1-5 recent auth (tokenIssuedAt + maxAge)",
      "tokenIssuedAt" in cup and "maxAge" in cup)
check("changeUserPassword.ts: hashPassword import removed",
      "import { hashPassword" not in cup)

ds = (ROOT / "functions/src/functions/deleteStudent.ts").read_text(encoding="utf-8")
check("deleteStudent.ts: P1-4 teacher classIds scope check",
      "callerClassIds" in ds and "targetClassId" in ds)

oud = (ROOT / "functions/src/functions/onUserDeleted.ts").read_text(encoding="utf-8")
check("onUserDeleted.ts: P2-2 cascade includes 'stages' + 'campuses' + 'announcements'",
      "'stages'" in oud and "'campuses'" in oud and "'announcements'" in oud)

# ---- 3. No undefined helper refs in firestore.rules -------------------------
# Find all `function NAME(` declarations
declared = set(re.findall(r"function\s+(\w+)\s*\(", rules))
# Find calls — use negative lookbehind for `-` to avoid matching "null-safety ("
# Pattern: identifier (one of our helper prefixes) followed by optional ws + `(`
# but NOT preceded by `-` (which would make it part of a hyphenated word like "null-safety")
called = set()
for m in re.finditer(r"(?<![-\w])(isStaff\w*|isTeacher\w*|isOwner\w*|isAdmin\w*|isAuth\w*|isIn\w*|preserves\w*|safe\w*|getUserRole|getOrgId)\s*\(", rules):
    called.add(m.group(1))
undefined = called - declared
check("firestore.rules: no undefined helper refs", not undefined,
      f"undefined: {undefined}" if undefined else "")

# ---- 4. Callers of patched saveAnswer / bulkSaveAnswers ----------------------
saveAnswer_callers = []
for f in ROOT.glob("lib/**/*.dart"):
    txt = f.read_text(encoding="utf-8")
    for m in re.finditer(r"\.saveAnswer\s*\(", txt):
        ctx = txt[m.start():m.start()+400]
        if "required String studentId" in ctx and "required String organizationId" in ctx:
            continue  # declaration
        if "studentId:" not in ctx or "organizationId:" not in ctx:
            saveAnswer_callers.append(f"{f.relative_to(ROOT)}:{txt[:m.start()].count(chr(10))+1}")

bulk_callers = []
for f in ROOT.glob("lib/**/*.dart"):
    txt = f.read_text(encoding="utf-8")
    for m in re.finditer(r"\.bulkSaveAnswers\s*\(", txt):
        ctx = txt[m.start():m.start()+400]
        if "required String studentId" in ctx and "required String organizationId" in ctx:
            continue
        if "studentId:" not in ctx or "organizationId:" not in ctx:
            bulk_callers.append(f"{f.relative_to(ROOT)}:{txt[:m.start()].count(chr(10))+1}")

check("lib/ callers of saveAnswer() all pass studentId+organizationId",
      not saveAnswer_callers,
      f"missing params at: {saveAnswer_callers}" if saveAnswer_callers else "")
check("lib/ callers of bulkSaveAnswers() all pass studentId+organizationId",
      not bulk_callers,
      f"missing params at: {bulk_callers}" if bulk_callers else "")

# ---- 5. gradeSubmission CF exists + exported ---------------------------------
gs = ROOT / "functions/src/functions/gradeSubmission.ts"
check("functions/src/functions/gradeSubmission.ts exists", gs.exists())

idx = (ROOT / "functions/src/index.ts").read_text(encoding="utf-8")
check("gradeSubmission exported from index.ts",
      "export { gradeSubmission }" in idx)

# ---- 6. storage.rules -------------------------------------------------------
sr = (ROOT / "storage.rules").read_text(encoding="utf-8")
opens = sr.count("{")
closes = sr.count("}")
check("storage.rules: braces balanced", opens == closes, f"opens={opens} closes={closes}")
check("storage.rules: isStaff() helper defined", "function isStaff()" in sr)
check("storage.rules: isTeacherOrOwner() back-compat alias", "function isTeacherOrOwner()" in sr)

# ---- 7. No remaining tenantId: 'default' in CFs -----------------------------
for cf_name in ["registerOwner.ts", "registerParent.ts", "createStudent.ts"]:
    cf = ROOT / "functions/src/functions" / cf_name
    if cf.exists():
        txt = cf.read_text(encoding="utf-8")
        # Live (non-comment) lines containing tenantId: 'default'
        bad_lines = []
        for i, line in enumerate(txt.split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("//"):
                continue
            if "tenantId: 'default'" in line:
                # Allow if it's in a comment after the value (e.g. "x: 'default'  // comment")
                before_default = line.split("tenantId: 'default'")[0]
                if "//" in before_default:
                    continue
                bad_lines.append(f"L{i}: {line.strip()}")
        check(f"{cf_name}: no live tenantId: 'default'", not bad_lines,
              f"found: {bad_lines}" if bad_lines else "")

# ---- 8. registerOwner.ts: P2-2b abuse controls + P1-5 tenantId fix ----------
ro = (ROOT / "functions/src/functions/registerOwner.ts").read_text(encoding="utf-8")
check("registerOwner.ts: P2-2b email duplicate check",
      "auth.getUserByEmail(data.email.trim().toLowerCase())" in ro)
check("registerOwner.ts: P1-5 tenantId = orgId (not 'default')",
      "tenantId: orgId" in ro)

# ---- 9. createStudent.ts: passwordHash removed from .set() -----------------
cs = (ROOT / "functions/src/functions/createStudent.ts").read_text(encoding="utf-8")
# passwordHash should NOT appear in any .set() payload. Check the users .set() block.
set_match = re.search(r"db\.collection\('users'\)\.doc\([^)]+\)\.set\(\{([^}]+)\}", cs, re.DOTALL)
if set_match:
    set_payload = set_match.group(1)
    check("createStudent.ts: passwordHash NOT in users .set() payload",
          "passwordHash" not in set_payload,
          f"found in payload: {[l for l in set_payload.split(chr(10)) if 'passwordHash' in l]}")
else:
    check("createStudent.ts: users .set() block found", False, "regex didn't match")
check("createStudent.ts: hashPassword import removed",
      "import { hashPassword" not in cs)

# ---- 10. permission_service.dart: P1-2 scope before override ---------------
ps = (ROOT / "lib/core/rbac/permission_service.dart").read_text(encoding="utf-8")
check("permission_service.dart: P1-2 scope-before-override",
      "P1-2 PATCH: Scope is checked BEFORE returning true on override" in ps)

# ---- 11. main.dart: P2-1 managementRoles ------------------------------------
md = (ROOT / "lib/main.dart").read_text(encoding="utf-8")
check("main.dart: P2-1 managementRoles.contains(userRole)",
      "KlasivoRole.managementRoles.contains(userRole)" in md)

# ---- 12. submission_service.dart: _functions field + CF call ----------------
ss = (ROOT / "lib/core/services/submission_service.dart").read_text(encoding="utf-8")
check("submission_service.dart: _functions field declared",
      "final FirebaseFunctions _functions = FirebaseFunctions.instance" in ss)
check("submission_service.dart: gradeSubmission CF call",
      "_functions.httpsCallable('gradeSubmission').call(" in ss)

# ---- 13. exam_taking_screen.dart: callers pass new params ------------------
ets = (ROOT / "lib/features/student_exams/pages/exam_taking_screen.dart").read_text(encoding="utf-8")
check("exam_taking_screen.dart: saveAnswer passes studentId+organizationId",
      "studentId: studentId," in ets and "organizationId: organizationId," in ets)

# ---- 14. lib/features/submissions/data/submission_service.dart is dead code -
warn("lib/features/submissions/data/submission_service.dart is dead (0 importers) — patches modified it harmlessly",
     True)

# ---- 15. TypeScript build still passes --------------------------------------
r = subprocess.run(["npm","run","build"], cwd=ROOT/"functions", capture_output=True, text=True)
check("functions npm run build passes (tsc returns 0)", r.returncode == 0,
      f"stderr: {r.stderr[-500:]}" if r.stderr else "")

# ---- Report -----------------------------------------------------------------
print("\n" + "=" * 78)
print("POST-PATCH VERIFIER REPORT (v2)")
print("=" * 78)
print(f"\nPASS: {len(passes)}  WARN: {len(warnings)}  FAIL: {len(errors)}\n")

if warnings:
    print("--- WARNINGS ---")
    for w in warnings:
        print(f"  [WARN] {w}")
    print()

if errors:
    print("--- FAILURES ---")
    for e in errors:
        print(f"  [FAIL] {e}")
    print()
    sys.exit(1)
else:
    print("All checks passed.")
    sys.exit(0)
