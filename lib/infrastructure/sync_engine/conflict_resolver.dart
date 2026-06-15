import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO CONFLICT RESOLVER — Conflict resolution strategies for sync
//
// When the same document is modified offline on multiple devices,
// the sync engine must resolve conflicts. This module provides:
// - Multiple resolution strategies
// - Per-collection strategy configuration
// - Custom merge logic
// - Conflict logging for audit trails
// ═══════════════════════════════════════════════════════════════════════════════

/// The strategy used to resolve a sync conflict.
enum ConflictStrategy {
  /// The server version always wins.
  serverWins,

  /// The local version always wins.
  localWins,

  /// The most recently updated version wins.
  lastWriteWins,

  /// Merge both versions — field-level merge.
  mergeFields,

  /// Custom resolution — delegate to a provided callback.
  custom,
}

/// Represents a conflict between local and server data.
class SyncConflict {
  final String documentPath;
  final String collectionName;
  final String documentId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;
  final DateTime detectedAt;

  const SyncConflict({
    required this.documentPath,
    required this.collectionName,
    required this.documentId,
    required this.localData,
    required this.serverData,
    this.localUpdatedAt,
    this.serverUpdatedAt,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();
}

/// Result of conflict resolution.
class ConflictResolution {
  final Map<String, dynamic> resolvedData;
  final ConflictStrategy strategy;
  final String documentPath;
  final String reason;
  final DateTime resolvedAt;

  const ConflictResolution({
    required this.resolvedData,
    required this.strategy,
    required this.documentPath,
    required this.reason,
    DateTime? resolvedAt,
  }) : resolvedAt = resolvedAt ?? DateTime.now();
}

/// Callback type for custom conflict resolution.
typedef ConflictResolverCallback = Map<String, dynamic> Function(SyncConflict conflict);

class ConflictResolver {
  ConflictResolver._();
  static final ConflictResolver instance = ConflictResolver._();

  /// Per-collection strategy configuration.
  final Map<String, ConflictStrategy> _collectionStrategies = {};

  /// Custom resolvers per collection.
  final Map<String, ConflictResolverCallback> _customResolvers = {};

  /// Conflict log for audit trails.
  final List<ConflictResolution> _resolutionLog = [];

  /// Maximum number of log entries to keep.
  int maxLogSize = 1000;

  // ─── Configuration ──────────────────────────────────────────────────────

  /// Set the conflict strategy for a specific collection.
  void setStrategy(String collectionName, ConflictStrategy strategy) {
    _collectionStrategies[collectionName] = strategy;
  }

  /// Set a custom resolver for a specific collection.
  void setCustomResolver(String collectionName, ConflictResolverCallback resolver) {
    _customResolvers[collectionName] = resolver;
    _collectionStrategies[collectionName] = ConflictStrategy.custom;
  }

  /// Get the strategy for a collection (defaults to lastWriteWins).
  ConflictStrategy getStrategy(String collectionName) {
    return _collectionStrategies[collectionName] ?? ConflictStrategy.lastWriteWins;
  }

  // ─── Resolution ─────────────────────────────────────────────────────────

  /// Resolve a sync conflict using the configured strategy.
  ConflictResolution resolve(SyncConflict conflict) {
    final strategy = getStrategy(conflict.collectionName);
    final resolution = _applyStrategy(conflict, strategy);

    // Log the resolution
    _resolutionLog.add(resolution);
    if (_resolutionLog.length > maxLogSize) {
      _resolutionLog.removeRange(0, _resolutionLog.length - maxLogSize);
    }

    debugPrint(
      '[ConflictResolver] Resolved ${conflict.documentPath} '
      'using ${strategy.name}: ${resolution.reason}',
    );

    return resolution;
  }

  /// Apply a specific strategy to a conflict.
  ConflictResolution _applyStrategy(SyncConflict conflict, ConflictStrategy strategy) {
    switch (strategy) {
      case ConflictStrategy.serverWins:
        return ConflictResolution(
          resolvedData: conflict.serverData,
          strategy: strategy,
          documentPath: conflict.documentPath,
          reason: 'Server version takes precedence',
        );

      case ConflictStrategy.localWins:
        return ConflictResolution(
          resolvedData: conflict.localData,
          strategy: strategy,
          documentPath: conflict.documentPath,
          reason: 'Local version takes precedence',
        );

      case ConflictStrategy.lastWriteWins:
        final localIsNewer = conflict.localUpdatedAt != null &&
            conflict.serverUpdatedAt != null &&
            conflict.localUpdatedAt!.isAfter(conflict.serverUpdatedAt!);

        if (localIsNewer) {
          return ConflictResolution(
            resolvedData: conflict.localData,
            strategy: strategy,
            documentPath: conflict.documentPath,
            reason: 'Local updated at ${conflict.localUpdatedAt} is newer than server ${conflict.serverUpdatedAt}',
          );
        } else {
          return ConflictResolution(
            resolvedData: conflict.serverData,
            strategy: strategy,
            documentPath: conflict.documentPath,
            reason: 'Server updated at ${conflict.serverUpdatedAt} is newer than local ${conflict.localUpdatedAt}',
          );
        }

      case ConflictStrategy.mergeFields:
        return _mergeFields(conflict);

      case ConflictStrategy.custom:
        final customResolver = _customResolvers[conflict.collectionName];
        if (customResolver != null) {
          final resolvedData = customResolver(conflict);
          return ConflictResolution(
            resolvedData: resolvedData,
            strategy: strategy,
            documentPath: conflict.documentPath,
            reason: 'Custom resolver applied for ${conflict.collectionName}',
          );
        }
        // Fall back to lastWriteWins if no custom resolver is registered
        return _applyStrategy(conflict, ConflictStrategy.lastWriteWins);
    }
  }

  /// Field-level merge strategy.
  /// - For shared keys, last write wins per field
  /// - Local-only fields are preserved
  /// - Server-only fields are preserved
  ConflictResolution _mergeFields(SyncConflict conflict) {
    final merged = <String, dynamic>{};

    // Start with all server fields
    merged.addAll(conflict.serverData);

    // Merge local fields — local overwrites server for matching keys
    // if local was updated more recently
    for (final entry in conflict.localData.entries) {
      final key = entry.key;
      if (!conflict.serverData.containsKey(key)) {
        // Local-only field — keep it
        merged[key] = entry.value;
      } else {
        // Both have this field — last write wins per field
        final localIsNewer = conflict.localUpdatedAt != null &&
            conflict.serverUpdatedAt != null &&
            conflict.localUpdatedAt!.isAfter(conflict.serverUpdatedAt!);
        if (localIsNewer) {
          merged[key] = entry.value;
        }
      }
    }

    return ConflictResolution(
      resolvedData: merged,
      strategy: ConflictStrategy.mergeFields,
      documentPath: conflict.documentPath,
      reason: 'Field-level merge applied',
    );
  }

  // ─── Query ──────────────────────────────────────────────────────────────

  /// Get the resolution log.
  List<ConflictResolution> get resolutionLog => List.unmodifiable(_resolutionLog);

  /// Get resolutions for a specific collection.
  List<ConflictResolution> getResolutionsForCollection(String collectionName) {
    return _resolutionLog
        .where((r) => r.documentPath.contains(collectionName))
        .toList();
  }

  /// Clear the resolution log.
  void clearLog() {
    _resolutionLog.clear();
  }
}
