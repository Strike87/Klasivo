import '../offline_manager.dart' show SyncStatus;

/// Abstract interface for offline-mode orchestration.
///
/// Implementations manage Firestore cache persistence, sync queues,
/// and provide streams for UI consumption.
abstract class IOfflineManager {
  /// Stream of the count of pending (uncommitted) writes.
  Stream<int> get pendingWritesCount;

  /// Stream of sync status changes.
  Stream<SyncStatus> get syncStatus;

  /// Enable offline mode (configure Firestore persistence, sync queue, etc.).
  Future<void> enableOfflineMode();

  /// Force an immediate sync of pending writes.
  Future<void> forceSync();

  /// Clear the local Firestore cache.
  Future<void> clearCache();

  /// Enqueue a write operation for offline-first processing.
  ///
  /// [operation] should be one of 'create', 'update', or 'delete'.
  Future<void> queueWrite({
    required String collection,
    required String docId,
    required String operation,
    Map<String, dynamic>? data,
  });
}
