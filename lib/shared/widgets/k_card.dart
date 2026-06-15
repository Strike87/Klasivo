import 'package:flutter/material.dart';
import '../../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO CARD — Design-system card using AppColors, AppSpacing,
// AppRadius, AppElevation tokens.
// ═══════════════════════════════════════════════════════════════════════════════

enum KCardVariant { elevated, outlined, filled, flat }

class KCard extends StatelessWidget {
  final Widget child;
  final KCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? borderRadius;
  final String? semanticLabel;

  const KCard({
    super.key,
    required this.child,
    this.variant = KCardVariant.outlined,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = borderRadius ?? AppRadius.card;

    // ─── Background color ────────────────────────────────────────────
    final Color backgroundColor;
    switch (variant) {
      case KCardVariant.elevated:
        backgroundColor = color ??
            AppColors.card(brightness);
      case KCardVariant.outlined:
        backgroundColor = color ??
            AppColors.card(brightness);
      case KCardVariant.filled:
        backgroundColor = color ??
            AppColors.resolve(
              brightness: brightness,
              light: AppColors.lightBackground,
              dark: AppColors.darkSurface,
            );
      case KCardVariant.flat:
        backgroundColor = color ??
            AppColors.card(brightness);
    }

    // ─── Border ──────────────────────────────────────────────────────
    final BoxBorder? border;
    switch (variant) {
      case KCardVariant.outlined:
        border = Border.all(
          color: AppColors.border(brightness),
          width: 1,
        );
      default:
        border = null;
    }

    // ─── Elevation ───────────────────────────────────────────────────
    final double elevation;
    switch (variant) {
      case KCardVariant.elevated:
        elevation = AppElevation.sm;
      default:
        elevation = AppElevation.none;
    }

    // ─── Shape ───────────────────────────────────────────────────────
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    // ─── Content padding ─────────────────────────────────────────────
    final effectivePadding = padding ??
        const EdgeInsets.all(AppSpacing.cardPadding);

    // ─── Margin ──────────────────────────────────────────────────────
    final effectiveMargin = margin ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Card(
        margin: effectiveMargin,
        elevation: elevation,
        color: backgroundColor,
        shape: shape,
        borderOnForeground: true,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: effectivePadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Convenience builder for section cards with a title.
class KSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final KCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Widget? trailing;
  final VoidCallback? onTap;

  const KSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.variant = KCardVariant.outlined,
    this.padding,
    this.margin,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return KCard(
      variant: variant,
      padding: padding ?? EdgeInsets.zero,
      margin: margin,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              0,
              AppSpacing.cardPadding,
              AppSpacing.cardPadding,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
