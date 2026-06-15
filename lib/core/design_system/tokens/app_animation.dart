import 'package:flutter/animation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ANIMATION TOKENS — Motion design system
// Consistent durations, curves, and animation patterns across the app.
// ═══════════════════════════════════════════════════════════════════════════════

class AppAnimation {
  AppAnimation._();

  // ─── Duration Scale ─────────────────────────────────────────────────────
  static const Duration instant = Duration(milliseconds: 50);   // Hover, press
  static const Duration fast = Duration(milliseconds: 150);     // Toggle, chip
  static const Duration normal = Duration(milliseconds: 250);   // Standard transition
  static const Duration slow = Duration(milliseconds: 400);     // Page transition
  static const Duration deliberate = Duration(milliseconds: 600); // Hero, onboarding

  // ─── Semantic Durations ─────────────────────────────────────────────────
  static const Duration buttonPress = fast;
  static const Duration toggle = fast;
  static const Duration expand = normal;
  static const Duration fade = normal;
  static const Duration slide = normal;
  static const Duration pageTransition = slow;
  static const Duration snackbar = Duration(milliseconds: 300);
  static const Duration bottomSheet = normal;
  static const Duration dialog = normal;
  static const Duration tooltip = fast;
  static const Duration shimmer = Duration(milliseconds: 1500);
  static const Duration skeletonPulse = Duration(milliseconds: 1200);

  // ─── Curves ─────────────────────────────────────────────────────────────
  // Standard Material motion curves
  static const Curve standard = Curves.easeInOut;
  static const Curve decelerate = Curves.decelerate;    // Incoming elements
  static const Curve accelerate = Curves.easeIn;    // Outgoing elements
  static const Curve linear = Curves.linear;            // Progress, loading

  // Custom Klasivo curves
  static const Curve smoothBounce = Curves.easeOutBack;     // Playful entrance
  static const Curve gentleSpring = Curves.easeOutCubic;    // Smooth settle
  static const Curve sharpSnap = Curves.easeInToLinear;     // Quick response

  // ─── Animation Patterns ─────────────────────────────────────────────────

  /// Standard fade-in with downward slide (content entering screen)
  static const Duration enterDuration = normal;
  static const Curve enterCurve = decelerate;

  /// Standard fade-out with upward slide (content leaving screen)
  static const Duration exitDuration = fast;
  static const Curve exitCurve = accelerate;

  /// List item stagger delay (for sequential item animations)
  static const Duration staggerDelay = Duration(milliseconds: 40);

  /// Max items to animate in a stagger (performance guard)
  static const int maxStaggerItems = 10;

  // ─── Motion Design Principles ───────────────────────────────────────────
  // 1. Purposeful — every animation serves a function (feedback, orientation,
  //    focus, or delight). No decorative animation.
  // 2. Quick — most animations complete in 150–250ms. Users should never wait.
  // 3. Natural — curves follow physics. Decelerate for entries, accelerate
  //    for exits. Linear only for progress indicators.
  // 4. Reducible — respects system accessibility settings:
  //    `MediaQuery.disableAnimationsOf(context)` should be checked.
}
