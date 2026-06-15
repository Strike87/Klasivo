import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import '../../localization/rtl_support.dart';
import 'k_button.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K DIALOG — Animated dialog component for the Klasivo Design System
//
// Supports variants: alert, confirm, form, bottomSheet
// Animated transitions
// Consistent button placement (RTL-aware)
// Title + description + actions pattern
// ═══════════════════════════════════════════════════════════════════════════════

/// Dialog variant within the Klasivo Design System.
enum KDialogVariant {
  /// Simple alert with a single dismiss action.
  alert,

  /// Confirmation dialog with confirm + cancel actions.
  confirm,

  /// Form dialog with a scrollable content area.
  form,

  /// Bottom sheet style dialog that slides up.
  bottomSheet,
}

/// A dialog component with animated transitions, consistent button placement,
/// and RTL-aware layout.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography], and
/// [AppAnimation] tokens exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KDialog.show(
///   context: context,
///   variant: KDialogVariant.confirm,
///   title: 'Delete Item?',
///   description: 'This action cannot be undone.',
///   confirmLabel: 'Delete',
///   isDestructive: true,
/// );
/// ```
class KDialog {
  KDialog._();

  /// Shows an alert dialog with a single dismiss action.
  static Future<void> alert({
    required BuildContext context,
    required String title,
    String? description,
    String dismissLabel = 'OK',
    IconData? icon,
  }) {
    return showKDialog(
      context: context,
      variant: KDialogVariant.alert,
      title: title,
      description: description,
      icon: icon,
      actions: [
        KButton(
          label: dismissLabel,
          variant: KButtonVariant.text,
          size: KButtonSize.md,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// Shows a confirmation dialog with confirm + cancel actions.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    String? description,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showKDialog<bool>(
      context: context,
      variant: KDialogVariant.confirm,
      title: title,
      description: description,
      icon: icon,
      actions: [
        KButton(
          label: cancelLabel,
          variant: KButtonVariant.text,
          size: KButtonSize.md,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        KButton(
          label: confirmLabel,
          variant: isDestructive ? KButtonVariant.elevated : KButtonVariant.elevated,
          size: KButtonSize.md,
          backgroundColor: isDestructive ? AppColors.error : null,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  /// Shows a form dialog with a scrollable content area.
  static Future<T?> form<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String? confirmLabel,
    String cancelLabel = 'Cancel',
    VoidCallback? onConfirm,
  }) {
    return showKDialog<T>(
      context: context,
      variant: KDialogVariant.form,
      title: title,
      body: child,
      actions: [
        KButton(
          label: cancelLabel,
          variant: KButtonVariant.text,
          size: KButtonSize.md,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (confirmLabel != null && onConfirm != null)
          KButton(
            label: confirmLabel,
            variant: KButtonVariant.elevated,
            size: KButtonSize.md,
            onPressed: onConfirm,
          ),
      ],
    );
  }

  /// Shows a bottom sheet dialog with slide-up animation.
  static Future<T?> bottomSheet<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return AnimatedContainer(
          duration: AppAnimation.bottomSheet,
          curve: AppAnimation.decelerate,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.bottomSheet),
              ),
            ),
            child: _KDialogContent(
              variant: KDialogVariant.bottomSheet,
              title: title,
              body: child,
              actions: actions,
            ),
          ),
        );
      },
    );
  }

  /// Generic dialog show method with full customization.
  static Future<T?> showKDialog<T>({
    required BuildContext context,
    required KDialogVariant variant,
    required String title,
    String? description,
    Widget? body,
    IconData? icon,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    if (variant == KDialogVariant.bottomSheet) {
      return bottomSheet<T>(
        context: context,
        title: title,
        child: body ?? const SizedBox.shrink(),
        actions: actions,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierDismissible ? 'Dismiss' : '',
      barrierColor: AppColors.scrim,
      transitionDuration: AppAnimation.dialog,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppAnimation.decelerate,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: AppAnimation.decelerate,
              ),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width > 560
                  ? AppSpacing.hero * 10
                  : MediaQuery.of(context).size.width -
                      AppSpacing.screenHorizontal * 2,
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius:
                    BorderRadius.circular(AppRadius.dialog),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                    blurRadius: AppElevation.xl * 4,
                    offset: const Offset(0, AppElevation.lg),
                  ),
                ],
              ),
              child: _KDialogContent(
                variant: variant,
                title: title,
                description: description,
                body: body,
                icon: icon,
                actions: actions,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Private widget that renders the dialog's inner content.
class _KDialogContent extends StatelessWidget {
  final KDialogVariant variant;
  final String title;
  final String? description;
  final Widget? body;
  final IconData? icon;
  final List<Widget>? actions;

  const _KDialogContent({
    required this.variant,
    required this.title,
    this.description,
    this.body,
    this.icon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = context.isRTL;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle for bottom sheet
        if (variant == KDialogVariant.bottomSheet) ...[
          Center(
            child: Container(
              width: AppSpacing.xxl + AppSpacing.lg,
              height: AppSpacing.xs,
              margin: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppSpacing.iconSizeLg,
                  color: variant == KDialogVariant.confirm
                      ? AppColors.primary
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              if (variant == KDialogVariant.bottomSheet)
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: AppSpacing.iconSizeMd,
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),

        // Description
        if (description != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              description!,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],

        // Body content
        if (body != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              0,
            ),
            child: body!,
          ),
        ],

        // Actions
        if (actions != null && actions!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              mainAxisAlignment: variant == KDialogVariant.alert
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.end,
              children: actions!
                  .map((action) => Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: AppSpacing.sm,
                        ),
                        child: action,
                      ))
                  .toList(),
            ),
          ),
        ],

        // Bottom safe area for bottom sheet
        if (variant == KDialogVariant.bottomSheet)
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom +
                AppSpacing.lg,
          ),
      ],
    );
  }
}
