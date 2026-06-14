import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import '../../localization/rtl_support.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K BUTTON — Comprehensive button component for the Klasivo Design System
//
// Supports variants: elevated, outlined, text, icon, loading
// Supports sizes: sm, md, lg
// RTL-aware icon placement and padding
// Loading state with spinner
// Disabled state
// All spacing, colors, radii use design tokens — never hardcoded.
// ═══════════════════════════════════════════════════════════════════════════════

/// Button visual variant within the Klasivo Design System.
enum KButtonVariant {
  /// Filled primary button — principal CTA (Save, Create, Submit).
  elevated,

  /// Outlined button — secondary actions (Cancel, Back).
  outlined,

  /// Text-only button — minimal actions (Skip, Dismiss).
  text,

  /// Icon-only circular button — toolbar actions, FAB alternatives.
  icon,

  /// Loading state button — shows a spinner, disables interaction.
  loading,
}

/// Button size within the Klasivo Design System.
enum KButtonSize {
  /// Compact — inline, tables, toolbars.
  sm,

  /// Standard — forms, dialogs (default).
  md,

  /// Prominent — onboarding, hero CTAs.
  lg,
}

/// A comprehensive button component that supports multiple variants, sizes,
/// loading/disabled states, and RTL-aware layout.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography], and
/// [AppAnimation] tokens exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KButton(
///   label: 'Save',
///   variant: KButtonVariant.elevated,
///   size: KButtonSize.md,
///   icon: Icons.check,
///   onPressed: () => handleSave(),
/// )
/// ```
class KButton extends StatelessWidget {
  /// The text label displayed on the button. Ignored for [KButtonVariant.icon].
  final String? label;

  /// Callback when the button is pressed. If null, the button is disabled.
  final VoidCallback? onPressed;

  /// The visual variant of the button.
  final KButtonVariant variant;

  /// The size of the button.
  final KButtonSize size;

  /// Optional icon displayed before the label (or as the sole content for
  /// [KButtonVariant.icon]).
  final IconData? icon;

  /// When true, shows a loading spinner and disables interaction.
  final bool loading;

  /// When true, the button stretches to fill available width.
  final bool fullWidth;

  /// Optional tooltip message shown on long-press/hover.
  final String? tooltip;

  /// Optional semantic label for accessibility.
  final String? semanticLabel;

  /// Optional custom background color (overrides variant default).
  final Color? backgroundColor;

  /// Optional custom foreground color (overrides variant default).
  final Color? foregroundColor;

