import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SYNC QUEUE SERVICE — Persistent queue for offline Firestore writes
//
// When the device is offline, Firestore mutations are queued locally using
// a Hive box. When connectivity is restored, entries are processed in
// batches with exponential backoff retry on failure.
//
// Max retry count: 5 before giving up
// Backoff: 1s, 2s, 4s, 8s, 16s
// Batch size: 10 entries per sync cycle
// ═══════════════════════════════════════════════════════════════════════════════

/// Operation types for sync queue entries.
enum SyncOperation {
  create,
  update,
  delete,
}

/// A single entry in the offline sync queue.
class SyncQueueEntry {
  final String id;
  final String collection;
  final String docId;
  final SyncOperation operation;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const SyncQueueEntry({
    required this.id,
    required this.collection,
    required this.docId,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  /// Serializes the entry to a JSON-compatible map for Hive storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'collection': collection,
        'docId': docId,
        'operation': operation.name,
        'data': jsonEncode(data),
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
        'lastError': lastError,
      };

  /// Deserializes a SyncQueueEntry from a Hive-stored map.
  factory SyncQueueEntry.fromJson(Map<String, dynamic> json) {
    return SyncQueueEntry(
      id: json['id'] as String,
      collection: json['collection'] as String,
      docId: json['docId'] as String,
      operation: SyncOperation.values.firstWhere(
        (e) => e.name == json['operation'],
        orElse: () => SyncOperation.create,
      ),
      data: jsonDecode(json['data'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  /// Creates a copy with updated retry/error fields.
  SyncQueueEntry copyWith({
    int? retryCount,
    String? lastError,
  }) {
    return SyncQueueEntry(
      id: id,
      collection: collection,
      docId: docId,
      operation: operation,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Callback type for processing a sync queue entry.
/// Returns `true` on success, `false` on failure.
typedef SyncProcessor = Future<bool> Function(SyncQueueEntry entry);

class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService instance = SyncQueueService._();

  // ─── Constants ─────────────────────────────────────────────────────────
  static const String _boxName = 'sync_queue';
  static const int maxRetryCount = 5;
  static const int batchSize = 10;

  /// Exponential backoff delays: 1s, 2s, 4s, 8s, 16s
  static const List<Duration> backoffDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  // ─── State ─────────────────────────────────────────────────────────────
  Box? _box;
  SyncProcessor? _processor;

  // ─── Initialization ────────────────────────────────────────────────────

  /// Initializes the sync queue service.
  /// Must be called after Hive.initFlutter().
  Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
    debugPrint('[SyncQueueService] Initialized with ${_box!.length} entries');
  }

  /// Registers the processor function that will apply mutations to Firestore.
  void registerProcessor(SyncProcessor processor) {
    _processor = processor;
  }

  // ─── Queue Operations ──────────────────────────────────────────────────

  /// Adds an entry to the sync queue.
  ///
  /// [collection] — Firestore collection path.
  /// [docId] — Document ID.
  /// [operation] — Type of mutation (create/update/delete).
  /// [data] — The data to write (empty map for delete).
  Future<void> enqueue({
    required String collection,
    required String docId,
    required SyncOperation operation,
    required Map<String, dynamic> data,
  }) async {
    _ensureInitialized();

    final entry = SyncQueueEntry(
      id: '${collection}_${docId}_${DateTime.now().millisecondsSinceEpoch}',
      collection: collection,
      docId: docId,
      operation: operation,
      data: data,
      createdAt: DateTime.now(),
    );

    await _box!.put(entry.id, entry.toJson());
    debugPrint(
      '[SyncQueueService] Enqueued ${operation.name} on $collection/$docId',
    );
  }

  /// Processes all pending entries in the queue (up to [batchSize] at a time).
  ///
  /// Returns the number of entries successfully processed.
  Future<int> processQueue() async {
    _ensureInitialized();

    if (_processor == null) {
      debugPrint('[SyncQueueService] No processor registered — skipping');
      return 0;
    }

    final pending = getPendingEntries();
    if (pending.isEmpty) return 0;

    // Process in batches of [batchSize]
    final batch = pending.take(batchSize).toList();
    int successCount = 0;

    for (final entry in batch) {
      try {
        final success = await _processor!(entry);
        if (success) {
          await markComplete(entry.id);
          successCount++;
        } else {
          await markFailed(entry.id, 'Processor returned failure');
        }
      } catch (e) {
        await markFailed(entry.id, e.toString());
      }
    }

    debugPrint(
      '[SyncQueueService] Processed $successCount/${batch.length} entries',
    );
    return successCount;
  }

  /// Retries entries that previously failed (retryCount < maxRetryCount).
  ///
  /// Respects exponential backoff: an entry is only retried if enough time
  /// has elapsed since its last failure.
  Future<int> retryFailed() async {
    _ensureInitialized();

    if (_processor == null) return 0;

    final pending = getPendingEntries();
    final retriable = pending.where((e) {
      if (e.retryCount == 0) return true; // Never retried
      if (e.retryCount >= maxRetryCount) return false; // Maxed out

      // Check backoff delay
      final backoffIndex = (e.retryCount - 1).clamp(0, backoffDelays.length - 1);
      final nextRetryAt = e.createdAt.add(backoffDelays[backoffIndex]);
      return DateTime.now().isAfter(nextRetryAt);
    }).toList();

    int successCount = 0;
    for (final entry in retriable.take(batchSize)) {
      try {
        final success = await _processor!(entry);
        if (success) {
          await markComplete(entry.id);
          successCount++;
        } else {
          await markFailed(entry.id, 'Retry failed');
        }
      } catch (e) {
        await markFailed(entry.id, e.toString());
      }
    }

    debugPrint(
      '[SyncQueueService] Retried $successCount/${retriable.length} failed entries',
    );
    return successCount;
  }

  /// Removes completed entries from the queue (housekeeping).
  Future<void> clearCompleted() async {
    _ensureInitialized();

    final entries = _box!.values.cast<Map>();
    final completedIds = <String>[];

    for (final raw in entries) {
      final json = Map<String, dynamic>.from(raw);
      if (json['retryCount'] as int? ?? 0 >= maxRetryCount) {
        completedIds.add(json['id'] as String);
      }
    }

    for (final id in completedIds) {
      await _box!.delete(id);
    }

    if (completedIds.isNotEmpty) {
      debugPrint(
        '[SyncQueueService] Cleared ${completedIds.length} maxed-out entries',
      );
    }
  }

  /// Returns all pending entries in the queue.
  List<SyncQueueEntry> getPendingEntries() {
    _ensureInitialized();

    final entries = <SyncQueueEntry>[];
    for (final raw in _box!.values) {
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        final entry = SyncQueueEntry.fromJson(json);
        if (entry.retryCount < maxRetryCount) {
          entries.add(entry);
        }
      } catch (e) {
        debugPrint('[SyncQueueService] Failed to parse entry: $e');
      }
    }

    // Sort by creation time (oldest first)
    entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return entries;
  }

  /// Returns the count of pending entries (retryCount < maxRetryCount).
  int getEntryCount() {
    _ensureInitialized();
    return getPendingEntries().length;
  }

  /// Marks an entry as complete and removes it from the queue.
  Future<void> markComplete(String id) async {
    _ensureInitialized();
    await _box!.delete(id);
    debugPrint('[SyncQueueService] Entry $id marked complete');
  }

  /// Marks an entry as failed — increments retry count and records the error.
  ///
  /// If retryCount exceeds [maxRetryCount], the entry stays in the queue
  /// but will be skipped during processing (it becomes "dead letter").
  Future<void> markFailed(String id, String error) async {
    _ensureInitialized();

    final raw = _box!.get(id);
    if (raw == null) return;

    final json = Map<String, dynamic>.from(raw as Map);
    final entry = SyncQueueEntry.fromJson(json);

    final updated = entry.copyWith(
      retryCount: entry.retryCount + 1,
      lastError: error,
    );

    await _box!.put(id, updated.toJson());

    if (updated.retryCount >= maxRetryCount) {
      debugPrint(
        '[SyncQueueService] Entry $id exceeded max retries — dead letter',
      );
    } else {
      debugPrint(
        '[SyncQueueService] Entry $id failed (retry ${updated.retryCount}/$maxRetryCount): $error',
      );
    }
  }

  /// Returns the number of dead-letter entries (maxed out retries).
  int getDeadLetterCount() {
    _ensureInitialized();
    int count = 0;
    for (final raw in _box!.values) {
      try {
        final json = Map<String, dynamic>.from(raw as Map);
        if ((json['retryCount'] as int? ?? 0) >= maxRetryCount) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  /// Clears the entire sync queue. Use with caution.
  Future<void> clearAll() async {
    _ensureInitialized();
    await _box!.clear();
    debugPrint('[SyncQueueService] Queue cleared');
  }

  // ─── Private Helpers ───────────────────────────────────────────────────

  void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'SyncQueueService not initialized. Call initialize() first.',
      );
    }
  }

  /// Disposes the service.
  Future<void> dispose() async {
    await _box?.close();
    _box = null;
  }
}
