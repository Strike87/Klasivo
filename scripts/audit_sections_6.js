/**
 * Klasivo UX Audit — Section content builders (Part 6).
 * Sections 11-13: design system cleanup, implementation plan, exact code changes.
 */

const U = require("./generate_ux_audit.js");
const {
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer,
  Paragraph, TextRun, PageBreak, AlignmentType, P, FONT, FONT_MONO,
} = U;

// ─────────────────────────────────────────────────────────────────────
// SECTION 11 — Design System Cleanup
// ─────────────────────────────────────────────────────────────────────
function buildDesignSystemAudit() {
  return [
    h1("11.  Design System Cleanup"),

    p("Klasivo ships with a well-structured token system (colors, spacing, radius, typography, elevation, animation) and a passable component library. However, the design system is only partially consumed: three parallel widget libraries compete for adoption, two parallel token folders exist with overlapping definitions, and the configured theme is ignored at runtime. This section catalogs the design-system debt and proposes a consolidation plan."),

    h2("11.1  Current design-system structure"),

    codeBlock(`lib/core/
├── config/
│   ├── theme.dart              ← ACTIVE: AppTheme.lightTheme / darkTheme
│   └── theme_provider.dart     ← ThemeModeNotifier + themeModeProvider (DEAD)
├── tokens/                     ← ACTIVE: legacy token home, 63 import sites
│   ├── app_colors.dart         (203 lines)
│   ├── app_spacing.dart        (68 lines)
│   ├── app_radius.dart         (31 lines)
│   ├── app_typography.dart     (191 lines)
│   ├── app_elevation.dart      (28 lines)
│   ├── app_animation.dart      (68 lines)
│   └── tokens.dart             ← barrel export
└── design_system/              ← DEAD CODE
    ├── design_system.dart      ← barrel; component exports COMMENTED OUT
    ├── tokens/                 ← DUPLICATE of lib/core/tokens/ (byte-identical)
    │   ├── app_colors.dart     (byte-identical)
    │   ├── app_spacing.dart    (byte-identical)
    │   ├── app_radius.dart     (byte-identical)
    │   ├── app_typography.dart (byte-identical)
    │   ├── app_elevation.dart  (byte-identical)
    │   ├── app_animation.dart  (byte-identical)
    │   ├── app_durations.dart  (NEW file, not in legacy dir)
    │   └── tokens.dart
    └── components/             ← DEAD — 11 K-prefixed widgets, zero imports
        ├── k_button.dart       (437 lines)
        ├── k_card.dart
        ├── k_dialog.dart
        ├── k_search_field.dart
        ├── k_avatar.dart
        ├── k_badge.dart
        ├── k_empty_state.dart
        ├── k_loading_state.dart
        ├── k_text_field.dart
        ├── k_modal.dart
        ├── k_toast.dart
        └── components.dart     (barrel export)

lib/widgets/                    ← ACTIVE component library (63 import sites)
├── klasivo_button.dart         (166 lines) — KlasivoButton
├── klasivo_card.dart           (117 lines) — KlasivoCard
├── klasivo_components.dart     (728 lines) — many widgets
├── klasivo_text_field.dart
├── klasivo_modal.dart
├── klasivo_toast.dart
├── klasivo_badge.dart
├── klasivo_avatar.dart
├── klasivo_cached_image.dart
├── klasivo_completion_badge.dart
├── klasivo_error_boundary.dart
├── klasivo_paginated_list.dart
├── klasivo_youtube_player.dart
├── klasivo_permission_gate.dart
└── common_widgets.dart         (barrel)

lib/shared/widgets/             ← DEAD — 11 K-prefixed widgets, zero imports
├── k_button.dart, k_card.dart, k_dialog.dart, k_search_field.dart,
├── k_empty_state.dart, k_loading_state.dart, k_avatar.dart,
├── k_badge.dart, k_text_field.dart, k_modal.dart, k_toast.dart,
└── widgets.dart`),

    h2("11.2  Design tokens — concrete values"),

    h3("11.2.1  Colors (lib/core/tokens/app_colors.dart)"),

    dataTable(
      ["Token", "Hex", "Role"],
      [
        ["primary / primaryLight / primaryDark / primarySurface", "#3B5BDB / #5C7CFA / #364FC7 / #EDF2FF", "Royal Indigo — main brand"],
        ["secondary / secondaryLight / secondaryDark / secondarySurface", "#12B886 / #38D9A9 / #099268 / #E6FCF5", "Emerald — success/positive"],
        ["accent / accentLight / accentDark / accentSurface", "#F59F00 / #FCC419 / #E67700 / #FFF9DB", "Amber Gold — highlights"],
        ["error / errorLight / errorDark / errorSurface", "#E03131 / #FF6B6B / #C92A2A / #FFE3E3", "Error states"],
        ["warning (== accent) / info (== primary) / success (== secondary)", "(same hexes)", "Semantically aliased — NOT distinct"],
        ["lightBackground / lightSurface / lightCard / lightBorder / lightDivider", "#F8F9FA / #FFFFFF / #FFFFFF / #E9ECEF / #DEE2E6", "Light theme surfaces"],
        ["lightTextPrimary / Secondary / Tertiary / Disabled", "#212529 / #495057 / #868E96 / #ADB5BD", "Light theme text"],
        ["darkBackground / darkSurface / darkCard / darkBorder / darkDivider", "#0F172A / #1E293B / #1E293B / #334155 / #334155", "Dark theme surfaces (Tailwind slate)"],
        ["darkTextPrimary / Secondary / Tertiary / Disabled", "#F1F5F9 / #CBD5E1 / #94A3B8 / #64748B", "Dark theme text"],
        ["subjectMath/Science/English/History/Arabic/Art/Physics/Chemistry/Biology/Geography/Default", "11 distinct hexes", "Subject color coding"],
        ["roleOwner/Admin/Teacher/Student/Parent/CampusManager/Observer/SuperAdmin", "8 distinct hexes", "Role color coding"],
        ["priorityLow/Medium/High/Urgent", "#12B886 / #F59F00 / #E8590C / #E03131", "Priority badges"],
      ],
      [38, 32, 30]
    ),

    p([plain("Helpers: "), code("resolve({brightness, light, dark})"), plain(", "), code("textPrimary/Secondary/Tertiary/Disabled(brightness)"), plain(", "), code("border/divider/background/surface/card/skeleton(brightness)"), plain(", "), code("subjectColor(String)"), plain(", "), code("roleColor(String)"), plain(".")]),

    h3("11.2.2  Spacing (lib/core/tokens/app_spacing.dart) — 4px grid"),

    dataTable(
      ["Token", "Value (dp)", "Use case"],
      [
        ["unit / xs / sm / md / lg / xl / xxl / xxxl / hero", "4 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48", "Base spacing scale"],
        ["inlineXs / Sm / Md / Lg", "4 / 8 / 12 / 16", "Inline (horizontal) gaps"],
        ["stackXs / Sm / Md / Lg / Xl", "4 / 8 / 12 / 16 / 24", "Stack (vertical) gaps"],
        ["buttonHorizontal / Vertical / IconGap", "24 / 14 / 8", "Button internal padding"],
        ["inputHorizontal / Vertical", "16 / 12", "TextField internal padding"],
        ["cardPadding / cardGap", "16 / 8", "Card padding and gap between cards"],
        ["listItemHorizontal / Vertical", "16 / 4", "List tile padding"],
        ["screenHorizontal / Top / Bottom", "16 / 16 / 32", "Screen edge padding"],
        ["appBarContent / tabBarIndicator / fabSpacing", "16 / 2 / 16", "Component-specific"],
        ["chipHorizontal / Vertical", "12 / 4", "Chip padding"],
        ["avatarRadius / Sm / Lg", "28 / 20 / 36", "Avatar sizes"],
        ["iconSizeSm / Md / Lg / Xl / Hero", "16 / 20 / 24 / 32 / 48", "Icon size scale"],
      ],
      [40, 22, 38]
    ),

    h3("11.2.3  Radius (lib/core/tokens/app_radius.dart)"),

    dataTable(
      ["Token", "Value (dp)", "Semantic"],
      [
        ["xs / sm / md / lg / xl / xxl / pill", "6 / 8 / 14 / 16 / 20 / 28 / 100", "Base radius scale"],
        ["button = md = 14", "14", "Standard button radius"],
        ["input = md = 14", "14", "TextField radius"],
        ["card = md = 14", "14", "Klasivo standard card radius"],
        ["dialog = lg = 16", "16", "Dialog radius"],
        ["bottomSheet = xl = 20", "20", "Bottom sheet radius"],
        ["snackbar = md = 14", "14", "Snackbar radius"],
        ["tooltip = sm = 8", "8", "Tooltip radius"],
        ["fab = lg = 16", "16", "FAB radius"],
        ["badge = pill = 100", "100", "Badge radius (full pill)"],
        ["avatar = pill = 100", "100", "Avatar radius (full pill)"],
        ["iconButton = sm = 8", "8", "IconButton radius"],
      ],
      [40, 22, 38]
    ),

    h3("11.2.4  Typography (lib/core/tokens/app_typography.dart)"),

    p([plain("Font family: "), code("PlusJakartaSans"), plain(" (regular 400, medium 500, semibold 600, bold 700 declared in pubspec.yaml:110-119). Arabic fallback: "), code("NotoSansArabic"), plain(".")]),

    p([plain("Type scale (font size / weight / line-height):")]),

    dataTable(
      ["Token", "Size / Weight / LH", "Use case"],
      [
        ["displayLarge", "40 / w700 / 1.1", "Splash title, hero numbers"],
        ["displayMedium", "32 / w700 / 1.15", "Large screen titles"],
        ["displaySmall", "28 / w700 / 1.2", "Dashboard hero stats"],
        ["headlineLarge", "26 / w700 / 1.25", "Screen titles (auth)"],
        ["headlineMedium", "22 / w600 / 1.3", "Section titles"],
        ["headlineSmall", "18 / w600 / 1.35", "AppBar titles"],
        ["titleLarge", "16 / w600 / 1.4", "Card titles"],
        ["titleMedium", "14 / w600 / 1.4", "List item titles"],
        ["titleSmall", "13 / w600 / 1.4", "Small titles (Feature Flag labels)"],
        ["bodyLarge", "16 / w400 / 1.5", "Primary body text"],
        ["bodyMedium", "14 / w400 / 1.5", "Default body text"],
        ["bodySmall", "12 / w400 / 1.5", "Captions, secondary text"],
        ["labelLarge", "14 / w600 / 1.4", "Button labels"],
        ["labelMedium", "12 / w600 / 1.4", "Badges, chips"],
        ["labelSmall", "11 / w600 / 1.4", "Tiny labels"],
        ["caption", "11 / w400 / 1.4", "Footnotes"],
        ["overline", "10 / w600 / 1.6", "Section headers (e.g., 'PRODUCT')"],
        ["monospace", "13 / w400 / 1.5", "Code blocks (⚠️ RobotoMono undeclared)"],
        ["arabicBody", "16 / w400 / 1.8", "Arabic body"],
        ["arabicTitle", "18 / w700 / 1.6", "Arabic title"],
      ],
      [25, 22, 53]
    ),

    h3("11.2.5  Elevation & Animation"),

    p([plain("Elevation (lib/core/tokens/app_elevation.dart): "), code("none=0, sm=1, md=2, lg=4, xl=8, xxl=16"), plain(". "), code("appBarResting=0, appBarScrolled=0.5"), plain(". Design philosophy is 'border-first' — cards use 1-px border instead of elevation.")]),

    p([plain("Animation (lib/core/tokens/app_animation.dart): durations "), code("instant=50ms, fast=150ms, normal=250ms, slow=400ms, deliberate=600ms"), plain(". Semantic: "), code("buttonPress=fast, toggle=fast, expand/fade/slide/dialog/bottomSheet=normal, pageTransition=slow, snackbar=300ms, tooltip=fast, shimmer=1500ms, skeletonPulse=1200ms"), plain(". Curves: "), code("standard=easeInOut, decelerate, accelerate=easeIn, linear, smoothBounce=easeOutBack, gentleSpring=easeOutCubic, sharpSnap=easeInToLinear"), plain(". Stagger delay 40ms, maxStaggerItems 10.")]),

    h3("11.2.6  AppDurations — orphaned and conflicting"),

    p([plain("Location: "), code("lib/core/design_system/tokens/app_durations.dart"), plain(" (DEAD).")]),

    p([plain("Values: "), code("instant=100ms, fast=200ms, normal=300ms, slow=500ms, verySlow=800ms, toastShort=2s, toastLong=4s, snackbar=3s, searchDebounce=300ms, inputDebounce=150ms, feedbackPulse=50ms, loadingDelay=500ms"), plain(".")]),

    p([bold("Conflict:"), plain(" these duplicate/overlap AppAnimation duration scale with DIFFERENT values: "), code("AppAnimation.fast=150ms"), plain(" vs "), code("AppDurations.fast=200ms"), plain("; "), code("AppAnimation.normal=250ms"), plain(" vs "), code("AppDurations.normal=300ms"), plain(". The two token sets disagree. Neither is consumed — widgets use hardcoded "), code("Duration(milliseconds: 200)"), plain(" (e.g., klasivo_components.dart:383,410,499; teacher_registration_screen.dart:437).")]),

    h2("11.3  What's MISSING from the design system"),

    bullet([bold("No logo/brand-mark asset"), plain(" — only assets/icon/app_icon.png and app_icon_foreground.png exist (both byte-identical 1024×1024 PNG). No SVG, no horizontal lockup, no monochrome variant, no favicon set.")]),
    bullet([bold("No BrandLogo widget"), plain(" — every screen reinvents the logo container (8 different sizes, 3 different shapes, 5 different Material Icons). See Section 4.")]),
    bullet([bold("No dark-mode-specific color tweaks"), plain(" — AppColors has parallel light*/dark* fields, but dark theme simply swaps to primaryLight (#5C7CFA) at ThemeData level. Custom widgets re-check Theme.of(context).brightness inline (massive duplication).")]),
    bullet([bold("RobotoMono font referenced but not declared"), plain(" — AppTypography.monospace (line 151) references 'RobotoMono' which is not in pubspec.yaml fonts. Silent fallback to system font.")]),
    bullet([bold("No motion tokens consumed"), plain(" — AppAnimation and AppDurations exist (with conflicting values), but widgets use hardcoded Duration(milliseconds: 200).")]),
    bullet([bold("No elevation tokens consumed"), plain(" — AppElevation exists, but KlasivoCard uses raw AppElevation.md only; custom shadows are hardcoded Colors.black.withOpacity(0.08) (klasivo_card.dart:80).")]),
    bullet([bold("No semantic AppColors.warning distinct from accent"), plain(" — both are #F59F00. Same for info==primary, success==secondary. Real semantic separation needed for accessibility.")]),
    bullet([bold("No dark-mode shadow tokens"), plain(" — AppElevation does not define dark-mode shadow opacity.")]),
    bullet([bold("No focus-ring / accessibility-outline tokens"), plain(" — for keyboard navigation.")]),
    bullet([bold("AppBar title textStyle hardcoded"), plain(" — appBarTheme.titleTextStyle (theme.dart:69-74, 406-411) hardcodes fontSize: 18, fontWeight: w600 instead of using AppTypography.headlineSmall (which is 18/w600/1.35 — close but not identical and not tokenized).")]),
    bullet([bold("No icon size tokens in ThemeData"), plain(" — iconTheme is not set on appBarTheme or globally; sizes are passed per-call site (337 hardcoded fontSize occurrences).")]),

    h2("11.4  Theme wiring — ignored at runtime"),

    p([plain("Location: "), code("lib/main.dart:407-414"), plain(" (active entry), "), code("lib/app/app.dart"), plain(" (dead KlasivoApp).")]),

    codeBlock(`// lib/main.dart:407-414 — ACTIVE entry point
return MaterialApp.router(
  title: 'Klasivo',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.system,  // ❌ hardcoded, ignores themeModeProvider
  routerConfig: router,
);`),

    p([plain("KlasivoApp at "), code("lib/app/app.dart"), plain(" watches "), code("themeModeProvider"), plain(" — but is never used (no "), code("runApp(const KlasivoApp())"), plain(" anywhere). Two competing "), code("themeModeProvider"), plain(" definitions exist (lib/core/config/theme_provider.dart:87 and lib/providers/theme_provider.dart:119), persisting to different Hive boxes (app_settings vs auth). Neither is consulted by main.dart.")]),

    p([bold("Fix:"), plain(" replace hardcoded "), code("ThemeMode.system"), plain(" with "), code("ref.watch(themeModeProvider)"), plain(". Consolidate the two competing providers into one. Delete the dead KlasivoApp.")]),

    codeBlock(`// lib/main.dart — FIXED
return MaterialApp.router(
  title: 'Klasivo',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ref.watch(themeModeProvider),  // ✅ honor user preference
  routerConfig: router,
);`),

    h2("11.5  Recommended consolidation plan"),

    h3("11.5.1  Phase A — Delete dead code (P0, 1 hour)"),

    bullet([code("rm -rf lib/features/auth/presentation/"), plain(" (8 duplicate files, ~1,921 lines)")]),
    bullet([code("rm -rf lib/features/exams/presentation/"), plain(" (4 duplicate files)")]),
    bullet([code("rm -rf lib/features/students/presentation/"), plain(" (3 duplicate files)")]),
    bullet([code("rm -rf lib/features/classes/presentation/"), plain(" (2 duplicate files)")]),
    bullet([code("rm -rf lib/shared/widgets/"), plain(" (11 dead K-prefixed widgets)")]),
    bullet([code("rm -rf lib/core/design_system/components/"), plain(" (11 dead K-prefixed widgets)")]),
    bullet([code("rm lib/app/app.dart"), plain(" (dead KlasivoApp)")]),
    bullet([code("rm /home/z/my-project/klasivo_icon.png"), plain(" (mislabeled JPEG)")]),

    h3("11.5.2  Phase B — Consolidate token folders (P1, 2 hours)"),

    p([plain("Two token folders exist: "), code("lib/core/tokens/"), plain(" (active) and "), code("lib/core/design_system/tokens/"), plain(" (dead duplicate, only diff: +app_durations.dart).")]),

    bullet([plain("Move "), code("lib/core/design_system/tokens/app_durations.dart"), plain(" to "), code("lib/core/tokens/app_durations.dart")]),
    bullet([plain("Resolve the value conflict: pick either AppAnimation values (150/250/400ms) or AppDurations values (200/300/500ms). Recommend AppDurations — they're more readable.")]),
    bullet([code("rm -rf lib/core/design_system/tokens/")]),
    bullet([code("rm -rf lib/core/design_system/"), plain(" (now empty)")]),
    bullet([plain("Update "), code("lib/core/design_system/design_system.dart"), plain(" barrel — delete it, redirect any callers to "), code("lib/core/tokens/tokens.dart")]),

    h3("11.5.3  Phase C — Wire themeModeProvider (P0, 30 min)"),

    bullet([plain("Replace hardcoded ThemeMode.system in main.dart:413 with ref.watch(themeModeProvider)")]),
    bullet([plain("Consolidate the two competing themeModeProvider definitions into one (pick lib/core/config/theme_provider.dart)")]),
    bullet([plain("Migrate any callers of the deprecated provider to the canonical one")]),
    bullet([plain("Verify on device: change theme in Settings → observe app respects light/dark/system")]),

    h3("11.5.4  Phase D — Add missing tokens (P2, 4 hours)"),

    bullet([plain("Add RobotoMono to pubspec.yaml fonts: section (or remove the monospace token)")]),
    bullet([plain("Add iconSizeHeroLg=56 and iconSizeDisplayLg=64 to AppSpacing (used by splash and welcome/forgot_password headers)")]),
    bullet([plain("Add semantic warning/info/success colors that are distinct from accent/primary/secondary (currently aliased — fails accessibility for users who rely on color alone)")]),
    bullet([plain("Add dark-mode shadow tokens (AppElevation.darkShadowOpacity)")]),
    bullet([plain("Add focus-ring color token (AppColors.focusRing) for keyboard navigation")]),

    h3("11.5.5  Phase E — Create missing reusable widgets (P2, 1 day)"),

    bullet([code("KlasivoBrandHeader"), plain(" — see Section 3.8 / Section 13.5")]),
    bullet([code("KlasivoAuthScaffold"), plain(" — see Section 3.2.1")]),
    bullet([code("KlasivoErrorBanner"), plain(" — extract the inline red Container + error icon + text pattern repeated 6× across auth screens")]),
    bullet([code("KlasivoDividerWithLabel"), plain(" — extract the OR divider pattern repeated 5× across auth screens")]),
    bullet([code("KlasivoBottomNav"), plain(" — see Section 8.4 / Section 13.4")]),
    bullet([code("KlasivoEmptyState"), plain(" (consolidated) — see Section 9.4")]),
    bullet([code("KlasivoSectionHeader"), plain(" — extract the two duplicate _SectionHeader classes from settings_screen.dart:386 and feature_flags_screen.dart:319")]),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 12 — Implementation Plan
// ─────────────────────────────────────────────────────────────────────
function buildImplementationPlan() {
  return [
    h1("12.  Implementation Plan"),

    p("The plan is organized into four phases by impact and effort. Phase 1 contains quick wins (under 30 minutes each) that ship the highest perceived-quality improvement per hour. Phase 2 contains medium improvements (under 2 hours each). Phase 3 contains the architectural refactors that unlock future polish. Phase 4 contains the localization and accessibility work that makes the app ready for international markets and assistive-technology users."),

    h2("12.1  Phase 1 — Quick wins (<30 min each, ship same day)"),

    p("48 quick wins were identified across the 9 audit dimensions. The highest-impact 20 are listed below. Estimated total: 8 hours."),

    dataTable(
      ["#", "Task", "Files", "Impact"],
      [
        ["1", "Replace adaptive_icon_background #1A3A8A → #3B5BDB", "pubspec.yaml:131", "Brand color consistency on launcher"],
        ["2", "Add loading: isLoading to Google button on 3 screens", "teacher_login, teacher_registration, owner_register", "Loading spinner shown on Google sign-in"],
        ["3", "Add SizedBox(height: 24) between 'Create one' Wrap and 'Link your child' Center in parent_login_screen", "parent_login_screen.dart:316", "Fix visual bug — CTAs no longer flush"],
        ["4", "Change welcome_screen top padding from hero(48) → lg(16)", "welcome_screen.dart:201", "Visual consistency with other auth screens"],
        ["5", "Change 'Sign In' button labels → 'Sign in' (Sentence case)", "teacher_login, student_login", "Capitalization consistency"],
        ["6", "Change 'Student Login' screen title → 'Student sign-in'", "student_login_screen.dart:105", "Login noun deprecated"],
        ["7", "Change 'Back to Login' → 'Back to sign-in'", "forgot_password_screen.dart:187", "Login noun deprecated"],
        ["8", "Change 'Organization Owner' → 'Workspace Owner'", "role_selection:73, teacher_registration:228", "Workspace is canonical term"],
        ["9", "Change 'Create Your Workspace' title → 'Create your account'", "owner_register_screen.dart:172", "Canonical registration verb"],
        ["10", "Change 'Create Workspace' button → 'Create account'", "owner_register_screen.dart:277", "Canonical registration verb"],
        ["11", "Change 'Set up your organization in minutes' → 'Set up your workspace in minutes'", "owner_register_screen.dart:183", "Workspace canonical"],
        ["12", "Change 'Parent Portal' screen title → 'Parent sign-in'", "parent_login_screen.dart:148", "Portal is jargon"],
        ["13", "Change 'Link Your Child' title → 'Link your child'", "parent_link_screen.dart:190", "Sentence case for titles"],
        ["14", "Replace GestureDetector+Text 'Sign in' link in owner_register with KlasivoButton(variant: tertiary)", "owner_register_screen.dart:328-337", "Fix tap target + Semantics"],
        ["15", "Add Tooltip: 'Back' to all 10 AppBar back IconButtons in auth screens", "10 auth screens", "iOS long-press label, TalkBack announcement"],
        ["16", "Add Tooltip: 'Show password' / 'Hide password' to all 8 visibility IconButtons", "8 auth screens", "Accessibility"],
        ["17", "Remove visualDensity: VisualDensity.compact from _ThemeSegmentedControl", "settings_screen.dart:555", "Touch target ≥48dp"],
        ["18", "Change people_outline_rounded → people_outline in bottom nav", "teacher_shell.dart:39, owner_shell.dart", "Icon style consistency"],
        ["19", "Add SizedBox(height: MediaQuery.padding.bottom + 24) at end of Settings screen", "settings_screen.dart:244", "Logout button not cut off on gesture-nav devices"],
        ["20", "Remove dead isDark parameter from _buildV*Flags methods", "feature_flags_screen.dart:95, 170, 205, 240, 281", "Code cleanup"],
      ],
      [4, 50, 30, 16]
    ),

    h2("12.2  Phase 2 — Medium improvements (<2 hours each, ship this week)"),

    p("15 medium improvements. Estimated total: 20 hours (3 days)."),

    dataTable(
      ["#", "Task", "Files", "Impact"],
      [
        ["1", "Wire router to real screens (replace 4 placeholder widgets, route through TeacherShell/OwnerShell)", "lib/app/router.dart:242-631", "P0 — Settings/FeatureFlags/Dashboard/Inbox become user-visible"],
        ["2", "Wire themeModeProvider into main.dart (replace hardcoded ThemeMode.system)", "lib/main.dart:413, lib/core/config/theme_provider.dart", "P0 — theme preference honored at runtime"],
        ["3", "Add MediaQuery.viewInsets.bottom to all 10 auth form screens", "10 auth screens", "P0 — keyboard no longer obscures primary button"],
        ["4", "Fix parent_link OTP Row overflow (LayoutBuilder + dispose FocusNodes)", "parent_link_screen.dart:215-246", "P0 — no more RenderFlex overflow on small screens"],
        ["5", "Fix _FeatureFlagTile Row overflow (move Switch inside Expanded)", "feature_flags_screen.dart:379-452", "P0 — no more 1.9px/7px/56px overflow"],
        ["6", "Rewrite splash_screen typography (use AppTypography tokens, fix Colors.white70 contrast)", "splash_screen.dart:121-137", "P1 — type scale consistency + WCAG AA pass"],
        ["7", "Rewrite change_password_screen using KlasivoButton + KlasivoTextField", "change_password_screen.dart (full rewrite)", "P1 — design system compliance"],
        ["8", "Create KlasivoBrandHeader widget + replace 12 ad-hoc header patterns", "NEW: lib/widgets/klasivo_brand_header.dart + 12 auth screens", "P1 — branding consistency"],
        ["9", "Create KlasivoAuthScaffold wrapper + apply to 12 auth screens", "NEW: lib/widgets/klasivo_auth_scaffold.dart + 12 auth screens", "P1 — maxWidth cap, consistent padding, keyboard handling"],
        ["10", "Replace 84 Colors.grey[300-500] with AppColors tokens", "28 files", "P0 accessibility — WCAG AA contrast pass"],
        ["11", "Fix sub-48dp touch targets in gradebook, exam_list, question_builder", "4 files", "P0 accessibility — WCAG 2.5.5 pass"],
        ["12", "Add Tooltip to ~60 IconButtons missing them", "~40 files", "P1 accessibility"],
        ["13", "Add Semantics(button: true, label: ...) to auth-flow tappable widgets", "12 auth screens", "P1 accessibility — screen reader support"],
        ["14", "Migrate inline Calendar and Academic Years empty states to KlasivoEmptyState", "calendar_screen.dart:188-197, academic_year_list_screen.dart:39-69", "P1 — design system compliance + contrast fix"],
        ["15", "Generate adaptive launcher icons (after fixing foreground PNG)", "pubspec.yaml + android/app/src/main/res/mipmap-anydpi-v26/", "P0 — adaptive icons render on Android 8+"],
      ],
      [4, 50, 30, 16]
    ),

    h2("12.3  Phase 3 — Architectural refactors (ship next sprint)"),

    p("7 refactors that unlock future polish. Estimated total: 5 days."),

    dataTable(
      ["#", "Task", "Impact"],
      [
        ["1", "Delete dead duplicate code: lib/features/auth/presentation/, lib/features/exams/presentation/, lib/features/students/presentation/, lib/features/classes/presentation/ (~2,000 lines)", "Eliminate maintenance hazard, prevent drift bugs"],
        ["2", "Delete dead widget libraries: lib/shared/widgets/ (11 files), lib/core/design_system/components/ (11 files), lib/core/design_system/tokens/ (duplicate)", "Eliminate confusion about which widget to use"],
        ["3", "Consolidate to single EmptyState widget (delete 3 of 4 competing definitions)", "Single API, future illustration/Lottie support"],
        ["4", "Extract KlasivoBottomNav widget, deduplicate TeacherShell/OwnerShell", "Single shell config, easier to maintain"],
        ["5", "Replace 337 hardcoded fontSize with AppTypography tokens (batch by file)", "Type scale compliance, accessibility"],
        ["6", "Refactor 58 unexpanded Row patterns to use Expanded/Flexible", "Responsive at 2x font scale, no overflow"],
        ["7", "Migrate native splash to flutter_native_splash with brand-color background + centered logo", "No distortion on different aspect ratios"],
      ],
      [4, 60, 36]
    ),

    h2("12.4  Phase 4 — Localization & deeper accessibility (ship before international launch)"),

    p("5 tasks. Estimated total: 8 days."),

    dataTable(
      ["#", "Task", "Impact"],
      [
        ["1", "Move all auth strings to app_en.arb (32 strings) + translate to fr/tr/ar", "Localization readiness"],
        ["2", "Move all bottom-nav labels to .arb files (5 strings × 4 languages)", "Localization readiness"],
        ["3", "Move Feature Flags labels and descriptions to .arb (31 strings)", "Localization readiness"],
        ["4", "Audit all 143 TextField calls for labelText/hintText; add Semantics where missing", "Screen reader form-field support"],
        ["5", "Write widget tests at 1.5x and 2x text scale; remove the stopgap clamp once tests pass", "Verified accessibility at large font scales"],
      ],
      [4, 70, 26]
    ),

    h2("12.5  Recommended execution order"),

    p("Execute Phase 1 (quick wins) immediately — same day. Then execute Phase 2 in the order listed (router wiring and theme provider first, since they unlock visibility for the rest). Phase 3 can run in parallel with Phase 2 (different files, no conflicts). Phase 4 should be scheduled for a dedicated localization/accessibility sprint after the visible polish work ships."),

    p("After Phase 2 ships, run a follow-up audit to verify that the 16 P0 issues are resolved and that no new issues were introduced. Use the same evidence-first methodology: take screenshots on iPhone SE (320×640), Pixel 5 (393×851), iPad mini (768×1024), and at 1.5x and 2x system font scale."),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 13 — Exact Code Changes
// ─────────────────────────────────────────────────────────────────────
function buildCodeChanges() {
  return [
    h1("13.  Exact Code Changes"),

    p("This section ships ready-to-apply code patches for the highest-impact fixes. Each patch is self-contained and can be applied independently. Patches are numbered to match the implementation plan phases."),

    h2("13.1  Patch — Wire router to real screens"),

    p([plain("File: "), code("lib/app/router.dart"), plain(" (lines 242-631).")]),

    p("Replace the no-op ShellRoute builder and 4 placeholder routes with role-based shell routing to real screens."),

    codeBlock(`// lib/app/router.dart — REPLACE lines 242-631

// 1. Add imports at top of file:
import 'package:klasivo/features/shell/teacher_shell.dart';
import 'package:klasivo/features/shell/owner_shell.dart';
import 'package:klasivo/features/shell/student_shell.dart';
import 'package:klasivo/features/shell/parent_shell.dart';
import 'package:klasivo/features/dashboard/teacher_dashboard.dart';
import 'package:klasivo/features/dashboard/owner_dashboard.dart';
import 'package:klasivo/features/dashboard/student_dashboard.dart';
import 'package:klasivo/features/notifications/pages/notification_center_screen.dart';
import 'package:klasivo/features/settings/pages/settings_screen.dart';
import 'package:klasivo/features/settings/pages/feature_flags_screen.dart';

// 2. Replace the ShellRoute block:
ShellRoute(
  builder: (context, state, child) {
    // Route through role-based shell
    final userRole = ref.read(userRoleProvider);
    switch (userRole) {
      case 'owner':
      case 'admin':
        return OwnerShell(child: child);
      case 'teacher':
        return TeacherShell(child: child);
      case 'student':
        return StudentShell(child: child);
      case 'parent':
        return ParentShell(child: child);
      default:
        return TeacherShell(child: child);  // safe default
    }
  },
  routes: [
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final userRole = ref.read(userRoleProvider);
        switch (userRole) {
          case 'owner':
          case 'admin':
            return const OwnerDashboard();
          case 'student':
            return const StudentDashboard();
          case 'parent':
            return const ParentDashboard();
          default:
            return const TeacherDashboard();
        }
      },
    ),
    GoRoute(
      path: '/academic',
      builder: (c, s) => const AcademicScreen(),  // TODO: implement AcademicScreen
    ),
    GoRoute(
      path: '/people',
      builder: (c, s) => const PeopleHubScreen(),
    ),
    GoRoute(
      path: '/inbox',
      builder: (c, s) => const NotificationCenterScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (c, s) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/settings/feature-flags',
      builder: (c, s) => const FeatureFlagsScreen(),
    ),
  ],
)`),

    h2("13.2  Patch — Fix parent_link OTP Row overflow"),

    p([plain("File: "), code("lib/features/parent/pages/parent_link_screen.dart"), plain(" (lines 25-50, 215-246).")]),

    p("Replace the fixed-width 8 × SizedBox(width: 38) Row with a LayoutBuilder that computes box width from available width. Dispose FocusNodes properly."),

    codeBlock(`// lib/features/parent/pages/parent_link_screen.dart

class _ParentLinkScreenState extends State<ParentLinkScreen> {
  final List<TextEditingController> _controllers =
      List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(8, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ... existing fields ...

  Widget _buildOtpRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 8 boxes + 7 gaps. Gap = 8dp. Reserve total gap = 56dp.
        const gapCount = 7;
        const gapWidth = 8.0;
        final totalGap = gapCount * gapWidth;
        final availableWidth = constraints.maxWidth - totalGap;
        // Cap box width at 48dp (max), floor at 32dp (min).
        final boxWidth = (availableWidth / 8).clamp(32.0, 48.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(8, (i) {
            return SizedBox(
              width: boxWidth,
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: AppTypography.titleLarge,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (value.length == 1 && i < 7) {
                    _focusNodes[i + 1].requestFocus();
                  }
                  if (value.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                  setState(() {});  // refresh _isCodeComplete
                },
              ),
            );
          }),
        );
      },
    );
  }
}`),

    h2("13.3  Patch — Fix _FeatureFlagTile Row overflow"),

    p([plain("File: "), code("lib/features/settings/pages/feature_flags_screen.dart"), plain(" (lines 343-474).")]),

    p("Already detailed in Section 7.2.4 — move Switch inside Expanded(Column), restructure title row. See the full code block in Section 7.2.4."),

    h2("13.4  Patch — Extract KlasivoBottomNav widget"),

    p([plain("File: "), code("lib/widgets/klasivo_bottom_nav.dart"), plain(" (NEW).")]),

    p("Already detailed in Section 8.4 — see the full code block. Once created, TeacherShell and OwnerShell become thin wrappers:"),

    codeBlock(`// lib/features/shell/teacher_shell.dart (REWRITTEN — 50 lines, was 145)
class TeacherShell extends ConsumerWidget {
  const TeacherShell({super.key, required this.child});
  final Widget child;

  static const _destinations = [
    KlasivoNavDestination(
      label: 'Dashboard',  // TODO: localize
      unselectedIcon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    KlasivoNavDestination(
      label: 'Academic',
      unselectedIcon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
    ),
    KlasivoNavDestination(
      label: 'People',
      unselectedIcon: Icons.people_outline,  // ✅ fixed suffix
      selectedIcon: Icons.people_rounded,
      showBadge: true,  // inbox badge
    ),
    KlasivoNavDestination(
      label: 'Inbox',
      unselectedIcon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox_rounded,
      showBadge: true,
    ),
    KlasivoNavDestination(
      label: 'Settings',
      unselectedIcon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = _destinations.indexWhere((d) =>
        location.startsWith(_routeForIndex(_destinations.indexOf(d))));
    final unreadCount = ref.watch(unreadNotificationsProvider).maybeWhen(
          data: (n) => n,
          orElse: () => 0,
        );

    return Scaffold(
      body: child,
      bottomNavigationBar: KlasivoBottomNav(
        currentIndex: index.clamp(0, _destinations.length - 1),
        onDestinationSelected: (i) => context.go(_routeForIndex(i)),
        destinations: _destinations,
        unreadBadgeCount: unreadCount,
      ),
    );
  }

  String _routeForIndex(int i) {
    switch (i) {
      case 0: return '/dashboard';
      case 1: return '/academic';
      case 2: return '/people';
      case 3: return '/inbox';
      case 4: return '/settings';
      default: return '/dashboard';
    }
  }
}`),

    h2("13.5  Patch — KlasivoBrandHeader widget"),

    p([plain("File: "), code("lib/widgets/klasivo_brand_header.dart"), plain(" (NEW).")]),

    p("Already detailed in Section 3.8 — see the full code block. Once created, replace all 12 ad-hoc header patterns. Example call site:"),

    codeBlock(`// lib/features/auth/pages/teacher_login_screen.dart (was no header)
// ADD at the top of the form Column:
const KlasivoBrandHeader(
  icon: Icons.school_outlined,
  size: KlasivoBrandHeaderSize.md,
),
const SizedBox(height: KlasivoSpacing.xxl),

// lib/features/auth/pages/splash_screen.dart (was 120×120 hardcoded Image.asset)
KlasivoBrandHeader(
  size: KlasivoBrandHeaderSize.xl,  // 144dp container, 72dp logo
  // icon: null → uses Image.asset('assets/icon/app_icon_foreground.png')
),
const SizedBox(height: KlasivoSpacing.xxl),`),

    h2("13.6  Patch — KlasivoAuthScaffold wrapper"),

    p([plain("File: "), code("lib/widgets/klasivo_auth_scaffold.dart"), plain(" (NEW).")]),

    p("Already detailed in Section 3.2.1 — see the full code block. Once created, refactor each auth screen to wrap its body in KlasivoAuthScaffold. Example call site:"),

    codeBlock(`// lib/features/auth/pages/teacher_login_screen.dart (REWRITTEN body)
@override
Widget build(BuildContext context) {
  return KlasivoAuthScaffold(
    appBarTitle: 'Sign in',  // TODO: localize
    body: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KlasivoBrandHeader(icon: Icons.school_outlined),
          const SizedBox(height: KlasivoSpacing.xxl),
          Text('Welcome back', style: AppTypography.headlineLarge),
          const SizedBox(height: KlasivoSpacing.sm),
          Text('Sign in to your Klasivo account',
              style: AppTypography.bodyMedium),
          const SizedBox(height: KlasivoSpacing.xxxl),
          // ... email field, password field, error banner, Sign In button ...
        ],
      ),
    ),
  );
}`),

    p("This eliminates ~200 lines of repeated Scaffold + AppBar + SafeArea + SingleChildScrollView + padding boilerplate across 12 auth screens."),

    h2("13.7  Patch — Theme provider wiring"),

    p([plain("File: "), code("lib/main.dart"), plain(" (line 413).")]),

    codeBlock(`// lib/main.dart — REPLACE line 413

// BEFORE:
themeMode: ThemeMode.system,

// AFTER:
themeMode: ref.watch(themeModeProvider),`),

    p([plain("Then consolidate the two competing themeModeProvider definitions. Pick "), code("lib/core/config/theme_provider.dart:87"), plain(" (the StateNotifierProvider<ThemeModeNotifier, ThemeMode>) as the canonical one. Update "), code("lib/providers/theme_provider.dart:119"), plain(" to delegate to it:")]),

    codeBlock(`// lib/providers/theme_provider.dart — REPLACE line 119
// BEFORE:
final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(themeProvider);
  switch (mode) {
    case AppThemeMode.light: return ThemeMode.light;
    case AppThemeMode.dark: return ThemeMode.dark;
    case AppThemeMode.system: return ThemeMode.system;
  }
});

// AFTER: delegate to the canonical provider in lib/core/config/theme_provider.dart
export 'package:klasivo/core/config/theme_provider.dart' show themeModeProvider;
// (delete the local definition; callers now import from the canonical location)`),

    h2("13.8  Patch — Splash screen typography fix"),

    p([plain("File: "), code("lib/features/auth/pages/splash_screen.dart"), plain(" (lines 121-137).")]),

    codeBlock(`// lib/features/auth/pages/splash_screen.dart — REPLACE lines 121-137

// BEFORE:
TextStyle(
  fontFamily: KlasivoTypography.fontFamily,
  fontSize: 36,
  fontWeight: FontWeight.w700,
  color: Colors.white,
  letterSpacing: -0.5,
),
// ...
TextStyle(
  fontFamily: KlasivoTypography.fontFamily,
  fontSize: 15,
  color: Colors.white70,
  fontWeight: FontWeight.w400,
),

// AFTER:
AppTypography.displayMedium.copyWith(
  color: Colors.white,
),  // 32pt w700 — in scale
// ...
AppTypography.bodyMedium.copyWith(
  color: Colors.white,  // was Colors.white70 — now passes WCAG AA (7.4:1)
),  // 14pt w400`),

    h2("13.9  Patch — Stopgap font scaling clamp"),

    p([plain("File: "), code("lib/main.dart"), plain(" (in MyApp.build(), after the MaterialApp.router construction).")]),

    p("Already detailed in Section 10.4.1 — see the full code block."),

    h2("13.10  Patch — Delete dead duplicate code"),

    p("Run these commands to delete ~2,000 lines of dead duplicate code:"),

    codeBlock(`# From project root:
rm -rf lib/features/auth/presentation/
rm -rf lib/features/exams/presentation/
rm -rf lib/features/students/presentation/
rm -rf lib/features/classes/presentation/
rm -rf lib/shared/widgets/
rm -rf lib/core/design_system/components/
rm lib/app/app.dart
rm klasivo_icon.png

# After deletion, run flutter analyze to verify no broken imports:
flutter analyze`),

    p("If flutter analyze reports any remaining imports of the deleted files, update those imports to point to the canonical locations (lib/features/*/pages/ and lib/widgets/klasivo_*.dart)."),

    h2("13.11  Patch — Add Tooltip to all auth IconButtons"),

    p([plain("Apply this pattern to all 10 AppBar back buttons and all 8 password visibility toggles in auth screens:")]),

    codeBlock(`// AppBar back button (×10 screens) — REPLACE
IconButton(
  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
  tooltip: 'Back',  // ← ADD THIS
  onPressed: () => context.pop(),
),

// Password visibility toggle (×8 screens) — REPLACE
IconButton(
  icon: Icon(
    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
    size: 20,
  ),
  tooltip: _obscurePassword ? 'Show password' : 'Hide password',  // ← ADD THIS
  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
)`),

    h2("13.12  Patch — Generate adaptive launcher icons"),

    p("Step 1: Create a new transparent 1024×1024 PNG containing only the Klasivo logo mark at ~66% canvas size, centered. Save as assets/icon/app_icon_foreground.png (replacing the byte-identical duplicate)."),

    p("Step 2: Update pubspec.yaml:"),
    codeBlock(`# pubspec.yaml — REPLACE lines 127-133
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#3B5BDB"   # ✅ AppColors.primary (was #1A3A8A)
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  remove_alpha_ios: true`),

    p("Step 3: Run generator:"),
    codeBlock(`dart run flutter_launcher_icons:main`),

    p("Step 4: Verify android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml was created and references the new adaptive icon background + foreground."),

    h2("13.13  Patch — Migrate native splash to flutter_native_splash"),

    p("Step 1: Add to pubspec.yaml dev_dependencies:"),
    codeBlock(`# pubspec.yaml dev_dependencies:
flutter_native_splash: ^2.4.0`),

    p("Step 2: Create flutter_native_splash.yaml at project root:"),
    codeBlock(`# flutter_native_splash.yaml
flutter_native_splash:
  color: "#0F172A"          # AppColors.darkBackground
  image: assets/icon/app_icon_foreground.png
  android_12:
    image: assets/icon/app_icon_foreground.png
    color: "#0F172A"
    icon_background_color: "#3B5BDB"`),

    p("Step 3: Generate:"),
    codeBlock(`dart run flutter_native_splash:create`),

    p("Step 4: Verify the new launch_background.xml uses a centered logo on a brand-color background, not a stretched full-bleed PNG."),

    h2("13.14  Patch — Add RobotoMono font (or remove monospace token)"),

    p("Option A (recommended): add RobotoMono to pubspec.yaml fonts section:"),
    codeBlock(`# pubspec.yaml flutter.fonts: section — ADD
- family: RobotoMono
  fonts:
    - asset: assets/fonts/RobotoMono-Regular.ttf
    - asset: assets/fonts/RobotoMono-Bold.ttf
      weight: 700`),

    p("Option B: remove the monospace token from lib/core/tokens/app_typography.dart:151 if no consumer exists."),

    p([bold("Recommendation:"), plain(" Option A. Even if no widget currently uses the monospace token, future code-display UIs (Feature Flag detail sheet, audit log viewer, etc.) will need it. Adding the font now costs ~2MB of APK size but saves a future debugging session when monospace text silently falls back to system font.")]),

    h2("13.15  Patch — Consolidate EmptyState widgets"),

    p("Step 1: Create lib/widgets/klasivo_empty_state.dart using the consolidated widget code in Section 9.4."),

    p("Step 2: Delete the 3 competing widgets:"),
    codeBlock(`rm lib/shared/widgets/k_empty_state.dart  # (already deleted in 13.10)
rm lib/core/design_system/components/k_empty_state.dart  # (already deleted in 13.10)
# Update lib/widgets/common_widgets.dart:10 to delegate to new KlasivoEmptyState
# Update lib/widgets/klasivo_components.dart:534 to delegate to new KlasivoEmptyState`),

    p("Step 3: Migrate the 2 inline empty states in calendar_screen.dart:188-197 and academic_year_list_screen.dart:39-69 to use the new KlasivoEmptyState widget."),

    p("Step 4: Add CTAs to the 4 empty states that lack them (Inbox, Chat, Attendance, Groups). Example for Groups:"),
    codeBlock(`// lib/features/groups/pages/group_list_screen.dart:25-31
// BEFORE:
const KlasivoEmptyState(
  icon: Icons.group_work_outlined,
  title: 'No Groups Yet',
  subtitle: 'Create groups within this class',
),

// AFTER:
KlasivoEmptyState(
  variant: KlasivoEmptyStateVariant.noData,
  icon: Icons.group_work_outlined,
  title: 'No groups yet',
  subtitle: 'Create study groups, project teams, or skill-based clusters within this class.',
  actionLabel: 'Create Group',
  onAction: () => context.go('/teacher/classes/\$classId/groups/create'),
),`),

    new Paragraph({ children: [new TextRun({ text: " " })] }),
  ];
}

module.exports = { buildDesignSystemAudit, buildImplementationPlan, buildCodeChanges };
