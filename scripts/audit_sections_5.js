/**
 * Klasivo UX Audit — Section content builders (Part 5).
 * Sections 9-11: empty states, accessibility, design system cleanup.
 * Sections 12-13: implementation plan, exact code changes.
 */

const U = require("./generate_ux_audit.js");
const {
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer,
  Paragraph, TextRun, PageBreak, AlignmentType, P, FONT, FONT_MONO,
} = U;

// ─────────────────────────────────────────────────────────────────────
// SECTION 9 — Empty States Audit
// ─────────────────────────────────────────────────────────────────────
function buildEmptyStatesAudit() {
  return [
    h1("9.  Empty States Audit"),

    p("The audit reviewed every list/grid screen for empty-state handling. Findings: 9 of 13 screens use a reusable widget, but 4 different reusable widgets exist (fragmentation). 2 screens use inline Center(Text) bypassing the design system. 4 of 13 screens lack a CTA in their empty state. Copy is functional but bland — no illustrations, no helpful messaging beyond the bare fact."),

    h2("9.1  Four competing empty-state widgets"),

    dataTable(
      ["#", "Class", "File:Line", "Variant system", "Status"],
      [
        ["1", "KEmptyState", "lib/shared/widgets/k_empty_state.dart:23", "KEmptyStateType enum (10 values: generic, noResults, noData, noMessages, noNotifications, noExams, noStudents, noClasses, error, offline)", "Dead — not imported anywhere"],
        ["2", "KEmptyState", "lib/core/design_system/components/k_empty_state.dart:46", "KEmptyStateVariant enum (4 values: noData, noResults, error, offline)", "Dead + import collision with #1"],
        ["3", "EmptyState (wrapper)", "lib/widgets/common_widgets.dart:10", "None — delegates to KlasivoEmptyState", "Active"],
        ["4", "KlasivoEmptyState", "lib/widgets/klasivo_components.dart:534", "None — props: icon, title, subtitle, actionLabel, onAction, iconColor", "Active"],
      ],
      [6, 18, 35, 32, 9]
    ),

    callout("FINDING", "Two classes with the same name (KEmptyState) but incompatible variant enums. Two active wrappers (EmptyState and KlasivoEmptyState) — callers use whichever they prefer. No widget supports illustrations / Lottie / SVG out of the box (only customIllustration slot on #1, which is dead).", P.high),

    h2("9.2  Per-screen empty state inventory"),

    dataTable(
      ["Screen", "Widget used", "Visual", "CTA?", "Copy (title / subtitle)"],
      [
        ["Exams list (3 tabs)", "EmptyState → KlasivoEmptyState", "Icon + title + subtitle", "✅ 'Create Exam'", "Upcoming: 'No Upcoming Exams' / 'Create and publish an exam to see it here'; Completed: 'No Completed Exams' / 'Completed exams will appear here'; Drafts: 'No Draft Exams' / 'Draft exams are shown here before publishing'"],
        ["Students list (per class)", "EmptyState", "Icon + title + subtitle", "✅ 'Add Student'", "'No Students Yet' / 'Add students to this class'"],
        ["Students list (all)", "EmptyState", "Icon + title + subtitle", "✅ 'Go to Classes'", "'No Students Yet' / 'Add students to your classes to see them here'"],
        ["Classes list", "EmptyState", "Icon + title + subtitle", "✅ 'Add Class'", "'No Classes Yet' / dynamic subtitle depending on _isStageScoped"],
        ["Inbox / Notifications", "const EmptyState", "Icon + title + subtitle", "❌ No CTA", "'No Notifications' / 'You\\'re all caught up!'"],
        ["Messaging — Conversations", "KlasivoEmptyState (3 distinct)", "Icon + title + subtitle", "Only on 'no messages' → 'New Message'", "Error: 'Something went wrong' / 'Could not load conversations. Pull to retry.'; No results: 'No results' / 'No conversations match \"$query\"'; Empty: 'No Messages Yet' / 'Start a conversation with a classmate or teacher'"],
        ["Messaging — Chat detail", "KlasivoEmptyState (2 distinct)", "Icon + title + subtitle", "❌ No CTA", "Error: 'Something went wrong'; Empty: 'Start the conversation' / 'Send a message to begin chatting'"],
        ["Teachers list (people hub)", "KlasivoEmptyState", "Icon + title + subtitle", "❌ No CTA", "Tab-specific: when query empty → 'No teachers yet' / 'Users will appear here once they join the organization'; when query present → 'No results for \"$query\"'"],
        ["Announcements", "KlasivoEmptyState", "Icon + title + subtitle", "✅ 'Create Announcement'", "'No Announcements' / 'Create your first announcement to reach your organization'"],
        ["Calendar", "INLINE Center(Text)", "Just text — no icon", "❌ No CTA", "'Select a day to view events' / 'No events on this day' — Color: Colors.grey (fails WCAG AA)"],
        ["Academic Years", "INLINE Center(Column)", "Icon (size 64, Colors.grey[300]) + title + subtitle", "✅ 'Create Year' (gated)", "'No Academic Years' / 'Create your first academic year to get started' — uses Colors.grey (fails WCAG AA)"],
        ["Attendance", "const KlasivoEmptyState (2 distinct)", "Icon + title + subtitle", "❌ No CTA", "No class: 'Select a Class' / 'Choose a class above to start taking attendance'; No students: 'No Students' / 'This class has no students enrolled yet'"],
        ["Stages", "EmptyState", "Icon + title + subtitle", "✅ 'Setup Structure'", "'No Stages Yet' / 'Create stages to organize your educational hierarchy.\\ne.g. Kindergarten, Primary, Preparatory, Secondary'"],
        ["Groups", "const KlasivoEmptyState", "Icon + title + subtitle", "❌ No CTA", "'No Groups Yet' / 'Create groups within this class'"],
      ],
      [12, 18, 12, 8, 50]
    ),

    h2("9.3  Issues found"),

    h3("9.3.1  2 screens use inline Center(Text) bypassing the design system"),

    p([code("lib/features/calendar/pages/calendar_screen.dart:188-197"), plain(" — uses Center(Text) with Colors.grey for color. Fails WCAG AA contrast (4.5:1 required for 14pt body text; Colors.grey on white is ~4.4:1 borderline).")]),

    p([code("lib/features/academic_years/pages/academic_year_list_screen.dart:39-69"), plain(" — uses Center(Column(Icon(size: 64, Colors.grey[300]) + Text + Text)). Colors.grey[300] on white is 1.4:1 — completely invisible to users with low vision.")]),

    h3("9.3.2  4 of 13 screens lack a CTA in their empty state"),

    p("Inbox / Notifications, Messaging — Chat detail, Attendance, Groups. Groups is the most egregious — the screen has a FAB for 'Create Group' but the empty state doesn't surface it. Users see an empty screen with no obvious next action."),

    h3("9.3.3  Bug in people_hub_screen.dart icon resolution"),

    p([plain("Location: "), code("lib/features/user_management/pages/people_hub_screen.dart:202-204"), plain(".")]),

    p("When query is empty, the icon for non-'all' tabs resolves to Icons.search_off_rounded instead of a people-icon. This is the wrong visual — it suggests 'no search results' when there's actually no query at all."),

    h3("9.3.4  Duplicate code paths"),

    p([code("features/exams/pages/"), plain(" and "), code("features/exams/presentation/"), plain(" contain byte-identical copies (verified with diff -q). Same for "), code("students/pages"), plain(" vs "), code("students/presentation"), plain(", "), code("classes/pages"), plain(" vs "), code("classes/presentation"), plain(". Empty-state copy is duplicated across both paths.")]),

    h2("9.4  Recommended canonical empty-state widget"),

    p("Consolidate to one widget with the KEmptyState API (variant enum) + the active KlasivoEmptyState props (icon, title, subtitle, actionLabel, onAction). Add an optional illustration slot for future Lottie/SVG support."),

    codeBlock(`// lib/widgets/klasivo_empty_state.dart (NEW — replaces both KEmptyState and KlasivoEmptyState)
enum KlasivoEmptyStateVariant {
  generic, noResults, noData, noMessages, noNotifications,
  noExams, noStudents, noClasses, error, offline,
}

class KlasivoEmptyState extends StatelessWidget {
  const KlasivoEmptyState({
    super.key,
    this.variant = KlasivoEmptyStateVariant.generic,
    this.icon,
    this.iconColor,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.illustration,  // optional Lottie/SVG widget
  });

  final KlasivoEmptyStateVariant variant;
  final IconData? icon;
  final Color? iconColor;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final defaults = _defaultsFor(variant);
    final effectiveIcon = icon ?? defaults.icon;
    final effectiveTitle = title ?? defaults.title;
    final effectiveSubtitle = subtitle ?? defaults.subtitle;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration slot (future Lottie/SVG)
            if (illustration != null) ...[
              illustration!,
              const SizedBox(height: KlasivoSpacing.xxl),
            ] else ...[
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primary).withAlpha(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  effectiveIcon,
                  size: 40,
                  color: iconColor ?? AppColors.primary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.lg),
            ],
            Text(
              effectiveTitle,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (effectiveSubtitle != null) ...[
              const SizedBox(height: KlasivoSpacing.sm),
              Text(
                effectiveSubtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary(Theme.of(context).brightness),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: KlasivoSpacing.xxl),
              KlasivoButton(
                label: actionLabel!,
                variant: KlasivoButtonVariant.primary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Defaults {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _Defaults(this.icon, this.title, [this.subtitle]);
}

_Defaults _defaultsFor(KlasivoEmptyStateVariant v) {
  switch (v) {
    case KlasivoEmptyStateVariant.generic:
      return _Defaults(Icons.inbox_outlined, 'Nothing here yet');
    case KlasivoEmptyStateVariant.noResults:
      return _Defaults(Icons.search_off_rounded, 'No results found', 'Try a different search term');
    case KlasivoEmptyStateVariant.noData:
      return _Defaults(Icons.folder_open_outlined, 'No data yet');
    case KlasivoEmptyStateVariant.noMessages:
      return _Defaults(Icons.chat_bubble_outline_rounded, 'No messages yet', 'Start a conversation to see it here');
    case KlasivoEmptyStateVariant.noNotifications:
      return _Defaults(Icons.notifications_none_outlined, 'You\\'re all caught up!', 'New notifications will appear here');
    case KlasivoEmptyStateVariant.noExams:
      return _Defaults(Icons.assignment_outlined, 'No exams yet', 'Create an exam to get started');
    case KlasivoEmptyStateVariant.noStudents:
      return _Defaults(Icons.people_outline_rounded, 'No students yet', 'Add students to see them here');
    case KlasivoEmptyStateVariant.noClasses:
      return _Defaults(Icons.class_outlined, 'No classes yet', 'Create a class to get started');
    case KlasivoEmptyStateVariant.error:
      return _Defaults(Icons.error_outline_rounded, 'Something went wrong', 'Pull to retry');
    case KlasivoEmptyStateVariant.offline:
      return _Defaults(Icons.cloud_off_outlined, 'You\\'re offline', 'Connect to the internet to continue');
  }
}`),

    h2("9.5  Recommended copy improvements"),

    p("Current copy is functional but bland. Apply these rewrites for warmth and actionability:"),

    dataTable(
      ["Screen", "Current copy", "Improved copy"],
      [
        ["Exams (upcoming)", "'No Upcoming Exams' / 'Create and publish an exam to see it here'", "'No upcoming exams' / 'Schedule your next exam and it\\'ll appear here with student counts and due dates.'"],
        ["Exams (completed)", "'No Completed Exams' / 'Completed exams will appear here'", "'No completed exams yet' / 'Once students submit their exams, results will show up here for review.'"],
        ["Students (per class)", "'No Students Yet' / 'Add students to this class'", "'This class has no students' / 'Add students individually or import a roster to get started.'"],
        ["Classes", "'No Classes Yet' / (varies)", "'No classes yet' / 'Create your first class — try Grade 1, Section A, or any name that fits your school.'"],
        ["Inbox", "'No Notifications' / 'You\\'re all caught up!'", "'You\\'re all caught up' / 'Announcements, exam reminders, and message notifications will appear here.'"],
        ["Teachers", "'No teachers yet' / 'Users will appear here once they join the organization'", "'No teachers yet' / 'Invite teachers with an invite code, or wait for them to join your workspace.'"],
        ["Announcements", "'No Announcements' / 'Create your first announcement to reach your organization'", "'No announcements yet' / 'Send your first announcement to notify teachers, parents, and students about news and events.'"],
        ["Calendar", "'Select a day to view events' / 'No events on this day'", "'Pick a day to see events' / 'Nothing scheduled for this day — add an exam, class, or holiday to fill the calendar.'"],
        ["Academic Years", "'No Academic Years' / 'Create your first academic year to get started'", "'No academic years yet' / 'Set up your first academic year (e.g., 2026-2027) to start organizing terms and classes.'"],
        ["Groups", "'No Groups Yet' / 'Create groups within this class'", "'No groups yet' / 'Create study groups, project teams, or skill-based clusters within this class.'"],
      ],
      [15, 40, 45]
    ),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 10 — Accessibility Audit
// ─────────────────────────────────────────────────────────────────────
function buildAccessibilityAudit() {
  return [
    h1("10.  Accessibility Audit"),

    p("The audit checked touch targets, contrast ratios, font scaling, and screen-reader friendliness across the entire lib/ directory. The findings are concentrated: most issues repeat the same patterns across many files. Fixing the patterns (rather than individual call sites) will resolve the majority of violations."),

    h2("10.1  Touch targets"),

    p("89 IconButton calls across 57 files. 67 GestureDetector/InkWell calls across 41 files. 143 TextField/TextFormField calls across 53 files. Sub-48dp violations:"),

    dataTable(
      ["File:line", "Code", "Issue"],
      [
        ["gradebook_screen.dart:462-465", "constraints: BoxConstraints(minWidth: 36, minHeight: 36)", "36×36 — fails 48dp minimum"],
        ["gradebook_screen.dart:476-479", "constraints: BoxConstraints(minWidth: 36, minHeight: 36)", "Same — delete IconButton"],
        ["exam_list_screen.dart:293-294", "padding: EdgeInsets.zero, constraints: const BoxConstraints()", "Empty BoxConstraints removes the default 48dp min — actual touch area ~20×20"],
        ["question_builder_screen.dart:340, 347", "padding: EdgeInsets.zero, constraints: const BoxConstraints()", "Same pattern — for edit + delete in question list"],
      ],
      [35, 35, 30]
    ),

    p([bold("Fix pattern:"), plain(" remove custom constraints entirely, OR set "), code("BoxConstraints(minWidth: 48, minHeight: 48)"), plain(". Also set "), code("IconButton.styleFrom(minimumSize: Size(48, 48))"), plain(" globally via the iconButtonTheme in ThemeData.")]),

    h2("10.2  Semantics usage"),

    p("Only 4 Semantics( occurrences in the entire codebase. All are in widget-library files: lib/widgets/klasivo_card.dart:107, lib/shared/widgets/k_card.dart:96 (dead), lib/core/design_system/components/k_card.dart:160 (dead), lib/core/design_system/components/k_button.dart:170 (dead)."),

    p("ZERO feature screens use Semantics on custom widgets. Notable gaps:"),
    bullet("_NotificationCard (notification_center_screen.dart) — no semantics"),
    bullet("_ExamTile (exam_list_screen.dart) — no semantics (delete IconButton has tooltip but card itself isn't a semantic button)"),
    bullet("Chat bubbles (chat_screen.dart) — no semantics for sender/timestamp grouping"),
    bullet("Dashboard stat cards — no semantics"),
    bullet("All auth flow widgets (Section 3.6.1) — zero Semantics"),

    p("KlasivoCard.semanticLabel prop exists but is optional and most callers don't pass it."),

    h2("10.3  Tooltip usage"),

    p("tooltip: used 27 times across 20 files (some are ButtonSegment tooltips in settings_screen.dart, not IconButtons). IconButtons without tooltips: ~60+ of the 89 total (~67% lack tooltips)."),

    p("AppBar action IconButtons are inconsistent: people_hub_screen.dart:107 has tooltip: 'Role Matrix', but many other AppBar IconButtons (e.g., in exam_detail_screen.dart, question_builder_screen.dart) lack tooltips."),

    h2("10.4  Font scaling — ZERO handling"),

    p("ZERO occurrences of MediaQuery.textScaler, textScaleFactor, maxFontSize, or textScaleFactorClamp in the entire lib/ directory. The app does not clamp font scaling. At 1.5x or 2x system font scale (common for users over 50), the 58 unexpanded Row(Icon + Text) patterns identified in Section 6.4 will overflow horizontally. No widget tests for large font scales exist."),

    h3("10.4.1  Stopgap fix — clamp textScaler in MaterialApp.builder"),

    codeBlock(`// lib/main.dart — in MyApp.build()
return MaterialApp.router(
  // ... existing config ...
  builder: (context, child) {
    final mediaQuery = MediaQuery.of(context);
    // Clamp text scale to 1.3x to prevent overflow on extreme accessibility settings.
    // Long-term fix: refactor all unexpanded Row patterns to scale gracefully.
    final clampedScaler = mediaQuery.textScaler.clamp(maxScaleFactor: 1.3);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: child!,
    );
  },
);`),

    p("This is a stopgap. The long-term fix is to refactor the 58 unexpanded Row patterns identified in Section 6.4 to scale gracefully. Until then, the clamp prevents catastrophic overflow."),

    h2("10.5  Contrast ratios — 84 Colors.grey[300-500] usages"),

    p("A grep for Colors.grey[300]/[400]/[500] returns 84 occurrences across 28 files. These map to #E0E0E0 / #BDBDBD / #9E9E9E — contrast ratios of 1.4:1 / 1.9:1 / 2.9:1 on white. All fail WCAG AA (requires 4.5:1 for normal text, 3:1 for large text ≥18pt)."),

    p("An additional 184 occurrences of Colors.grey (default = #757575) across 40 files — ~4.5:1 on white (borderline, fails for small text and fails AAA). 18 occurrences of Colors.white70/60/54/30 across 10 files — fail WCAG on most backgrounds."),

    h3("10.5.1  Top contrast offenders"),

    dataTable(
      ["File:line", "Color used", "Contrast on white", "Fix"],
      [
        ["audit_log_screen.dart:25", "Colors.grey[300] icon", "1.4:1 — invisible", "AppColors.textTertiary(brightness)"],
        ["audit_log_screen.dart:28, 31, 113", "Colors.grey text", "~4.5:1 borderline", "AppColors.textSecondary(brightness)"],
        ["academic_year_list_screen.dart:44", "Colors.grey[300] icon", "1.4:1 (empty state!)", "AppColors.textTertiary(brightness)"],
        ["academic_year_list_screen.dart:46, 49", "Colors.grey text", "Borderline", "AppColors.textSecondary(brightness)"],
        ["exam_instances_screen.dart:35, 37, 40", "Colors.grey[300] + Colors.grey + Colors.grey[500]", "All fail", "AppColors tokens"],
        ["calendar_screen.dart:191, 196", "Colors.grey text", "Borderline (empty state)", "AppColors.textSecondary"],
        ["exam_integrity_dashboard.dart:76, 80", "Colors.grey[400] + Colors.grey[500]", "1.9:1 and 2.9:1", "AppColors tokens"],
        ["teacher_analytics_dashboard.dart (24 usages)", "Various grey[200]/[400]/[500]/[600]", "Multiple failures", "AppColors tokens"],
        ["klasivo_components.dart:166, 177", "Colors.white70", "Fails on light surface", "AppColors.textTertiary(brightness)"],
        ["student_exam_list_screen.dart (8 usages)", "Colors.grey[500]/[600]/[700]", "Mixed", "AppColors tokens"],
        ["live_class_screen.dart (8 usages)", "Various", "Mixed", "AppColors tokens"],
      ],
      [32, 22, 22, 24]
    ),

    p([bold("Fix:"), plain(" batch find-and-replace Colors.grey[300] → AppColors.textTertiary(brightness), Colors.grey[400]/[500] → AppColors.textSecondary(brightness), Colors.grey (default) → AppColors.textSecondary(brightness). Each replacement is a single-line edit. The 84 + 184 = 268 occurrences can be batched by file and fixed in ~6 hours.")]),

    h2("10.6  Screen reader — form labels & list items"),

    p("Form fields: TextField/TextFormField are 143 occurrences. A spot check shows most use KlasivoTextField/KTextField wrappers which expose label/hintText. Not exhaustively verified — recommend a follow-up audit specifically of all TextField( calls to ensure each has labelText or hintText."),

    p("List items are NOT semantic. None of the custom list-item widgets (_NotificationCard, _ExamTile, _ConversationTile, _StudentTile, _AnnouncementCard, etc.) wrap their content in Semantics. Screen-reader users will hear each child Text individually rather than a coherent 'Exam: Math Test, scheduled for…' announcement."),

    h2("10.7  Prioritized accessibility fixes"),

    dataTable(
      ["Priority", "Fix", "Files affected", "Effort"],
      [
        ["P0", "Fix sub-48dp touch targets in gradebook, exam_list, question_builder", "4 files", "30 min"],
        ["P0", "Replace 84 Colors.grey[300-500] with AppColors tokens", "28 files", "6 hours"],
        ["P0", "Clamp textScaler in MaterialApp.builder (stopgap)", "1 file (main.dart)", "10 min"],
        ["P1", "Add Tooltip to all 60+ IconButtons missing them", "~40 files", "3 hours"],
        ["P1", "Add Semantics(button: true, label: ...) to all auth-flow tappable widgets", "12 files", "4 hours"],
        ["P1", "Add Semantics to custom list-item widgets (NotificationCard, ExamTile, etc.)", "~10 files", "4 hours"],
        ["P2", "Audit all 143 TextField calls for labelText/hintText", "~53 files", "6 hours"],
        ["P2", "Add Semantics to dashboard stat cards", "~5 files", "2 hours"],
        ["P2", "Refactor 58 unexpanded Row patterns so they scale at 2x font", "~30 files", "8 hours"],
        ["P3", "Write widget tests at 1.5x and 2x text scale", "test/ directory", "1 day"],
      ],
      [8, 50, 25, 17]
    ),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

module.exports = { buildEmptyStatesAudit, buildAccessibilityAudit };
