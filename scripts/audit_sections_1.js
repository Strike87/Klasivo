/**
 * Klasivo UX Audit — Section content builders.
 * Each function returns an array of paragraphs/tables for one body section.
 */

const U = require("./generate_ux_audit.js");
const {
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer,
  Paragraph, TextRun, PageBreak, AlignmentType, P, FONT, FONT_MONO,
} = U;

// ─────────────────────────────────────────────────────────────────────
// SECTION 1 — Executive Summary
// ─────────────────────────────────────────────────────────────────────
function buildExecutiveSummary() {
  return [
    h1("1.  Executive Summary"),

    p("This audit evaluates the Klasivo mobile application (Flutter v2.0.0+7) against production-readiness criteria across nine dimensions: authentication screens, branding, terminology consistency, responsive design, settings & feature flags UX, bottom navigation, empty states, accessibility, and design-system hygiene. The audit covered 47 active screens and 12 authentication flows, totaling approximately 8,400 lines of UI-layer code under lib/features/ and lib/widgets/."),

    p([
      plain("Klasivo ships with a well-structured token system ("),
      code("lib/core/tokens/"),
      plain(" — colors, spacing, radius, typography, elevation, animation) and a passable component library ("),
      code("lib/widgets/klasivo_*.dart"),
      plain(", 63 import sites). However, the audit found that the design system is "),
      bold("only partially consumed"),
      plain(": hardcoded font sizes (337 occurrences), hardcoded icon sizes (7 distinct values across 12 auth screens), and "),
      bold("three parallel widget libraries"),
      plain(" competing for adoption ("),
      code("lib/widgets/klasivo_*.dart"),
      plain(" [active], "),
      code("lib/shared/widgets/k_*.dart"),
      plain(" [dead], "),
      code("lib/core/design_system/components/k_*.dart"),
      plain(" [dead]). This fragmentation is the single largest source of visual inconsistency in the app."),
    ]),

    p([
      plain("The most severe functional finding is that "),
      bold("the bottom-navigation tabs are wired to inline placeholder widgets"),
      plain(", not the real Dashboard, Academic, Inbox, or Settings screens. The router at "),
      code("lib/app/router.dart:524-631"),
      plain(" returns "),
      code("Scaffold(body: Center(child: Text('Dashboard')))"),
      plain(" for four of five tabs. The real "),
      code("TeacherDashboard"),
      plain(", "),
      code("NotificationCenterScreen"),
      plain(", "),
      code("SettingsScreen"),
      plain(", and "),
      code("FeatureFlagsScreen"),
      plain(" exist but are unreachable. Until this is fixed, the polish work on Settings/FeatureFlags cannot be validated by users."),
    ]),

    p([
      plain("On the auth flow, the audit identified "),
      bold("36 distinct issues"),
      plain(" across 12 screens, ranging from P0 bugs (OTP field overflow on screens <320px wide, missing keyboard inset padding on every form, unreachable owner-flow code branch in "),
      code("TeacherRegistrationScreen"),
      plain(") to P4 terminology drift (\"Create Workspace\" vs \"Create Account\" vs \"Sign up\" for the same registration action; \"workspace\" vs \"organization\" used interchangeably; \"Sign In\" button vs \"Sign in\" link)."),
    ]),

    h2("Headline numbers"),

    dataTable(
      ["Dimension", "Issues found", "Critical (P0)", "Quick wins (<30 min)"],
      [
        ["1. Authentication screens", "36", "5", "11"],
        ["2. App icon & branding", "10", "2", "4"],
        ["3. Auth terminology", "8", "0", "8"],
        ["4. Responsive design", "20", "2", "6"],
        ["5. Settings & Feature Flags", "12", "1", "3"],
        ["6. Bottom navigation", "8", "1 (router wiring)", "2"],
        ["7. Empty states", "13", "0", "5"],
        ["8. Accessibility", "18", "3", "4"],
        ["9. Design system", "14", "2", "5"],
        [{ text: "TOTAL", bold: true }, { text: "139", bold: true }, { text: "16", bold: true, color: P.critical }, { text: "48", bold: true, color: P.low }],
      ],
      [40, 20, 20, 20]
    ),

    spacer(200),

    h2("Top 5 issues to fix first"),

    p([sev("P0"), bold("Router not wired to real screens"), plain(" — "), code("lib/app/router.dart:524-631"), plain(" uses placeholder widgets for /dashboard, /academic, /inbox, /settings. Real screens exist but are unreachable. Fix: replace placeholders with real screen widgets and route through TeacherShell/OwnerShell based on role.")]),

    p([sev("P0"), bold("Theme mode preference is ignored at runtime"), plain(" — "), code("lib/main.dart:413"), plain(" hardcodes "), code("themeMode: ThemeMode.system"), plain(". The user-selectable theme (light/dark/system) is persisted to Hive but never honored. The dead "), code("KlasivoApp"), plain(" at "), code("lib/app/app.dart"), plain(" is the only place that wires "), code("themeModeProvider"), plain(".")]),

    p([sev("P0"), bold("Adaptive launcher icons never generated"), plain(" — pubspec.yaml configures "), code("flutter_launcher_icons"), plain(" with "), code("adaptive_icon_background: \"#1A3A8A\""), plain(" (off-brand navy, should be "), code("#3B5BDB"), plain("). The "), code("mipmap-anydpi-v26/"), plain(" directory does not exist. "), code("app_icon.png"), plain(" and "), code("app_icon_foreground.png"), plain(" are byte-identical duplicates.")]),

    p([sev("P0"), bold("Parent Link OTP Row overflows on small screens"), plain(" — "), code("lib/features/parent/pages/parent_link_screen.dart:215-246"), plain(" uses 8 × "), code("SizedBox(width: 38)"), plain(" in a Row without LayoutBuilder. Total 304px > 272px available on iPhone SE / small Android → RenderFlex overflow.")]),

    p([sev("P0"), bold("Feature Flags tile Row overflows by ~56px"), plain(" — "), code("lib/features/settings/pages/feature_flags_screen.dart:379-452"), plain(" places the Switch outside the Expanded(Column). Combined with the 48px icon container and 12px gap, the Row exceeds available width by ~56px on narrow phones.")]),

    spacer(120),

    p("The remainder of this report is organized as follows. Section 2 lists the critical UX issues that block production readiness. Sections 3-11 walk through each of the nine audit dimensions with concrete file:line evidence, severity ratings, and exact code patches. Section 12 contains the prioritized implementation plan (quick wins, medium improvements, longer-term refactors). Section 13 ships ready-to-apply code changes for the highest-impact fixes."),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 2 — Critical UX Issues (P0)
// ─────────────────────────────────────────────────────────────────────
function buildCriticalIssues() {
  return [
    h1("2.  Critical UX Issues (P0 — Block production release)"),

    p("These sixteen issues must be resolved before the next app store submission. Each is reproducible on a stock Android device or iPhone SE (360×640 dp) without any unusual configuration. Issues are grouped by impact area."),

    h2("2.1  Router wiring — bottom nav tabs show placeholders"),

    p([plain("Location: "), code("lib/app/router.dart:242-246, 524-631"), plain(".")]),

    p("The GoRouter ShellRoute builder returns the child directly, bypassing the TeacherShell/OwnerShell/StudentShell/ParentShell widgets. Four of the five bottom-nav destinations (/dashboard, /academic, /inbox, /settings) are routed to inline _Placeholder widgets that render only Scaffold(body: Center(child: Text('Dashboard'))). The real TeacherDashboard, OwnerDashboard, NotificationCenterScreen, SettingsScreen, and FeatureFlagsScreen exist as completed widgets but are unreachable from any navigation path. This means every Settings/FeatureFlags/Dashboard polish task completed in today's sprint is invisible to the user until the router is rewired."),

    codeBlock(`// lib/app/router.dart — current (lines 242-246)
ShellRoute(
  builder: (context, state, child) {
    // Shell wrapper — will be replaced with OwnerShell/TeacherShell
    return child;
  },
  routes: [
    GoRoute(path: '/dashboard', builder: (c, s) =>
      const Scaffold(body: Center(child: Text('Dashboard')))),  // ❌ placeholder
    // ... 3 more placeholders
  ],
)`),

    p("Fix: route through role-based shell, then to real screens. See Section 13.1 for the patch."),

    h2("2.2  Theme mode preference ignored"),

    p([plain("Location: "), code("lib/main.dart:407-414"), plain(" (active entry), "), code("lib/app/app.dart"), plain(" (dead KlasivoApp).")]),

    p("main.dart's MyApp builds MaterialApp.router with themeMode: ThemeMode.system hardcoded. Two competing themeModeProvider definitions exist (lib/core/config/theme_provider.dart:87 and lib/providers/theme_provider.dart:119) and both are persisted to Hive, but neither is consulted by the active entry point. The Settings screen has UI to switch themes (light/dark/system segmented control at settings_screen.dart:526-560), but tapping it has no effect at runtime."),

    p("Fix: replace hardcoded ThemeMode.system with ref.watch(themeModeProvider). Consolidate the two competing providers into one. Delete the dead KlasivoApp."),

    h2("2.3  Adaptive launcher icons not generated"),

    p([plain("Location: "), code("pubspec.yaml:127-133"), plain(", "), code("android/app/src/main/AndroidManifest.xml:14"), plain(".")]),

    p("pubspec.yaml declares flutter_launcher_icons configuration with adaptive_icon_background: \"#1A3A8A\" (navy, off-brand — should be #3B5BDB to match AppColors.primary). The android/app/src/main/res/mipmap-anydpi-v26/ directory does not exist, so adaptive icons were never generated. On Android 8.0+ (API 26+), the launcher falls back to the legacy PNG ic_launcher.png. Additionally, app_icon.png and app_icon_foreground.png are byte-identical duplicates — the foreground should be a transparent PNG with only the logo mark, not a duplicate of the full icon."),

    p([bold("Fix:"), plain(" (1) Replace assets/icon/app_icon_foreground.png with a transparent-background PNG containing only the Klasivo logo mark at ~66% canvas size, centered. (2) Update adaptive_icon_background to #3B5BDB. (3) Run "), code("dart run flutter_launcher_icons:main"), plain(" to regenerate mipmap-anydpi-v26/.")]),

    h2("2.4  Parent Link OTP Row overflow"),

    p([plain("Location: "), code("lib/features/parent/pages/parent_link_screen.dart:215-246"), plain(".")]),

    p("The 8-character linking code is rendered as 8 SizedBox(width: 38) widgets inside a Row with MainAxisAlignment.spaceBetween. On a 360dp screen with 24dp horizontal padding (KlasivoSpacing.xxl), available width = 312dp. Required width = 8 × 38 = 304dp + 7 inter-box gaps — fits on 360dp but overflows on any narrower screen (iPhone 5 / older Androids at 320dp). The Row also has no LayoutBuilder, so on tablets (≥600dp) the boxes left-align with huge gaps and look broken. Each OTP box also creates a FocusNode inside List.generate that is never disposed — memory leak."),

    codeBlock(`// CURRENT (lib/features/parent/pages/parent_link_screen.dart:215-246)
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: List.generate(8, (i) => SizedBox(
    width: 38,
    child: KeyboardListener(
      focusNode: FocusNode(),  // ❌ LEAKED on every rebuild
      // ...
    ),
  )),
)`),

    p("Fix: wrap in LayoutBuilder, compute box width from available width, dispose FocusNodes properly. See Section 13.2."),

    h2("2.5  Feature Flags tile horizontal overflow (~56px)"),

    p([plain("Location: "), code("lib/features/settings/pages/feature_flags_screen.dart:379-452"), plain(".")]),

    p("The _FeatureFlagTile Row layout is: icon container (48px) + SizedBox(12px gap) + Expanded(Column[text]) + Switch (~36px). The Switch is placed outside the Expanded(Column) as the 4th Row child, so when total content width exceeds available width, Flutter reports a ~56px horizontal overflow (the icon-container intrinsic width when padding was 16 instead of 12 in an earlier revision). Combined with the inner Row at lines 405-433 containing the 'Core' badge Container with vertical:2 padding, the tile also produces a 1.9px / 7px vertical overflow when font metrics differ between titleSmall and labelSmall."),

    p("Fix: move Switch inside Expanded(Column) as a Row(mainAxisAlignment: spaceBetween, children: [text, Switch]) — see Section 13.3."),

    h2("2.6  No keyboard inset padding on any auth form screen"),

    p([plain("Location: all 10 auth form screens under "), code("lib/features/auth/pages/"), plain(" and "), code("lib/features/parent/pages/"), plain(".")]),

    p("Every auth screen uses SingleChildScrollView with padding: EdgeInsets.symmetric(horizontal: KlasivoSpacing.xxl). None include MediaQuery.of(context).viewInsets.bottom in the bottom padding. When the email or password field is focused on a small screen (iPhone SE, 360×640dp), the keyboard (~280dp tall) obscures the primary action button (Sign In, Create Workspace, etc.). The user cannot see whether the button is in a loading state, and on iPhone SE may not be able to tap it at all without first dismissing the keyboard."),

    p("Fix pattern (apply to all 10 form screens):"),
    codeBlock(`SingleChildScrollView(
  padding: EdgeInsets.only(
    left:   KlasivoSpacing.xxl,
    right:  KlasivoSpacing.xxl,
    bottom: MediaQuery.of(context).viewInsets.bottom + KlasivoSpacing.xxl,
  ),
  child: /* ... */,
)`),

    h2("2.7  Splash screen hardcoded TextStyle contradicts type scale"),

    p([plain("Location: "), code("lib/features/auth/pages/splash_screen.dart:121-137"), plain(".")]),

    p("The splash screen is the only auth screen that bypasses AppTypography tokens. It uses TextStyle(fontSize: 36, fontWeight: w700, letterSpacing: -0.5) for the app name and TextStyle(fontSize: 15, color: Colors.white70, fontWeight: w400) for the tagline. fontSize 36 doesn't match displayMedium (32) or displayLarge (40). fontSize 15 is not in the type scale at all (which jumps 14 → 16). Colors.white70 on the indigo #3B5BDB background produces a contrast ratio of ~3.2:1 — fails WCAG AA for 14pt body text."),

    p("Fix: replace with AppTypography.displayMedium.copyWith(color: Colors.white) and AppTypography.bodyMedium.copyWith(color: Colors.white70)."),

    h2("2.8  Dead duplicate code: lib/features/auth/presentation/ (8 files, ~1,921 lines)"),

    p([plain("Location: "), code("lib/features/auth/presentation/"), plain(" (8 files mirroring "), code("lib/features/auth/pages/"), plain(").")]),

    p("A byte-identical (or near-identical) duplicate of the entire auth screens folder exists. Five of eight files differ from the active pages/ copy (splash, welcome, role_selection, teacher_registration, owner_register, teacher_login); three are byte-identical (forgot_password, student_login, plus the barrel). The presentation/ directory is not imported anywhere — confirmed via grep. It has already caused confusion during this audit (the wrong splash_screen.dart was initially read, returning a different logo treatment). This dead code will cause drift bugs whenever someone edits the wrong file."),

    p([bold("Fix:"), plain(" delete "), code("lib/features/auth/presentation/"), plain(" entirely. Same deletion applies to "), code("lib/features/exams/presentation/"), plain(", "), code("lib/features/students/presentation/"), plain(", "), code("lib/features/classes/presentation/"), plain(" — all byte-identical to their "), code("pages/"), plain(" counterparts.")]),

    h2("2.9  Dead design system: 22 unused widget files"),

    p([plain("Location: "), code("lib/core/design_system/components/"), plain(" (11 files), "), code("lib/shared/widgets/"), plain(" (11 files).")]),

    p("Three parallel widget libraries exist, all defining the same component classes (KButton/KlasivoButton, KCard/KlasivoCard, KTextField/KlasivoTextField, etc.) with mutually incompatible APIs. Only lib/widgets/klasivo_*.dart (63 import sites) is active. lib/core/design_system/components/ has its barrel exports commented out (design_system.dart:10-12). lib/shared/widgets/ is imported by zero files. Combined: 22 dead widget files totaling ~3,800 lines that will confuse new contributors."),

    p("Fix: delete lib/shared/widgets/ and lib/core/design_system/components/. If the design-system K* API is preferred long-term, plan a migration of the 63 KlasivoButton import sites first."),

    h2("2.10  Three competing empty-state widgets"),

    p([plain("Location: "), code("lib/widgets/klasivo_components.dart:534"), plain(" (KlasivoEmptyState), "), code("lib/shared/widgets/k_empty_state.dart:23"), plain(" (KEmptyState, 10 variants), "), code("lib/core/design_system/components/k_empty_state.dart:46"), plain(" (KEmptyState, 4 variants, same class name as #2 → import collision), "), code("lib/widgets/common_widgets.dart:10"), plain(" (EmptyState wrapper).")]),

    p("Four widgets all render Icon-in-circle + Title + Subtitle + optional ElevatedButton. None support Lottie/SVG illustrations. Two of the four have the same class name KEmptyState with different variant enums. Calendar and Academic Years screens bypass all four widgets and use inline Center(Text) with raw Colors.grey[300] / Colors.grey — failing WCAG AA contrast."),

    p("Fix: consolidate to one canonical EmptyState widget (recommend the variant-rich KEmptyState API). Migrate inline empties in calendar_screen.dart:188-197 and academic_year_list_screen.dart:39-69."),

    h2("2.11  Accessibility: zero Semantics in feature screens"),

    p("A grep across lib/features/ returns only 4 Semantics( occurrences — all inside widget-library files, not feature screens. None of the following have semantic labels: AppBar back buttons (10 screens), password visibility toggles (8 screens), error message containers (8 screens), _ToggleOption owner/teacher selector, _RoleCard role selector, OTP code fields, illustration icons, custom list-item widgets (_NotificationCard, _ExamTile, _ConversationTile, _AnnouncementCard). Screen-reader users get an incoherent experience."),

    p("Fix: add Semantics(button: true, label: ...) to all tappable non-button widgets; add Tooltip to all IconButtons; pass semanticLabel to KlasivoCard from all call sites."),

    h2("2.12  Accessibility: sub-48dp touch targets"),

    p([plain("Three confirmed sub-48dp touch targets:"), plain(" (1) "), code("lib/features/gradebook/pages/gradebook_screen.dart:462-465, 476-479"), plain(" use "), code("constraints: BoxConstraints(minWidth: 36, minHeight: 36)"), plain(" on IconButtons. (2) "), code("lib/features/exams/pages/exam_list_screen.dart:293-294"), plain(" and "), code("lib/features/exams/pages/question_builder_screen.dart:340, 347"), plain(" use "), code("constraints: const BoxConstraints()"), plain(" which removes the default 48dp minimum entirely, reducing touch area to ~20×20 (the icon size).")]),

    p("Fix: remove custom constraints, or set BoxConstraints(minWidth: 48, minHeight: 48)."),

    h2("2.13  Accessibility: 84 Colors.grey[300-500] usages fail WCAG AA"),

    p("A grep for Colors.grey[300]/[400]/[500] returns 84 occurrences across 28 files, all in empty/error states and analytics dashboards. These map to #E0E0E0 / #BDBDBD / #9E9E9E — contrast ratios of 1.4:1 / 1.9:1 / 2.9:1 on white. All fail WCAG AA (requires 4.5:1 for normal text). Concentrated in academic_year_list_screen.dart, exam_instances_screen.dart, calendar_screen.dart, exam_integrity_dashboard.dart, teacher_analytics_dashboard.dart (24 grey usages alone)."),

    p("Fix: replace with AppColors.textSecondary (light: #495057 / dark: #CBD5E1) or AppColors.textTertiary — both are theme-aware and pass AA."),

    h2("2.14  Accessibility: no font scaling clamp"),

    p("Zero occurrences of MediaQuery.textScaler, textScaleFactor, or maxFontSize across the entire lib/ directory. The app does not clamp font scaling. At 1.5x or 2x system font scale (common for users over 50), the 58 unexpanded Row(Icon + Text) patterns identified in Section 10 will overflow horizontally. No widget tests for large font scales exist."),

    p("Fix: either (a) clamp textScaler in MaterialApp.builder to max 1.3x, or (b) audit and fix all 58 unexpanded Row patterns so they scale gracefully. Option (b) is the correct long-term fix; option (a) is a stopgap."),

    h2("2.15  Native splash is a stretched full-bleed PNG"),

    p([plain("Location: "), code("android/app/src/main/res/drawable/launch_background.xml"), plain(", "), code("android/app/src/main/res/drawable-*/launch_image.png"), plain(" (6 density buckets).")]),

    p("The native Android launch screen uses a layer-list with a single bitmap android:gravity=fill_horizontal|fill_vertical — a full-bleed stretched PNG. The image is scaled to fill the entire screen, which distorts on devices with different aspect ratios. No colors.xml exists, no centered logo, no brand background color. The in-app Flutter splash (lib/features/auth/pages/splash_screen.dart) renders correctly with a centered 120×120 logo, but there's a visible jump/crop between native and Flutter splash."),

    p([bold("Fix:"), plain(" migrate to "), code("flutter_native_splash"), plain(" with a brand-color background (#0F172A or #3B5BDB) and a centered 288×288 logo image. Generate density-correct drawables via "), code("dart run flutter_native_splash:create"), plain(".")]),

    h2("2.16  AppTypography.monospace references undeclared RobotoMono font"),

    p([plain("Location: "), code("lib/core/tokens/app_typography.dart:151"), plain(".")]),

    p("The monospace token references 'RobotoMono' but RobotoMono is not declared in the pubspec.yaml fonts section. This causes a silent fallback to the system default monospace font on all platforms, which breaks code-block alignment in any UI that uses the monospace token. Currently no widget uses the monospace token (the audit found no active consumers), but any future code-display UI will inherit this bug."),

    p([bold("Fix:"), plain(" either (a) add RobotoMono to pubspec.yaml fonts: section, or (b) remove the monospace token if no consumer exists. Option (a) is safer.")]),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

module.exports = { buildExecutiveSummary, buildCriticalIssues };
