import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO TOAST — Notification toast/snackbar system
// Semantic toasts for success, error, warning, and info messages.
// ═══════════════════════════════════════════════════════════════════════════════

enum KlasivoToastType {
  success,
  error,
  warning,
  info,
}

class KlasivoToast {
  KlasivoToast._();

  static void show(
    BuildContext context, {
    required String message,
    KlasivoToastType type = KlasivoToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final (icon, color, bgColor) = _toastStyles(type);

    // ── Compute safe margin for floating SnackBar ──────────────────────
    // Floating SnackBars can render off-screen or behind bottom navigation
    // bars. Add a bottom margin that lifts the SnackBar above any
    // BottomNavigationBar / NavigationBar / FAB that the Scaffold might
    // have. Use MediaQuery viewInsets to also avoid the keyboard.
    final mediaQuery = MediaQuery.of(context);
    final viewInsetsBottom = mediaQuery.viewInsets.bottom;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        // ── Safe margin: lift above keyboard + bottom nav ──
        // The default floating margin (28px) can be pushed off-screen by
        // the bottom navigation bar. Use a larger margin when the keyboard
        // is open, and always ensure at least 80px from the bottom edge
        // to clear typical BottomNavigationBar heights (~56-80px).
        margin: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          viewInsetsBottom > 0 ? viewInsetsBottom + 16 : 80,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.snackbar),
        ),
        backgroundColor: bgColor,
        content: Row(
          children: [
            Icon(icon, color: color, size: AppSpacing.iconSizeMd),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: color,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, {required String message}) =>
      show(context, message: message, type: KlasivoToastType.success);

  static void error(BuildContext context, {required String message}) =>
      show(context, message: message, type: KlasivoToastType.error);

  static void warning(BuildContext context, {required String message}) =>
      show(context, message: message, type: KlasivoToastType.warning);

  static void info(BuildContext context, {required String message}) =>
      show(context, message: message, type: KlasivoToastType.info);

  static (IconData, Color, Color) _toastStyles(KlasivoToastType type) {
    return switch (type) {
      KlasivoToastType.success => (
        Icons.check_circle_outline,
        AppColors.success,
        AppColors.successSurface,
      ),
      KlasivoToastType.error => (
        Icons.error_outline_rounded,
        AppColors.error,
        AppColors.errorSurface,
      ),
      KlasivoToastType.warning => (
        Icons.warning_amber_rounded,
        AppColors.accent,
        AppColors.warningSurface,
      ),
      KlasivoToastType.info => (
        Icons.info_outline_rounded,
        AppColors.info,
        AppColors.infoSurface,
      ),
    };
  }
}
