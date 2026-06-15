// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RADIUS TOKENS — Rounded but not childish, modern and professional
// All border radii in the system are defined here.
// ═══════════════════════════════════════════════════════════════════════════════

class AppRadius {
  AppRadius._();

  // ─── Scale ──────────────────────────────────────────────────────────────
  static const double xs = 6;      // Tags, tiny badges
  static const double sm = 8;      // Small buttons, compact chips
  static const double md = 14;     // Primary radius — the Klasivo standard
  static const double lg = 16;     // Cards, dialogs, modals
  static const double xl = 20;     // Large cards, bottom sheets
  static const double xxl = 28;    // Feature cards, onboarding
  static const double pill = 100;  // Badges, chips, avatars, toggle buttons

  // ─── Semantic Radii ─────────────────────────────────────────────────────
  static const double button = md;           // Standard button radius
  static const double input = md;            // Text field radius
  static const double card = md;             // Card radius
  static const double dialog = lg;           // Dialog radius
  static const double bottomSheet = xl;      // Bottom sheet top corners
  static const double snackbar = md;         // SnackBar radius
  static const double tooltip = sm;          // Tooltip radius
  static const double fab = lg;              // FAB radius
  static const double notification = md;     // Notification card radius
  static const double badge = pill;          // Badge/chip radius
  static const double avatar = pill;         // Avatar radius (circular)
  static const double iconButton = sm;       // Icon button splash radius
}
