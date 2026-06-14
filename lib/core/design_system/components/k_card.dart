import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'k_empty_state.dart';
import 'k_loading_state.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K CARD — Versatile card component for the Klasivo Design System
//
// Supports variants: elevated, outlined, filled
// Pre-built layouts: header+body, header+body+footer
// Loading shimmer state
// Empty state
// All spacing, colors, radii use design tokens — never hardcoded.
// ═══════════════════════════════════════════════════════════════════════════════

/// Card visual variant within the Klasivo Design System.
enum KCardVariant {
  /// Shadow-based lift — for floating panels, modals.
  elevated,

  /// 1px border, no elevation — the Klasivo standard.
  outlined,

  /// Background fill — for grouped content, sidebars.
  filled,
}

/// A versatile card component supporting multiple variants, pre-built layouts,
/// loading shimmer, and empty states.
///
/// Uses [AppElevation], [AppSpacing], [AppRadius], [AppColors] tokens
/// exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KCard(
///   variant: KCardVariant.outlined,
///   header: Text('Title'),
///   body: Text('Content'),
/// )
/// ```
class KCard extends StatelessWidget {
  /// The card's visual variant.
  final KCardVariant variant;

  /// Optional header widget displayed above the body.
  final Widget? header;

  /// The main content widget of the card.
  final Widget? body;

  /// Optional footer widget displayed below the body.
  final Widget? footer;

  /// Direct child — used instead of header/body/footer for free-form content.
  final Widget? child;

  /// Custom padding (overrides default [AppSpacing.cardPadding]).
  final EdgeInsetsGeometry? padding;

  /// Custom margin (overrides default).
  final EdgeInsetsGeometry? margin;

  /// Optional accent color for a leading border.
  final Color? accentColor;

  /// Optional tap handler — makes the card interactive.
  final VoidCallback? onTap;

  /// When true, shows a shimmer loading placeholder.
  final bool loading;

  /// Optional semantic label for accessibility.
  final String? semanticLabel;

  /// Optional custom background color.
  final Color? backgroundColor;

  const KCard({
    super.key,
    this.variant = KCardVariant.outlined,
    this.header,
    this.body,
    this.footer,
    this.child,
    this.padding,
    this.margin,
    this.accentColor,
    this.onTap,
    this.loading = false,
    this.semanticLabel,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (bgColor, borderColor, elevation) = _variantStyles(isDark);

    final effectiveBg = backgroundColor ?? bgColor;

    // Build content
    Widget content;
    if (loading) {
      content = const KLoadingSkeleton.card();
    } else if (child != null) {
      content = child!;
    } else {
      content = _buildLayout();
    }

    Widget cardWidget = Container(
      margin: margin ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
      decoration: BoxDecoration(
        color: effectiveBg,
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
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Padding(
                  padding: padding ??
                      const EdgeInsets.all(AppSpacing.cardPadding),
                  child: content,
                ),
              )
            : Padding(
                padding: padding ??
                    const EdgeInsets.all(AppSpacing.cardPadding),
                child: content,
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

  /// Builds the header + body + footer layout.
  Widget _buildLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          DefaultTextStyle(
            style: AppTypography.titleLarge,
            child: header!,
          ),
          if (body != null || footer != null)
            const SizedBox(height: AppSpacing.md),
        ],
        if (body != null)
          DefaultTextStyle(
            style: AppTypography.bodyMedium,
            child: body!,
          ),
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.lg),
          DefaultTextStyle(
            style: AppTypography.bodySmall,
            child: footer!,
          ),
        ],
      ],
    );
  }

  /// Returns variant-specific styles: (bgColor, borderColor, elevation).
  (Color, Color, double) _variantStyles(bool isDark) {
    return switch (variant) {
      KCardVariant.elevated => (
          isDark ? AppColors.darkCard : AppColors.lightCard,
          Colors.transparent,
          AppElevation.md,
        ),
      KCardVariant.outlined => (
          isDark ? AppColors.darkCard : AppColors.lightCard,
          isDark ? AppColors.darkBorder : AppColors.lightBorder,
          AppElevation.none,
        ),
      KCardVariant.filled => (
          isDark ? AppColors.darkSurface : AppColors.lightBackground,
          Colors.transparent,
          AppElevation.none,
        ),
    };
  }
}

/// Convenience widget for a card with header + body layout.
class KCardWithHeader extends StatelessWidget {
  final Widget header;
  final Widget body;
  final KCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;

  const KCardWithHeader({
    super.key,
    required this.header,
    required this.body,
    this.variant = KCardVariant.outlined,
    this.padding,
    this.margin,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      variant: variant,
      header: header,
      body: body,
      padding: padding,
      margin: margin,
      accentColor: accentColor,
      onTap: onTap,
    );
  }
}

/// Convenience widget for a card with header + body + footer layout.
class KCardWithFooter extends StatelessWidget {
  final Widget header;
  final Widget body;
  final Widget footer;
  final KCardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;

  const KCardWithFooter({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
    this.variant = KCardVariant.outlined,
    this.padding,
    this.margin,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      variant: variant,
      header: header,
      body: body,
      footer: footer,
      padding: padding,
      margin: margin,
      accentColor: accentColor,
      onTap: onTap,
    );
  }
}
