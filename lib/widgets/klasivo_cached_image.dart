import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/image_cache_service.dart';
import '../core/tokens/tokens.dart';
import '../providers/image_cache_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO CACHED IMAGE — Drop-in replacement for Image.network with caching
//
// Features:
// - Cache-first loading via ImageCacheService
// - Built-in shimmer placeholder matching Klasivo design
// - Error fallback with broken image icon
// - Circular clipping for avatars (isCircular flag)
// - Optional cache tag for group invalidation
// - Optional TTL override
// - Optional cache dimensions for memory-efficient resizing
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoCachedImage extends ConsumerStatefulWidget {
  final String imageUrl;

  /// Optional width.
  final double? width;

  /// Optional height.
  final double? height;

  /// How to fit the image within its bounds.
  final BoxFit fit;

  /// Placeholder widget shown while loading. Defaults to Klasivo shimmer.
  final Widget? placeholder;

  /// Error widget shown on failure. Defaults to broken image icon.
  final Widget? errorWidget;

  /// Optional border radius.
  final BorderRadius? borderRadius;

  /// Optional cache tag for group invalidation.
  final String? tag;

  /// Optional cache TTL override.
  final Duration? ttl;

  /// Resize before caching to save memory.
  final int? cacheWidth;

  /// Resize before caching to save memory.
  final int? cacheHeight;

  /// Clip to a circle (useful for avatars).
  final bool isCircular;

  const KlasivoCachedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.tag,
    this.ttl,
    this.cacheWidth,
    this.cacheHeight,
    this.isCircular = false,
  }) : super(key: key);

  @override
  ConsumerState<KlasivoCachedImage> createState() => _KlasivoCachedImageState();
}

class _KlasivoCachedImageState extends ConsumerState<KlasivoCachedImage> {
  CachedImage? _cachedImage;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadCachedImage();
  }

  @override
  void didUpdateWidget(KlasivoCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _cachedImage = null;
      });
      _loadCachedImage();
    }
  }

  Future<void> _loadCachedImage() async {
    final service = ref.read(imageCacheServiceProvider);
    await service.init();

    // Check cache
    final cached = service.getCachedImage(widget.imageUrl);
    if (cached != null && !cached.isExpired) {
      if (mounted) {
        setState(() {
          _cachedImage = cached;
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    // Cache miss — download in background
    try {
      final result = await service.cacheImage(
        widget.imageUrl,
        tag: widget.tag,
        ttl: widget.ttl,
      );
      if (mounted) {
        setState(() {
          _cachedImage = result;
          _isLoading = false;
          _hasError = result == null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return _buildWrapped(widget.placeholder ?? _buildShimmer());
    }

    // Error state
    if (_hasError || _cachedImage == null) {
      // Fall back to network image as last resort
      return _buildWrapped(_buildNetworkFallback());
    }

    // Cached image from file
    final file = File(_cachedImage!.localPath);
    if (!file.existsSync()) {
      return _buildWrapped(_buildNetworkFallback());
    }

    final image = Image.file(
      file,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ?? _buildDefaultError(),
    );

    return _buildWrapped(image);
  }

  /// Wrap the child with border radius and/or circular clipping.
  Widget _buildWrapped(Widget child) {
    if (widget.isCircular) {
      return ClipOval(
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: child,
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }

  /// Build a shimmer placeholder matching Klasivo design.
  Widget _buildShimmer() {
    return _KlasivoShimmer(
      width: widget.width,
      height: widget.height,
      isCircular: widget.isCircular,
      borderRadius: widget.borderRadius,
    );
  }

  /// Build a default error widget (broken image icon).
  Widget _buildDefaultError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.lightSkeleton,
      child: Icon(
        Icons.broken_image_outlined,
        color: AppColors.lightTextDisabled,
        size: (widget.width ?? 24) * 0.5,
      ),
    );
  }

  /// Fall back to network image if cache failed.
  Widget _buildNetworkFallback() {
    return Image.network(
      widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ?? _buildDefaultError(),
      loadingBuilder: (_, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return widget.placeholder ?? _buildShimmer();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SHIMMER — Lightweight shimmer animation for image placeholders
// ═══════════════════════════════════════════════════════════════════════════════

class _KlasivoShimmer extends StatefulWidget {
  final double? width;
  final double? height;
  final bool isCircular;
  final BorderRadius? borderRadius;

  const _KlasivoShimmer({
    this.width,
    this.height,
    this.isCircular = false,
    this.borderRadius,
  });

  @override
  State<_KlasivoShimmer> createState() => _KlasivoShimmerState();
}

class _KlasivoShimmerState extends State<_KlasivoShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
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
    final baseColor = AppColors.skeleton(brightness);
    final highlightColor = brightness == Brightness.dark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircular ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                widget.isCircular ? null : widget.borderRadius ?? BorderRadius.circular(AppRadius.sm),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 2), 0),
              end: Alignment(1.0 - (_controller.value * 2), 0),
              colors: [
                baseColor,
                highlightColor.withOpacity(0.4),
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
