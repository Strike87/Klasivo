import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO IMAGE CACHE SERVICE — Persistent image caching with TTL & LRU eviction
//
// Uses Hive for metadata index and file system for actual image storage.
// Provides cache-first image loading with automatic expiration and size management.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Cache Constants ────────────────────────────────────────────────────────

const String _boxName = 'image_cache_index';
const String _cacheDirName = 'image_cache';

/// Default TTL for avatar images (7 days)
const Duration defaultAvatarTtl = Duration(days: 7);

/// Default TTL for material images (30 days)
const Duration defaultMaterialTtl = Duration(days: 30);

/// Maximum cache size in bytes (100 MB)
const int maxCacheSizeBytes = 100 * 1024 * 1024;

// ═══════════════════════════════════════════════════════════════════════════════
// CACHED IMAGE MODEL — Metadata for a single cached image
// ═══════════════════════════════════════════════════════════════════════════════

class CachedImage {
  final String url;
  final String key;
  final String localPath;
  final DateTime cachedAt;
  final DateTime expiresAt;
  final int sizeBytes;
  final String mimeType;
  final String? tag;

  CachedImage({
    required this.url,
    required this.key,
    required this.localPath,
    required this.cachedAt,
    required this.expiresAt,
    required this.sizeBytes,
    required this.mimeType,
    this.tag,
  });

