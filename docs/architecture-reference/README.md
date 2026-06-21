# Architecture Reference

This directory contains **design reference files** that were moved out of `lib/`
during the Sprint 1 scaffold cleanup (Phase 5+). They are NOT compiled into the
Flutter app and are NOT wired into any live code path.

## Purpose

These files represent substantial design work that may inform future migrations:

- **Riverpod Generator migration** — `auth_notifier_provider.dart` and
  `exam_notifier_provider.dart` are complete reference implementations of the
  proposed Riverpod Generator pattern. They consolidate the existing
  `StateProvider` sprawl into cohesive `Notifier`-based state machines.
- **Typed domain models** — `exam_instance_model.dart`, `exam_stats_model.dart`,
  `exam_template_model.dart` define typed equivalents of the raw
  `Map<String, dynamic>` shapes currently used by the live services.
- **Staff approval workflow** — `staff_application_model.dart`,
  `staff_approval_status.dart`, `staff_type.dart` define the data layer for the
  v2.2 Teacher Approval Workflow described in `DEVELOPMENT_ROADMAP.md` lines
  583-607.

## ⚠️ Critical Warnings

**DO NOT migrate any of these files without reading the warning header at the
top of each file.** Each file documents its known incompleteness relative to
the current live code. The most common gaps are:

1. **Missing codegen** — `auth_notifier_provider.dart` and
   `exam_notifier_provider.dart` declare `part '..._provider.g.dart';`
   directives pointing at files that do not exist. They have NEVER compiled.
2. **Missing security instrumentation** — both notifier files lack the
   Sentry/Crashlytics telemetry added to the live providers during the Sentry
   integration sprint.
3. **Missing `rbacInitProvider` trigger** — `auth_notifier_provider.dart` lacks
   the ISSUE 5 claims-sync trigger that is a Sprint 1 security requirement.
4. **P0-8 cold-start bug** — `auth_notifier_provider.dart` has
   `defaultValue: true` on `hasCompletedSetupProvider`. Live version has
   `defaultValue: false`.
5. **P0-9 dashboard flicker** — `exam_notifier_provider.dart` lacks the
   `skipLoadingOnReload: true` fix on `.when()` calls.
6. **Incomplete `deleteExam`** — `exam_notifier_provider.dart`'s `deleteExam`
   method (line ~543) explicitly notes "we delete just the exam doc" with no
   sub-collection cleanup. Live `exam_service.dart::_deleteExamImpl` does full
   cascading cleanup of questions/submissions/instances/stats/answers.

## File Inventory

| File (relative) | Source path (moved from) | LOC | Purpose |
|---|---|---:|---|
| `auth/providers/auth_notifier_provider.dart` | `lib/features/auth/providers/` | 522 | Riverpod Generator reference for auth state |
| `exams/providers/exam_notifier_provider.dart` | `lib/features/exams/providers/` | 598 | Riverpod Generator reference for exam list state |
| `exams/domain/exam_instance_model.dart` | `lib/features/exams/domain/` | 55 | Typed model for `exam_instances` collection |
| `exams/domain/exam_stats_model.dart` | `lib/features/exams/domain/` | 207 | 5-class typed model for exam analytics |
| `exams/domain/exam_template_model.dart` | `lib/features/exams/domain/` | 71 | Typed model for `exam_templates` collection |
| `staff_approval/domain/staff_application_model.dart` | `lib/features/staff_approval/domain/` | 515 | v2.2 teacher approval workflow model |
| `staff_approval/domain/staff_approval_status.dart` | `lib/features/staff_approval/domain/` | 126 | 7-value status enum + transition validator |
| `staff_approval/domain/staff_type.dart` | `lib/features/staff_approval/domain/` | 75 | 3-value staff type enum |

**Total:** 8 files, 2169 LOC.

## Provenance

These files were originally part of a clean-architecture scaffold that landed
in commit `83a427f docs: add complete audit + Phase 2 deploy archive`
(2026-06-18). The scaffold was a bulk import from another repo with no
evolutionary history — the Riverpod Generator migration it represented was
started but never completed (the `.g.dart` part files were never generated).

The original investigation report at `download/scaffold-investigation-report.md`
classified these as "KEEP-AS-REFERENCE" (Phase 4 of the recommended action
plan). The move to `docs/architecture-reference/` was the report's preferred
resolution: it keeps the design work accessible while removing the files from
`flutter analyze` scope.

## Related Documentation

- `download/scaffold-investigation-report.md` — full per-file analysis
- `download/scaffold-phase2-report.md` — Phase 2 judgment pass
- `DEVELOPMENT_ROADMAP.md` lines 583-607 — v2.2 Teacher Approval Workflow
  (target consumer for the staff_approval files)
- `worklog.md` tasks `phase1-scaffold-cleanup-attempt`, `phase2-scaffold-judgment`,
  `phase2-scaffold-execution`, `phase5-tickets-2-3-sweep` — full execution
  history of the scaffold cleanup
