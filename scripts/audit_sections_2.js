/**
 * Klasivo UX Audit — Section content builders (Part 2).
 * Sections 3-7: auth screens, branding, terminology, responsive, settings/feature-flags.
 */

const U = require("./generate_ux_audit.js");
const {
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer,
  Paragraph, TextRun, PageBreak, AlignmentType, P, FONT, FONT_MONO,
} = U;

// ─────────────────────────────────────────────────────────────────────
// SECTION 3 — Authentication Screen Audit
// ─────────────────────────────────────────────────────────────────────
function buildAuthScreenAudit() {
  return [
    h1("3.  Authentication Screen Audit"),

    p("The Klasivo auth flow consists of 12 active screens across two feature folders: lib/features/auth/pages/ (8 screens, 2,258 lines) and lib/features/parent/pages/ (4 screens, 1,208 lines). All screens are wired through the GoRouter in lib/main.dart (lines 685-742). The audit reviewed each screen for layout, spacing, typography, button hierarchy, accessibility, and responsiveness."),

    h2("3.1  Screen inventory"),

    dataTable(
      ["#", "Screen", "File", "Lines"],
      [
        ["1", "Splash", "lib/features/auth/pages/splash_screen.dart", "154"],
        ["2", "Role Selection (/auth)", "lib/features/auth/pages/role_selection_screen.dart", "206"],
        ["3", "Teacher Login", "lib/features/auth/pages/teacher_login_screen.dart", "305"],
        ["4", "Teacher Registration (owner+teacher toggle)", "lib/features/auth/pages/teacher_registration_screen.dart", "473"],
        ["5", "Student Login", "lib/features/auth/pages/student_login_screen.dart", "234"],
        ["6", "Owner Register", "lib/features/auth/pages/owner_register_screen.dart", "347"],
        ["7", "Welcome / Workspace Naming", "lib/features/auth/pages/welcome_screen.dart", "339"],
        ["8", "Forgot Password", "lib/features/auth/pages/forgot_password_screen.dart", "200"],
        ["9", "Change Password (forced)", "lib/features/auth/pages/change_password_screen.dart", "239"],
        ["10", "Parent Login", "lib/features/parent/pages/parent_login_screen.dart", "336"],
        ["11", "Parent Register", "lib/features/parent/pages/parent_register_screen.dart", "319"],
        ["12", "Parent Link (post-register OTP)", "lib/features/parent/pages/parent_link_screen.dart", "277"],
        [{ text: "TOTAL", bold: true }, "", "", { text: "3,387 lines", bold: true }],
      ],
      [8, 32, 50, 10]
    ),

    h2("3.2  Alignment issues"),

    h3("3.2.1  No maxWidth cap on any screen (except Change Password)"),

    p("Only lib/features/auth/pages/change_password_screen.dart:134-135 uses ConstrainedBox(maxWidth: 400) centered. Every other auth screen lets the form stretch edge-to-edge on tablet/web (≥768dp). The role_selection cards and the parent_link OTP row look particularly broken at wide widths — cards stretch to 1200dp+ with no upper bound, and OTP boxes left-align with massive inter-box gaps."),

    p("Recommended pattern — extract a KlasivoAuthScaffold wrapper:"),
    codeBlock(`// lib/widgets/klasivo_auth_scaffold.dart (NEW)
class KlasivoAuthScaffold extends StatelessWidget {
  const KlasivoAuthScaffold({
    super.key,
    required this.body,
    this.appBarTitle,
    this.showBackButton = true,
    this.maxWidth = 480,
  });

  final Widget body;
  final String? appBarTitle;
  final bool showBackButton;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarTitle != null
        ? AppBar(
            title: Text(appBarTitle!),
            leading: showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                )
              : null,
          )
        : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left:   KlasivoSpacing.xxl,
                right:  KlasivoSpacing.xxl,
                bottom: MediaQuery.of(context).viewInsets.bottom + KlasivoSpacing.xxl,
              ),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}`),

    h3("3.2.2  Mixed navigation semantics — go() vs pop()"),

    p("Six screens use context.go('/auth') (replaces the entire navigation stack), one uses context.pop() (preserves stack), one uses context.go(AppConstants.routeParentLogin). For the back button specifically, the user's expectation is 'go back one screen', which is pop semantics — but go('/auth') discards the stack and lands them at role selection. This is especially wrong on the forgot_password_screen, which hardcodes context.go('/auth/teacher-login') at line 189 — meaning a parent who reached forgot-password gets bounced to the teacher login instead of back to the parent login."),

    p("Fix: standardize on context.pop() for back buttons. Where the previous route is ambiguous (e.g., deep-linked directly to forgot-password), fall back to context.go('/auth')."),

    h2("3.3  Spacing inconsistencies"),

    h3("3.3.1  Last-field-to-primary-button spacing varies across screens"),

    dataTable(
      ["Screen", "Last field", "Primary button", "Gap (twips)", "Token"],
      [
        ["teacher_login", "password", "Sign In", "20", "KlasivoSpacing.xl"],
        ["teacher_registration", "password", "Create/Join", "16", "KlasivoSpacing.lg"],
        ["owner_register", "password", "Create Workspace", "16", "KlasivoSpacing.lg"],
        ["student_login", "password", "Sign In", "24", "KlasivoSpacing.xxl"],
        ["parent_login", "password", "Sign In", "20", "KlasivoSpacing.xl"],
        ["parent_register", "password", "Create Account", "16", "KlasivoSpacing.lg"],
        ["forgot_password", "email", "Send Reset Link", "24", "KlasivoSpacing.xxl"],
        ["welcome", "workspace name", "Continue", "32", "KlasivoSpacing.xxxl"],
        [{ text: "RECOMMENDED", bold: true, color: P.accent }, "", "", { text: "24", bold: true, color: P.accent }, { text: "KlasivoSpacing.xxl", bold: true, color: P.accent, mono: true }],
      ],
      [25, 18, 18, 14, 25]
    ),

    h3("3.3.2  parent_login_screen — missing spacer between CTAs (visual bug)"),

    p([plain("Location: "), code("lib/features/parent/pages/parent_login_screen.dart:316-319"), plain(".")]),

    p("After the 'Don't have an account? Create one' Wrap, there is NO SizedBox spacer before the 'Link your child' Center widget. The two CTAs are stacked flush against each other. Every other auth screen has SizedBox(height: KlasivoSpacing.xxl) (24) between distinct UI sections. This is a visual bug that makes the screen feel cramped and amateurish."),

    p("Fix:"),
    codeBlock(`// lib/features/parent/pages/parent_login_screen.dart:316
// INSERT before the 'Link your child' Center widget:
const SizedBox(height: KlasivoSpacing.xxl),  // 24`),

    h3("3.3.3  welcome_screen uses hero=48 top padding — visually jarring"),

    p([plain("Location: "), code("lib/features/auth/pages/welcome_screen.dart:201"), plain(" (padding KlasivoSpacing.hero=48). Every other auth screen uses KlasivoSpacing.lg=16 at the top. The Welcome screen's 48px top padding makes it visually disconnected from the rest of the auth flow.")]),

    p("Fix: change padding to KlasivoSpacing.lg (=16) for visual consistency."),

    h2("3.4  Typography inconsistencies"),

    h3("3.4.1  Splash screen — only screen with ad-hoc TextStyle"),

    p([plain("Location: "), code("lib/features/auth/pages/splash_screen.dart:121-137"), plain(".")]),

    codeBlock(`// CURRENT (splash_screen.dart:121-127)
TextStyle(
  fontFamily: KlasivoTypography.fontFamily,
  fontSize: 36,        // ❌ NOT in type scale (scale is 32, 40)
  fontWeight: FontWeight.w700,
  color: Colors.white,
  letterSpacing: -0.5,
),
// ...
TextStyle(
  fontFamily: KlasivoTypography.fontFamily,
  fontSize: 15,        // ❌ NOT in type scale (scale is 14, 16)
  color: Colors.white70, // ❌ contrast 3.2:1 fails WCAG AA
  fontWeight: FontWeight.w400,
)`),

    p("Fix:"),
    codeBlock(`// FIXED
style: AppTypography.displayMedium.copyWith(
  color: Colors.white,
),  // 32pt w700 — in scale, passes contrast on indigo
// ...
style: AppTypography.bodyMedium.copyWith(
  color: Colors.white,  // 14pt w400 — passes contrast (7.4:1)
),`),

    h3("3.4.2  Change Password screen uses Theme.of(context).textTheme instead of KlasivoTypography"),

    p([plain("Location: "), code("lib/features/auth/pages/change_password_screen.dart:128, 147, 160"), plain(".")]),

    p("Every other auth screen uses KlasivoTypography.* tokens directly. The Change Password screen uses Theme.of(context).textTheme.titleMedium and TextStyle(color: AppColors.error) with no fontSize/fontFamily specified. This is the only auth screen that bypasses the typography tokens."),

    h3("3.4.3  Hardcoded icon sizes — 7 distinct values across 12 screens"),

    dataTable(
      ["Icon size (px)", "Token equivalent", "Where used"],
      [
        ["20", "AppSpacing.iconSizeMd", "AppBar back buttons (×10), visibility toggles (×8), error icons (×6)"],
        ["48", "AppSpacing.iconSizeHero", "Header illustrations (5 screens: student_login, owner_register, parent_login, parent_register, parent_link)"],
        ["56", "(none — add to scale)", "Header illustrations (welcome, forgot_password)"],
        ["64", "(none — add to scale)", "Splash error fallback, change_password lock icon"],
        ["52", "(none)", "role_selection top logo"],
        ["28", "(none)", "role_selection role-card icon"],
        ["120", "(none)", "splash logo container width/height"],
      ],
      [15, 25, 60]
    ),

    p("Fix: tokenize all icon sizes. Add iconSizeHeroLg=56 and iconSizeDisplayLg=64 to AppSpacing."),

    h2("3.5  Button hierarchy problems"),

    h3("3.5.1  Three different loading-state patterns"),

    dataTable(
      ["Pattern", "Screens using it", "Issue"],
      [
        ["onPressed: isLoading ? null : fn + loading: isLoading", "teacher_login, teacher_registration, owner_register, student_login, forgot_password, welcome, parent_link", "Redundant — KlasivoButton already disables when loading: true. The ternary is harmless but inconsistent with pattern #2."],
        ["onPressed: fn (always enabled) + loading: isLoading", "parent_login, parent_register", "Cleaner. Relies on KlasivoButton's internal disable. Recommended pattern."],
        ["ElevatedButton + manual CircularProgressIndicator swap", "change_password_screen", "Doesn't use KlasivoButton at all — no spinner integration, no size/variant system. Must be rewritten."],
      ],
      [40, 35, 25]
    ),

    p("Fix: standardize on pattern #2 (onPressed: fn + loading: isLoading). Remove the redundant isLoading ? null ternary from the 7 screens using pattern #1."),

    h3("3.5.2  Google button missing loading spinner on 3 screens"),

    p([plain("teacher_login_screen.dart:272, teacher_registration_screen.dart:377-384, owner_register_screen.dart:309 — the Google sign-in button has "), code("onPressed: isLoading ? null : _loginWithGoogle"), plain(" but is missing the "), code("loading: isLoading"), plain(" prop. No spinner is shown on the Google button while Google sign-in is in progress. parent_login and parent_register do this correctly.")]),

    p("Fix: add loading: isLoading to the Google button on these 3 screens."),

    h3("3.5.3  owner_register uses GestureDetector+Text instead of KlasivoButton for 'Sign in' link"),

    p([plain("Location: "), code("lib/features/auth/pages/owner_register_screen.dart:328-337"), plain(".")]),

    p("Every other auth screen uses KlasivoButton(variant: tertiary) for the 'Sign in' inline link. owner_register_screen uses a raw GestureDetector wrapping a Text with underline decoration. The tap target is the text height only (~20px) — fails WCAG 2.5.5 (44px minimum). No Semantics(button: true) — screen readers read it as plain text. Visually inconsistent with sibling screens."),

    p("Fix: replace with KlasivoButton(variant: tertiary, label: 'Sign in', onPressed: ...)."),

    h3("3.5.4  change_password_screen — entire screen bypasses KlasivoButton and KlasivoTextField"),

    p([plain("Location: "), code("lib/features/auth/pages/change_password_screen.dart:167-229"), plain(".")]),

    p("Uses raw TextFormField with inline InputDecoration. Uses raw ElevatedButton with styleFrom(padding: EdgeInsets.symmetric(vertical: 16)). Hardcoded BorderRadius.circular(8), hardcoded EdgeInsets.all(24), hardcoded SizedBox(height: 16/24). The only auth screen that doesn't use the design system at all."),

    p("Fix: rewrite using KlasivoButton(primary, fullWidth: true, size: lg, loading: _isLoading) and KlasivoTextField for all three password fields."),

    h2("3.6  Accessibility issues"),

    h3("3.6.1  No Semantics widgets anywhere in the auth flow"),

    p("A grep for Semantics( and Tooltip( across lib/features/auth/pages/ and lib/features/parent/pages/ returns ZERO matches. None of the following have accessibility labels: AppBar back buttons (10 screens), password visibility toggles (8 screens), error message containers (8 screens), the _ToggleOption owner/teacher selector in teacher_registration, the _RoleCard role selector in role_selection, the 8 OTP code fields in parent_link, illustration icons on every screen."),

    h3("3.6.2  Low contrast on divider 'OR' label"),

    p([plain("The 'OR' divider label uses "), code("KlasivoColors.darkTextTertiary (#94A3B8)"), plain(" / "), code("lightTextTertiary (#868E96)"), plain(" on the background. Contrast ratio ≈ 3.0:1 on light — fails WCAG AA (requires 4.5:1 for 11pt labelSmall text). The same tertiary color is used for the 'Don't have an account?' prefix text on every login/register screen.")]),

    p("Fix: use AppColors.textSecondary (#495057 light / #CBD5E1 dark) — passes AA at 7.5:1 / 9.2:1."),

    h3("3.6.3  Missing Tooltip on IconButtons"),

    p("All ~18 IconButtons across the 12 auth screens lack a Tooltip message. iOS users won't see a label on long-press. Android TalkBack will announce only the icon name (e.g., 'arrow back' instead of 'Back to role selection')."),

    p("Fix pattern:"),
    codeBlock(`IconButton(
  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
  tooltip: 'Back',  // ← ADD THIS
  onPressed: () => context.pop(),
)`),

    h2("3.7  Responsiveness issues"),

    h3("3.7.1  No LayoutBuilder on any auth screen"),

    p("Confirmed via grep — zero LayoutBuilder usages in lib/features/auth/ or lib/features/parent/. Combined with the missing maxWidth cap (Section 3.2.1), this means forms stretch edge-to-edge on tablet and the OTP row breaks on narrow phones."),

    h3("3.7.2  No MediaQuery.viewInsets.bottom on any form screen"),

    p("All 10 form screens use padding: EdgeInsets.symmetric(horizontal: KlasivoSpacing.xxl) with no bottom component for the keyboard. On small screens with the keyboard open, the primary action button is obscured. See also Section 2.6."),

    h3("3.7.3  parent_link OTP row overflows on screens <320dp"),

    p("Detailed in Section 2.4. The 8 × SizedBox(width: 38) = 304px layout exceeds 272px available on iPhone SE / older Android. Fix: use LayoutBuilder + Wrap or compute width from constraints."),

    h2("3.8  Logo / branding placement per screen"),

    p("Four different header illustration patterns exist across 12 screens:"),

    dataTable(
      ["Screen", "Asset used", "Size", "Container shape", "Container color"],
      [
        ["splash (active)", "Image.asset app_icon_foreground.png", "120×120", "Rounded square (radius 20)", "White fill + boxShadow blur 24"],
        ["role_selection", "Icons.school_outlined", "52", "Rounded square (radius 16)", "primary.withAlpha(0.08)"],
        ["teacher_login", "(none)", "—", "—", "—"],
        ["teacher_registration", "(none)", "—", "—", "—"],
        ["student_login", "Icons.school_outlined", "48", "Rounded square (radius 16)", "secondary.withAlpha(0.08)"],
        ["owner_register", "Icons.business_outlined", "48", "Rounded square (radius 16)", "primary.withAlpha(0.08)"],
        ["welcome", "Icons.rocket_launch_outlined", "56", "Circle", "primary.withAlpha(0.08)"],
        ["forgot_password", "Icons.lock_reset_outlined / mark_email_read_outlined", "56", "Circle", "primary.withAlpha(0.08)"],
        ["parent_login", "Icons.family_restroom_outlined", "48", "Rounded square (radius 16)", "Color(0xFF845EF7).withAlpha(0.08)"],
        ["parent_register", "Icons.family_restroom_outlined", "48", "Rounded square (radius 16)", "Color(0xFF845EF7).withAlpha(0.08)"],
        ["parent_link", "Icons.link_rounded", "48", "Rounded square (radius 16)", "secondary.withAlpha(0.08)"],
        ["change_password (forced)", "Icons.lock_outline", "64", "(none)", "(none)"],
      ],
      [22, 30, 8, 22, 18]
    ),

    p([bold("Recommendation:"), plain(" Standardize on a single KlasivoBrandHeader widget with the following spec:")]),

    codeBlock(`// lib/widgets/klasivo_brand_header.dart (NEW)
class KlasivoBrandHeader extends StatelessWidget {
  const KlasivoBrandHeader({
    super.key,
    this.icon,
    this.size = KlasivoBrandHeaderSize.md,
    this.tint,
  });

  /// If null, uses the real app logo asset.
  final IconData? icon;
  final KlasivoBrandHeaderSize size;
  final Color? tint;  // defaults to AppColors.primary

  @override
  Widget build(BuildContext context) {
    final dims = _dimsFor(size);
    return Container(
      width: dims.container,
      height: dims.container,
      decoration: BoxDecoration(
        color: (tint ?? AppColors.primary).withAlpha(0.08),
        shape: BoxShape.circle,  // ← single canonical shape
      ),
      alignment: Alignment.center,
      child: icon != null
        ? Icon(icon, size: dims.icon, color: tint ?? AppColors.primary)
        : Image.asset(
            'assets/icon/app_icon_foreground.png',
            width: dims.icon,
            height: dims.icon,
            fit: BoxFit.contain,
          ),
    );
  }
}

enum KlasivoBrandHeaderSize { sm, md, lg, xl }
class _Dims {
  final double container, icon;
  const _Dims(this.container, this.icon);
}
_Dims _dimsFor(KlasivoBrandHeaderSize s) {
  switch (s) {
    case KlasivoBrandHeaderSize.sm: return const _Dims(56, 28);
    case KlasivoBrandHeaderSize.md: return const _Dims(72, 36);
    case KlasivoBrandHeaderSize.lg: return const _Dims(96, 48);
    case KlasivoBrandHeaderSize.xl: return const _Dims(144, 72);
  }
}`),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 4 — App Icon & Branding Audit
// ─────────────────────────────────────────────────────────────────────
function buildBrandingAudit() {
  return [
    h1("4.  App Icon & Branding Audit"),

    p("The audit reviewed branding consistency across the splash, login, registration, workspace creation, parent portal, and in-app screens. The headline finding is that the app's raster logo asset (assets/icon/app_icon_foreground.png) is rendered on exactly one screen (splash). Every other screen fakes the brand mark with a generic Material Icon at seven different sizes in three different container shapes."),

    h2("4.1  Where the logo appears"),

    p([plain("A repo-wide search for "), code("Image.asset"), plain(", "), code("AssetImage"), plain(", "), code("SvgPicture.asset"), plain(", and the strings "), code("assets/logo"), plain(", "), code("assets/icon"), plain(", "), code("assets/brand"), plain(" returned exactly ONE active match:")]),

    codeBlock(`// lib/features/auth/pages/splash_screen.dart:107-115
Image.asset(
  'assets/icon/app_icon_foreground.png',
  fit: BoxFit.contain,
  errorBuilder: (_, __, ___) => Icon(
    Icons.school_outlined,
    size: 64,
    color: KlasivoColors.primary,
  ),
)`),

    p("Everywhere else, 'the logo' is one of five different Material Icons (Icons.school_outlined, Icons.business_outlined, Icons.family_restroom_outlined, Icons.rocket_launch_outlined, Icons.lock_reset_outlined) at seven different sizes (20, 40, 48, 52, 56, 64, 120) in three different container shapes (rounded square at radii 8/14/16/20, circle, transparent)."),

    h2("4.2  Logo size inconsistency summary"),

    dataTable(
      ["Screen", "Asset", "Container size", "Icon size", "Shape"],
      [
        ["Splash (active)", "PNG asset", "120×120", "—", "Rounded square (r=20)"],
        ["Splash (DEAD duplicate)", "Icons.school_outlined", "72 (padding 24)", "72", "Rounded square (r=20)"],
        ["Role selection", "Icons.school_outlined", "(padding 16)", "52", "Rounded square (r=16)"],
        ["Owner register", "Icons.business_outlined", "(padding 16)", "48", "Rounded square (r=16)"],
        ["Student login", "Icons.school_outlined", "(padding 16)", "48", "Rounded square (r=16)"],
        ["Parent login", "Icons.family_restroom_outlined", "(padding 16)", "48", "Rounded square (r=16)"],
        ["Welcome", "Icons.rocket_launch_outlined", "(padding 24)", "56", "Circle"],
        ["Forgot password", "Icons.lock_reset_outlined", "(padding 24)", "56", "Circle"],
        ["Settings → About", "Icons.school_outlined", "(padding 12)", "40", "Rounded square (r=14)"],
        ["Owner dashboard AppBar", "Icons.school_outlined", "(padding 8)", "20", "Rounded square (r=8)"],
        ["Teacher dashboard AppBar", "Icons.school_outlined", "(padding 8)", "20", "Rounded square (r=8)"],
        ["Student dashboard AppBar", "(none)", "—", "—", "—"],
        ["Parent dashboard AppBar", "(none)", "—", "—", "—"],
      ],
      [22, 28, 18, 12, 20]
    ),

    callout("FINDING", "Seven different logo sizes (20, 40, 48, 52, 56, 64, 120) and three different container shapes. No reusable KlasivoLogo or KlasivoBrandHeader widget exists. This is the single largest source of perceived quality gap in the auth flow.", P.critical),

    h2("4.3  App icon configuration issues"),

    h3("4.3.1  Adaptive icon background color is off-brand"),

    p([plain("Location: "), code("pubspec.yaml:131"), plain(".")]),

    codeBlock(`# pubspec.yaml (current)
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#1A3A8A"   # ❌ off-brand navy
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  remove_alpha_ios: true`),

    p([plain("The adaptive icon background "), code("#1A3A8A"), plain(" does not appear anywhere in "), code("lib/core/tokens/app_colors.dart"), plain(". The design system primary is "), code("#3B5BDB"), plain(" (royal indigo), primaryDark is "), code("#364FC7"), plain(", primaryLight is "), code("#5C7CFA"), plain(". The launcher icon background is therefore visually inconsistent with the in-app brand color.")]),

    p("Fix:"),
    codeBlock(`# pubspec.yaml (fixed)
  adaptive_icon_background: "#3B5BDB"   # ✅ AppColors.primary`),

    h3("4.3.2  Adaptive icons never generated"),

    p([plain("The "), code("android/app/src/main/res/mipmap-anydpi-v26/"), plain(" directory does not exist. Adaptive icons require "), code("mipmap-anydpi-v26/ic_launcher.xml"), plain(" referencing "), code("@drawable/ic_launcher_background"), plain(" and "), code("@drawable/ic_launcher_foreground"), plain(". On Android 8.0+ (API 26+, ~95% of active devices), the launcher falls back to the legacy PNG ic_launcher.png and ignores the adaptive_icon_* config entirely.")]),

    p([bold("Fix:"), plain(" after updating the foreground PNG and background color, run:")]),
    codeBlock(`dart run flutter_launcher_icons:main`),

    h3("4.3.3  app_icon.png and app_icon_foreground.png are byte-identical"),

    p("Both files have md5 20ff2d0e41f44927c30d0a09d5b7133e and are 1024×1024 PNGs. The foreground should be a transparent PNG with only the logo mark (typically 66% of canvas, centered) so the background color shows through. Currently it's a full opaque duplicate of the full icon. The launcher will render the full opaque icon on top of the background color, defeating the adaptive icon design."),

    p([bold("Fix:"), plain(" create a new transparent 1024×1024 PNG containing only the Klasivo logo mark at ~66% canvas size, centered. Save as "), code("assets/icon/app_icon_foreground.png"), plain(". Keep "), code("assets/icon/app_icon.png"), plain(" as the full opaque 1024×1024 for legacy devices.")]),

    h3("4.3.4  Root-level klasivo_icon.png is a mislabeled JPEG"),

    p("The file command reports /home/z/my-project/klasivo_icon.png as 'JPEG image data ... 1024x1024' despite the .png extension. This file is not referenced by pubspec.yaml or any code — appears to be a stray source asset. Delete it."),

    h2("4.4  Native Android splash is a stretched full-bleed PNG"),

    p([plain("Location: "), code("android/app/src/main/res/drawable/launch_background.xml"), plain(", "), code("android/app/src/main/res/drawable-*/launch_image.png"), plain(" (6 density buckets, 37-309 KB each).")]),

    codeBlock(`<!-- android/app/src/main/res/drawable/launch_background.xml (current) -->
<layer-list>
  <item>
    <bitmap
      android:src="@drawable/launch_image"
      android:gravity="fill_horizontal|fill_vertical" />  <!-- ❌ stretched -->
  </item>
</layer-list>`),

    p("The launch_image PNG is scaled to fill the entire screen, which distorts on devices with different aspect ratios. No colors.xml exists, no centered logo, no brand background color. The in-app Flutter splash (lib/features/auth/pages/splash_screen.dart) renders correctly with a centered 120×120 logo, but there's a visible jump/crop between native and Flutter splash."),

    p("Recommended fix — migrate to flutter_native_splash:"),
    codeBlock(`# 1. Add to pubspec.yaml dev_dependencies:
#    flutter_native_splash: ^2.4.0

# 2. Create flutter_native_splash.yaml at project root:
flutter_native_splash:
  color: "#0F172A"          # AppColors.darkBackground
  image: assets/icon/app_icon_foreground.png
  android_12:
    image: assets/icon/app_icon_foreground.png
    color: "#0F172A"
    icon_background_color: "#3B5BDB"

# 3. Generate:
#    dart run flutter_native_splash:create`),

    h2("4.5  Recommended logo size & spacing scale"),

    h3("4.5.1  Logo size scale (canonical)"),

    dataTable(
      ["Token", "Container size (dp)", "Icon/logo size (dp)", "Use case"],
      [
        ["KlasivoBrandHeaderSize.sm", "56", "28", "Inline mentions, AppBar brand chip"],
        ["KlasivoBrandHeaderSize.md", "72", "36", "Auth screen headers (default)"],
        ["KlasivoBrandHeaderSize.lg", "96", "48", "Welcome, forgot password success state"],
        ["KlasivoBrandHeaderSize.xl", "144", "72", "Splash screen, onboarding hero"],
      ],
      [30, 22, 22, 26]
    ),

    h3("4.5.2  Spacing scale around the brand header"),

    p("Apply this canonical vertical rhythm on every auth screen:"),
    codeBlock(`Column(
  children: [
    KlasivoBrandHeader(size: KlasivoBrandHeaderSize.md),  // 72dp
    SizedBox(height: KlasivoSpacing.xxl),  // 24dp — gap between header and title
    Text('Screen Title', style: AppTypography.headlineLarge),
    SizedBox(height: KlasivoSpacing.sm),   // 8dp — gap between title and subtitle
    Text('Screen subtitle', style: AppTypography.bodyMedium),
    SizedBox(height: KlasivoSpacing.xxxl), // 32dp — gap before form
    // ... form fields
  ],
)`),

    h3("4.5.3  Reusable widget — KlasivoBrandHeader"),

    p("See Section 3.8 for the complete widget code. Once created, replace all 12 ad-hoc header patterns with this single widget."),

    h2("4.6  App icon asset cleanup checklist"),

    bullet([plain("Replace "), code("assets/icon/app_icon_foreground.png"), plain(" with a transparent 1024×1024 PNG containing only the Klasivo logo mark at ~66% canvas size, centered")]),
    bullet([plain("Update "), code("pubspec.yaml:131"), plain(" adaptive_icon_background from "), code("#1A3A8A"), plain(" to "), code("#3B5BDB")]),
    bullet([plain("Run "), code("dart run flutter_launcher_icons:main"), plain(" to regenerate mipmap-anydpi-v26/")]),
    bullet([plain("Delete "), code("/home/z/my-project/klasivo_icon.png"), plain(" (mislabeled JPEG, unreferenced)")]),
    bullet([plain("Add "), code("flutter_native_splash"), plain(" dev dependency and migrate native splash to centered logo on brand-color background")]),
    bullet([plain("Verify on Android 8+ device that adaptive icon renders correctly with the brand-color background")]),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

module.exports = { buildAuthScreenAudit, buildBrandingAudit };
