import 'package:flutter/material.dart';
import '../tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K LOADING STATE — Loading state widgets for the Klasivo Design System
//
// Features:
// - Shimmer effect for content placeholders
// - Spinner variant
// - Skeleton variants: list, card, grid, detail
// - Uses AppColors for shimmer base/highlight
// ═══════════════════════════════════════════════════════════════════════════════

/// Skeleton layout variant for different content types.
enum KSkeletonVariant {
  /// Single card skeleton.
  card,

  /// List item skeleton (avatar + lines).
  list,

  /// Grid of card skeletons.
  grid,

  /// Detail page skeleton (hero area + lines).
  detail,
}

/// A shimmer-based loading placeholder widget.
///
/// Renders an animated shimmer gradient over a container to indicate
/// loading state. Uses [AppColors.skeleton] for the base and a lighter
/// variant for the highlight sweep.
///
/// Example:
/// ```dart
/// KShimmer(
///   width: 200,
///   height: 16,
///   borderRadius: AppRadius.sm,
/// )
/// ```
class KShimmer extends StatefulWidget {
  /// Width of the shimmer placeholder.
  final double? width;

  /// Height of the shimmer placeholder.
  final double height;

  /// Border radius of the shimmer placeholder.
  final double borderRadius;

  /// Optional custom base color (overrides theme default).
  final Color? baseColor;

  /// Optional custom highlight color (overrides theme default).
  final Color? highlightColor;

  const KShimmer({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = AppRadius.xs,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<KShimmer> createState() => _KShimmerState();
}

class _KShimmerState extends State<KShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimation.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ?? AppColors.skeleton(isDark ? Brightness.dark : Brightness.light);
    final highlight = base.withOpacity(0.4);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A simple spinner loading indicator with optional message.
///
/// Example:
/// ```dart
/// KLoadingSpinner(message: 'Loading grades...')
/// ```
class KLoadingSpinner extends StatelessWidget {
  /// Optional message displayed below the spinner.
  final String? message;

  /// Spinner size.
  final double size;

  /// Spinner stroke width.
  final double strokeWidth;

  const KLoadingSpinner({
    super.key,
    this.message,
    this.size = AppSpacing.iconSizeHero,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation(
                isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pre-built skeleton layouts for common content patterns.
///
/// Example:
/// ```dart
/// KLoadingSkeleton.list()
/// KLoadingSkeleton.card()
/// ```
class KLoadingSkeleton extends StatelessWidget {
  final KSkeletonVariant _variant;
  final int _itemCount;

  const KLoadingSkeleton._(this._variant, this._itemCount);

  /// Creates a card skeleton.
  const KLoadingSkeleton.card({super.key}) : _variant = KSkeletonVariant.card, _itemCount = 1;

  /// Creates a list skeleton with [itemCount] items.
  const KLoadingSkeleton.list({super.key, int itemCount = 3})
      : _variant = KSkeletonVariant.list,
        _itemCount = itemCount;

  /// Creates a grid skeleton with [itemCount] items.
  const KLoadingSkeleton.grid({super.key, int itemCount = 6})
      : _variant = KSkeletonVariant.grid,
        _itemCount = itemCount;

  /// Creates a detail page skeleton.
  const KLoadingSkeleton.detail({super.key})
      : _variant = KSkeletonVariant.detail,
        _itemCount = 1;

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      KSkeletonVariant.card => _buildCardSkeleton(),
      KSkeletonVariant.list => _buildListSkeleton(),
      KSkeletonVariant.grid => _buildGridSkeleton(),
      KSkeletonVariant.detail => _buildDetailSkeleton(),
    };
  }

  Widget _buildCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KShimmer(width: AppSpacing.hero * 3, height: AppSpacing.lg),
          const SizedBox(height: AppSpacing.md),
          const KShimmer(height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.sm),
          const KShimmer(width: AppSpacing.hero * 2, height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KShimmer(
                width: AppSpacing.xxl * 2,
                height: AppSpacing.lg + AppSpacing.xs,
                borderRadius: AppRadius.button,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListSkeleton() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _itemCount,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Row(
          children: [
            // Avatar placeholder
            const KShimmer(
              width: AppSpacing.iconSizeHero,
              height: AppSpacing.iconSizeHero,
              borderRadius: AppRadius.avatar,
            ),
            const SizedBox(width: AppSpacing.md),
            // Text lines
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KShimmer(
                    width: double.infinity,
                    height: AppSpacing.sm + AppSpacing.xs,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const KShimmer(
                    width: AppSpacing.hero * 3,
                    height: AppSpacing.sm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _itemCount,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.cardGap,
        crossAxisSpacing: AppSpacing.cardGap,
        childAspectRatio: 0.75,
      ),
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Expanded(
            child: KShimmer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: AppRadius.card,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const KShimmer(
            width: double.infinity,
            height: AppSpacing.sm + AppSpacing.xs,
          ),
          const SizedBox(height: AppSpacing.xs),
          const KShimmer(
            width: AppSpacing.hero,
            height: AppSpacing.sm,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero area
          const KShimmer(
            width: double.infinity,
            height: AppSpacing.hero,
            borderRadius: AppRadius.md,
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Title
          const KShimmer(
            width: double.infinity,
            height: AppSpacing.lg + AppSpacing.xs,
          ),
          const SizedBox(height: AppSpacing.md),
          // Subtitle
          const KShimmer(
            width: AppSpacing.hero * 4,
            height: AppSpacing.sm + AppSpacing.xs,
          ),
          const SizedBox(height: AppSpacing.xxl),
          // Body lines
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: KShimmer(
                width: i == 3 ? AppSpacing.hero * 3 : double.infinity,
                height: AppSpacing.sm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A general-purpose loading state widget that chooses between spinner
/// and skeleton based on the variant.
///
/// Example:
/// ```dart
/// KLoadingState(variant: KSkeletonVariant.list, message: 'Loading...')
/// ```
class KLoadingState extends StatelessWidget {
  /// The skeleton layout variant.
  final KSkeletonVariant variant;

  /// Number of skeleton items.
  final int itemCount;

  /// Optional message for the spinner variant.
  final String? message;

  /// When true, shows a centered spinner instead of skeleton.
  final bool showSpinner;

  const KLoadingState({
    super.key,
    this.variant = KSkeletonVariant.list,
    this.itemCount = 3,
    this.message,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showSpinner) {
      return KLoadingSpinner(message: message);
    }

    return switch (variant) {
      KSkeletonVariant.card =>
        KLoadingSkeleton.card(),
      KSkeletonVariant.list =>
        KLoadingSkeleton.list(itemCount: itemCount),
      KSkeletonVariant.grid =>
        KLoadingSkeleton.grid(itemCount: itemCount),
      KSkeletonVariant.detail =>
        KLoadingSkeleton.detail(),
    };
  }
}
