// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SPACING TOKENS — Apple-inspired 4px base grid
// All spacing values in the system are defined here. No magic numbers.
// ═══════════════════════════════════════════════════════════════════════════════

class AppSpacing {
  AppSpacing._();

  // ─── Base Grid (4px) ────────────────────────────────────────────────────
  static const double unit = 4; // 1 grid unit = 4px

  // ─── Scale ──────────────────────────────────────────────────────────────
  static const double xs = 4;     // 1 unit  — tight gaps
  static const double sm = 8;     // 2 units — small padding
  static const double md = 12;    // 3 units — medium padding
  static const double lg = 16;    // 4 units — standard padding
  static const double xl = 20;    // 5 units — section padding
  static const double xxl = 24;   // 6 units — large section padding
  static const double xxxl = 32;  // 8 units — hero padding
  static const double hero = 48;  // 12 units — screen-level padding

  // ─── Semantic Spacing ───────────────────────────────────────────────────
  static const double inlineXs = 4;     // Between icon and label
  static const double inlineSm = 8;     // Between related items
  static const double inlineMd = 12;    // Between adjacent sections
  static const double inlineLg = 16;    // Between distinct sections

  static const double stackXs = 4;      // Tight vertical stack
  static const double stackSm = 8;      // Small vertical gap
  static const double stackMd = 12;     // Medium vertical gap
  static const double stackLg = 16;     // Large vertical gap
  static const double stackXl = 24;     // Section divider gap

  // ─── Component-specific spacing ─────────────────────────────────────────
  static const double buttonHorizontal = 24;  // Button left/right padding
  static const double buttonVertical = 14;    // Button top/bottom padding
  static const double buttonIconGap = 8;      // Between icon and label

  static const double inputHorizontal = 16;   // Input left/right padding
  static const double inputVertical = 12;     // Input top/bottom padding

  static const double cardPadding = 16;       // Card internal padding
  static const double cardGap = 8;            // Between cards in a list

  static const double listItemHorizontal = 16; // ListTile left/right
  static const double listItemVertical = 4;    // ListTile top/bottom

  static const double screenHorizontal = 16;   // Screen edge padding
  static const double screenTop = 16;          // Screen top padding
  static const double screenBottom = 32;       // Screen bottom safe area

  static const double appBarContent = 16;      // AppBar content padding
  static const double tabBarIndicator = 2;     // Tab indicator height

  static const double fabSpacing = 16;         // FAB from edge
  static const double chipHorizontal = 12;     // Chip left/right padding
  static const double chipVertical = 4;        // Chip top/bottom padding

  static const double avatarRadius = 28;       // Default avatar radius
  static const double avatarRadiusSm = 20;     // Small avatar radius
  static const double avatarRadiusLg = 36;     // Large avatar radius

  static const double iconSizeSm = 16;         // Small icon
  static const double iconSizeMd = 20;         // Medium icon
  static const double iconSizeLg = 24;         // Standard icon
  static const double iconSizeXl = 32;         // Large icon
  static const double iconSizeHero = 48;       // Hero/empty state icon
}
