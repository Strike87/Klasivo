/// Klasivo v2.0 - KToast component
/// 
/// Enhanced toast notification component based on klasivo_toast.dart.
/// Supports success, error, warning, and info variants
/// with RTL-aware positioning.
library;

import "package:flutter/material.dart";

/// Klasivo toast notification component.
class KToast {
  /// Show a success toast.
  static void success(BuildContext context, {required String message}) {
    _show(context, message: message, variant: KToastVariant.success);
  }

  /// Show an error toast.
  static void error(BuildContext context, {required String message}) {
    _show(context, message: message, variant: KToastVariant.error);
  }

  /// Show a warning toast.
  static void warning(BuildContext context, {required String message}) {
    _show(context, message: message, variant: KToastVariant.warning);
  }

  /// Show an info toast.
  static void info(BuildContext context, {required String message}) {
    _show(context, message: message, variant: KToastVariant.info);
  }

  static void _show(
    BuildContext context, {
    required String message,
    KToastVariant variant = KToastVariant.info,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_variantIcon(variant), color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _variantColor(variant),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static IconData _variantIcon(KToastVariant v) => switch (v) {
        KToastVariant.success => Icons.check_circle,
        KToastVariant.error => Icons.error,
        KToastVariant.warning => Icons.warning,
        KToastVariant.info => Icons.info,
      };

  static Color _variantColor(KToastVariant v) => switch (v) {
        KToastVariant.success => Colors.green,
        KToastVariant.error => Colors.red,
        KToastVariant.warning => Colors.orange,
        KToastVariant.info => Colors.blue,
      };
}

enum KToastVariant { success, error, warning, info }
