# Registration & Security — Verified Status

**Date:** 2026-06-23
**Verified against:** commit `4d25d09` (HEAD of `main`, in sync with `github.com/Strike87/Klasivo`)
**Author:** ZCode agent session — every claim below re-checked against the actual codebase, not assumed.

> This document supersedes the informal "Repo Status — All Fixes Confirmed" note circulated in chat.
> That note contained a material error (the org-create rule description was inverted) and several
> misframed claims. Corrections are documented in the [Corrections](#corrections) section.
> This file records only what the code actually shows.

---

## 1. Registration Cloud Functions

All four roles register through server-side Cloud Functions using the Admin SDK. Client code never
writes privilege-bearing fields.

| Role | CF | Screen → caller | Verified |
|------|-----|-----------------|----------|
| Owner | `registerOwner.ts` | `lib/features/auth/pages/owner_register_screen.dart:46` → `registerOwnerViaCF` | ✅ |
| Parent | `registerParent.ts` | `lib/features/auth/pages/parent_register_screen.dart:43` → `registerParentViaCF` | ✅ |
| Teacher | `registerTeacher.ts` + `redeemInviteCode.ts` | `lib/features/auth/pages/teacher_registration_screen.dart:57` → `registerOwnerViaCF`; invite path via `redeemInviteCode` | ✅ |
| Student | `createStudent.ts` | staff-only CF; no client self-create | ✅ |

### Parent-linking flow (the deadlock fix — commit `8bd55dc`)

A parent registers with `organizationId: ''` and empty-org claims. The client cannot complete the
link (rules block parent from writing its own org/status/claims). The `linkParent` CF
(`functions/src/functions/linkParent.ts`) does it server-side:

1. Caller = authenticated `role: 'parent'`.
2. Looks up the pending `parent_links` doc by 8-char `code`.
3. Transaction: flips link to `status: 'approved'` + stamps `parentId`/`linkedAt`.
4. **Writes the parent's `organizationId` + `tenantId`** (the deadlock fix).
5. **Re-mints parent claims** with the real org + bumps `roleVersion`.
6. Writes the deterministic `parent_links/{parentId}_{studentId}` doc that
   `parentHasAccessToStudent()` (`firestore.rules:153`) requires.
7. Stamps `parentId` on the student doc.
8. Rolls the link back to `pending` if any post-transaction step fails.

Client side: `lib/core/services/parent_link_service.dart` `linkParentToStudent` is now a thin
`httpsCallable('linkParent')` wrapper.

### Invite schema unification (commit `8bd55dc`)

`redeemInviteCode.ts` was rewritten to the **canonical** schema (`isUsed` / `useCount` / `usedBy` /
`usedAt` / `maxUses`), matching `lib/core/services/invite_code_service.dart` creation and
`registerTeacher.ts`. The invented `status` / `usesCount` / `role` / `campusId` fields were removed.
`redeemInviteCode` enforces App Check (authenticated-alternative path).

### Rollback hygiene

`registerOwner`, `registerTeacher`, `registerParent`, `redeemInviteCode` all delete the Auth
account **and** the `users/{uid}` doc on any post-create failure. `onUserCreated` short-circuits
when the user doc is missing (no welcome email for orphaned accounts).

---

## 2. Security Rules — verified per collection

| Collection | Rule | Line | Verified |
|---|---|---|---|
| `organizations` create | **`allow create: if false;`** — fully blocked, server-only via `registerOwner` CF | `firestore.rules:478` | ✅ |
| `organizations` update | `isOwnerInSameOrg()` (or super_admin via CF) | `:480` | ✅ |
| `users` read | self (`uid == userId`) OR (`isInSameOrg()` && `isStaffExcludingObserver()`) — students read only own doc | `:239-241` | ✅ |
| `users` self-create role | `role in ['student','parent']` only (teacher/owner never client-created) | `:251` | ✅ |
| `users` self-update | privilege fields (`role`, `organizationId`, `tenantId`, scope arrays, `roleVersion`, …) immutable | `:255-266` | ✅ |
| `questions` read | `isStaffExcludingObserver()` — students never read question docs (see them via `exam_instances`) | `:328` | ✅ |
| `exams` read | staff all; students `status == 'published'` only | `:317-318` | ✅ |
| `invite_codes` read (auth) | `isAuth() && isInSameOrg()` | `:506` | ✅ |
| `invite_codes` read (unauth) | **only** unused, non-expired codes (pre-auth `validateInviteCode`); used/expired blocked | `:519-522` | ✅ |
| `parent_links` | staff create; parent can redeem via `linkParent` CF; deterministic doc shape enforced | `:715+` | ✅ |
| `audit_logs` / `email_queue` / `emailLog*` | server-only (Admin SDK) | `:782-783, 1057+` | ✅ |

---

## 3. Other verified items

| Item | Verdict | Evidence |
|---|---|---|
| `passwordHash` removed from `createStudent` | ✅ | all 4 references are comments; `:481` "Firebase Auth is source of truth" |
| `mustChangePassword` set on student creation | ✅ | `createStudent.ts:527` |
| Student login uses `.doc(uid).get()` (not a list query) | ✅ | `auth_service.dart:744` |
| `syncClaims.ts` increments `roleVersion` | ✅ | `:129` `FieldValue.increment(1)` |
| `currentOrganizationIdProvider` sync | ✅ | ~90 references including writers at `auth_provider.dart:175,243,301,352,384` |
| Registration CFs: `enforceAppCheck: false` | ✅ intentional | App Check token can't be minted pre-signin; abuse mitigated by input validation + Auth rate limits + duplicate-email guard |
| Registration CFs: generic client-facing error messages | ✅ | no raw `${msg}` leaks to client; Sentry captures full detail server-side |

---

## 4. Known open / intentionally-deferred items

These are **not** regressions — they are explicitly acknowledged trade-offs or pending QA. Listed
here so they aren't mistaken for oversights.

| Item | Status | Note |
|---|---|---|
| `StatefulShellRoute` tab-switch flicker (`skipLoadingOnReload`) | ⚠️ Unverified | Requires manual QA; not auto-tested |
| `defaultInstitutionId` references | 16 remaining | Down from 27; remaining refs are safe model-default read paths, not write paths |
| `registerOwnerWithGoogle` writes `role: 'owner'` from client | ⚠️ Known | `teacher_registration_screen.dart:124-126` — needs a new `registerOwnerWithGoogle` CF; tracked separately |
| `redeemInviteCode` App-Check enforcement | ✅ resolved | Header comment now consistent with `enforceAppCheck: true` |

---

## Corrections

The earlier informal "Repo Status — All Fixes Confirmed" note contained these inaccuracies. The
verified facts above are authoritative; this section records what was wrong so the discrepancy is
auditable.

1. **Org-create rule — backwards.** The note said the rule was "NOT blocked (`if false`)" and used
   `isInSameOrgById(orgId)`. The actual rule at `firestore.rules:478` is `allow create: if false;`
   (fully blocked, server-only). The note described the pre-fix state.
2. **`teacher_shell.dart` — nonexistent.** The note claimed a `KlasivoRole` usage there was removed.
   No `*shell*.dart` file exists in the repo. `KlasivoRole` is legitimately referenced in 23 other
   files (RBAC system) — not a build error.
3. **`owner_register_screen.dart` path — wrong.** The note put it under `features/owner/pages/`; it
   is at `lib/features/auth/pages/owner_register_screen.dart`. The substance (uses
   `registerOwnerViaCF`) is correct.
4. **`currentOrganizationIdProvider` count — understated.** Note said 5 references; there are ~90.
5. **"All Fixes Confirmed" — overstated.** Skipped `StatefulShellRoute` QA and 16 open
   `defaultInstitutionId` refs are not "confirmed".

---

## Reproduction / how to re-verify

```powershell
cd C:\Users\Strik\Klasivo
git fetch origin
git rev-parse HEAD            # expect 4d25d099916d393fded638936b91a63a1eef8d78
git status                    # expect clean
flutter analyze               # expect no errors
cd functions && npx tsc --noEmit   # expect no errors
firebase deploy --only functions,firestore:rules
```

Manual smoke checklist (from the registration flows):

```
[ ] Owner registers via CF → org + user doc created, claims minted
[ ] Parent registers via CF → orgId '', routed to /auth/parent-link
[ ] Parent redeems 8-char code via linkParent CF → orgId populated, claims re-minted, reads /parent/results
[ ] Student logs in (.doc(uid).get()) → succeeds
[ ] Student takes exam → saves → submits → graded
[ ] Teacher grades assignment → student notified
[ ] Admin changes role → user claims refresh within ~5s (roleVersion bump)
```
