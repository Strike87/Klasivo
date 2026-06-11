import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO CARD — Unified card component with variants
// Supports outlined (default), elevated, filled, and interactive variants.
// ═══════════════════════════════════════════════════════════════════════════════

enum KlasivoCardVariant {
  outlined,    // Default — 1px border, no elevation (Klasivo standard)
  elevated,    // Shadow-based lift — for modals, floating panels
  filled,      // Background fill — for grouped content, sidebars
  interactive, // Outlined + hover/press states — for clickable cards
}

class KlasivoCard extends StatelessWidget {
  final Widget child;
  final KlasivoCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;       // Left border accent (like SubjectCard)
  final VoidCallback? onTap;
  final String? semanticLabel;

  const KlasivoCard({
    Key? key,
    required this.child,
    this.variant = KlasivoCardVariant.outlined,
    this.padding,
    this.margin,
    this.accentColor,
    this.onTap,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (bgColor, borderColor, elevation) = switch (variant) {
      KlasivoCardVariant.outlined => (
        isDark ? AppColors.darkCard : AppColors.lightCard,
        isDark ? AppColors.darkBorder : AppColors.lightBorder,
        AppElevation.none,
      ),
      KlasivoCardVariant.elevated => (
        isDark ? AppColors.darkCard : AppColors.lightCard,
        Colors.transparent,
        AppElevation.md,
      ),
      KlasivoCardVariant.filled => (
        isDark ? AppColors.darkSurface : AppColors.lightBackground,
        Colors.transparent,
        AppElevation.none,
      ),
      KlasivoCardVariant.interactive => (
        isDark ? AppColors.darkCard : AppColors.lightCard,
        isDark ? AppColors.darkBorder : AppColors.lightBorder,
        AppElevation.none,
      ),
    };

    Widget cardWidget = Container(
      margin: margin ?? const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: accentColor != null
            ? Border(left: BorderSide(color: accentColor!, width: 4))
            : (borderColor != Colors.transparent
                ? Border.all(color: borderColor, width: 1)
                : null),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: variant == KlasivoCardVariant.interactive && onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
                child: child,
              ),
      ),
    );

    if (semanticLabel != null) {
      cardWidget = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}
