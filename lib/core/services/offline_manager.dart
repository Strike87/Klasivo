import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'connectivity_service.dart';
import 'sync_queue_service.dart';
import 'cache_service.dart';
import '../config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO OFFLINE MANAGER — Central offline mode orchestration
//
// Initializes Firestore persistence, manages the sync queue, and provides
// streams for UI consumption (pending writes count, sync status).
// Uses "server wins" conflict resolution strategy by default.
// ═══════════════════════════════════════════════════════════════════════════════

/// Current sync status of the offline manager.
enum SyncStatus {
  /// No sync in progress.
  idle,

  /// Currently syncing pending mutations.
  syncing,

  /// An error occurred during sync.
  error,

  /// A conflict was detected (server wins by default).
  conflict,
}

class OfflineManager {
  OfflineManager._();
  static final OfflineManager instance = OfflineManager._();

  // ─── Dependencies ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SyncQueueService _syncQueue = SyncQueueService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final CacheService _cache = CacheService.instance;

  // ─── Streams & Controllers ─────────────────────────────────────────────
  final _pendingWritesController = StreamController<int>.broadcast();
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  // ─── State ─────────────────────────────────────────────────────────────
  SyncStatus _currentSyncStatus = SyncStatus.idle;
  bool _isOfflineModeEnabled = false;
  int _lastPendingCount = 0;

  // ─── Firestore cache config ────────────────────────────────────────────
  static const int _defaultCacheSizeMB = 100; // 100 MB default cache

  // ─── Public API ────────────────────────────────────────────────────────

  /// Stream of pending writes count (for UI badge).
  Stream<int> get pendingWritesCount => _pendingWritesController.stream;

  /// Stream of sync status changes.
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  /// Current sync status.
  SyncStatus get currentSyncStatus => _currentSyncStatus;

  /// Whether offline mode has been enabled.
  bool get isOfflineModeEnabled => _isOfflineModeEnabled;

