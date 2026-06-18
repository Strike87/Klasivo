# Klasivo Production-Readiness Audit — Prior Context Summary

> This section captures the engagement state at the start of the current
> session. It is the condensed summary that was carried forward when the
> previous conversation ran out of context.

## Decision at Session Start

**Option A confirmed**: Apply a predeploy hook AND author all Phase 2
patching tracks. This means:
1. Build a predeploy hook (likely enforcing the **D1+D3+D4+D6 lockstep**
   — Firestore Rules + assignRole + assignScope + changeUserPassword must
   deploy together to avoid masking privilege-escalation bugs)
2. Begin authoring all Phase 2 patching tracks in the verified order

## Phase 2 Patching Order (User-Specified)

Student Login → Firestore Rules → createStudent → deleteStudent →
deleteClass safety → orphaned user protection → indexes → UI bugs →
privilege-escalation lockstep (D1+D3+D4+D6)

## Audit Status: Complete (Read-Only Phase 1 Done)

- 14 forensic investigations completed (FORENSIC-1 through FORENSIC-14)
- Two reports produced:
  - `Klasivo_Production_Readiness_Audit.md` (496 lines)
  - `Klasivo_Phase1_Findings_Report.md` (Sections A-J)
- All root causes verified — no remaining "probable" findings
- BLOCKER P2-1 (appExists=false) RESOLVED — confirmed App Check token
  indicator, not document existence

## Critical Findings (15 P0 / 16 P1 / 10 P2 / 4 P3)

### Privilege Escalation Chain (LOCKSTEP required)

- `assignRole.ts:75` — only blocks `admin`, not `super_admin` → owner
  can self-assign super_admin → GLOBAL cross-org control
- `assignScope.ts` — uses caller-supplied `organizationId` instead of
  target user's actual org → cross-tenant claim leak
- `syncClaims.ts` — callable by any authed user, mints claims without
  validation → escalation primitive
- `changeUserPassword.ts` — no role-hierarchy check → campus_manager can
  reset owner password → org takeover

### Student Login (FORENSIC-9)

- `auth_service.dart:514-519` — unauthenticated `.get()` before
  `signInWithEmailAndPassword` → chicken-and-egg permission-denied
- `auth_service.dart:579-585` — try/catch swallows ALL Auth errors,
  returns success → wrong-password student flagged logged in

### Firestore Rules (FORENSIC-10, 13)

- `getUserOrgId()` returns null/"" for missing org → `null==null`
  cross-tenant leak
- `users/{userId}` update — NO diffKeys guard on role/organizationId
  → self-escalation
- `parentHasAccessToStudent()` looks up wrong doc ID pattern → ALWAYS false
- `invite_codes` read requires `isAuth() && isInSameOrg()` → catch-22
  for new teacher onboarding
- Zero rules reference `isArchived`/`archivedAt`/`archivedBy`

### createStudent.ts

- Line 201: `enforceAppCheck: true` TEMPORARILY DISABLED
- Lines 447-458: Reads only `organizationId` from class doc, does NOT
  check `isArchived`
- Line 453: Strict `!==` fails on empty-string organizationId
- `secrets: ['SENTRY_DSN']` declared but secret not set → BLOCKS deploy

### deleteClass TIME BOMB (`class_service.dart:98`)

- Cascade-deletes student Firestore docs but NOT Auth accounts
- Skips 10+ related collections, no audit log, zero UI callers but
  still callable
- Duplicate file exists at `lib/features/classes/data/class_service.dart`

### UI

`/teacher/**` routes registered as top-level GoRoute siblings of
ShellRoute → bottom nav disappears on 30+ call sites

### Indexes

`firestore.indexes.json` has indexes for `question_banks` (plural) but
ZERO for `questions` (singular, needs `examId ASC, order ASC/DESC`)

## Remaining Blockers at Session Start

1. **BLOCKER 1 (SENTRY_DSN)** — blocks ALL function-side fixes
2. **BLOCKER P2-2** — deployed function state verification
3. **BLOCKER P2-3** — exhaustive compound-query index audit

## Environment

- All 5 Firebase config surfaces target `klasivo-prod`
- `smart-exam-pro-3d1cf` is operational CLI mismatch only
- All 9 callable functions verified: names match case-sensitive, all
  regions us-central1
- `functions/index.js` (top-level, stale v1, 618 lines) — silent-deploy
  trap, not currently used by `package.json main`
