import 'dart:async';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ANALYTICS WAREHOUSE — Pre-computed analytics data store
//
// The warehouse caches pre-computed analytics results so that dashboards
// and reports can render instantly without re-computing aggregates on
// every page visit. Data is refreshed on a configurable interval or
// on-demand when source data changes.
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents a cached analytics result with metadata.
class AnalyticsEntry<T> {
  final T data;
  final DateTime computedAt;
  final DateTime expiresAt;
  final String cacheKey;

  const AnalyticsEntry({
    required this.data,
    required this.computedAt,
    required this.expiresAt,
    required this.cacheKey,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time-to-live remaining
  Duration get ttl => expiresAt.difference(DateTime.now());
}

/// Pre-computed analytics data structures.
class AttendanceAnalytics {
  final double overallRate;
  final Map<String, double> rateByClass;
  final Map<String, double> rateBySubject;
  final Map<String, int> trendData; // date → count
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;

  const AttendanceAnalytics({
    this.overallRate = 0,
    this.rateByClass = const {},
    this.rateBySubject = const {},
    this.trendData = const {},
    this.totalStudents = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.excusedCount = 0,
  });
}

class ExamAnalytics {
  final double averageScore;
  final double passRate;
  final Map<String, double> scoreBySubject;
  final Map<String, int> gradeDistribution; // grade → count
  final int totalExams;
  final int totalSubmissions;
  final double highestScore;
  final double lowestScore;

  const ExamAnalytics({
    this.averageScore = 0,
    this.passRate = 0,
    this.scoreBySubject = const {},
    this.gradeDistribution = const {},
    this.totalExams = 0,
    this.totalSubmissions = 0,
    this.highestScore = 0,
    this.lowestScore = 0,
  });
}

class StudentAnalytics {
  final double gpa;
  final double attendanceRate;
  final int examsCompleted;
  final int assignmentsCompleted;
  final Map<String, double> subjectScores;
  final List<String> upcomingExams;
  final List<String> pendingAssignments;

  const StudentAnalytics({
    this.gpa = 0,
    this.attendanceRate = 0,
    this.examsCompleted = 0,
    this.assignmentsCompleted = 0,
    this.subjectScores = const {},
    this.upcomingExams = const [],
    this.pendingAssignments = const [],
  });
}

class ClassAnalytics {
  final String classId;
  final String className;
  final int studentCount;
  final double averageScore;
  final double attendanceRate;
  final double passRate;
  final Map<String, double> subjectAverages;

  const ClassAnalytics({
    required this.classId,
    required this.className,
    this.studentCount = 0,
    this.averageScore = 0,
    this.attendanceRate = 0,
    this.passRate = 0,
    this.subjectAverages = const {},
  });
}

/// The analytics warehouse — a pre-computed cache of analytics data.
class AnalyticsWarehouse {
  AnalyticsWarehouse._();
  static final AnalyticsWarehouse instance = AnalyticsWarehouse._();

  final Map<String, AnalyticsEntry> _cache = {};
  final _controller = StreamController<String>.broadcast();

  /// Duration before cached entries expire.
  Duration cacheTtl = const Duration(hours: 1);

  /// Stream of cache invalidation events.
  Stream<String> get onCacheInvalidated => _controller.stream;

  // ─── Read Operations ────────────────────────────────────────────────────

  /// Get a cached analytics entry, returning null if expired or missing.
  T? get<T>(String cacheKey) {
    final entry = _cache[cacheKey];
    if (entry == null) return null;
    if (entry.isExpired) {
      _cache.remove(cacheKey);
      return null;
    }
    return entry.data as T;
  }

  /// Get a cached entry, computing it on cache miss using [compute].
  Future<T> getOrCompute<T>(String cacheKey, Future<T> Function() compute) async {
    final cached = get<T>(cacheKey);
    if (cached != null) return cached;

    final data = await compute();
    put(cacheKey, data);
    return data;
  }

  // ─── Write Operations ───────────────────────────────────────────────────

  /// Store a pre-computed analytics result.
  void put<T>(String cacheKey, T data) {
    final now = DateTime.now();
    _cache[cacheKey] = AnalyticsEntry<T>(
      data: data,
      computedAt: now,
      expiresAt: now.add(cacheTtl),
      cacheKey: cacheKey,
    );
    _controller.add(cacheKey);
  }

  /// Invalidate a specific cache entry.
  void invalidate(String cacheKey) {
    _cache.remove(cacheKey);
    _controller.add(cacheKey);
  }

  /// Invalidate all entries matching a prefix.
  void invalidatePrefix(String prefix) {
    final keysToRemove = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      _controller.add(key);
    }
  }

  /// Invalidate all cache entries.
  void invalidateAll() {
    _cache.clear();
    _controller.add('__all__');
  }

  // ─── Batch Operations ───────────────────────────────────────────────────

  /// Store multiple entries at once.
  void putAll<T>(Map<String, T> entries) {
    final now = DateTime.now();
    for (final entry in entries.entries) {
      _cache[entry.key] = AnalyticsEntry<T>(
        data: entry.value,
        computedAt: now,
        expiresAt: now.add(cacheTtl),
        cacheKey: entry.key,
      );
    }
  }

  // ─── Maintenance ────────────────────────────────────────────────────────

  /// Remove all expired entries.
  void evictExpired() {
    final expiredKeys = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    if (expiredKeys.isNotEmpty) {
      debugPrint('[AnalyticsWarehouse] Evicted ${expiredKeys.length} expired entries');
    }
  }

  /// Current cache size.
  int get size => _cache.length;

  /// Check if a key exists and is not expired.
  bool has(String cacheKey) {
    final entry = _cache[cacheKey];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(cacheKey);
      return false;
    }
    return true;
  }

  /// Dispose the warehouse.
  void dispose() {
    _cache.clear();
    _controller.close();
  }
}
