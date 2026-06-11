import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO BUTTON — Unified button component with variants, sizes, and states
// Replaces scattered ElevatedButton/OutlinedButton/TextButton usage.
// ═══════════════════════════════════════════════════════════════════════════════

enum KlasivoButtonVariant {
  primary,    // Filled indigo — primary actions (Save, Create, Submit)
  secondary,  // Outlined — secondary actions (Cancel, Back)
  tertiary,   // Text only — minimal actions (Skip, Dismiss)
  danger,     // Filled red — destructive actions (Delete, Remove)
  ghost,      // Transparent — inline actions (Edit, View)
}

enum KlasivoButtonSize {
  sm,   // Compact — inline, tables, toolbars
  md,   // Standard — forms, dialogs
  lg,   // Prominent — onboarding, hero CTAs
}

class KlasivoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final KlasivoButtonVariant variant;
  final KlasivoButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final String? tooltip;

  const KlasivoButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.variant = KlasivoButtonVariant.primary,
    this.size = KlasivoButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null || loading;

    // Size configurations
    final (hPad, vPad, fontSize, iconSize, radius) = switch (size) {
      KlasivoButtonSize.sm => (12.0, 8.0, 12.0, 14.0, AppRadius.sm),
      KlasivoButtonSize.md => (AppSpacing.buttonHorizontal, AppSpacing.buttonVertical - 2, 14.0, 18.0, AppRadius.button),
      KlasivoButtonSize.lg => (32.0, 16.0, 16.0, 20.0, AppRadius.button),
    };

    // Variant configurations
    final (bg, fg, border, overlayColor) = _variantStyles(theme, isDisabled);

    final button = ConstrainedBox(
      constraints: fullWidth
          ? const BoxConstraints(minWidth: double.infinity)
          : const BoxConstraints(minWidth: 80),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(radius),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered)) return overlayColor.withOpacity(0.5);
            return null;
          }),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: border != null
                  ? Border.all(color: border, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.inlineSm),
                    child: Icon(icon, size: iconSize, color: fg),
                  ),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: fg,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }

  (Color?, Color, Color?, Color) _variantStyles(ThemeData theme, bool isDisabled) {
    final isDark = theme.brightness == Brightness.dark;

    if (isDisabled) {
      return (
        isDark ? AppColors.darkBorder : AppColors.lightBorder,
        isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
        null,
        Colors.transparent,
      );
    }

    return switch (variant) {
      KlasivoButtonVariant.primary => (
        AppColors.primary,
        Colors.white,
        null,
        AppColors.primaryDark.withOpacity(0.2),
      ),
      KlasivoButtonVariant.secondary => (
        Colors.transparent,
        AppColors.primary,
        AppColors.primary,
        AppColors.primarySurface,
      ),
      KlasivoButtonVariant.tertiary => (
        Colors.transparent,
        AppColors.primary,
        null,
        AppColors.primarySurface,
      ),
      KlasivoButtonVariant.danger => (
        AppColors.error,
        Colors.white,
        null,
        AppColors.errorDark.withOpacity(0.2),
      ),
      KlasivoButtonVariant.ghost => (
        Colors.transparent,
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        null,
        isDark ? AppColors.darkBorder.withOpacity(0.5) : AppColors.lightBorder,
      ),
    };
  }
}
