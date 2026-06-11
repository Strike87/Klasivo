// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ELEVATION TOKENS — Shadow and depth system
// Klasivo uses a flat design with subtle borders. Elevation is used sparingly
// for floating elements only (FABs, modals, dropdowns).
// ═══════════════════════════════════════════════════════════════════════════════

class AppElevation {
  AppElevation._();

  // ─── Shadow Scale ───────────────────────────────────────────────────────
  static const double none = 0;      // Cards, surfaces (use borders instead)
  static const double sm = 1;        // Subtle lift — dropdowns, popovers
  static const double md = 2;        // Standard lift — FABs, chips
  static const double lg = 4;        // Floating — bottom sheets, snackbars
  static const double xl = 8;        // Modals — dialogs, overlays
  static const double xxl = 16;      // Maximum — search overlay, command palette

  // ─── Scrolled Elevation ─────────────────────────────────────────────────
  static const double appBarResting = 0;
  static const double appBarScrolled = 0.5;  // Very subtle line

  // ─── Design Philosophy ──────────────────────────────────────────────────
  // Klasivo follows a "border-first" approach:
  // - Cards use border (1px) instead of elevation
  // - Only truly floating elements get elevation
  // - Dark mode uses slightly more elevation for separation
  // - Surface tint is disabled (surfaceTintColor: Colors.transparent)
}
