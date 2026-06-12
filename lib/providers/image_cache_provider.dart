import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/image_cache_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO IMAGE CACHE PROVIDERS — Riverpod integration for image caching
//
// Provides the ImageCacheService singleton and async providers for
// cache-aware image loading.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Image Cache Service Provider ──────────────────────────────────────────

/// Provides the singleton [ImageCacheService] instance.
/// Initializes the service on first access.
final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  final service = ImageCacheService.instance;
  // Ensure initialization on first read
  service.init();
  return service;
});

// ─── Cached Image Provider ─────────────────────────────────────────────────

/// Checks the cache for an image URL and returns [CachedImage] if available.
///
/// If the image is not cached or expired, triggers a background download
/// and returns null (so the caller can fall back to network loading).
///
/// Usage:
///   final cached = ref.watch(cachedImageProvider('https://example.com/avatar.png'));
final cachedImageProvider =
    FutureProvider.family<CachedImage?, String>((ref, url) async {
  final service = ref.read(imageCacheServiceProvider);
  await service.init();

  // Check cache first
  final cached = service.getCachedImage(url);
  if (cached != null) {
    return cached;
  }

  // Cache miss — try to download and cache
  try {
    final result = await service.cacheImage(url);
    return result;
  } catch (_) {
    return null;
  }
});

// ─── Preloaded Images Provider ─────────────────────────────────────────────

/// Provider for batch preloading avatar URLs.
///
/// Accepts a list of avatar URLs and preloads them with the 'avatar' tag
/// and the default avatar TTL (7 days).
///
/// Usage:
///   ref.read(preloadedImagesProvider).preload(avatarUrls);
class PreloadNotifier extends StateNotifier<AsyncValue<void>> {
  final ImageCacheService _service;

  PreloadNotifier(this._service) : super(const AsyncValue.data(null));

  /// Preload a list of image URLs.
  Future<void> preload(List<String> urls, {String? tag, Duration? ttl}) async {
    state = const AsyncValue.loading();
    try {
      await _service.preloadImages(urls, tag: tag ?? 'avatar', ttl: ttl);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final preloadedImagesProvider =
    StateNotifierProvider<PreloadNotifier, AsyncValue<void>>((ref) {
  final service = ref.read(imageCacheServiceProvider);
  return PreloadNotifier(service);
});
