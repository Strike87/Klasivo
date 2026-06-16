/**
 * Klasivo UX Audit — Section content builders (Part 3).
 * Sections 5-9: terminology, responsive, settings/feature-flags, bottom nav, empty states.
 */

const U = require("./generate_ux_audit.js");
const {
  h1, h2, h3, h4, p, code, bold, plain, sev, bullet,
  codeBlock, callout, dataTable, spacer,
  Paragraph, TextRun, PageBreak, AlignmentType, P, FONT, FONT_MONO,
} = U;

// ─────────────────────────────────────────────────────────────────────
// SECTION 5 — Auth Flow Terminology Consistency
// ─────────────────────────────────────────────────────────────────────
function buildTerminologyAudit() {
  return [
    h1("5.  Auth Flow Terminology Consistency"),

    p("The audit extracted every user-facing string from the 12 auth screens and the role_selection card. Terminology is inconsistent in three dimensions: (1) the verb used for registration, (2) the noun used for the entity being created (workspace vs organization), and (3) capitalization of common actions (Sign In vs Sign in). This section proposes a unified terminology system with preferred wording, screen-by-screen impact, and a migration plan."),

    h2("5.1  Current terminology inventory"),

    h3("5.1.1  Registration verb — three different verbs for the same action"),

    dataTable(
      ["String", "file:line", "Context"],
      [
        ["'Create Your Workspace'", "owner_register_screen.dart:172", "Screen title (Title Case)"],
        ["'Create Workspace'", "owner_register_screen.dart:277", "Button label (Sentence case)"],
        ["'Create Workspace'", "teacher_registration_screen.dart:349", "Conditional button label (owner flow)"],
        ["'Create new workspace'", "teacher_registration_screen.dart:229", "Toggle subtitle"],
        ["'Create and manage your educational workspace'", "role_selection_screen.dart:74", "Owner card subtitle"],
        ["'Create Parent Account'", "parent_register_screen.dart:148", "Parent register title (Title Case)"],
        ["'Create Account'", "parent_register_screen.dart:253", "Parent register button"],
        ["'Create one'", "teacher_login_screen.dart:292", "Inline link"],
        ["'Create one'", "parent_login_screen.dart:312", "Inline link"],
        ["'Sign up to track your child\\'s progress'", "parent_register_screen.dart:159", "Parent register subtitle"],
        ["'Create your account'", "teacher_registration_screen.dart:192", "Teacher registration title"],
        ["'Sign in to your Klasivo account'", "teacher_login_screen.dart:148", "Teacher login subtitle"],
      ],
      [40, 32, 28]
    ),

    callout("FINDING", "Four different verbs for the registration action across the 12 screens: 'Create Workspace' (owner), 'Create Account' (parent), 'Sign up' (parent subtitle), 'Create your account' (teacher). No single canonical verb.", P.critical),

    h3("5.1.2  Entity noun — 'workspace' vs 'organization' mixed"),

    dataTable(
      ["String", "file:line", "Term used"],
      [
        ["'Create Your Workspace'", "owner_register_screen.dart:172", "workspace"],
        ["'Create Workspace'", "owner_register_screen.dart:277", "workspace"],
        ["'Create Workspace'", "teacher_registration_screen.dart:349", "workspace"],
        ["'Create new workspace'", "teacher_registration_screen.dart:229", "workspace"],
        ["'Create and manage your educational workspace'", "role_selection_screen.dart:74", "workspace"],
        ["'What would you like to call your workspace, $userName?'", "welcome_screen.dart:241", "workspace"],
        ["'Workspace Name'", "welcome_screen.dart:254", "workspace"],
        ["'Please enter a workspace name'", "welcome_screen.dart:260", "workspace"],
        ["'Set up your organization in minutes'", "owner_register_screen.dart:183", "organization"],
        ["'Join Organization'", "teacher_registration_screen.dart:349", "organization"],
        ["'Organization Owner'", "role_selection_screen.dart:73", "organization"],
        ["'Organization Owner'", "teacher_registration_screen.dart:228", "organization"],
      ],
      [50, 32, 18]
    ),

    p([plain("The data model uses "), code("organization"), plain(" throughout (Organization, OrganizationModel, organizationId, OrganizationProvider). The UI mixes freely. The role is called "), code("Organization Owner"), plain(" but the entity being created is called "), code("workspace"), plain(" — the role name and entity name don't match.")]),

    h3("5.1.3  'Sign In' vs 'Sign in' — capitalization inconsistency"),

    dataTable(
      ["String", "file:line", "Case", "Context"],
      [
        ["'Sign In'", "teacher_login_screen.dart:240", "Title Case", "Primary button"],
        ["'Sign In'", "student_login_screen.dart:196", "Title Case", "Primary button"],
        ["'Sign in'", "teacher_registration_screen.dart:401", "Sentence case", "Inline link"],
        ["'Sign in'", "owner_register_screen.dart:331", "Sentence case", "Inline link"],
        ["'Sign in'", "parent_register_screen.dart:307", "Sentence case", "Inline link"],
        ["'Sign in to your Klasivo account'", "teacher_login_screen.dart:148", "Sentence case", "Subtitle"],
        ["'Back to Login'", "forgot_password_screen.dart:187", "Title Case + 'Login' noun", "Back link"],
        ["'Student Login'", "student_login_screen.dart:105", "Title Case + 'Login' noun", "Screen title"],
        ["'Parent Portal'", "parent_login_screen.dart:148", "Title Case + 'Portal' noun", "Screen title"],
        ["'Create Parent Account'", "parent_register_screen.dart:148", "Title Case + 'Account' noun", "Screen title"],
      ],
      [40, 30, 18, 12]
    ),

    h3("5.1.4  Role names — partially consistent"),

    dataTable(
      ["Role", "Where used (canonical)", "Inconsistencies"],
      [
        ["'Organization Owner'", "role_selection_screen.dart:73, teacher_registration_screen.dart:228", "Entity called 'workspace' elsewhere — name/entity mismatch"],
        ["'Teacher'", "role_selection_screen.dart:84, teacher_registration_screen.dart:237", "Consistent (no 'Instructor' anywhere)"],
        ["'Parent'", "role_selection_screen.dart:106 (role card)", "Screen titles use 'Parent Portal' (login) and 'Create Parent Account' (register) and 'Link Your Child' (link) — four different surface terms"],
        ["'Student'", "(implicit — student_login_screen.dart)", "Screen title 'Student Login' uses 'Login' noun, button uses 'Sign In' verb"],
      ],
      [22, 38, 40]
    ),

    h2("5.2  Unified terminology system (proposed)"),

    h3("5.2.1  Decision: 'Workspace' is the user-facing term"),

    p("Rationale: 'workspace' is already used in 7 of 12 user-facing strings; 'organization' appears in only 4. 'Workspace' is also shorter, more user-friendly, and aligns with competitor terminology (Slack, Notion, Linear all use 'workspace'). The data model can keep Organization as the internal class name; the UI surface uses 'workspace' exclusively."),

    p([bold("Migration rule:"), plain(" replace every user-facing occurrence of 'organization' with 'workspace'. The role "), code("Organization Owner"), plain(" becomes "), code("Workspace Owner"), plain(".")]),

    h3("5.2.2  Decision: 'Create account' is the canonical registration verb"),

    p("Rationale: 'Create account' is the most common registration verb across consumer SaaS (Google, Apple, Microsoft, Slack all use 'Create account' or 'Create your account'). It applies uniformly to all roles. 'Create Workspace' is a secondary action that happens AFTER account creation (in the welcome_screen)."),

    p([bold("Migration rule:"), plain(" (1) The account-creation button on teacher_registration, owner_register, and parent_register says 'Create account'. (2) The workspace-naming button on welcome_screen says 'Create workspace' (this is a separate step). (3) Inline links to register say 'Create one' (already correct). (4) Subtitles say 'Create your account' or 'Sign up' — standardize on 'Create your account'.")]),

    h3("5.2.3  Decision: 'Sign in' (Sentence case) is canonical"),

    p("Rationale: Sentence case is the modern convention (Google, Apple, Slack all use 'Sign in' not 'Sign In'). Title Case is reserved for screen titles. 'Login' as a noun is deprecated — use 'Sign in' as the verb and 'Sign-in screen' if a noun is needed."),

    p([bold("Migration rule:"), plain(" replace 'Sign In' button labels with 'Sign in'. Replace 'Login' noun occurrences with 'sign-in' (e.g., 'Student sign-in' instead of 'Student Login').")]),

    h3("5.2.4  Role name standardization"),

    dataTable(
      ["Role (canonical)", "Screen title (canonical)", "Action verb (canonical)"],
      [
        ["Workspace Owner", "Create workspace", "Create account → Create workspace"],
        ["Teacher", "Create teacher account", "Create account"],
        ["Parent", "Create parent account", "Create account → Link child"],
        ["Student", "Student sign-in", "(no self-registration)"],
      ],
      [30, 35, 35]
    ),

    h2("5.3  Migration plan"),

    h3("5.3.1  Phase 1 — string fixes (quick wins, <2 hours)"),

    p("Apply the following string replacements. Each is a single-line edit."),

    dataTable(
      ["File:line", "Current string", "Replace with", "Reason"],
      [
        ["owner_register_screen.dart:172", "'Create Your Workspace'", "'Create your account'", "Account creation is the action; workspace naming comes later"],
        ["owner_register_screen.dart:277", "'Create Workspace'", "'Create account'", "Same as above"],
        ["owner_register_screen.dart:183", "'Set up your organization in minutes'", "'Set up your workspace in minutes'", "Workspace is canonical"],
        ["owner_register_screen.dart:331", "'Sign in'", "'Sign in'", "(already correct)"],
        ["teacher_login_screen.dart:240", "'Sign In'", "'Sign in'", "Sentence case canonical"],
        ["student_login_screen.dart:196", "'Sign In'", "'Sign in'", "Sentence case canonical"],
        ["student_login_screen.dart:105", "'Student Login'", "'Student sign-in'", "Login noun deprecated"],
        ["teacher_registration_screen.dart:228", "'Organization Owner'", "'Workspace Owner'", "Workspace is canonical"],
        ["teacher_registration_screen.dart:349", "'Create Workspace' / 'Join Organization'", "'Create account' / 'Join workspace'", "Workspace is canonical"],
        ["teacher_registration_screen.dart:401", "'Sign in'", "'Sign in'", "(already correct)"],
        ["role_selection_screen.dart:73", "'Organization Owner'", "'Workspace Owner'", "Workspace is canonical"],
        ["role_selection_screen.dart:74", "'Create and manage your educational workspace'", "(keep — already uses workspace)"],
        ["welcome_screen.dart:241", "'What would you like to call your workspace, $userName?'", "(keep — already correct)"],
        ["welcome_screen.dart:254", "'Workspace Name'", "(keep)"],
        ["parent_login_screen.dart:148", "'Parent Portal'", "'Parent sign-in'", "Portal is jargon; Login noun deprecated"],
        ["parent_register_screen.dart:148", "'Create Parent Account'", "'Create parent account'", "Sentence case for titles"],
        ["parent_register_screen.dart:159", "'Sign up to track your child\\'s progress'", "'Create your account to track your child\\'s progress'", "Canonical verb"],
        ["parent_register_screen.dart:253", "'Create Account'", "'Create account'", "Sentence case"],
        ["parent_register_screen.dart:307", "'Sign in'", "'Sign in'", "(already correct)"],
        ["forgot_password_screen.dart:187", "'Back to Login'", "'Back to sign-in'", "Login noun deprecated"],
        ["parent_link_screen.dart:190", "'Link Your Child'", "'Link your child'", "Sentence case for titles"],
        ["parent_login_screen.dart:322", "'Link your child'", "'Link your child'", "(already correct)"],
      ],
      [25, 30, 30, 15]
    ),

    h3("5.3.2  Phase 2 — move strings to localization (medium, 1-2 days)"),

    p("All auth strings are currently hardcoded English. The lib/l10n/ directory has app_en.arb, app_fr.arb, app_tr.arb, app_ar.arb — auth screens bypass localization entirely. After Phase 1 string fixes, move all auth strings into app_en.arb with stable keys (e.g., auth_signIn_button, auth_createAccount_button, auth_workspaceOwner_role). Then translate to fr/tr/ar."),

    p("Recommended ICU message format for parameterized strings:"),
    codeBlock(`// app_en.arb
"auth_welcomeWorkspacePrompt": "What would you like to call your workspace, {userName}?",
"@auth_welcomeWorkspacePrompt": {
  "placeholders": { "userName": { "type": "String" } }
}`),

    h3("5.3.3  Phase 3 — delete unreachable owner-flow code in TeacherRegistrationScreen"),

    p([plain("Location: "), code("lib/features/auth/pages/teacher_registration_screen.dart:47-68, 108-130"), plain(".")]),

    p("The RoleSelectionScreen 'Organization Owner' card routes to /auth/owner-register (the dedicated OwnerRegisterScreen), NOT to TeacherRegistrationScreen. But TeacherRegistrationScreen ALSO supports the owner flow via the _isOwnerFlow = true toggle. This branch is unreachable from any navigation path. Either delete the owner flow from TeacherRegistrationScreen, or wire up role selection to use it (pick one — current state is dead code that can drift out of sync)."),

    p([bold("Recommendation:"), plain(" delete the owner-flow branch from TeacherRegistrationScreen. OwnerRegisterScreen is the canonical owner registration path. This simplifies TeacherRegistrationScreen to a single-flow 'teacher join with invite code' screen.")]),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

// ─────────────────────────────────────────────────────────────────────
// SECTION 6 — Responsive Design Audit
// ─────────────────────────────────────────────────────────────────────
function buildResponsiveAudit() {
  return [
    h1("6.  Responsive Design Audit"),

    p("The audit searched the entire lib/ directory for hardcoded widths, hardcoded heights, fixed Row layouts, and overflow risks. The findings indicate that while most screens use SingleChildScrollView or ListView correctly, hardcoded dimensions and unexpanded Row patterns are widespread and will break on small Android phones (≤320dp), tablets (≥768dp), and at large font scales (≥1.5x)."),

    h2("6.1  Hardcoded widths (≥100dp) — top offenders"),

    dataTable(
      ["File:line", "Code", "Issue"],
      [
        ["live_class_screen.dart:415", "width: 300", "Fixed-width panel — breaks on phones <360dp"],
        ["live_class_screen.dart:522", "width: 280", "Same — fixed panel width"],
        ["qr_scan_screen.dart:77", "width: 250", "QR viewfinder — should be screen-relative"],
        ["parent_progress_screen.dart:312, 319, 332", "width: 160 (×3)", "Fixed-width progress cards — should be Flexible"],
        ["progress_tracking_screen.dart:399", "width: 100", "Fixed-width indicator"],
        ["k_loading_state.dart:190", "width: 180", "Shimmer line — ok for loading placeholder"],
        ["teacher_analytics_dashboard.dart:1193, 1284", "width: 120 (×2)", "Chart legends — fixed width"],
        ["splash_screen.dart:92", "width: 120", "Logo container — ok for splash"],
        ["pdf_service.dart:620", "width: 140", "PDF rendering — ok, not UI"],
      ],
      [38, 22, 40]
    ),

    h2("6.2  Hardcoded heights (≥100dp) — top offenders"),

    dataTable(
      ["File:line", "Code", "Issue"],
      [
        ["teacher_analytics_dashboard.dart:408, 557, 754, 881, 1105", "height: 200 (×5)", "Chart containers — no scroll fallback on small screens"],
        ["teacher_analytics_dashboard.dart:1194, 1285", "height: 120 (×2)", "Chart legends"],
        ["qr_scan_screen.dart:78", "height: 250", "QR viewfinder"],
        ["parent_progress_screen.dart:313, 320, 333", "height: 160 (×3)", "Progress cards"],
        ["exam_integrity_dashboard.dart:207", "height: 160", "Integrity widget"],
        ["lesson_detail_screen.dart:846", "height: 220", "Video placeholder"],
        ["klasivo_youtube_player.dart:156", "height: 220", "16:9 video — should compute from width"],
        ["subject_content_screen.dart:229", "SizedBox(height: 100)", "Spacer — use Expanded or Flexible"],
        ["splash_screen.dart:93", "height: 120", "Logo container — ok for splash"],
      ],
      [38, 22, 40]
    ),

    h2("6.3  Hardcoded fontSize literals — 337 occurrences"),

    p("A grep for fontSize: \\d{2,} returns 337 occurrences. Most problematic:"),

    dataTable(
      ["File:line", "fontSize", "Issue"],
      [
        ["student_results_screen.dart:383", "48", "Display-grade size — will overflow at 1.5x scale"],
        ["student_result_detail_screen.dart:82", "48", "Same"],
        ["splash_screen.dart:123", "36", "Not in type scale (should be 32 or 40)"],
        ["exam_integrity_dashboard.dart:490, 559", "10 / 11", "Tiny — won't scale with accessibility"],
        ["teacher_analytics_dashboard.dart (24+ occurrences)", "10-14", "Mixed hardcoded sizes throughout"],
      ],
      [40, 12, 48]
    ),

    p([bold("Fix:"), plain(" replace all hardcoded fontSize with AppTypography.* tokens. The 337 occurrences can be batched by file and fixed in ~4 hours of focused work.")]),

    h2("6.4  Unexpanded Row patterns — top 20 overflow risks"),

    p("Found 58 suspicious Row blocks containing Text children without Expanded/Flexible wrappers. Top 20 worst offenders:"),

    dataTable(
      ["#", "File:line", "Pattern"],
      [
        ["1", "campus_list_screen.dart:249-261", "Icon + SizedBox + Text(campus.locationText) — Text not wrapped"],
        ["2", "campus_list_screen.dart:266-289", "Icon + Text + Icon + Text stats row — both Texts unexpanded"],
        ["3", "campus_list_screen.dart:280-285", "Same pattern for teacher count"],
        ["4", "academic_year_list_screen.dart:142", "Icon + Text(year.dateRange) + Icon + Text — 2 unexpanded Texts"],
        ["5", "exam_instances_screen.dart:130", "Text('Started: ...') + Text('Completed: ...') — both unexpanded"],
        ["6", "student_results_screen.dart:264", "Icon + Text('Submitted: ...')"],
        ["7", "student_results_screen.dart:566", "Avatar + Text"],
        ["8", "question_builder_screen.dart:303", "Avatar + Text question header"],
        ["9", "question_builder_screen.dart:758", "Text('Edit $_typeLabel') in modal header"],
        ["10", "exam_detail_screen.dart:216", "Icon + Text('Schedule') section header"],
        ["11", "exam_detail_screen.dart:252", "Text('Questions') + Icon(actions) Row"],
        ["12", "class_list_screen.dart:227, 242", "Icon + Text(capacity) and Icon + Text(student count)"],
        ["13", "stage_list_screen.dart:208, 223", "Icon + Text(classCount) and Icon + Text(studentTotal)"],
        ["14", "announcement_list_screen.dart:191", "Avatar + Text(createdByName) + Text(date)"],
        ["15", "announcement_detail_screen.dart:134", "Same pattern"],
        ["16", "chat_screen.dart:426", "Text(time) — min-size row, OK"],
        ["17", "report_generation_screen.dart:111", "Icon + Text('Report Preview')"],
        ["18", "moderation_queue_screen.dart:224", "Status badge + title text row"],
        ["19", "lesson_detail_screen.dart:1204", "Badge + filename Text"],
        ["20", "lesson_detail_screen.dart:945", "Icon + Text info row"],
      ],
      [6, 32, 62]
    ),

    p([bold("Fix pattern:"), plain(" wrap each Text in Expanded or Flexible. For Icon + Text rows where the icon is fixed-width and the text should fill remaining space:")]),

    codeBlock(`// BEFORE (overflow risk)
Row(children: [
  Icon(Icons.event_outlined, size: 16),
  SizedBox(width: 4),
  Text(year.dateRange),  // ❌ no Expanded
]),

// AFTER (safe)
Row(children: [
  Icon(Icons.event_outlined, size: 16),
  SizedBox(width: 4),
  Expanded(
    child: Text(year.dateRange,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  ),
]),`),

    h2("6.5  Widgets that should use Expanded / Flexible / LayoutBuilder / Wrap"),

    h3("6.5.1  Should use Expanded"),

    bullet([code("feature_flags_screen.dart:379-452"), plain(" — _FeatureFlagTile Row needs Expanded around the Switch or move Switch inside the Expanded(Column)")]),
    bullet([code("parent_link_screen.dart:215-246"), plain(" — 8 OTP SizedBoxes need to be computed via LayoutBuilder and wrapped in Flexible")]),
    bullet([plain("All 20 unexpanded Row patterns in Section 6.4 above")]),

    h3("6.5.2  Should use Flexible"),

    bullet([code("role_selection_screen.dart:157-201"), plain(" — _RoleCard trailing arrow Icon should be Flexible to allow it to shrink on narrow screens (currently fixed)")]),
    bullet([code("settings_screen.dart:473"), plain(" — _ThemeSegmentedControl as ListTile trailing should be Flexible")]),

    h3("6.5.3  Should use LayoutBuilder"),

    bullet([code("parent_link_screen.dart:215"), plain(" — OTP Row (compute box width from available width)")]),
    bullet([code("feature_flags_screen.dart:379"), plain(" — _FeatureFlagTile (decide Switch placement based on available width)")]),
    bullet([code("teacher_analytics_dashboard.dart (5 chart containers)"), plain(" — compute chart height as a fraction of available width")]),
    bullet([code("klasivo_youtube_player.dart:156"), plain(" — compute 16:9 height from parent width")]),
    bullet([plain("Every auth screen (12 screens)"), plain(" — to apply the maxWidth=480 cap")]),

    h3("6.5.4  Should use Wrap"),

    bullet([code("role_selection_screen.dart:114-115"), plain(" — 'Terms of Service' and 'Privacy Policy' links should Wrap to avoid clipping")]),
    bullet([code("welcome_screen.dart:280-282"), plain(" — already uses Wrap (good)")]),
    bullet([code("feature_flags_screen.dart:405-433"), plain(" — Core badge + label Row could Wrap when label is long")]),
    bullet([code("exam_detail_screen.dart:252"), plain(" — Questions header + action icons could Wrap on narrow screens")]),

    h2("6.6  Recommended responsive scaffold (apply to all auth screens)"),

    p("Already detailed in Section 3.2.1 — KlasivoAuthScaffold wraps body in SafeArea + Center + ConstrainedBox(maxWidth: 480) + SingleChildScrollView with viewInsets.bottom padding. Apply to all 12 auth screens."),

    h2("6.7  Tablet / landscape mode"),

    p("Currently no screen has explicit tablet or landscape handling. The recommended KlasivoAuthScaffold (maxWidth: 480) handles tablet for auth screens. For list screens (exam_list, student_list, etc.), consider a two-pane MasterDetail layout on tablets (≥768dp) using LayoutBuilder — left pane shows list, right pane shows detail. This is a larger refactor; defer until after P0/P1 fixes ship."),

    new Paragraph({ children: [new PageBreak()] }),
  ];
}

module.exports = { buildTerminologyAudit, buildResponsiveAudit };
