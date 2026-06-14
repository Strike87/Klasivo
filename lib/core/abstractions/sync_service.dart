import 'dart:async';

/// Abstract interface for offline sync queue services.
///
/// When the device is offline, mutations are queued locally.
/// When connectivity is restored, entries are processed in batches
/// with exponential back-off retry on failure.
abstract class ISyncService {
  /// Enqueue a sync operation for later processing.
  ///
  /// [operation] should be `'create'`, `'update'`, or `'delete'`.
  Future<void> enqueue({
    required String collection,
    required String docId,
    required String operation,
    required Map<String, dynamic> data,
  });

  /// Process all pending entries in the queue (up to the batch size).
  /// Returns the number of entries successfully processed.
  Future<int> processQueue();

  /// Retry entries that previously failed but have not exceeded
  /// the maximum retry count. Returns the number of successful retries.
  Future<int> retryFailed();

  /// Remove completed / dead-letter entries from the queue.
  Future<void> clearCompleted();

  /// Number of pending entries waiting to be processed.
  int get pendingCount;

  /// Number of dead-letter entries (maxed-out retries).
  int get deadLetterCount;

  /// A broadcast stream that emits the current pending count
  /// whenever it changes.
  Stream<int> get pendingCountStream;
}
