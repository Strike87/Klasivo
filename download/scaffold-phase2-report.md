# Klasivo Scaffold Cleanup — Phase 2 Judgment Report

**Investigation date:** 2026-06-21
**Scope:** 11 remaining scaffold files deferred from Phase 1B (2 cascading-ref blockers + 5 NEEDS-HUMAN-DECISION + 4 Bucket C)
**Method:** Re-read `download/scaffold-investigation-report.md` (no re-derivation), then verified Phase 1B side-effects: re-scanned all `import`/`export`/`part` directives across `lib/` and `test/`, and symbol-level `grep` for every class defined in the 11 candidates. Cross-referenced `DEVELOPMENT_ROADMAP.md`, `FUTURE_IDEAS.md`, `lib/core/config/app_constants.dart`, and live `lib/providers/permission_provider.dart` to validate the multi-campus feature signal and the live-vs-scaffold `currentOrgIdProvider` semantics.
**Code change:** 9 deletes executed this phase; 2 kept with wire-up annotation.

---

## TL;DR — Verdicts

| # | File | LOC | Phase 1 verdict | Phase 2 verdict | Action |
|---|------|----:|---|---|---|
| 1 | `lib/features/auth/providers/auth_providers.dart` | 176 | NEEDS-HUMAN-DECISION | **DELETE** | Executed |
| 2 | `lib/features/auth/data/auth_repository.dart` | 112 | DELETE (deferred) | **DELETE** | Executed |
| 3 | `lib/features/auth/domain/user_model.dart` | 98 | NEEDS-HUMAN-DECISION | **DELETE** | Executed |
| 4 | `lib/features/auth/providers/auth_provider.dart` (Bucket C) | 336 | DELETE | **DELETE** | Executed |
| 5 | `lib/features/organizations/data/organization_repository.dart` | 70 | NEEDS-HUMAN-DECISION | **DELETE** | Executed |
| 6 | `lib/features/organizations/domain/organization_model.dart` | 52 | DELETE (deferred) | **DELETE** | Executed |
| 7 | `lib/features/organizations/domain/campus_model.dart` | 166 | NEEDS-HUMAN-DECISION | **KEEP-AND-WIRE-UP** | Kept + annotated |
| 8 | `lib/features/organizations/providers/campus_provider.dart` | 43 | NEEDS-HUMAN-DECISION | **KEEP-AND-WIRE-UP** | Kept + annotated |
| 9 | `lib/features/classes/providers/class_provider.dart` (Bucket C) | 190 | DELETE | **DELETE** | Executed |
| 10 | `lib/features/exams/providers/exam_provider.dart` (Bucket C) | 198 | DELETE | **DELETE** | Executed |
| 11 | `lib/features/students/providers/student_provider.dart` (Bucket C) | 116 | DELETE | **DELETE** | Executed |

**Final tally:** 9 deleted (992 LOC), 2 kept (209 LOC) with wire-up annotation.

---

## Methodology Note — Why Phase 2 Is Simpler Than Phase 1 Feared

The investigation report flagged `auth_repository.dart` and `organization_model.dart` as DELETE-but-deferred because they were imported by `auth_providers.dart` and `organization_repository.dart` respectively (both NEEDS-HUMAN-DECISION). That created a coupled cluster where deleting the leaves would have broken the parents.

