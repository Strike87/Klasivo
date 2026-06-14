import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO CACHE SERVICE — Generic local cache for non-Firestore data
//
// Provides a TTL-aware, tag-based cache backed by Hive.
// Used for API responses, computed data, and any data that doesn't
// come from Firestore (which has its own offline persistence).
//
// Default TTL: 1 hour, configurable per entry.
// Supports tag-based invalidation for related data groups.
// ═══════════════════════════════════════════════════════════════════════════════

/// A single cache entry with optional TTL and tags.
class CacheEntry<T> {
  final String key;
  final T data;
  final DateTime cachedAt;
  final DateTime? expiresAt;
  final List<String> tags;

  const CacheEntry({
    required this.key,
    required this.data,
    required this.cachedAt,
    this.expiresAt,
    this.tags = const [],
  });

  /// Whether this entry has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Serializes the entry for Hive storage.
  Map<String, dynamic> toJson() => {
        'key': key,
        'data': jsonEncode(data),
        'cachedAt': cachedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'tags': jsonEncode(tags),
      };

  /// Deserializes a CacheEntry from a Hive-stored map.
  static CacheEntry<dynamic> fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      key: json['key'] as String,
      data: jsonDecode(json['data'] as String),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      tags: (jsonDecode(json['tags'] as String) as List)
          .cast<String>(),
    );
  }
}

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  // ─── Constants ─────────────────────────────────────────────────────────
  static const String _boxName = 'app_cache';
  static const Duration defaultTtl = Duration(hours: 1);

  // ─── State ─────────────────────────────────────────────────────────────
  Box? _box;

  // ─── Initialization ────────────────────────────────────────────────────

  /// Initializes the cache service.
  /// Must be called after Hive.initFlutter().
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
    debugPrint('[CacheService] Initialized with ${_box!.length} entries');
  }

  // ─── Core Operations ───────────────────────────────────────────────────

  /// Retrieves cached data for the given key.
  ///
  /// Returns `null` if the key doesn't exist or the entry has expired.
  /// Expired entries are automatically removed on access.
  T? get<T>(String key) {
    _ensureInitialized();

    final raw = _box!.get(key);
    if (raw == null) return null;

    try {
      final json = Map<String, dynamic>.from(raw as Map);
      final entry = CacheEntry.fromJson(json);

      if (entry.isExpired) {
        invalidate(key);
        return null;
      }

      return entry.data as T;
    } catch (e) {
      debugPrint('[CacheService] Failed to read key "$key": $e');
      invalidate(key);
      return null;
    }
  }

  /// Stores data in the cache with optional TTL and tags.
  ///
  /// [key] — Unique cache key.
  /// [data] — The data to cache (must be JSON-serializable).
  /// [ttl] — Time-to-live. Defaults to 1 hour.
  /// [tags] — Optional tags for group invalidation (e.g., "exams", "students").
  Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
    List<String>? tags,
  }) async {
    _ensureInitialized();

    final now = DateTime.now();
    final effectiveTtl = ttl ?? defaultTtl;

    final entry = CacheEntry<T>(
      key: key,
      data: data,
      cachedAt: now,
      expiresAt: now.add(effectiveTtl),
      tags: tags ?? [],
    );

    await _box!.put(key, entry.toJson());
  }

  /// Removes a specific cache entry.
  Future<void> invalidate(String key) async {
    _ensureInitialized();
    await _box!.delete(key);
  }

  /// Removes all cache entries that have the given tag.
  ///
  /// Example: `invalidateByTag('exams')` removes all entries tagged "exams".
  Future<void> invalidateByTag(String tag) async {
    _ensureInitialized();

    final keysToDelete = <dynamic>[];

    for (final raw in _box!.values) {
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        final entry = CacheEntry.fromJson(json);
        if (entry.tags.contains(tag)) {
          keysToDelete.add(entry.key);
        }
      } catch (_) {}
    }

    for (final key in keysToDelete) {
      await _box!.delete(key);
    }

    if (keysToDelete.isNotEmpty) {
      debugPrint(
        '[CacheService] Invalidated ${keysToDelete.length} entries with tag "$tag"',
      );
    }
  }

  /// Clears the entire cache.
  Future<void> invalidateAll() async {
    _ensureInitialized();
    await _box!.clear();
    debugPrint('[CacheService] Cache cleared');
  }

  /// Checks if a key exists and is not expired.
  bool isCached(String key) {
    _ensureInitialized();
    return get(key) != null;
  }

  /// Cache-first with fallback: returns cached data if available,
  /// otherwise calls [fetchFn], caches the result, and returns it.
  ///
  /// ```dart
  /// final data = await cacheService.getOrFetch(
  ///   'exam_stats_$examId',
  ///   () => api.fetchExamStats(examId),
  ///   ttl: Duration(minutes: 30),
  ///   tags: ['exams', 'stats'],
  /// );
  /// ```
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetchFn, {
    Duration? ttl,
    List<String>? tags,
  }) async {
    // Try cache first
    final cached = get<T>(key);
    if (cached != null) return cached;

    // Cache miss — fetch fresh data
    final data = await fetchFn();
    await set<T>(key, data, ttl: ttl, tags: tags);
    return data;
  }

  /// Returns the number of entries in the cache (including expired ones).
  int getSize() {
    _ensureInitialized();
    return _box!.length;
  }

  /// Removes all expired entries from the cache.
  ///
  /// Call periodically (e.g., on app startup) to reclaim storage.
  Future<int> cleanExpired() async {
    _ensureInitialized();

    final keysToDelete = <dynamic>[];

    for (final raw in _box!.values) {
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        final entry = CacheEntry.fromJson(json);
        if (entry.isExpired) {
          keysToDelete.add(entry.key);
        }
      } catch (_) {}
    }

    for (final key in keysToDelete) {
      await _box!.delete(key);
    }

    if (keysToDelete.isNotEmpty) {
      debugPrint(
        '[CacheService] Cleaned ${keysToDelete.length} expired entries',
      );
    }

    return keysToDelete.length;
  }

  /// Returns all tags currently in use across the cache.
  Set<String> getActiveTags() {
    _ensureInitialized();

    final tags = <String>{};
    for (final raw in _box!.values) {
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        final entry = CacheEntry.fromJson(json);
        if (!entry.isExpired) {
          tags.addAll(entry.tags);
        }
      } catch (_) {}
    }
    return tags;
  }

  /// Returns cache statistics.
  Map<String, dynamic> getStats() {
    _ensureInitialized();

    int total = 0;
    int expired = 0;
    int valid = 0;

    for (final raw in _box!.values) {
      total++;
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        final entry = CacheEntry.fromJson(json);
        if (entry.isExpired) {
          expired++;
        } else {
          valid++;
        }
      } catch (_) {
        expired++; // Corrupted entries count as expired
      }
    }

    return {
      'total': total,
      'valid': valid,
      'expired': expired,
    };
  }

  // ─── Private Helpers ───────────────────────────────────────────────────

  void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'CacheService not initialized. Call initialize() first.',
      );
    }
  }

  /// Disposes the service.
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
  }
}
