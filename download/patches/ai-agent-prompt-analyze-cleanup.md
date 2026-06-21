# AI Agent Prompt — Klasivo Flutter Analyze Cleanup

> Copy everything below the line and paste into a fresh AI agent session (Claude / GPT / Gemini / etc.) to fix the 739 pre-existing `flutter analyze` errors in the Klasivo repo.

---

You are an autonomous code-fixing agent working on the **Klasivo** Flutter/Dart repository (GitHub: Strike87/Klasivo).

## Repository Context

- **Location**: `C:\Users\Strik\Klasivo` (Windows) or wherever the repo is cloned
- **Stack**: Flutter + Dart + Riverpod + Firebase (Firestore, Cloud Functions v2, Auth, Storage, AppCheck, LiveKit, Sentry)
- **Current HEAD**: `f7b733d` — `fix(final-wiring-v5): owner/parent screens + syncClaims`
- **Latest verified state**: `tsc` build of `functions/` is clean; `flutter analyze` reports **739 errors / 241 warnings / 3,542 infos** — all pre-existing, none introduced by v5

## Your Mission

Reduce the `flutter analyze` error count from **739 → ≤ 20** (only hard-to-fix design issues should remain) without breaking any runtime behavior, the v5 changes, or existing tests.

## Hard Constraints (DO NOT VIOLATE)

1. **Do not touch** these files (v5 work, just shipped):
   - `lib/features/auth/pages/owner_register_screen.dart`
   - `lib/features/parent/pages/parent_register_screen.dart`
   - `functions/src/functions/syncClaims.ts`
   - `functions/src/functions/registerOwner.ts`
   - `functions/src/functions/registerParent.ts`
   - `lib/core/services/auth_service.dart`

2. **Do not change runtime behavior.** Only fix imports, add missing type definitions, or rename. No logic changes.

3. **Preserve the Google sign-in flows** on both register screens. The email flows use `registerOwnerViaCF` / `registerParentViaCF` (return `{uid, ...}`); the Google flows use `registerOwnerWithGoogle` / `registerParentWithGoogle` (return `{id, fullName, email, ...}`). **Do not unify these return shapes** — they are correct as-is.

4. **One commit per phase.** Each phase below = one git commit with the message format `chore(analyze-cleanup-phase-N): <summary>`.

5. **Build after each phase**: `cd functions && npm run build` must stay clean.

6. **Never delete a file** unless you can prove it's unused (no imports anywhere).

7. **Working tree must be clean before starting**: `git status --porcelain` should be empty. If not, ask the user to `git stash` first.

## The 5 Phases

### Phase 1 — Exclude non-source dirs from analyzer (5 min, kills 182 errors)

Edit `analysis_options.yaml` at the repo root. Add (or merge into) the `analyzer.exclude` list:

```yaml
analyzer:
  exclude:
    - 'docs/**'
    - 'sprints/**'
    - 'extracted/**'
```

Also remove the 3 invalid lint rules that produce warnings at the top of the file:
- `control_flow_in_finally_blocks` (undefined_lint)
- `invariant_booleans` (removed in Dart 3.0.0)
- `prefer_equal_for_default_values` (removed in Dart 3.0.0)

**Commit**: `chore(analyze-cleanup-phase-1): exclude docs/sprints + remove dead lint rules`

**Verify**: `flutter analyze | grep "^  error" | wc -l` should drop from 739 to ~557.

### Phase 2 — Bulk-fix broken `app_constants.dart` imports (15 min, kills ~150 errors)

The files in `lib/features/{exams,submissions,user_management}/` use a wrong relative path:
```dart
import '../config/app_constants.dart';   // ❌ wrong
```

The correct path from `lib/features/<feature>/data/` or `lib/features/<feature>/pages/` is:
```dart
import '../../../core/config/app_constants.dart';   // ✅
```

Steps:
1. Find all broken imports: `rg "import '\.\./config/app_constants\.dart'" lib/`
2. For each match, calculate the correct relative path based on the file's location:
   - File in `lib/features/<feature>/data/` → `'../../../core/config/app_constants.dart'`
   - File in `lib/features/<feature>/pages/` → `'../../../core/config/app_constants.dart'`
   - File in `lib/features/<feature>/providers/` → `'../../../core/config/app_constants.dart'`
   - File in `lib/core/<subdir>/` → `'../config/app_constants.dart'`
3. Apply fixes via `Edit` tool (one file at a time, verify each).
4. Re-run `flutter analyze` and confirm error count dropped.

**Commit**: `chore(analyze-cleanup-phase-2): fix app_constants.dart relative imports`

**Verify**: `flutter analyze | grep "^  error" | wc -l` should drop by ~150.

### Phase 3 — Locate and fix missing service imports (20 min, kills ~80 errors)

