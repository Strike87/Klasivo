import 'package:flutter/material.dart';
import '../../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO BUTTON — Design-system button using AppColors, AppSpacing,
// AppRadius, AppTypography tokens. RTL-aware icon placement.
// ═══════════════════════════════════════════════════════════════════════════════

enum KButtonVariant { elevated, outlined, text, tonal }
enum KButtonSize { small, medium, large }

class KButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = KButtonVariant.elevated,
    this.size = KButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // ─── Size-dependent spacing ──────────────────────────────────────
    final EdgeInsetsGeometry padding;
    final TextStyle textStyle;

    switch (size) {
      case KButtonSize.small:
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );
        textStyle = AppTypography.labelMedium;
        break;
      case KButtonSize.medium:
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonHorizontal,
          vertical: AppSpacing.buttonVertical,
        );
        textStyle = AppTypography.labelLarge;
        break;
      case KButtonSize.large:
        padding = const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        );
        textStyle = AppTypography.labelLarge;
        break;
    }

    // ─── Icon + Label row (RTL-aware) ────────────────────────────────
    Widget child;
    if (isLoading) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: AppSpacing.iconSizeMd,
            height: AppSpacing.iconSizeMd,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foreground(brightness),
            ),
          ),
          const SizedBox(width: AppSpacing.buttonIconGap),
          Text(label, style: textStyle),
        ],
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: isRtl
            ? [
                Text(label, style: textStyle),
                const SizedBox(width: AppSpacing.buttonIconGap),
                Icon(icon, size: _iconSize, color: _foreground(brightness)),
              ]
            : [
                Icon(icon, size: _iconSize, color: _foreground(brightness)),
                const SizedBox(width: AppSpacing.buttonIconGap),
                Text(label, style: textStyle),
              ],
      );
    } else {
      child = Text(label, style: textStyle);
    }

    // ─── Variant styling ─────────────────────────────────────────────
    final Widget button;

    switch (variant) {
      case KButtonVariant.elevated:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: child,
        );
        break;
      case KButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: child,
        );
        break;
      case KButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: child,
        );
        break;
      case KButtonVariant.tonal:
        button = FilledButton.tonal(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: child,
        );
        break;
    }

    // ─── Full width wrapper ──────────────────────────────────────────
    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  // ─── Helpers ────────────────────────────────────────────────────────

  double get _iconSize {
    switch (size) {
      case KButtonSize.small:
        return AppSpacing.iconSizeSm;
      case KButtonSize.medium:
        return AppSpacing.iconSizeMd;
      case KButtonSize.large:
        return AppSpacing.iconSizeLg;
    }
  }

  Color _foreground(Brightness brightness) {
    switch (variant) {
      case KButtonVariant.elevated:
        return Colors.white;
      case KButtonVariant.outlined:
      case KButtonVariant.text:
        return AppColors.resolve(
          brightness: brightness,
          light: AppColors.primary,
          dark: AppColors.primaryLight,
        );
      case KButtonVariant.tonal:
        return AppColors.resolve(
          brightness: brightness,
          light: AppColors.primaryDark,
          dark: AppColors.primaryLight,
        );
    }
  }
}
