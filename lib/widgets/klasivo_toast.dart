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

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
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
