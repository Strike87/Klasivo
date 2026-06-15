import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'k_button.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K EMPTY STATE — Empty state widget for the Klasivo Design System
//
// Features:
// - Illustration/icon
// - Title + description
// - Optional action button
// - Variants: noData, noResults, error, offline
// ═══════════════════════════════════════════════════════════════════════════════

/// Empty state variant within the Klasivo Design System.
enum KEmptyStateVariant {
  /// No data available — shown when a collection is empty.
  noData,

  /// No search results — shown after an empty search.
  noResults,

  /// Error state — shown when content failed to load.
  error,

  /// Offline state — shown when there is no network connection.
  offline,
}

/// A polished empty state widget with illustration, title, description,
/// and optional action button.
///
/// Uses [AppColors], [AppSpacing], [AppTypography] tokens exclusively — no
/// hardcoded values.
///
/// Example:
/// ```dart
/// KEmptyState(
///   variant: KEmptyStateVariant.noResults,
///   title: 'No students found',
///   description: 'Try adjusting your search terms.',
///   actionLabel: 'Clear Search',
///   onAction: () => clearSearch(),
/// )
/// ```
class KEmptyState extends StatelessWidget {
  /// The variant determines the default icon and color scheme.
  final KEmptyStateVariant variant;

  /// The primary message displayed below the icon.
  final String title;

  /// A secondary description providing context or guidance.
  final String? description;

  /// Optional action button label.
  final String? actionLabel;

  /// Optional action button callback.
  final VoidCallback? onAction;

  /// Custom icon (overrides variant default).
  final IconData? icon;

  /// Custom icon color (overrides variant default).
  final Color? iconColor;

  const KEmptyState({
    super.key,
    this.variant = KEmptyStateVariant.noData,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveIcon = icon ?? _defaultIcon;
    final effectiveColor = iconColor ?? _defaultColor;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxxl,
          vertical: AppSpacing.hero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration circle
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: effectiveColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                effectiveIcon,
                size: AppSpacing.iconSizeHero,
                color: effectiveColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Title
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            // Description
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              KButton(
                label: actionLabel!,
                variant: KButtonVariant.elevated,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Returns the default icon for the current variant.
  IconData get _defaultIcon => switch (variant) {
        KEmptyStateVariant.noData => Icons.inbox_outlined,
        KEmptyStateVariant.noResults => Icons.search_off_rounded,
        KEmptyStateVariant.error => Icons.error_outline_rounded,
        KEmptyStateVariant.offline => Icons.cloud_off_rounded,
      };

  /// Returns the default color for the current variant.
  Color get _defaultColor => switch (variant) {
        KEmptyStateVariant.noData => AppColors.primary,
        KEmptyStateVariant.noResults => AppColors.primary,
        KEmptyStateVariant.error => AppColors.error,
        KEmptyStateVariant.offline => AppColors.warning,
      };
}