  const KButton({
    super.key,
    this.label,
    this.onPressed,
    this.variant = KButtonVariant.elevated,
    this.size = KButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.tooltip,
    this.semanticLabel,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDisabled = onPressed == null || loading;
    final effectiveVariant = loading ? KButtonVariant.loading : variant;

    // Size configuration — all values from tokens
    final (hPad, vPad, fontSize, iconSize, radius, minSize) =
        _sizeConfig(size, effectiveVariant);

    // Variant configuration — all colors from tokens
    final (bg, fg, borderColor, overlayColor) = _variantStyles(
      isDark: isDark,
      isDisabled: isDisabled,
      variant: effectiveVariant,
    );

    final effectiveBg = backgroundColor ?? bg;
    final effectiveFg = foregroundColor ?? fg;

    Widget buttonChild;

    if (effectiveVariant == KButtonVariant.icon) {
      buttonChild = _buildIconButton(
        context: context,
        isDisabled: isDisabled,
        effectiveBg: effectiveBg,
        effectiveFg: effectiveFg,
        borderColor: borderColor,
        overlayColor: overlayColor,
        iconSize: iconSize,
        radius: radius,
        minSize: minSize,
      );
    } else {
      buttonChild = _buildContentButton(
        context: context,
        isDisabled: isDisabled,
        effectiveBg: effectiveBg,
        effectiveFg: effectiveFg,
        borderColor: borderColor,
        overlayColor: overlayColor,
        hPad: hPad,
        vPad: vPad,
        fontSize: fontSize,
        iconSize: iconSize,
        radius: radius,
      );
    }

    // Wrap with tooltip if provided
    if (tooltip != null) {
      buttonChild = Tooltip(message: tooltip!, child: buttonChild);
    }

    // Wrap with semantics if provided
    if (semanticLabel != null) {
      buttonChild = Semantics(
        label: semanticLabel,
        button: true,
        enabled: !isDisabled,
        child: buttonChild,
      );
    }

    return buttonChild;
  }

  /// Builds a standard content button (elevated, outlined, text, loading).
  Widget _buildContentButton({
    required BuildContext context,
    required bool isDisabled,
    required Color effectiveBg,
    required Color effectiveFg,
    required Color? borderColor,
    required Color overlayColor,
    required double hPad,
    required double vPad,
    required double fontSize,
    required double iconSize,
    required double radius,
  }) {
    return ConstrainedBox(
      constraints: fullWidth
          ? const BoxConstraints(minWidth: double.infinity)
          : BoxConstraints(minWidth: AppSpacing.xxl * 2),
      child: Material(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(radius),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered)) {
              return overlayColor.withOpacity(0.5);
            }
            return null;
          }),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: borderColor != null
                  ? Border.all(
                      color: borderColor,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: label != null ? AppSpacing.buttonIconGap : 0,
                    ),
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(effectiveFg),
                      ),
                    ),
                  )
                else if (icon != null)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: label != null ? AppSpacing.buttonIconGap : 0,
                    ),
                    child: Icon(icon, size: iconSize, color: effectiveFg),
                  ),
                if (label != null)
                  Text(
                    label!,
                    style: AppTypography.labelMedium.copyWith(
                      color: effectiveFg,
                      fontSize: fontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an icon-only circular button.
  Widget _buildIconButton({
    required BuildContext context,
    required bool isDisabled,
    required Color effectiveBg,
    required Color effectiveFg,
    required Color? borderColor,
    required Color overlayColor,
    required double iconSize,
    required double radius,
    required double minSize,
  }) {
    return SizedBox(
      width: minSize,
      height: minSize,
      child: Material(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(radius),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered)) {
              return overlayColor.withOpacity(0.5);
            }
            return null;
          }),
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: borderColor != null
                  ? Border.all(color: borderColor, width: 1.5)
                  : null,
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(effectiveFg),
                      ),
                    ),
                  )
                : Icon(icon, size: iconSize, color: effectiveFg),
          ),
        ),
      ),
    );
  }

  /// Returns size configuration based on [KButtonSize] and [KButtonVariant].
  ///
  /// All values derive from [AppSpacing] and [AppRadius] tokens.
  (double, double, double, double, double, double) _sizeConfig(
    KButtonSize btnSize,
    KButtonVariant btnVariant,
  ) {
    if (btnVariant == KButtonVariant.icon) {
      return switch (btnSize) {
        KButtonSize.sm => (
            0,
            0,
            0,
            AppSpacing.iconSizeSm,
            AppRadius.iconButton,
            AppSpacing.xxl + AppSpacing.sm
          ),
        KButtonSize.md => (
            0,
            0,
            0,
            AppSpacing.iconSizeMd,
            AppRadius.iconButton,
            AppSpacing.xxxl + AppSpacing.sm
          ),
        KButtonSize.lg => (
            0,
            0,
            0,
            AppSpacing.iconSizeLg,
            AppRadius.iconButton,
            AppSpacing.xxxl + AppSpacing.lg
          ),
      };
    }

    return switch (btnSize) {
      KButtonSize.sm => (
          AppSpacing.md,
          AppSpacing.sm,
          AppTypography.labelSmall.fontSize!,
          AppSpacing.iconSizeSm,
          AppRadius.sm,
          0.0
        ),
      KButtonSize.md => (
          AppSpacing.buttonHorizontal,
          AppSpacing.buttonVertical - AppSpacing.xs,
          AppTypography.labelMedium.fontSize!,
          AppSpacing.iconSizeMd,
          AppRadius.button,
          0.0
        ),
      KButtonSize.lg => (
          AppSpacing.buttonHorizontal + AppSpacing.sm,
          AppSpacing.buttonVertical,
          AppTypography.labelLarge.fontSize!,
          AppSpacing.iconSizeLg,
          AppRadius.button,
          0.0
        ),
    };
  }

  /// Returns variant-specific colors: (background, foreground, border, overlay).
  ///
  /// All colors from [AppColors] tokens. Respects dark mode and disabled state.
  (Color, Color, Color?, Color) _variantStyles({
    required bool isDark,
    required bool isDisabled,
    required KButtonVariant variant,
  }) {
    if (isDisabled) {
      return (
        isDark ? AppColors.darkBorder : AppColors.lightBorder,
        isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled,
        null,
        Colors.transparent,
      );
    }

    return switch (variant) {
      KButtonVariant.elevated => (
          AppColors.primary,
          Colors.white,
          null,
          AppColors.primaryDark.withOpacity(0.2),
        ),
      KButtonVariant.outlined => (
          Colors.transparent,
          AppColors.primary,
          AppColors.primary,
          AppColors.primarySurface,
        ),
      KButtonVariant.text => (
          Colors.transparent,
          AppColors.primary,
          null,
          AppColors.primarySurface,
        ),
      KButtonVariant.icon => (
          Colors.transparent,
          isDark ? AppColors.darkIconDefault : AppColors.lightIconDefault,
          null,
          isDark
              ? AppColors.darkBorder.withOpacity(0.5)
              : AppColors.lightBorder,
        ),
      KButtonVariant.loading => (
          AppColors.primary.withOpacity(0.7),
          Colors.white,
          null,
          Colors.transparent,
        ),
    };
  }
}
