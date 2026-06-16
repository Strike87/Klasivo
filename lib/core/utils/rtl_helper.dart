import 'dart:ui';

import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO RTL HELPER
// Utility functions for Right-to-Left (RTL) language support.
//
// Provides:
//   - RTL locale detection
//   - Text direction helpers
//   - EdgeInsets / BorderRadius flipping for RTL layouts
//   - Alignment helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// RTL locale codes supported by the app.
const Set<String> _rtlLanguageCodes = {'ar', 'he', 'fa', 'ur'};

/// Returns `true` if the given [locale] uses an RTL script.
bool isRtlLocale(Locale locale) {
  return _rtlLanguageCodes.contains(locale.languageCode);
}

/// Returns `true` if the given language code uses an RTL script.
bool isRtlLanguageCode(String languageCode) {
  return _rtlLanguageCodes.contains(languageCode);
}

/// Returns the [TextDirection] appropriate for the given [locale].
TextDirection textDirectionForLocale(Locale locale) {
  return isRtlLocale(locale) ? TextDirection.rtl : TextDirection.ltr;
}

/// Attempts to resolve the text direction from the nearest [Directionality]
/// ancestor in the widget tree. Falls back to [TextDirection.ltr].
TextDirection resolveTextDirection(BuildContext context) {
  return Directionality.maybeOf(context) ?? TextDirection.ltr;
}

/// Returns `true` if the current [Directionality] is RTL.
bool isContextRtl(BuildContext context) {
  return resolveTextDirection(context) == TextDirection.rtl;
}

// ─── EdgeInsets Helpers ─────────────────────────────────────────────────────

/// Flips [EdgeInsets] horizontally for RTL layouts.
///
/// In LTR: `EdgeInsets.only(left: 16)` → padding on the start side
/// In RTL: should become `EdgeInsets.only(right: 16)` → padding on the start side
///
/// Usage:
/// ```dart
/// padding: RtlHelper.flipEdgeInsets(
///   context,
///   EdgeInsets.only(left: 16, right: 8),
/// ),
/// ```
EdgeInsets flipEdgeInsets(BuildContext context, EdgeInsets padding) {
  if (!isContextRtl(context)) return padding;
  return EdgeInsets.only(
    left: padding.right,
    right: padding.left,
    top: padding.top,
    bottom: padding.bottom,
  );
}

/// Returns start-aware [EdgeInsets].
/// `start` maps to `left` in LTR and `right` in RTL.
/// `end` maps to `right` in LTR and `left` in RTL.
EdgeInsets edgeInsetsWithStart({
  required BuildContext context,
  double start = 0.0,
  double end = 0.0,
  double top = 0.0,
  double bottom = 0.0,
}) {
  final rtl = isContextRtl(context);
  return EdgeInsets.only(
    left: rtl ? end : start,
    right: rtl ? start : end,
    top: top,
    bottom: bottom,
  );
}

// ─── BorderRadius Helpers ───────────────────────────────────────────────────

/// Flips [BorderRadius] horizontally for RTL layouts.
///
/// In LTR: `BorderRadius.only(topLeft: Radius.circular(12))`
/// In RTL: should become `BorderRadius.only(topRight: Radius.circular(12))`
BorderRadius flipBorderRadius(BorderRadius radius) {
  return BorderRadius.only(
    topLeft: radius.topRight,
    topRight: radius.topLeft,
    bottomLeft: radius.bottomRight,
    bottomRight: radius.bottomLeft,
  );
}

/// Returns a direction-aware [BorderRadius] where `startStart` is the
/// top-start corner and `startEnd` is the top-end corner.
BorderRadius borderRadiusWithStart({
  required BuildContext context,
  double startStart = 0.0,
  double startEnd = 0.0,
  double endStart = 0.0,
  double endEnd = 0.0,
}) {
  final rtl = isContextRtl(context);
  return BorderRadius.only(
    topLeft: Radius.circular(rtl ? startEnd : startStart),
    topRight: Radius.circular(rtl ? startStart : startEnd),
    bottomLeft: Radius.circular(rtl ? endEnd : endStart),
    bottomRight: Radius.circular(rtl ? endStart : endEnd),
  );
}

// ─── Alignment Helpers ──────────────────────────────────────────────────────

/// Returns the start [Alignment] (left in LTR, right in RTL).
Alignment alignmentStart(BuildContext context) {
  return isContextRtl(context) ? Alignment.centerRight : Alignment.centerLeft;
}

/// Returns the end [Alignment] (right in LTR, left in RTL).
Alignment alignmentEnd(BuildContext context) {
  return isContextRtl(context) ? Alignment.centerLeft : Alignment.centerRight;
}

// ─── Icon Helpers ───────────────────────────────────────────────────────────

/// Returns a flipped [Icon] for directional icons (e.g. arrows, chevrons)
/// in RTL mode. Non-directional icons are returned as-is.
///
/// Usage:
/// ```dart
/// RtlHelper.maybeFlipIcon(context, Icons.arrow_back)
/// // In RTL: shows Icons.arrow_back with transform flip
/// ```
Widget maybeFlipIcon(BuildContext context, IconData icon, {double? size, Color? color}) {
  if (!isContextRtl(context)) {
    return Icon(icon, size: size, color: color);
  }
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.rotationY(3.1415926535897932), // pi, flips horizontally
    child: Icon(icon, size: size, color: color),
  );
}

// ─── Widget Wrappers ────────────────────────────────────────────────────────

/// Wraps a [child] widget with a [Directionality] widget matching [locale].
/// Useful for ensuring a specific text direction independent of the app-wide
/// directionality.
Widget withDirectionality({
  required Locale locale,
  required Widget child,
}) {
  return Directionality(
    textDirection: textDirectionForLocale(locale),
    child: child,
  );
}
