import 'package:flutter/material.dart';
import '../../core/tokens/tokens.dart';
import 'k_card.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO LOADING STATE — Loading state with shimmer effect
// Uses AppColors, AppSpacing, AppRadius, AppAnimation tokens.
// ═══════════════════════════════════════════════════════════════════════════════

/// A shimmer effect widget for loading placeholders.
class KShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration? duration;

  const KShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration,
  });

  @override
  State<KShimmer> createState() => _KShimmerState();
}

class _KShimmerState extends State<KShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppAnimation.shimmer,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor = widget.baseColor ?? AppColors.skeleton(brightness);
    final highlightColor = widget.highlightColor ??
        AppColors.resolve(
          brightness: brightness,
          light: AppColors.lightSurface,
          dark: AppColors.darkBorder,
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(1.0 + 2.0 * _controller.value, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A widget that rebuilds on animation changes.
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder_(
      animation: animation,
      builder: builder,
      child: child,
    );
  }
}

class AnimatedBuilder_ extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder_({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}

// ─── Shimmer Placeholders ────────────────────────────────────────────────────

/// A shimmer line placeholder (for text).
class KShimmerLine extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const KShimmerLine({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = AppRadius.xs,
  });

  @override
  Widget build(BuildContext context) {
    return KShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A shimmer circle placeholder (for avatars).
class KShimmerCircle extends StatelessWidget {
  final double size;

  const KShimmerCircle({
    super.key,
    this.size = AppSpacing.avatarRadius * 2,
  });

  @override
  Widget build(BuildContext context) {
    return KShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// A shimmer card placeholder.
class KShimmerCard extends StatelessWidget {
  final int lineCount;

  const KShimmerCard({
    super.key,
    this.lineCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      variant: KCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title line
          KShimmerLine(
            width: 180,
            height: 16,
          ),
          const SizedBox(height: AppSpacing.md),
          // Body lines
          for (int i = 0; i < lineCount; i++) ...[
            KShimmerLine(
              width: i == lineCount - 1 ? 200 : double.infinity,
            ),
            if (i < lineCount - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

// ─── KLoadingState ───────────────────────────────────────────────────────────

/// A full-page loading state with optional message.
class KLoadingState extends StatelessWidget {
  final String? message;
  final bool useShimmer;
  final int shimmerItemCount;

  const KLoadingState({
    super.key,
    this.message,
    this.useShimmer = false,
    this.shimmerItemCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (useShimmer) {
      return _buildShimmerList();
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.resolve(
              brightness: brightness,
              light: AppColors.primary,
              dark: AppColors.primaryLight,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.screenTop,
      ),
      itemCount: shimmerItemCount,
      itemBuilder: (context, index) {
        return const KShimmerCard();
      },
    );
  }
}

/// Inline loading indicator for buttons and small areas.
class KInlineLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const KInlineLoader({
    super.key,
    this.size = AppSpacing.iconSizeMd,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ??
            AppColors.resolve(
              brightness: brightness,
              light: AppColors.primary,
              dark: AppColors.primaryLight,
            ),
      ),
    );
  }
}
