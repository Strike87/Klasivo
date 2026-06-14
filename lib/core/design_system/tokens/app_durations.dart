// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO DURATION TOKENS — Semantic animation and display durations
// Used alongside AppAnimation for higher-level duration semantics.
// ═══════════════════════════════════════════════════════════════════════════════

/// Semantic duration tokens for animations, toasts, snackbars, and transitions.
///
/// Use these tokens for any time-based UI behavior. Lower-level animation
/// durations are defined in [AppAnimation]; these tokens cover display-level
/// durations such as toast visibility, auto-dismiss timers, and feedback
/// intervals.
class AppDurations {
  AppDurations._();

  // ─── Animation Durations ────────────────────────────────────────────────

  /// Instant feedback — hover states, micro-interactions.
  static const Duration instant = Duration(milliseconds: 100);

  /// Fast transitions — toggle, chip selection.
  static const Duration fast = Duration(milliseconds: 200);

  /// Normal transitions — standard enter/exit, content swap.
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow transitions — page transitions, hero animations.
  static const Duration slow = Duration(milliseconds: 500);

  /// Very slow transitions — onboarding, elaborate reveals.
  static const Duration verySlow = Duration(milliseconds: 800);

  // ─── Toast & Snackbar Durations ─────────────────────────────────────────

  /// Short toast display duration.
  static const Duration toastShort = Duration(seconds: 2);

  /// Long toast display duration.
  static const Duration toastLong = Duration(seconds: 4);

  /// Standard snackbar display duration.
  static const Duration snackbar = Duration(seconds: 3);

  // ─── Debounce Durations ─────────────────────────────────────────────────

  /// Standard search debounce duration.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Short input debounce for immediate feedback.
  static const Duration inputDebounce = Duration(milliseconds: 150);

  // ─── Feedback Durations ─────────────────────────────────────────────────

  /// Duration for haptic/visual feedback pulses.
  static const Duration feedbackPulse = Duration(milliseconds: 50);

  /// Duration before showing a loading indicator.
  static const Duration loadingDelay = Duration(milliseconds: 500);
}
