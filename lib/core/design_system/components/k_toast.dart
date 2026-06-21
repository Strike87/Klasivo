import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import '../../localization/rtl_support.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K TOAST — Toast/snackbar component for the Klasivo Design System
//
// Features:
// - Variants: success, error, warning, info
// - Auto-dismiss with configurable duration
// - Action button
// - RTL-aware layout
// - Stacking behavior
// ═══════════════════════════════════════════════════════════════════════════════

/// Toast semantic variant within the Klasivo Design System.
enum KToastVariant {
  /// Green — success messages.
  success,

  /// Red — error messages.
  error,

  /// Amber — warning messages.
  warning,

  /// Blue/indigo — informational messages.
  info,
}

/// A toast/snackbar system supporting semantic variants, auto-dismiss,
/// action buttons, RTL-aware layout, and stacking behavior.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography], and
/// [AppDurations] tokens exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KToast.show(
///   context,
///   message: 'Student added successfully!',
///   variant: KToastVariant.success,
/// );
///
/// KToast.error(context, message: 'Failed to save.');
/// ```
class KToast {
  KToast._();

  /// Shows a toast with full customization.
  static void show(
    BuildContext context, {
    required String message,
    KToastVariant variant = KToastVariant.info,
    Duration duration = AppDurations.snackbar,
    String? actionLabel,
    VoidCallback? onAction,
    bool clearPrevious = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = context.isRTL;
    final (icon, iconColor, bgColor) = _variantStyles(variant);

    final messenger = ScaffoldMessenger.of(context);
    if (clearPrevious) {
      messenger.clearSnackBars();
    }

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.snackbar),
        ),
        backgroundColor: bgColor,
        content: Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: AppSpacing.iconSizeMd),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: iconColor,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  /// Convenience: shows a success toast.
  static void success(
    BuildContext context, {
    required String message,
    Duration duration = AppDurations.snackbar,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      variant: KToastVariant.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience: shows an error toast.
  static void error(
    BuildContext context, {
    required String message,
    Duration duration = AppDurations.toastLong,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      variant: KToastVariant.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience: shows a warning toast.
  static void warning(
    BuildContext context, {
    required String message,
    Duration duration = AppDurations.snackbar,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      variant: KToastVariant.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Convenience: shows an info toast.
  static void info(
    BuildContext context, {
    required String message,
    Duration duration = AppDurations.snackbar,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      variant: KToastVariant.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Returns (icon, iconColor, backgroundColor) for the given variant.
  static (IconData, Color, Color) _variantStyles(KToastVariant variant) {
    return switch (variant) {
      KToastVariant.success => (
          Icons.check_circle_outline,
          AppColors.success,
          AppColors.successSurface,
        ),
      KToastVariant.error => (
          Icons.error_outline_rounded,
          AppColors.error,
          AppColors.errorSurface,
        ),
      KToastVariant.warning => (
          Icons.warning_amber_rounded,
          AppColors.accent,
          AppColors.warningSurface,
        ),
      KToastVariant.info => (
          Icons.info_outline_rounded,
          AppColors.info,
          AppColors.infoSurface,
        ),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// K TOAST OVERLAY — Custom overlay toast with stacking behavior
//
// For use cases where ScaffoldMessenger is not available or when you need
// stacking behavior. Uses an OverlayEntry approach.
// ═══════════════════════════════════════════════════════════════════════════════

/// A custom toast overlay that supports stacking and is not tied to
/// ScaffoldMessenger.
///
/// Example:
/// ```dart
/// KToastOverlay.show(
///   context,
///   message: 'Saved!',
///   variant: KToastVariant.success,
/// );
/// ```
class KToastOverlay {
  KToastOverlay._();

  static final List<_ToastEntry> _activeToasts = [];

  /// Shows a custom overlay toast with stacking.
  static void show(
    BuildContext context, {
    required String message,
    KToastVariant variant = KToastVariant.info,
    Duration duration = AppDurations.snackbar,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final (icon, iconColor, bgColor) = KToast._variantStyles(variant);

    late _ToastEntry toastEntry;
    late OverlayEntry entry;

    // Construct `entry` first — its builder closure captures `toastEntry`
    // by reference, which is safe because the builder isn't invoked until
    // the overlay renders (after `toastEntry` is assigned below).
    entry = OverlayEntry(
      builder: (context) {
        final index = _activeToasts.indexOf(toastEntry);
        final topOffset = MediaQuery.of(context).padding.top +
            AppSpacing.lg +
            (index * (AppSpacing.xxl + AppSpacing.lg + AppSpacing.xxl));

        return Positioned(
          top: topOffset,
          left: AppSpacing.screenHorizontal,
          right: AppSpacing.screenHorizontal,
          child: _KToastCard(
            message: message,
            icon: icon,
            iconColor: iconColor,
            bgColor: bgColor,
            isDark: isDark,
            isRtl: isRtl,
            actionLabel: actionLabel,
            onAction: onAction != null
                ? () {
                    _activeToasts.remove(toastEntry);
                    entry.remove();
                    onAction();
                  }
                : null,
            onDismiss: () {
              _activeToasts.remove(toastEntry);
              entry.remove();
            },
          ),
        );
      },
    );

    toastEntry = _ToastEntry(
      entry: entry,
      dismiss: () {
        _activeToasts.remove(toastEntry);
        entry.remove();
      },
    );

    _activeToasts.add(toastEntry);
    overlay.insert(entry);

    // Auto-dismiss
    Future.delayed(duration, () {
      if (_activeToasts.contains(toastEntry)) {
        _activeToasts.remove(toastEntry);
        entry.remove();
      }
    });
  }
}

/// Internal toast entry for tracking active overlay toasts.
class _ToastEntry {
  final OverlayEntry entry;
  final VoidCallback dismiss;

  _ToastEntry({required this.entry, required this.dismiss});
}

/// Internal widget for rendering a single toast card in the overlay.
class _KToastCard extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool isDark;
  final bool isRtl;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _KToastCard({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.isDark,
    required this.isRtl,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_KToastCard> createState() => _KToastCardState();
}

class _KToastCardState extends State<_KToastCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimation.normal,
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AppAnimation.decelerate,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimation.decelerate,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          elevation: AppElevation.lg,
          borderRadius: BorderRadius.circular(AppRadius.snackbar),
          color: widget.bgColor,
          child: InkWell(
            onTap: _dismiss,
            borderRadius: BorderRadius.circular(AppRadius.snackbar),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.snackbar),
              ),
              child: Directionality(
                textDirection: widget.isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: AppSpacing.iconSizeMd,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppTypography.bodyMedium.copyWith(
                          color: widget.isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    if (widget.actionLabel != null && widget.onAction != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: widget.onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: widget.iconColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: AppTypography.labelMedium.copyWith(
                            color: widget.iconColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