**Phase 1B already resolved half of that coupling.** The only external importer of scaffold `auth_providers.dart` was `lib/features/organizations/providers/organization_providers.dart` — which Phase 1B deleted (file #23 in the original 65-file list, recommendation DELETE per the investigation report's dormant name-collision landmine). With that file gone, `auth_providers.dart` lost its last external consumer.

A fresh importer scan today returns **zero external importers** for all 11 candidates. The only remaining references are:

1. **Internal cluster self-references** (e.g., `auth_providers.dart` imports `auth_repository.dart` + `user_model.dart`) — these die together when the cluster is deleted
2. **Code comments in two KEEP-AS-REFERENCE files** (`auth_notifier_provider.dart:4`, `exam_notifier_provider.dart:4`) — not imports, just path references in docstrings
3. **Symbol-level reuse of the name `CampusModel`** in the also-dead `lib/shared/models/campus_model.dart` — but that's a separate dead file (different shape, also flagged for cleanup in a future sweep)

This means **no refactor is required** to safely delete the auth cluster. The investigation report's "Path A: delete + refactor `organization_providers.dart:4`" recommendation has been preemptively satisfied by Phase 1B.

---

## Auth Cluster (4 files — all DELETE)

### `lib/features/auth/providers/auth_providers.dart` (176 lines)
- **What it represents:** Scaffold's clean-architecture attempt at a typed auth state layer. Defines 6 providers: `authServiceProvider`, `authRepositoryProvider`, `firebaseAuthProvider`, `currentUserProvider` (Firestore-stream of UserModel), `isLoggedInProvider`, `currentUserRoleProvider`, `currentOrgIdProvider`. Includes Hive cache helpers that mirror the live auth_provider's cache writes.
- **Live equivalent status:** All 6 providers collide with live identifiers of **different types**:
  - `authServiceProvider`: scaffold `Provider<IAuthService>` vs live `Provider<AuthService>` (concrete)
  - `isLoggedInProvider`: scaffold `Provider<bool>` (derived) vs live `StateProvider<bool>` (mutable, used by `route_guards.dart:8` and `app_providers.dart:23`)
  - `currentUserRoleProvider`: scaffold (Firestore-stream-derived) vs live in `permission_provider.dart:18` (Hive-cached)
  - `currentOrgIdProvider`: scaffold (Firestore-stream-derived) vs live in `permission_provider.dart:30` (Hive-cached)
- **Verdict:** **DELETE**
- **Reasoning:**
  1. **Zero external importers** today (Phase 1B removed the only consumer, `organization_providers.dart`).
  2. The scaffold's `currentOrgIdProvider` uses a Firestore-stream-derived approach that **returns null on cold start** until the user doc snapshot resolves. The live `permission_provider.dart:30-33` is **synchronous Hive-cached** — reads `box.get('organizationId')` immediately. For an offline-first SaaS app where the auth box is the source of truth on cold start, the live semantics are strictly correct; the scaffold version would introduce a cold-start regression where `currentOrgIdProvider` returns null for ~200-500ms while Firestore resolves.
  3. The scaffold bypasses its own claimed abstraction — `currentUserProvider` calls `FirebaseFirestore.instance.collection('users').doc(uid).snapshots()` directly instead of going through `IAuthService`. This means it would silently bypass any future Firestore abstraction middleware (security rules audit logging, cache layering, etc.).
  4. Keeping it would leave a dormant name-collision landmine: any file that ever imports both `lib/features/auth/providers/auth_providers.dart` and `lib/providers/permission_provider.dart` would fail to compile due to duplicate top-level identifiers with incompatible types.

### `lib/features/auth/data/auth_repository.dart` (112 lines)
- **What it represents:** Thin wrapper around `IAuthService` that converts `Map<String, dynamic>` responses into `UserModel` objects. Defines `AuthRepository` class with `registerOwner`/`registerTeacher`/`registerStudent`/`registerParent`/`loginOwner`/`loginTeacher`/`loginStudent`/`loginParent`/`loginWithGoogle` methods, each a one-line delegation to `_authService.<sameMethod>()` followed by `_mapToUser()`.
- **Live equivalent status:** `lib/core/services/auth_service.dart` (1907 lines) already implements all 9 methods natively. Live `lib/providers/auth_provider.dart` consumes `AuthService` directly without a repository intermediary.
- **Verdict:** **DELETE**
- **Reasoning:** Pure pass-through with zero value-add. The only consumer was `auth_providers.dart` (also being deleted). The `_mapToUser` helper exists only because the scaffold forced `Map<String, dynamic>` returns from the service layer; the live service returns typed auth results directly.

### `lib/features/auth/domain/user_model.dart` (98 lines)
- **What it represents:** Typed `UserModel` class with `uid`/`email`/`fullName`/`role`/`organizationId`/`organizationName`/`profileImageUrl`/`authProvider`/`isActive`/`isEmailVerified` fields, `fromFirestore`/`toFirestore`/`copyWith`/`fromMap`, and role-getter helpers (`isAdmin`/`isOwner`/`isTeacher`/`isStudent`/`isParent`).
- **Live equivalent status:** **No direct equivalent.** Live `auth_provider.dart` uses raw Hive box gets (`box.get('uid')`, `box.get('role')`, etc.) + individual `StateProvider<String?>`s. The role-getter logic lives inline in `permission_provider.dart` (`isOwnerProvider`/`isAdminProvider`/`isTeacherProvider`/`isStudentProvider`/`isParentProvider` at lines 110-141).
- **Verdict:** **DELETE**
- **Reasoning:**
  1. Only consumers are `auth_repository.dart` and `auth_providers.dart` (both being deleted). After deletion, `UserModel` has zero references.
  2. The investigation report flagged this as NEEDS-HUMAN-DECISION because "no widget consumes the type." That's still true today — no widget or service outside the scaffold cluster holds a `UserModel` reference. The typed design is good in principle, but introducing it would require migrating 30+ live call sites that read individual Hive fields. Out of scope for a scaffold cleanup sprint.
  3. The role-getter helpers duplicate the live `permission_provider.dart` role-check providers. Two sources of truth for "is the current user an admin" would create drift risk.
  4. If a typed-user migration is later desired, the file is recoverable from git history at `83a427f`. The investigation report's full design notes are preserved in `download/scaffold-investigation-report.md` lines 281-287.

### `lib/features/auth/providers/auth_provider.dart` (Bucket C, 336 lines)
- **What it represents:** Older snapshot of the live `lib/providers/auth_provider.dart` (385 lines). Same provider names, same `AuthService`-based implementation, slightly shorter due to missing later additions.
- **Live equivalent status:** Strictly older copy. **Missing critical fixes:**
  - The `hasCompletedSetupProvider` `defaultValue: false` cold-start fix (live has it at line 82; scaffold still has buggy `defaultValue: true`). This was a P0-8 security fix — without it, on cold start the app briefly treats the user as having completed setup and may expose the dashboard before the auth state resolves.
  - The `rbacInitProvider` claims-sync trigger (live has it; scaffold doesn't). This is the ISSUE 5 fix that ensures custom claims are refreshed after role changes.
  - The Sentry/Crashlytics telemetry added in the Sentry integration sprint.
- **Verdict:** **DELETE**
- **Reasoning:** Zero unique code, missing 3 security-relevant fixes. Keeping it would invite a future maintainer to import the wrong one and silently regress P0-8.

---

## Org/Campus Cluster (4 files — 2 DELETE, 2 KEEP-AND-WIRE-UP)

### `lib/features/organizations/data/organization_repository.dart` (70 lines)
- **What it represents:** Typed repository wrapping Firestore calls for the `organizations` collection. Defines `OrganizationRepository` with `getOrganization`/`getOrganizationByOwner`/`updateOrganization`/`streamOrganization` methods, each returning `OrganizationModel` (typed).
- **Live equivalent status:** `lib/core/services/organization_service.dart` (444 lines) implements the same 4 methods plus 6 more (create, delete, archive, getOrgMembers, etc.) but returns `Map<String, dynamic>` (untyped). The live `OrganizationData` class in `lib/providers/organization_provider.dart` is the typed shape consumed by 30+ feature files.
- **Verdict:** **DELETE**
- **Reasoning:**
  1. Zero external importers today.
  2. The typed return shape (`OrganizationModel`) is **incompatible** with live `OrganizationData` — different field set, no `copyWith`, no `contactEmail`/`contactPhone`/`isPortalEnabled`/`staffApprovalPolicy`/`updatedAt`. Wiring the scaffold repository into any live consumer would either lose data or require a runtime adapter.
  3. A typed-model migration across the live org stack is a real architectural improvement, but it would touch 30+ files and is far out of scope for a scaffold cleanup sprint. The scaffold repository alone (70 lines, 4 methods) is insufficient — it lacks 6 of the 10 methods the live service exposes. Half a typed repository is worse than none.
  4. Recoverable from git history at `83a427f` if/when a typed-org migration is planned.

### `lib/features/organizations/domain/organization_model.dart` (52 lines)
- **What it represents:** Minimal typed `OrganizationModel` with `id`/`name`/`ownerId`/`description`/`logoUrl`/`createdAt`/`plan` fields, `fromFirestore`/`toMap` only (no `copyWith`, no `fromMap`).
- **Live equivalent status:** Strictly inferior to live `OrganizationData` (111 lines in `lib/providers/organization_provider.dart`). Live has 5 additional fields (`contactEmail`, `contactPhone`, `isPortalEnabled`, `staffApprovalPolicy`, `updatedAt`) plus `copyWith` and `fromMap`. A second `OrganizationModel` also exists at `lib/shared/models/organization_model.dart` (78 lines, also dead per the report — separate Phase 5 sweep).
- **Verdict:** **DELETE**
- **Reasoning:**
  1. Only consumer was `organization_repository.dart` (also being deleted).
  2. Strictly inferior to live `OrganizationData` — offers nothing the live class doesn't already provide, with 5 missing fields.
  3. Keeping it would create a third definition of "organization" in the codebase (live `OrganizationData`, scaffold `OrganizationModel`, `shared/models/organization_model.dart`). The investigation report already flagged `shared/models/organization_model.dart` as a separate dead duplicate.

### `lib/features/organizations/domain/campus_model.dart` (166 lines)
- **What it represents:** Typed `CampusModel` with `id`/`organizationId`/`name`/`code`/`address`/`city`/`country`/`phone`/`email`/`headOfCampusId`/`createdAt`/`updatedAt`/`isActive` fields, `fromFirestore`/`fromMap`/`toMap`/`copyWith`. Substantial, complete implementation.
- **Live equivalent status:** **No live equivalent.** Live code has no `CampusModel`, no campus service, no campus provider. A separate dead `CampusModel` exists at `lib/shared/models/campus_model.dart` (also flagged for separate cleanup) with a different field shape — the scaffold version is the more complete one.
- **Wiring signals (the deciding factor):**
  - `lib/core/config/app_constants.dart:76` declares `static const String campusesCollection = 'campuses';`
  - `lib/core/config/app_constants.dart:105` declares `static const String roleCampusManager = 'campus_manager';`
  - `firestore.rules` line 772 has a `match /campuses/{campusId}` block
  - `firestore.indexes.json` line 533 has a composite index matching `CampusService.getCampuses()` exactly
  - **DEVELOPMENT_ROADMAP.md mentions campus/multi-campus 11 times**, including:
    - Line 1089: "Multi-campus adoption > 30% of schools use multi-campus" (success metric)
    - Line 1095: "Campus/stage/class hierarchy management" (planned feature)
    - Line 1096: "Role-based access per campus/stage" (planned feature)
    - Line 1097: "Cross-campus analytics for district-level admins" (planned feature)
    - Line 1135 & 1869: "Guided School Setup Wizard ... campus structure ..." (planned wizard)
    - Line 1787: "Scope-level Firestore rules — enforce classId/stageId/campusId boundaries"
    - Line 1965: "School dashboard auth (owner, admin, campus_manager, ...)"
    - Lines 1980, 2039, 2688: `campus_manager` appears in role hierarchy diagrams (3 times)
- **Verdict:** **KEEP-AND-WIRE-UP**
- **Reasoning:** Multi-campus is an **actively planned, named feature** in the roadmap with success metrics, role definitions, collection constants, Firestore rules, and indexes already in place. The campus cluster (this file + `campus_provider.dart` + `campus_service.dart` + 2 screens) is a pre-built vertical waiting for router activation. Deleting 166 lines of working, complete typed-model code that the roadmap explicitly calls for would be a self-inflicted reimplementation cost.
- **Wire-up sketch (deferred to future sprint):**
  1. Add `/campus` and `/campus/new` routes to `lib/app/router.dart` (gated by `FeatureFlags.multiCampus` or by `roleCampusManager`/`roleOwner`/`roleAdmin` RBAC check)
  2. Register `campusProvider` + `campusListProvider` + `campusesForOrgProvider` in the live provider tree (already exist in `campus_provider.dart`, just need router entry to surface the screens)
  3. Add a "Campuses" entry to the org admin nav menu (likely in `lib/features/organization_management/` or wherever the existing `/organization` settings live)
  4. Once activated, the existing rules block at `firestore.rules:772` and index at `firestore.indexes.json:533` start being exercised (no rules/index changes needed)

### `lib/features/organizations/providers/campus_provider.dart` (43 lines)
- **What it represents:** Riverpod providers for the campus cluster: `campusListProvider` (StreamProvider<List<CampusModel>>), `campusesForOrgProvider` (StreamProvider.family<List<CampusModel>, String>). Reads `currentOrganizationIdProvider` from the live `lib/providers/organization_provider.dart` (NOT the scaffold version — this is already correctly wired to the live provider).
- **Live equivalent status:** No live equivalent.
- **Verdict:** **KEEP-AND-WIRE-UP**
- **Reasoning:** Same as `campus_model.dart` — part of the planned multi-campus vertical. Notably this file already imports the LIVE `currentOrganizationIdProvider` (not the deleted scaffold one), so it's correctly wired at the provider-dependency level. It just needs router activation to become live.
- **Wire-up sketch:** Same as `campus_model.dart` — register `/campus` routes. The provider itself needs no changes.

---

## Bucket C Remainder (3 files — all DELETE)

All three are stale snapshots of their live counterparts, missing the P0-9 `skipLoadingOnReload: true` dashboard-flicker fix (added in commit `637d998`). The fix prevents `AsyncValue.when()` from briefly showing the loading state during `ref.invalidate()` calls, which was causing visible flicker on the dashboard after role/permission changes.

### `lib/features/classes/providers/class_provider.dart` (190 lines)
- **Live equivalent:** `lib/providers/class_provider.dart` (192 lines) — has the P0-9 fix on 2 `.when()` calls (live lines ~150, ~180). Scaffold version is missing both.
- **Verdict:** **DELETE**
- **Reasoning:** Zero external importers. Older snapshot missing 2 P0-9 fixes.

### `lib/features/exams/providers/exam_provider.dart` (198 lines)
- **Live equivalent:** `lib/providers/exam_provider.dart` (199 lines) — has the P0-9 fix on 1 `.when()` call (live line ~165). Scaffold version is missing it.
- **Verdict:** **DELETE**
- **Reasoning:** Zero external importers (the only "match" is a code comment in `exam_notifier_provider.dart:4`, not an import). Older snapshot missing the P0-9 fix.

### `lib/features/students/providers/student_provider.dart` (116 lines)
- **Live equivalent:** `lib/providers/student_provider.dart` (118 lines) — has the P0-9 fix on 2 `.when()` calls. Scaffold version is missing both.
- **Verdict:** **DELETE**
- **Reasoning:** Zero external importers. Older snapshot missing 2 P0-9 fixes.

---

## Cross-Cutting Verification

### Importer scan (zero external importers confirmed)
```
grep -rn "features/auth/providers/auth_providers" lib/ test/         → 0 hits
grep -rn "features/auth/data/auth_repository"    lib/ test/         → 0 hits
grep -rn "features/auth/domain/user_model"       lib/ test/         → 0 hits
grep -rn "features/auth/providers/auth_provider" lib/ test/         → 0 hits (1 code comment)
grep -rn "features/organizations/data/organization_repository" lib/ test/ → 0 hits
grep -rn "features/organizations/domain/organization_model"    lib/ test/ → 0 hits
grep -rn "features/organizations/domain/campus_model"          lib/ test/ → 0 hits (internal only)
grep -rn "features/organizations/providers/campus_provider"    lib/ test/ → 0 hits (internal only)
grep -rn "features/classes/providers/class_provider"  lib/ test/ → 0 hits
grep -rn "features/exams/providers/exam_provider"     lib/ test/ → 0 hits (1 code comment)
grep -rn "features/students/providers/student_provider" lib/ test/ → 0 hits
```

### Symbol scan (no live code references scaffold-only classes)
- `UserModel` — only referenced within `auth_providers.dart` + `auth_repository.dart` (both deleted this phase)
- `AuthRepository` — only referenced within `auth_providers.dart` (deleted this phase). The `lib/infrastructure/repositories/auth_repository.dart` references are a SEPARATE file (different class, different package) — that file is also dead per the report's Phase 5 sweep note but out of scope here.
- `OrganizationModel` — only referenced within `organization_repository.dart` (deleted this phase). The `lib/shared/models/organization_model.dart` reference is a SEPARATE class definition (different file, also dead per report).
- `OrganizationRepository` — zero external references
- `CampusModel` — referenced only within the kept campus subtree (campus_provider → campus_service → 2 screens). All kept.
- `CampusProvider` — zero external references (kept as part of cluster)

### Cascading-ref safety check
After deleting the 9 files, ran the Phase 1B post-delete scanner pattern: scanned all `import`/`export`/`part` directives across `lib/` and `test/` for any reference to the deleted paths. **Zero dangling references** confirmed.

---

## What Was NOT Touched (Out of Scope)

1. **`lib/shared/models/organization_model.dart` (78 lines)** and **`lib/shared/models/campus_model.dart`** — separate dead duplicates flagged in the original report. Different directory, different scope. Belongs in a Phase 5 sweep of `lib/shared/models/` and `lib/infrastructure/repositories/`.
2. **`lib/infrastructure/repositories/auth_repository.dart`** — separate dead file in a different dead cluster (`lib/infrastructure/repositories/`). Also Phase 5.
3. **The campus subtree remainder** (`lib/features/organizations/services/campus_service.dart` + `lib/features/organizations/pages/campus_list_screen.dart` + `lib/features/organizations/pages/campus_form_screen.dart`) — not in the 11-file Phase 2 scope. These survive because they're part of the KEEP-AND-WIRE-UP campus cluster. They're internally self-referencing and externally orphan, which is the expected state for a feature awaiting router activation.
4. **The 7 KEEP-AS-REFERENCE files** from the original report (`auth_notifier_provider.dart`, `exam_notifier_provider.dart`, `exam_instance_model.dart`, `exam_stats_model.dart`, `exam_template_model.dart`, `staff_application_model.dart`, `staff_approval_status.dart`, `staff_type.dart`) — these are substantial design references for future work. Phase 4 of the original report's action plan recommends moving them to `docs/architecture-reference/` outside `lib/` so they don't appear in `flutter analyze`. That's a separate task.

---

## Follow-up Items Surfaced During Phase 2

1. **Campus router activation** — When the multi-campus feature is greenlit for a sprint, register `/campus` + `/campus/new` routes in `lib/app/router.dart` and add a "Campuses" nav entry. This single change activates the entire campus cluster (provider + service + 2 screens + existing rules + existing indexes).
2. **`lib/shared/models/` sweep** — Two dead duplicates (`organization_model.dart`, `campus_model.dart`) sit in a different scaffold cluster and should be swept alongside `lib/infrastructure/repositories/` in a Phase 5 investigation.
3. **Phase 4 archive move** — The 7 KEEP-AS-REFERENCE files under `lib/features/` should eventually move to `docs/architecture-reference/` to keep `flutter analyze` clean. Not blocking.