  /// Enables Firestore cache persistence and offline mode.
  ///
  /// Must be called before any Firestore operations (ideally in main.dart).
  /// This configures Firestore settings for offline support with a
  /// configurable cache size.
  Future<void> enableOfflineMode({int cacheSizeMB = _defaultCacheSizeMB}) async {
    if (_isOfflineModeEnabled) {
      debugPrint('[OfflineManager] Offline mode already enabled');
      return;
    }

    try {
      // Configure Firestore cache persistence
      _firestore.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: cacheSizeMB * 1024 * 1024, // Convert MB to bytes
      );

      _isOfflineModeEnabled = true;

      // Initialize sync queue
      await _syncQueue.initialize();
      _syncQueue.registerProcessor(_processSyncEntry);

      // Initialize cache service
      await _cache.initialize();
      await _cache.cleanExpired();

      // Listen to connectivity changes
      _connectivitySub = _connectivity.onStatusChange.listen(_onConnectivityChange);

      // Do initial pending count
      _updatePendingCount();

      // Open audit log box
      await _ensureAuditBox();

      debugPrint(
        '[OfflineManager] Offline mode enabled (cache: ${cacheSizeMB}MB)',
      );

      _logAuditEvent('offline_mode_enabled', {
        'cacheSizeMB': cacheSizeMB,
        'pendingEntries': _syncQueue.getEntryCount(),
      });
    } catch (e) {
      debugPrint('[OfflineManager] Failed to enable offline mode: $e');
      _emitSyncStatus(SyncStatus.error);
    }
  }

  /// Returns the count of pending (uncommitted) writes.
  int getPendingMutationsCount() {
    return _syncQueue.getEntryCount();
  }

  /// Triggers an immediate sync when online.
  ///
  /// Returns the number of entries successfully synced.
  Future<int> forceSync() async {
    if (_connectivity.isOffline) {
      debugPrint('[OfflineManager] Cannot force sync while offline');
      return 0;
    }

    _emitSyncStatus(SyncStatus.syncing);

    try {
      // First, retry any previously failed entries
      await _syncQueue.retryFailed();

      // Then process the main queue
      final count = await _syncQueue.processQueue();

      _updatePendingCount();

      if (count > 0) {
        _logAuditEvent('force_sync', {'syncedCount': count});
      }

      _emitSyncStatus(SyncStatus.idle);
      return count;
    } catch (e) {
      debugPrint('[OfflineManager] Force sync failed: $e');
      _emitSyncStatus(SyncStatus.error);
      return 0;
    }
  }

  /// Clears the local Firestore cache.
  ///
  /// **Warning**: This removes all locally cached data. The user should
  /// confirm before calling this. Does not affect the sync queue.
  Future<void> clearCache() async {
    try {
      await _firestore.clearPersistence();
      await _cache.invalidateAll();

      _logAuditEvent('cache_cleared', {});

      debugPrint('[OfflineManager] Firestore cache cleared');
    } catch (e) {
      debugPrint('[OfflineManager] Failed to clear cache: $e');
    }
  }

  /// Returns the estimated cache size in bytes.
  ///
  /// Note: Firestore doesn't expose exact cache size. This returns the
  /// Hive cache size as a proxy for non-Firestore data.
  Future<int> getCacheSize() async {
    try {
      return _cache.getSize();
    } catch (e) {
      return 0;
    }
  }

  /// Enqueues a write operation for offline-first processing.
  ///
  /// If the device is online, the write goes directly to Firestore
  /// and the queue is skipped. If offline, it's queued for later.
  Future<void> queueWrite({
    required String collection,
    required String docId,
    required SyncOperation operation,
    required Map<String, dynamic> data,
  }) async {
    if (_connectivity.isOnline) {
      // Online — try direct write first
      try {
        await _applyFirestoreWrite(collection, docId, operation, data);
        return;
      } catch (e) {
        // Write failed even though we think we're online — queue it
        debugPrint(
          '[OfflineManager] Direct write failed, queuing: $e',
        );
      }
    }

    // Offline or write failed — queue for later
    await _syncQueue.enqueue(
      collection: collection,
      docId: docId,
      operation: operation,
      data: data,
    );

    _updatePendingCount();

    _logAuditEvent('write_queued', {
      'collection': collection,
      'docId': docId,
      'operation': operation.name,
    });
  }

  /// Disposes all resources.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _pendingWritesController.close();
    await _syncStatusController.close();
    await _syncQueue.dispose();
    await _cache.dispose();
  }

  // ─── Private: Connectivity Handler ─────────────────────────────────────

  void _onConnectivityChange(ConnectivityStatus status) {
    if (status == ConnectivityStatus.online) {
      // Back online — trigger sync
      debugPrint('[OfflineManager] Back online — starting sync');
      forceSync();
    } else if (status == ConnectivityStatus.offline) {
      debugPrint('[OfflineManager] Went offline — writes will be queued');
    }
  }

  // ─── Private: Sync Processing ──────────────────────────────────────────

  /// Processes a single sync queue entry by applying it to Firestore.
  Future<bool> _processSyncEntry(SyncQueueEntry entry) async {
    try {
      await _applyFirestoreWrite(
        entry.collection,
        entry.docId,
        entry.operation,
        entry.data,
      );
      return true;
    } on FirebaseException catch (e) {
      // Check for conflict — server wins
      if (e.code == 'cancelled' || e.code == 'aborted') {
        _emitSyncStatus(SyncStatus.conflict);
        _logAuditEvent('sync_conflict', {
          'collection': entry.collection,
          'docId': entry.docId,
          'strategy': 'server_wins',
        });
        // Server wins — mark as complete (discard local change)
        return true;
      }
      return false;
    } catch (e) {
      debugPrint(
        '[OfflineManager] Failed to process ${entry.operation.name} '
        'on ${entry.collection}/${entry.docId}: $e',
      );
      return false;
    }
  }

  /// Applies a write operation directly to Firestore.
  Future<void> _applyFirestoreWrite(
    String collection,
    String docId,
    SyncOperation operation,
    Map<String, dynamic> data,
  ) async {
    final docRef = _firestore.collection(collection).doc(docId);

    switch (operation) {
      case SyncOperation.create:
        await docRef.set(data, SetOptions(merge: true));
        break;
      case SyncOperation.update:
        await docRef.update(data);
        break;
      case SyncOperation.delete:
        await docRef.delete();
        break;
    }
  }

  // ─── Private: Status Emitters ──────────────────────────────────────────

  void _emitSyncStatus(SyncStatus status) {
    _currentSyncStatus = status;
    _syncStatusController.add(status);
  }

  void _updatePendingCount() {
    final count = _syncQueue.getEntryCount();
    if (count != _lastPendingCount) {
      _lastPendingCount = count;
      _pendingWritesController.add(count);
    }
  }

  // ─── Private: Audit Logging ────────────────────────────────────────────

  Future<void> _ensureAuditBox() async {
    if (!Hive.isBoxOpen('offline_audit')) {
      await Hive.openBox('offline_audit');
    }
  }

  void _logAuditEvent(String action, Map<String, dynamic> details) {
    try {
      final box = Hive.box('offline_audit');
      box.add({
        'action': action,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[OfflineManager] Failed to log audit event: $e');
    }
  }
}
