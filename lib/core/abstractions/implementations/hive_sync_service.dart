import 'dart:async';

import '../sync_service.dart';
import '../../services/sync_queue_service.dart' as native;

/// Production implementation of [ISyncService] that delegates to the
/// singleton [native.SyncQueueService.instance].
///
/// The existing [native.SyncQueueService] uses its own [native.SyncOperation]
/// enum; this adapter maps the string-based [operation] parameter to the enum
/// and bridges the pending-count stream.
class HiveSyncService implements ISyncService {
  final native.SyncQueueService _delegate =
      native.SyncQueueService.instance;

  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  /// Whether the stream controller is still active.
  bool _disposed = false;

  // ─── ISyncService ───────────────────────────────────────────────────────

  @override
  Future<void> enqueue({
    required String collection,
    required String docId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final syncOp = _parseOperation(operation);
    await _delegate.enqueue(
      collection: collection,
      docId: docId,
      operation: syncOp,
      data: data,
    );
    _emitPendingCount();
  }

  @override
  Future<int> processQueue() async {
    final count = await _delegate.processQueue();
    _emitPendingCount();
    return count;
  }

  @override
  Future<int> retryFailed() async {
    final count = await _delegate.retryFailed();
    _emitPendingCount();
    return count;
  }

  @override
  Future<void> clearCompleted() async {
    await _delegate.clearCompleted();
    _emitPendingCount();
  }

  @override
  int get pendingCount => _delegate.getEntryCount();

  @override
  int get deadLetterCount => _delegate.getDeadLetterCount();

  @override
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  // ─── Internal Helpers ───────────────────────────────────────────────────

  native.SyncOperation _parseOperation(String operation) {
    switch (operation) {
      case 'create':
        return native.SyncOperation.create;
      case 'update':
        return native.SyncOperation.update;
      case 'delete':
        return native.SyncOperation.delete;
      default:
        throw ArgumentError('Unknown sync operation: $operation');
    }
  }

  void _emitPendingCount() {
    if (!_disposed && !_pendingCountController.isClosed) {
      _pendingCountController.add(pendingCount);
    }
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  /// Dispose the internal stream controller.
  /// Call when the service is no longer needed.
  void dispose() {
    _disposed = true;
    _pendingCountController.close();
  }
}
