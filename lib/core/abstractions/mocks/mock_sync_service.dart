import 'dart:async';
import '../sync_service.dart';

/// A single entry in the in-memory sync queue.
class _SyncEntry {
  final String collection;
  final String docId;
  final String operation;
  final Map<String, dynamic> data;
  int retryCount;
  String? lastError;

  _SyncEntry({
    required this.collection,
    required this.docId,
    required this.operation,
    required this.data,
    this.retryCount = 0,
    this.lastError,
  });
}

/// Mock implementation of [ISyncService] for testing.
///
/// Maintains an in-memory queue of sync entries with full support for
/// enqueue, process, retry, dead-letter tracking, and a pending-count stream.
class MockSyncService implements ISyncService {
  final List<_SyncEntry> _queue = [];
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  /// Maximum retry count before an entry becomes dead-letter.
  static const int maxRetryCount = 5;

  /// Optional processor function. If set, [processQueue] and [retryFailed]
  /// will call it for each entry. Return `true` for success, `false` for
  /// failure.
  Future<bool> Function(_SyncEntry entry)? processor;

  // ─── ISyncService ───────────────────────────────────────────────────────

  @override
  Future<void> enqueue({
    required String collection,
    required String docId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    _queue.add(_SyncEntry(
      collection: collection,
      docId: docId,
      operation: operation,
      data: Map<String, dynamic>.from(data),
    ));
    _emitPendingCount();
  }

  @override
  Future<int> processQueue() async {
    final pending = _queue
        .where((e) => e.retryCount < maxRetryCount)
        .toList();
    if (pending.isEmpty || processor == null) return 0;

    int successCount = 0;
    for (final entry in pending) {
      try {
        final success = await processor!(entry);
        if (success) {
          _queue.remove(entry);
          successCount++;
        } else {
          _markFailed(entry, 'Processor returned failure');
        }
      } catch (e) {
        _markFailed(entry, e.toString());
      }
    }
    _emitPendingCount();
    return successCount;
  }

  @override
  Future<int> retryFailed() async {
    final retriable = _queue
        .where((e) =>
            e.retryCount > 0 && e.retryCount < maxRetryCount)
        .toList();
    if (retriable.isEmpty || processor == null) return 0;

    int successCount = 0;
    for (final entry in retriable) {
      try {
        final success = await processor!(entry);
        if (success) {
          _queue.remove(entry);
          successCount++;
        } else {
          _markFailed(entry, 'Retry failed');
        }
      } catch (e) {
        _markFailed(entry, e.toString());
      }
    }
    _emitPendingCount();
    return successCount;
  }

  @override
  Future<void> clearCompleted() async {
    _queue.removeWhere((e) => e.retryCount >= maxRetryCount);
    _emitPendingCount();
  }

  @override
  int get pendingCount =>
      _queue.where((e) => e.retryCount < maxRetryCount).length;

  @override
  int get deadLetterCount =>
      _queue.where((e) => e.retryCount >= maxRetryCount).length;

  @override
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  // ─── Internal Helpers ───────────────────────────────────────────────────

  void _markFailed(_SyncEntry entry, String error) {
    entry.retryCount++;
    entry.lastError = error;
  }

  void _emitPendingCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(pendingCount);
    }
  }

  // ─── Test Helpers ───────────────────────────────────────────────────────

  /// All entries currently in the queue (pending + dead-letter).
  List<Map<String, dynamic>> get allEntries => _queue
      .map((e) => {
            'collection': e.collection,
            'docId': e.docId,
            'operation': e.operation,
            'data': e.data,
            'retryCount': e.retryCount,
            'lastError': e.lastError,
          })
      .toList();

  /// Clear all entries and reset state.
  void reset() {
    _queue.clear();
    _emitPendingCount();
  }

  /// Close the stream controller. Call in tearDown.
  void dispose() {
    _pendingCountController.close();
  }
}
