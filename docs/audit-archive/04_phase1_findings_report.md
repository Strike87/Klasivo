# Klasivo Phase 1 Findings Report (Sections A-J)

> **Report Date:** 2026-06-17
> **Companion to:** `Klasivo_Production_Readiness_Audit.md`
> **Phase 1 Status:** COMPLETE — all findings verified, no remaining
> "probable" entries

---

## Section A — Firebase Configuration Surfaces

**Finding:** All 5 Firebase config surfaces (Android `google-services.json`,
iOS `GoogleService-Info.plist`, Web `firebase-config.js`, Cloud Functions
runtime config, FlutterFire `firebase_options.dart`) target
`klasivo-prod` (project ID 952580193002). The `smart-exam-pro-3d1cf`
identifier seen in CLI output is an operational mismatch only — not
present in any committed file.

**Verdict:** CLEAN — no action required.

---

## Section B — Cloud Functions Inventory

**Finding:** 9 callable functions + 5 triggers + 1 scheduled function
+ 1 API gateway function = 16 total. All in `us-central1`. All
case-sensitive names match between client SDK calls and function
declarations.

**Critical sub-finding:** `functions/index.js` (top-level, 618 lines,
v1 syntax) is a stale artifact from before the v2 migration. It's NOT
referenced by `package.json main` (which points to `lib/index.js`),
but its existence is a silent-deploy trap — if anyone runs
`firebase deploy --only functions` from a context where tsc fails to
emit `lib/`, the CLI could fall back to the stale v1 file.

**Action taken:** Deleted in Phase 2 commit `45b7b1d`.

---

## Section C — Firestore Rules

**Finding:** 63 collection blocks, 27 helper functions. Multiple
critical vulnerabilities:

1. `getUserOrgId()` returns `null` or `""` for users with missing org
   field → `null == null` evaluates true → cross-tenant leak
2. `users/{userId}` update rule has NO immutable-field guard → users
   can directly write `role: 'super_admin'` to their own doc
3. `parentHasAccessToStudent()` looks up `parent_links/{uid}_{studentId}`
   but client code uses `.add()` (auto-ID) → ALWAYS false → parents
   locked out of their children's data
