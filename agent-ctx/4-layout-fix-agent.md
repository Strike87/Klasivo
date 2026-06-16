# Task 4 — Layout Overflow Fix Agent

## Task
Fix ALL layout overflow errors ("RIGHT OVERFLOWED BY N PIXELS") across the Klasivo Flutter project.

## Root Cause Analysis
- Primary: `KlasivoAnalyticsCard` label `Text` in `Row` not wrapped in `Expanded`/`Flexible`
- Secondary: `_QuickActionChip` in `Row` (3 chips on narrow screens), stat pill `Row`s, `_InfoCard`/`_DetailCard` inner `Column` not in `Expanded`, `_ScheduleRow` bare `Text`

## Files Changed (17 total)

### Core Components
1. **lib/widgets/klasivo_components.dart** — KlasivoAnalyticsCard label+value Text overflow, KlasivoSectionHeader title overflow
2. **lib/widgets/klasivo_card.dart** — No changes needed

### Dashboards
3. **lib/features/dashboard/owner_dashboard.dart** — Row→Wrap for QuickActionChips, text overflow
4. **lib/features/dashboard/teacher_dashboard.dart** — ListTile title/subtitle overflow
5. **lib/features/dashboard/student_dashboard.dart** — Exam card text overflow

### LMS
6. **lib/features/lms/pages/lesson_detail_screen.dart** — StatPills Row→Wrap
7. **lib/features/lms/pages/subject_content_screen.dart** — StatPills Row→Wrap

### Exams
8. **lib/features/exams/pages/exam_detail_screen.dart** — _InfoCard Expanded, _ScheduleRow Flexible
9. **lib/features/exams/presentation/exam_detail_screen.dart** — Same as #8

### Results
10. **lib/features/student_results/pages/student_results_screen.dart** — _DetailCard Expanded
11. **lib/features/teacher_results/pages/exam_results_screen.dart** — _StatCard value overflow

### Analytics
12. **lib/features/analytics/pages/teacher_analytics_dashboard.dart** — _StatCard/_MetricCard text overflow

### Parent
13. **lib/features/parent/pages/parent_dashboard.dart** — Trailing Row date Flexible
14. **lib/features/shell/parent_shell.dart** — Trailing Row date Flexible

### LiveKit
15. **lib/features/livekit/pages/session_analytics_dashboard.dart** — _StatCard overflow, _MetricChip Row→Wrap
16. **lib/features/livekit/pages/scheduled_classes_screen.dart** — Teacher name Flexible, chips Row→Wrap

### Integrity & Progress
17. **lib/features/integrity/pages/exam_integrity_dashboard.dart** — _IntegrityCard overflow, type label Flexible
18. **lib/features/progress/pages/progress_tracking_screen.dart** — Stat cards overflow, _MetricChip Row→Wrap

## Fix Patterns Applied
- `Expanded` wrapping for Row children with Text
- `Flexible` for Texts that share Row space with icons
- `maxLines: 1` + `overflow: TextOverflow.ellipsis` for constrained Texts
- `Row` → `Wrap` for chips/tags that should reflow on narrow screens
- No business logic or data fetching changes
