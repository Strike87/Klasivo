import 'package:flutter/material.dart';

class RtlSupport {
  RtlSupport._();

  /// Check if a language code is RTL
  static bool isRtlLanguage(String languageCode) {
    const rtlLanguages = {'ar', 'he', 'fa', 'ur', 'ku'};
    return rtlLanguages.contains(languageCode);
  }

  /// Get text direction for a language
  static TextDirection textDirection(String languageCode) {
    return isRtlLanguage(languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Wrap a widget with RTL-aware directionality
  static Widget withDirectionality({
    required String languageCode,
    required Widget child,
  }) {
    return Directionality(
      textDirection: textDirection(languageCode),
      child: child,
    );
  }

  /// Reverse padding for RTL layouts
  static EdgeInsetsDirectional directionalPadding({
    double start = 0,
    double top = 0,
    double end = 0,
    double bottom = 0,
  }) {
    return EdgeInsetsDirectional.only(
      start: start,
      top: top,
      end: end,
      bottom: bottom,
    );
  }

  /// Reverse alignment for RTL
  static AlignmentDirectional flipAlignment(AlignmentDirectional alignment) {
    return AlignmentDirectional(-alignment.start, alignment.y);
  }

  /// Get proper icon for back navigation (flips in RTL)
  static IconData backIcon(TextDirection direction) {
    return direction == TextDirection.rtl
        ? Icons.arrow_forward
        : Icons.arrow_back;
  }
}

/// Extension on BuildContext for easy RTL access
extension RtlContext on BuildContext {
  bool get isRtl => Directionality.of(this) == TextDirection.rtl;
  TextDirection get textDirection => Directionality.of(this);
}
