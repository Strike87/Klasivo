/**
 * Klasivo UX Audit — Section content builders (Part 4).
 * Sections 7-11: settings/feature-flags, bottom nav, empty states, accessibility, design system.
 */

const U = require("./generate_ux_audit.js");
const {
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer,
  Paragraph, TextRun, PageBreak, AlignmentType, P, FONT, FONT_MONO,
} = U;

// ─────────────────────────────────────────────────────────────────────
// SECTION 7 — Settings & Feature Flags UX
// ─────────────────────────────────────────────────────────────────────
function buildSettingsFeatureFlagsAudit() {
  return [
    h1("7.  Settings & Feature Flags UX Audit"),

    callout("CRITICAL", "Settings and Feature Flags screens are NOT routed. lib/app/router.dart:524-631 uses inline placeholder widgets for /settings. Until the router is rewired (Section 2.1), none of the polish work below is user-visible.", P.critical),

    h2("7.1  Settings screen"),

    p([plain("Location: "), code("lib/features/settings/pages/settings_screen.dart"), plain(" (964 lines). Structure: Scaffold(appBar: AppBar(title: Text('Settings')), body: SingleChildScrollView(child: Column(...)))")]),

    h3("7.1.1  Card layout & grouping"),

    p("Settings are grouped into 5 sections plus a full-width Logout button at the bottom:"),
    bullet("Profile card (always shown) — KlasivoCard with margin and padding both = KlasivoSpacing.lg (16)"),
    bullet("Organization section — gated via KlasivoRoleGate for owner/admin only"),
    bullet("Account section — change password, link devices"),
    bullet("Preferences section — theme toggle (segmented control), language"),
    bullet("Support section — help, about, contact"),
    bullet("Logout button — full-width, danger variant"),

    p("Section cards use horizontal margin = KlasivoSpacing.lg (16) and padding: EdgeInsets.zero. Cards host a Column of _SettingsTile widgets separated by Divider(height: 1, indent: 56)."),

    h3("7.1.2  Toggle/switch widgets"),

    p("Main list uses a custom _SettingsTile (StatelessWidget) wrapping a ListTile with leading icon container, title, subtitle, and trailing chevron_right_rounded icon. NOT a SwitchListTile. The theme toggle uses _ThemeToggleTile with a ListTile whose trailing is a _ThemeSegmentedControl (SegmentedButton<AppThemeMode> with visualDensity: VisualDensity.compact)."),

    p([plain("Notification settings are inside a modal (_showNotificationSettings, lines 296-326) using raw SwitchListTile (4 of them). They use "), code("value: true, onChanged: (v) {}"), plain(" — hardcoded stubs with no provider wiring. This is incomplete code shipped as if functional.")]),

    h3("7.1.3  Text overflow risk"),

    p("Profile card Row (line 49-102) — user name/email column is wrapped in Expanded — safe. Theme toggle tile trailing _ThemeSegmentedControl is a 3-segment SegmentedButton placed as ListTile.trailing (line 473). On narrow phones, the segmented control (~90px) + the title/subtitle text + leading icon container may compete for width. ListTile does manage this, but the segmented control has no Flexible/Expanded and could push the title to ellipsize aggressively. Low-to-medium risk."),

    h3("7.1.4  Section spacing inconsistency"),

    dataTable(
      ["Location", "Spacing", "Token"],
      [
        ["After Organization card (line 153)", "16", "KlasivoSpacing.lg"],
        ["After Account card (line 183)", "16", "KlasivoSpacing.lg"],
        ["After Preferences card (line 204)", "16", "KlasivoSpacing.lg"],
        ["After Support card (line 231)", "24", "KlasivoSpacing.xxl"],
        ["After Logout button (line 244)", "32", "KlasivoSpacing.xxxl"],
        [{ text: "RECOMMENDED: all section gaps", bold: true, color: P.accent }, { text: "16", bold: true, color: P.accent }, { text: "KlasivoSpacing.lg", bold: true, color: P.accent, mono: true }],
      ],
      [50, 20, 30]
    ),

    p([plain("Additionally, the final "), code("SizedBox(height: KlasivoSpacing.xxxl)"), plain(" (32) at line 244 is not a true SafeArea bottom inset. On devices with gesture navigation or home indicator, the logout button may be cut off. Replace with:")]),

    codeBlock(`// lib/features/settings/pages/settings_screen.dart:244
// BEFORE:
SizedBox(height: KlasivoSpacing.xxxl),

// AFTER:
SizedBox(height: MediaQuery.of(context).padding.bottom + KlasivoSpacing.xxl),`),

    h3("7.1.5  Touch target — _ThemeSegmentedControl uses compact density"),

    p([plain("Location: "), code("settings_screen.dart:555"), plain(".")]),

    p([plain("The _ThemeSegmentedControl uses "), code("visualDensity: VisualDensity.compact"), plain(" which reduces each segment's touch target below 48dp. WCAG 2.5.5 requires 44dp minimum; Material 3 recommends 48dp. The compact density saves ~8dp per segment but makes the toggle harder to tap for users with motor impairments.")]),

    p([bold("Fix:"), plain(" remove "), code("visualDensity: VisualDensity.compact"), plain(" from the SegmentedButton, or accept the larger touch target.")]),

    h3("7.1.6  Two _SectionHeader classes with the same name"),

    p([plain("settings_screen.dart:386-406 defines a file-private "), code("_SectionHeader"), plain(" class taking only "), code("title"), plain(". feature_flags_screen.dart:319-339 defines a DIFFERENT "), code("_SectionHeader"), plain(" class taking "), code("title + subtitle"), plain(". Same name, different API — relies on the file-private _ prefix to disambiguate. This is a maintenance smell.")]),

    p([bold("Fix:"), plain(" extract a single canonical "), code("KlasivoSectionHeader"), plain(" widget to "), code("lib/widgets/klasivo_components.dart"), plain(" with optional subtitle parameter.")]),

    h2("7.2  Feature Flags screen"),

    p([plain("Location: "), code("lib/features/settings/pages/feature_flags_screen.dart"), plain(" (706 lines). Structure: Scaffold(appBar: AppBar(title: Text('Feature Flags')), body: RefreshIndicator(child: ListView(...)))")]),

    h3("7.2.1  How flags are listed"),

    p("A single ListView (line 34) with padding: EdgeInsets.all(KlasivoSpacing.lg) (16). Children are built by 5 helper methods that return List<Widget> spread into the ListView:"),
    bullet("_buildV16Flags (line 95-168): 10 flags, all isCore: true"),
    bullet("_buildV17Flags (line 170-203): 5 flags"),
    bullet("_buildV18Flags (line 205-238): 5 flags"),
    bullet("_buildV19Flags (line 240-279): 6 flags — this is the v1.9 'ERP' section the user mentioned"),
    bullet("_buildV20Flags (line 281-314): 5 flags"),

    p("Between sections: SizedBox(height: KlasivoSpacing.xxl) (24) at lines 63, 68, 73, 78. Final SizedBox(height: KlasivoSpacing.hero) (48) at line 88."),

    h3("7.2.2  Card content per flag — _FeatureFlagTile (lines 343-474)"),

    p("Structure: Padding(bottom: 8) → Material → InkWell → Container(padding: 16, border) → Row (line 379) containing:"),
    bullet("Icon container (lines 382-397): padding: EdgeInsets.all(KlasivoSpacing.md=12), child Icon(size: KlasivoSpacing.iconSizeLg=24). Total icon-box width = 48px."),
    bullet("SizedBox(width: KlasivoSpacing.md=12) gap (line 398)"),
    bullet("Expanded(Column) text content (line 401-444) — title row + description"),
    bullet([plain("Switch (line 447-451) — placed as the 4th child of the Row, NOT in Expanded. "), code("activeColor: KlasivoColors.primary"), plain(". "), code("onChanged: null"), plain(" when isCore (disables the switch).")]),

    h3("7.2.3  Known overflow — exact root cause of 1.9px / 7px / 56px"),

    p([bold("(a) 56px horizontal overflow"), plain(" — the icon container width.")]),

    p([plain("The icon Container at lines 382-397 has fixed intrinsic size = padding(12) + icon(24) + padding(12) = 48px. Combined with the SizedBox(width: 12) gap at line 398, the icon+gap block measures 60px. On a constrained-width Row that needs to fit icon + gap + Expanded(content) + Switch (~36px), if the Switch overflows by its own width, the icon+gap block (~60px, often reported as ~56px) is the visible artifact.")]),

    p([bold("(b) 1.9px / 7px vertical overflow"), plain(" — the Core badge Row (lines 405-433).")]),

    p([plain("The inner Row at line 405 contains a Flexible(Text(label)) + optional Core badge Container. The Core badge has "), code("padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2)"), plain(". When "), code("KlasivoTypography.titleSmall"), plain(" (13pt w600, line-height 1.4 = ~18.2px) and "), code("KlasivoTypography.labelSmall"), plain(" (11pt w600, line-height 1.4 = ~15.4px) have different font metrics, the badge Container forces the Row taller than the label's natural line height by exactly 1.9px or 7px depending on font rendering. This is the source of the small vertical overflow.")]),

    h3("7.2.4  Fix — restructure _FeatureFlagTile Row"),

    p("Move the Switch inside the Expanded(Column), placed in a Row with the title. The icon container moves to the leading position. The trailing Switch becomes part of the title row."),

    codeBlock(`// lib/features/settings/pages/feature_flags_screen.dart:379-452
// BEFORE:
Row(
  children: [
    Container(/* icon 48px */),
    SizedBox(width: 12),
    Expanded(
      child: Column(
        children: [
          Row(/* label + Core badge */),  // ❌ vertical overflow
          Text(description, maxLines: 2),
        ],
      ),
    ),
    Switch(...),  // ❌ outside Expanded — horizontal overflow
  ],
)

// AFTER:
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(/* icon 48px — same */),
    SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(  // title + Switch on same line
            children: [
              Expanded(
                child: Text(label,
                  style: AppTypography.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCore)
                Container(
                  margin: EdgeInsets.only(left: KlasivoSpacing.sm),
                  padding: EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('Core',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              SizedBox(width: KlasivoSpacing.sm),
              Switch(
                value: enabled,
                onChanged: isCore ? null : onChanged,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          SizedBox(height: KlasivoSpacing.xs),
          Text(description,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary(Theme.of(context).brightness),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  ],
)`),

    p("This removes both overflow sources: the Switch is now inside Expanded (no horizontal overflow), and the Core badge is in the same Row as the title with consistent line-height (no vertical overflow)."),

    h3("7.2.5  Other Feature Flags issues"),

    p([plain("Dead isDark parameter: "), code("_buildV16Flags(ref, isDark)"), plain(" etc. all take isDark but never use it (lines 95, 170, 205, 240, 281). The isDark value is computed at line 23 and passed down but unused. Remove the parameter.")]),

    p([plain("Hardcoded English labels — no localization. The 31 flag labels and descriptions should be moved to "), code("app_en.arb"), plain(".")]),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 8 — Bottom Navigation Review
// ─────────────────────────────────────────────────────────────────────
function buildBottomNavAudit() {
  return [
    h1("8.  Bottom Navigation Review"),

    callout("CRITICAL", "Bottom-nav shells (TeacherShell, OwnerShell, StudentShell, ParentShell) are dead code. lib/app/router.dart:242-246 ShellRoute builder just returns child. The 4 main nav tabs (/dashboard, /academic, /inbox, /settings) route to inline placeholder widgets rendering only Center(child: Text('Dashboard')). See Section 2.1.", P.critical),

    h2("8.1  Shell files inventory"),

    dataTable(
      ["Shell", "File", "Nav widget line", "Total lines", "Status"],
      [
        ["TeacherShell", "lib/features/shell/teacher_shell.dart", "84", "145", "Dead — not routed"],
        ["OwnerShell", "lib/features/shell/owner_shell.dart", "89", "154", "Dead — not routed"],
        ["StudentShell", "lib/features/shell/student_shell.dart", "61", "121", "Dead — not routed"],
        ["ParentShell", "lib/features/shell/parent_shell.dart", "105", "506", "Dead — not routed"],
      ],
      [20, 38, 12, 12, 18]
    ),

    h2("8.2  Items: icon + label (Teacher & Owner — identical)"),

    dataTable(
      ["#", "Label", "Unselected Icon", "Selected Icon", "Route"],
      [
        ["0", "Dashboard", "Icons.space_dashboard_outlined", "Icons.space_dashboard_rounded", "/dashboard"],
        ["1", "Academic", "Icons.school_outlined", "Icons.school_rounded", "/academic"],
        ["2", "People", "Icons.people_outline_rounded", "Icons.people_rounded", "/people"],
        ["3", "Inbox", "Icons.inbox_outlined", "Icons.inbox_rounded", "/inbox"],
        ["4", "Settings", "Icons.settings_outlined", "Icons.settings_rounded", "/settings"],
      ],
      [6, 18, 32, 32, 12]
    ),

    p("StudentShell (line 22-47): Home / Exams / Inbox / Settings. ParentShell (line 33-64): Home / Progress / Results / Attendance / More."),

    h2("8.3  Icon source and consistency"),

    p("All icons are Material IconData from package:flutter/material.dart. No SVG, no PNG, no custom asset icons. Icon style consistency issue: 4 of 5 unselected icons use the _outlined suffix, but 'People' uses people_outline_rounded (mixed outlined + rounded suffix). The selected icons all use _rounded consistently. Fix: change people_outline_rounded to people_outline to match the other 4."),

    h2("8.4  Active state styling — inconsistent across shells"),

    dataTable(
      ["Shell", "BackgroundColor", "IndicatorColor", "LabelTextStyle", "Height"],
      [
        ["TeacherShell", "(default)", "(default M3)", "(default M3)", "(default 80)"],
        ["OwnerShell", "dark/light surface", "primary.withAlpha(0.12)", "(default M3)", "(default 80)"],
        ["StudentShell", "(default)", "(default M3)", "(default M3)", "(default 80)"],
        ["ParentShell", "surface", "secondarySurface", "selected: secondary", "64"],
      ],
      [18, 22, 22, 28, 10]
    ),

    p("Four different configurations for the same widget. TeacherShell and StudentShell rely entirely on M3 defaults; OwnerShell sets backgroundColor + indicatorColor; ParentShell sets everything plus a custom labelTextStyle. Pick one canonical configuration."),

    p([bold("Recommended canonical config:"), plain(" ParentShell's config is the most polished. Extract to a single "), code("KlasivoBottomNav"), plain(" widget:")]),

    codeBlock(`// lib/widgets/klasivo_bottom_nav.dart (NEW)
class KlasivoBottomNav extends StatelessWidget {
  const KlasivoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.unreadBadgeCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<KlasivoNavDestination> destinations;
  final int unreadBadgeCount;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: AppColors.primary.withAlpha(0.12),
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      labelTextStyle: WidgetStateProperty.resolveTextStyle((states) {
        final selected = states.contains(WidgetState.selected);
        return AppTypography.labelSmall.copyWith(
          color: selected
            ? AppColors.primary
            : AppColors.textTertiary(Theme.of(context).brightness),
        );
      }),
      destinations: destinations.map((d) {
        final showBadge = d.showBadge && unreadBadgeCount > 0;
        return NavigationDestination(
          icon: showBadge
            ? Badge(
                label: Text('$unreadBadgeCount'),
                child: Icon(d.unselectedIcon),
              )
            : Icon(d.unselectedIcon),
          selectedIcon: Icon(d.selectedIcon),
          label: d.label,
        );
      }).toList(),
    );
  }
}

class KlasivoNavDestination {
  const KlasivoNavDestination({
    required this.label,
    required this.unselectedIcon,
    required this.selectedIcon,
    this.showBadge = false,
  });
  final String label;
  final IconData unselectedIcon;
  final IconData selectedIcon;
  final bool showBadge;
}`),

    h2("8.5  Inbox badge logic"),

    p("TeacherShell and OwnerShell both position a KlasivoBadge (variant danger, size sm) at top: -4, right: -12 inside a Stack(clipBehavior: Clip.none) — applied to BOTH icon and selectedIcon (lines 93-124 of teacher_shell, mirrored in owner_shell). The badge count comes from unreadNotificationsProvider. Same logic duplicated in both shells. Extract into the KlasivoBottomNav widget above."),

    h2("8.6  Localization — no labels localized"),

    p("No labels are localized in any shell. All 4 shell files contain hardcoded English string literals. The lib/l10n/ directory has app_en.arb, app_fr.arb, app_tr.arb, app_ar.arb — bottom-nav labels are not pulled from them."),

    p("Fix: add navDashboard, navAcademic, navPeople, navInbox, navSettings keys to each .arb file, and reference via AppLocalizations.of(context).navDashboard in the shells."),

    h2("8.7  TeacherShell / OwnerShell duplication"),

    p("TeacherShell and OwnerShell are near-identical code (different class names, identical _destinations list, identical badge logic). The only differences: OwnerShell sets backgroundColor + indicatorColor (TeacherShell does not), and OwnerShell uses userName ?? 'Owner' vs 'User' (though userName is read but never displayed in either shell's build method — dead variable in both). This is a maintenance smell — these two should share a base widget."),

    p([bold("Fix:"), plain(" extract "), code("KlasivoShell"), plain(" that takes a "), code("destinations"), plain(" list and role-based config. TeacherShell and OwnerShell become thin wrappers passing different destinations / role config.")]),

    h2("8.8  Recommended improvements"),

    bullet([bold("P0:"), plain(" Wire router to use the shells — see Section 2.1.")]),
    bullet([bold("P0:"), plain(" Extract "), code("KlasivoBottomNav"), plain(" widget (see Section 13.4)")]),
    bullet([bold("P1:"), plain(" Fix "), code("people_outline_rounded"), plain(" → "), code("people_outline"), plain(" for icon style consistency")]),
    bullet([bold("P1:"), plain(" Standardize on ParentShell's NavigationBar config (height: 64, indicatorColor: primary.withAlpha(0.12), labelTextStyle with selected/unselected color)")]),
    bullet([bold("P1:"), plain(" Localize all 5 nav labels via AppLocalizations")]),
    bullet([bold("P2:"), plain(" Delete unused "), code("userName"), plain(" provider subscription in both shells")]),
    bullet([bold("P2:"), plain(" Add "), code("SafeArea"), plain(" around the NavigationBar to handle gesture-nav devices")]),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

module.exports = { buildSettingsFeatureFlagsAudit, buildBottomNavAudit };