4. `invite_codes` read requires `isAuth() && isInSameOrg()` → catch-22
   for new teacher onboarding (teacher can't auth until they redeem,
   can't redeem until they auth)
5. Zero rules reference `isArchived` / `archivedAt` / `archivedBy` →
   archive is purely advisory, archived resources remain fully
   accessible

**Action taken:** All five fixed in Phase 2 commit `45b7b1d` (rules
overhaul) + `dfdaee2` (diffKeys fix that made immutable-field guards
actually work).

---

## Section D — Authentication Service

**Finding (FORENSIC-9):** Two compounding bugs in
`lib/core/services/auth_service.dart`:

1. **Lines 514-519:** Student login performs an unauthenticated `.get()`
   on the user document BEFORE calling `signInWithEmailAndPassword`.
   The rules require `isAuth()`, so the read fails with permission-
   denied, which propagates up and prevents the sign-in from being
   attempted. Chicken-and-egg.
2. **Lines 579-585:** The entire flow is wrapped in a try/catch that
   swallows ALL Auth errors and returns success. A student entering
   the wrong password is flagged as logged in.

**Action taken:** Reordered flow (sign-in first, then read) and
narrowed the catch clause to specific expected errors. Deployed in
Phase 2 commit `45b7b1d`.

---

## Section E — Class Service

**Finding (FORENSIC-6):** `class_service.dart:98` (`deleteClass`)
cascade-deletes student Firestore docs but NOT Auth accounts. Also
skips 10+ related collections (exam_results, attendance,
parent_links, chat_messages, etc.), has no audit log, and has zero
UI callers but remains callable via direct invocation.

**Duplicate file:** `lib/features/classes/data/class_service.dart`
is byte-identical to `lib/core/services/class_service.dart`. Both
existed before Phase 2.

**Action taken:** Replaced cascade logic with a safe `deleteClass`
that requires explicit cascade confirmation. Auth account deletion
moved to new `deleteStudent` Cloud Function (created in this deploy).
Duplicate file resolved. Deployed in Phase 2 commit `45b7b1d`.

---

## Section F — createStudent Function

**Finding (FORENSIC-5):** Three issues:

1. **Line 201:** `enforceAppCheck: true` commented out — App Check
   bypassed
2. **Lines 447-458:** Reads `organizationId` from class doc but does
   NOT check `isArchived` — students can be created in archived classes
3. **Line 453:** Strict `!==` comparison fails on empty-string
   `organizationId` — Hive hydration bug from `registerOwner` writing
   `''` as placeholder

**Additional blocker:** `secrets: ['SENTRY_DSN']` declared but
secret not set → blocks ALL function-side deploys.

**Action taken:** App Check re-enabled (post secret rotation),
`isArchived` check added, org check relaxed to handle empty-string
case. SENTRY_DSN secret version 3 created by user. Deployed in
Phase 2 commit `45b7b1d`.

---

## Section G — Privilege Escalation Chain

**Finding:** Four-function chain (FORENSIC-10, 11, 12 + D6):

1. **`assignRole.ts:75`** (D3) — only blocks `admin`, not `super_admin`
2. **`assignScope.ts`** (D4) — uses caller-supplied `organizationId`
   instead of target user's actual org
3. **`syncClaims.ts`** — callable by any authed user, mints claims
   without validation
4. **`changeUserPassword.ts`** (D6) — no role-hierarchy check

**Combined exploit:** Compromised `campus_manager` resets owner
password (D6) → logs in as owner → self-assigns `super_admin` (D3) →
cross-tenant claim leak (D4) → global takeover.

**Action taken:** All four functions patched. D1 rules-level
immutable-field guards added. Deployed atomically in single command.
Lockstep confirmed in deploy output — all four functions show
"Successful update operation."

---

## Section H — UI Routing

**Finding (FORENSIC-14):** `/teacher/**` routes in `main.dart:897-1114`
registered as top-level GoRoute siblings of ShellRoute rather than
nested inside it. Result: bottom navigation bar disappears on 30+
teacher screens, breaking navigation back to home/dashboard.

**Action taken:** Moved `/teacher/**` routes inside the ShellRoute.
Deployed in Phase 2 commit `45b7b1d`.

---

## Section I — Firestore Indexes

**Finding:** `firestore.indexes.json` declared indexes for
`question_banks` (plural) collection, but ZERO for `questions`
(singular) which needs `examId ASC, order ASC/DESC`. Additionally,
57 production auto-indexes existed in the project but were not
declared in the file — causing the recurring "not present in your
firestore indexes file" warning on every deploy.

**Action taken:**
1. Added `questions` index in Phase 2 commit `45b7b1d`
2. Backfilled all 57 production auto-indexes via
   `firebase firestore:indexes > firestore.indexes.json` (commit
   `0d714bd`, re-encoded to UTF-8 in commit `2860b78`)

---

## Section J — Sentry Integration

**Finding:** Production DSN hardcoded in `EnvironmentConfig` with
compile-time override support. 14 Cloud Functions have initSentry +
withIsolatedScope + captureException + setUser. Auth flows use
SentryFirestoreHelper. Session Replay configured with maskAllText +
maskAllImages. Riverpod observer + navigation observer wired.

**Verdict:** COMPLETE — 8.5/10 readiness score. No action required.

---

## Phase 1 Conclusion

All 14 forensic investigations complete. All root causes verified —
no remaining "probable" entries. 15 P0 / 16 P1 / 10 P2 / 4 P3
findings documented. Phase 2 patching deployed to production on
2026-06-17.

The audit is formally closed pending the four non-blocking
verification tests outlined in the Production-Readiness Audit report.