Three service files are imported but the import paths are wrong (or the files don't exist where expected):
- `notification_service.dart`
- `search_keyword_service.dart`
- `performance_trace_service.dart`

Steps:
1. Locate each file: `rg "^class NotificationService" lib/` (same for the other two)
2. For each file that imports them, fix the path:
   - If the file is in `lib/features/<feature>/data/`, the path to `lib/core/services/notification_service.dart` is `'../../../core/services/notification_service.dart'`
3. If a service file does **not** exist anywhere in `lib/`:
   - Check if the importing file actually uses the service (search for `NotificationService.`, `SearchKeywordService.`, `PerformanceTraceService.`)
   - If unused: remove the import
   - If used: comment out the import + add `// TODO(phase-3): NotificationService missing — reimplement or remove usage` at each call site. Do NOT delete the call site.
4. Re-run `flutter analyze`.

**Commit**: `chore(analyze-cleanup-phase-3): fix missing service imports (notification/search/perf-trace)`

**Verify**: `flutter analyze | grep "uri_does_not_exist" | wc -l` should be 0.

### Phase 4 — Fix missing type definitions (30 min, kills ~30 errors)

These types are referenced but not imported:
- `ExamStatsData`
- `SessionAnalytics`
- `ExamData`
- `ExamStats` (if present)
- `LiveKitSession` (if present)

Steps:
1. Locate each type: `rg "^class ExamStatsData" lib/` then `rg "class ExamStatsData" lib/` (covers `abstract class`, `mixin`, etc.)
2. If found: add the correct import to files that use the type
3. If not found: search for the type's usage to understand what shape it should have, then either:
   - Define a minimal class in the appropriate file (e.g. `lib/features/exams/data/exam_stats_data.dart`) with the fields the usages require
   - OR replace the usage with `Map<String, dynamic>` and add `// TODO(phase-4): replace with proper type`
4. Re-run `flutter analyze`.

**Commit**: `chore(analyze-cleanup-phase-4): fix missing type definitions (ExamStatsData/SessionAnalytics/ExamData)`

**Verify**: `flutter analyze | grep "isn't a type" | wc -l` should be 0.

### Phase 5 — Fix user_management screen errors (45 min, kills ~200 errors)

The `lib/features/user_management/pages/` directory has 256 errors concentrated in:
- `user_detail_screen.dart` (74)
- `role_assignment_sheet.dart` (36)
- `permission_override_screen.dart` (34)
- `people_hub_screen.dart` (34)
- `scope_assignment_screen.dart` (33)
- `role_matrix_screen.dart` (24)
- `effective_permissions_screen.dart` (21)

Steps:
1. Open each file. Most errors will be the same patterns as Phases 2–4 (broken imports, missing types).
2. Fix imports first (Phase 2 pattern).
3. Fix missing types (Phase 4 pattern).
4. If you encounter `undefined_identifier` for names that aren't imports (e.g. `AppDurations`, `AppSizes`, `isRTL`), check if there's a design-system extension file that wasn't imported. Likely candidates:
   - `lib/core/design_system/tokens/durations.dart` → defines `AppDurations`
   - `lib/core/design_system/tokens/sizes.dart` → defines `AppSizes`
   - `lib/core/extensions/build_context_extensions.dart` → defines `context.isRTL`
5. Add the correct import for each.
6. If a referenced extension/type genuinely doesn't exist, define a minimal version or comment out the usage with a TODO.
7. Re-run `flutter analyze` after each file.

**Commit**: `chore(analyze-cleanup-phase-5): fix user_management screens (imports + types + extensions)`

**Verify**: `flutter analyze | grep "^  error" | wc -l` should be ≤ 20.

## Final Verification

After Phase 5:

1. `flutter analyze` should report ≤ 20 errors (down from 739)
2. `cd functions && npm run build` should still pass
3. `git log --oneline -6` should show 5 new `chore(analyze-cleanup-phase-N)` commits on top of `f7b733d`
4. `git push origin main`
5. Print a summary table:
   ```
   Phase | Errors before | Errors after | Files touched
   ------+---------------+--------------+--------------
   1     | 739           | ~557         | 1 (analysis_options.yaml)
   2     | ~557          | ~407         | ~10
   3     | ~407          | ~327         | ~15
   4     | ~327          | ~297         | ~10
   5     | ~297          | ≤ 20         | ~7
   ```

## Rollback Plan

If any phase breaks something:
```powershell
git reset --hard HEAD~1   # undo last commit
git push --force-with-lease origin main
```

If you discover mid-phase that the change is too risky, abandon the phase and skip to the next one. Note the skipped phase in the final summary.

## What NOT to Do

- ❌ Don't refactor code to "fix" infos or warnings (e.g. don't add `await` to `FirebaseCrashlytics.instance.recordError` — it's intentional fire-and-forget)
- ❌ Don't rename methods, classes, or variables
- ❌ Don't change Riverpod providers or their signatures
- ❌ Don't touch Cloud Functions (`functions/src/**`) — those are TypeScript and the `tsc` build is already clean
- ❌ Don't delete test files even if they have errors — fix their imports instead
- ❌ Don't add new dependencies to `pubspec.yaml`
- ❌ Don't run `dart format` or `flutter format` — it would create noise in the diff

## Communication

After each phase, print a 3-line status:
```
Phase N complete.
Errors before: X | Errors after: Y | Δ: -Z
Commit: <hash> | Files changed: N | Lines: +A/-B
```

If you encounter a decision point not covered by this prompt (e.g. ambiguous import path, type with conflicting definitions), **stop and ask the user** instead of guessing.

---

**Start with Phase 1.**