  /// Whether this cache entry has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Convert to a Map for Hive storage.
  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'key': key,
      'localPath': localPath,
      'cachedAt': cachedAt.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
      'mimeType': mimeType,
      'tag': tag,
    };
  }

  /// Create from a Map (Hive storage).
  factory CachedImage.fromMap(Map<String, dynamic> map) {
    return CachedImage(
      url: map['url'] as String,
      key: map['key'] as String,
      localPath: map['localPath'] as String,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(map['cachedAt'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
      sizeBytes: map['sizeBytes'] as int,
      mimeType: map['mimeType'] as String,
      tag: map['tag'] as String?,
    );
  }

  @override
  String toString() =>
      'CachedImage(url: $url, key: $key, size: $sizeBytes, expired: $isExpired)';
}

// ═══════════════════════════════════════════════════════════════════════════════
// IMAGE CACHE SERVICE — Singleton service for image caching operations
// ═══════════════════════════════════════════════════════════════════════════════

class ImageCacheService {
  ImageCacheService._();
  static final ImageCacheService _instance = ImageCacheService._();
  static ImageCacheService get instance => _instance;

  Box<dynamic>? _box;
  Directory? _cacheDir;
  bool _initialized = false;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Initialize the cache service. Must be called before any other method.
  /// Opens the Hive box and ensures the cache directory exists.
  Future<void> init() async {
    if (_initialized) return;

    try {
      _box = await Hive.openBox(_boxName);
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirName');

      if (!_cacheDir!.existsSync()) {
        await _cacheDir!.create(recursive: true);
      }

      _initialized = true;
      debugPrint('[ImageCacheService] Initialized — cache dir: ${_cacheDir!.path}');
    } catch (e) {
      debugPrint('[ImageCacheService] Initialization failed: $e');
      rethrow;
    }
  }

  /// Ensure the service is initialized before operations.
  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  // ─── Cache Key Generation ───────────────────────────────────────────────

  /// Generate a cache key from a URL using SHA-256.
  static String generateKey(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── File Extension from MIME Type ──────────────────────────────────────

  /// Determine file extension from a MIME type.
  static String _extensionFromMime(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'image/svg+xml':
        return 'svg';
      case 'image/bmp':
        return 'bmp';
      default:
        return 'jpg'; // Safe default
    }
  }

  // ─── Core: Cache an Image ───────────────────────────────────────────────

  /// Download and cache an image from [url].
  ///
  /// - [key]: Optional custom cache key (defaults to SHA-256 of URL).
  /// - [ttl]: Time-to-live for this cache entry (defaults to 7 days).
  /// - [tag]: Optional tag for group invalidation.
  /// - [onProgress]: Optional callback for download progress (received / total bytes).
  ///
  /// Returns the [CachedImage] metadata, or null on failure.
  Future<CachedImage?> cacheImage(
    String url, {
    String? key,
    Duration? ttl,
    String? tag,
    void Function(int received, int total)? onProgress,
  }) async {
    await _ensureInitialized();

    final cacheKey = key ?? generateKey(url);
    final effectiveTtl = ttl ?? defaultAvatarTtl;

    // Check if already cached and not expired
    final existing = getCachedImage(url);
    if (existing != null && !existing.isExpired) {
      return existing;
    }

    try {
      // Download the image
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        debugPrint('[ImageCacheService] Download failed: ${response.statusCode} for $url');
        return null;
      }

      // Determine MIME type from response headers
      final contentType = response.headers['content-type'] ?? 'image/jpeg';
      final mimeType = contentType.split(';').first.trim();
      final extension = _extensionFromMime(mimeType);

      // Read bytes with optional progress reporting
      final contentLength = response.contentLength ?? 0;
      final chunks = <Uint8List>[];
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        chunks.add(chunk);
        receivedBytes += chunk.length;
        if (onProgress != null && contentLength > 0) {
          onProgress(receivedBytes, contentLength);
        }
      }

      // Assemble full byte array
      final bytes = Uint8List(receivedBytes);
      int offset = 0;
      for (final chunk in chunks) {
        bytes.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }

      // Write to file
      final fileName = '$cacheKey.$extension';
      final file = File('${_cacheDir!.path}/$fileName');
      await file.writeAsBytes(bytes);

      final now = DateTime.now();
      final cachedImage = CachedImage(
        url: url,
        key: cacheKey,
        localPath: file.path,
        cachedAt: now,
        expiresAt: now.add(effectiveTtl),
        sizeBytes: bytes.length,
        mimeType: mimeType,
        tag: tag,
      );

      // Save metadata to Hive
      await _box!.put(cacheKey, cachedImage.toMap());

      debugPrint(
        '[ImageCacheService] Cached: $fileName (${bytes.length} bytes, ttl: ${effectiveTtl.inDays}d)',
      );

      // Check cache size and evict if necessary
      await _autoEvictIfNeeded();

      return cachedImage;
    } catch (e) {
      debugPrint('[ImageCacheService] Error caching $url: $e');
      return null;
    }
  }

  // ─── Core: Get Cached Image ─────────────────────────────────────────────

  /// Get the cached image metadata for [url] if it exists and is not expired.
  ///
  /// Returns null if not cached or expired.
  CachedImage? getCachedImage(String url) {
    if (_box == null) return null;

    final cacheKey = generateKey(url);
    final data = _box!.get(cacheKey);

    if (data == null) return null;

    try {
      final cached = CachedImage.fromMap(Map<String, dynamic>.from(data as Map));

      // Check if expired
      if (cached.isExpired) {
        // Clean up expired entry asynchronously
        _invalidateEntry(cacheKey);
        return null;
      }

      // Check if the file still exists on disk
      final file = File(cached.localPath);
      if (!file.existsSync()) {
        _invalidateEntry(cacheKey);
        return null;
      }

      return cached;
    } catch (e) {
      debugPrint('[ImageCacheService] Error reading cache for $url: $e');
      return null;
    }
  }

  // ─── Core: Get Cached Image Path ────────────────────────────────────────

  /// Get the local file path of a cached image, or null if not available.
  String? getCachedImagePath(String url) {
    final cached = getCachedImage(url);
    return cached?.localPath;
  }

  // ─── Batch Preload ──────────────────────────────────────────────────────

  /// Preload a batch of image URLs into the cache.
  ///
  /// Downloads images in parallel (up to 4 concurrent) with optional tag
  /// and TTL for the batch.
  Future<void> preloadImages(
    List<String> urls, {
    String? tag,
    Duration? ttl,
  }) async {
    await _ensureInitialized();

    debugPrint('[ImageCacheService] Preloading ${urls.length} images...');

    // Process in batches of 4 for controlled concurrency
    const batchSize = 4;
    for (var i = 0; i < urls.length; i += batchSize) {
      final batch = urls.sublist(
        i,
        i + batchSize > urls.length ? urls.length : i + batchSize,
      );

      await Future.wait(
        batch.map((url) => cacheImage(url, tag: tag, ttl: ttl)),
      );
    }

    debugPrint('[ImageCacheService] Preload complete');
  }

  // ─── Invalidation ───────────────────────────────────────────────────────

  /// Remove a specific cached image by URL.
  Future<void> invalidateImage(String url) async {
    await _ensureInitialized();
    final cacheKey = generateKey(url);
    await _invalidateEntry(cacheKey);
  }

  /// Remove all cached images with a given tag.
  Future<void> invalidateByTag(String tag) async {
    await _ensureInitialized();

    final keysToDelete = <String>[];
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final map = Map<String, dynamic>.from(data as Map);
          if (map['tag'] == tag) {
            keysToDelete.add(key as String);
          }
        } catch (_) {}
      }
    }

    for (final key in keysToDelete) {
      await _invalidateEntry(key);
    }

    debugPrint(
      '[ImageCacheService] Invalidated ${keysToDelete.length} images with tag: $tag',
    );
  }

  /// Clear the entire image cache (metadata + files).
  Future<void> clearAllCache() async {
    await _ensureInitialized();

    // Delete all cached files
    if (_cacheDir!.existsSync()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }

    // Clear Hive box
    await _box!.clear();

    debugPrint('[ImageCacheService] All cache cleared');
  }

  // ─── Cache Stats ────────────────────────────────────────────────────────

  /// Get the total size of cached images in bytes.
  int getCacheSize() {
    if (_box == null) return 0;

    int totalSize = 0;
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final map = Map<String, dynamic>.from(data as Map);
          totalSize += (map['sizeBytes'] as int?) ?? 0;
        } catch (_) {}
      }
    }
    return totalSize;
  }

  /// Get the number of cached images.
  int getCacheEntryCount() {
    if (_box == null) return 0;
    return _box!.length;
  }

  // ─── Maintenance ────────────────────────────────────────────────────────

  /// Remove all expired cache entries.
  Future<int> cleanExpired() async {
    await _ensureInitialized();

    final keysToDelete = <String>[];
    final now = DateTime.now();

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final map = Map<String, dynamic>.from(data as Map);
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(
            map['expiresAt'] as int,
          );
          if (now.isAfter(expiresAt)) {
            keysToDelete.add(key as String);
          }
        } catch (_) {}
      }
    }

    for (final key in keysToDelete) {
      await _invalidateEntry(key);
    }

    debugPrint('[ImageCacheService] Cleaned ${keysToDelete.length} expired entries');
    return keysToDelete.length;
  }

  /// LRU eviction — remove oldest entries until only [maxEntries] remain.
  ///
  /// Returns the number of entries evicted.
  Future<int> evictOldest(int maxEntries) async {
    await _ensureInitialized();

    // Gather all entries with their timestamps
    final entries = <MapEntry<String, int>>[]; // key → cachedAt
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        try {
          final map = Map<String, dynamic>.from(data as Map);
          final cachedAt = map['cachedAt'] as int? ?? 0;
          entries.add(MapEntry(key as String, cachedAt));
        } catch (_) {}
      }
    }

    // Sort by cachedAt ascending (oldest first)
    entries.sort((a, b) => a.value.compareTo(b.value));

    final toEvict = entries.length - maxEntries;
    if (toEvict <= 0) return 0;

    for (var i = 0; i < toEvict; i++) {
      await _invalidateEntry(entries[i].key);
    }

    debugPrint('[ImageCacheService] LRU evicted $toEvict entries');
    return toEvict;
  }

  // ─── Private Helpers ────────────────────────────────────────────────────

  /// Invalidate a single cache entry by key (delete file + metadata).
  Future<void> _invalidateEntry(String cacheKey) async {
    if (_box == null) return;

    final data = _box!.get(cacheKey);
    if (data != null) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final localPath = map['localPath'] as String?;
        if (localPath != null) {
          final file = File(localPath);
          if (file.existsSync()) {
            await file.delete();
          }
        }
      } catch (_) {}
    }

    await _box!.delete(cacheKey);
  }

  /// Auto-evict if cache size exceeds the maximum.
  Future<void> _autoEvictIfNeeded() async {
    final currentSize = getCacheSize();
    if (currentSize <= maxCacheSizeBytes) return;

    debugPrint(
      '[ImageCacheService] Cache size ${(currentSize / 1024 / 1024).toStringAsFixed(1)}MB '
      'exceeds limit — running eviction...',
    );

    // First, clean expired entries
    await cleanExpired();

    // If still over limit, evict oldest entries in batches
    var currentSizeAfter = getCacheSize();
    while (currentSizeAfter > maxCacheSizeBytes * 0.8) {
      // Evict to 80% capacity
      final entryCount = getCacheEntryCount();
      if (entryCount <= 1) break;

      // Remove 10% of entries (or at least 1)
      final toEvict = (entryCount * 0.1).ceil().clamp(1, entryCount);
      await evictOldest(entryCount - toEvict);
      currentSizeAfter = getCacheSize();
    }
  }
}
