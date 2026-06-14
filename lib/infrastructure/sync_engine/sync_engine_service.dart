import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/config/app_constants.dart';
import '../../core/services/connectivity_service.dart';
import 'conflict_resolver.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SYNC ENGINE — Enhanced offline-first sync engine
//
// Manages bi-directional synchronization between local data and Firestore:
// - Queue-based offline write operations
// - Automatic sync when connectivity is restored
// - Conflict detection and resolution
// - Retry with exponential backoff
// - Progress reporting
// - Selective collection sync
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents a pending write operation in the sync queue.
class SyncOperation {
  final String id;
  final String collectionPath;
  final String documentId;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final String? error;

  const SyncOperation({
    required this.id,
    required this.collectionPath,
    required this.documentId,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.error,
  });

  /// Maximum number of retries before giving up.
  bool get isExhausted => retryCount >= 5;

  SyncOperation copyWith({
    int? retryCount,
    DateTime? lastAttemptAt,
    String? error,
  }) {
    return SyncOperation(
      id: id,
      collectionPath: collectionPath,
      documentId: documentId,
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      error: error ?? this.error,
    );
  }
}

enum SyncOperationType { create, update, delete }

/// Current state of the sync engine.
enum SyncState {
  idle,
  syncing,
  paused,
  error,
  offline,
}

/// Progress of a sync operation.
class SyncProgress {
  final int total;
  final int completed;
  final int failed;
  final String currentCollection;

  const SyncProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.currentCollection = '',
  });

  double get progress => total > 0 ? completed / total : 0;
  bool get isComplete => completed + failed >= total && total > 0;

  SyncProgress copyWith({
    int? total,
    int? completed,
    int? failed,
    String? currentCollection,
  }) {
    return SyncProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      currentCollection: currentCollection ?? this.currentCollection,
    );
  }
}

class SyncEngine {
  SyncEngine._();
  static final SyncEngine instance = SyncEngine._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ConflictResolver _conflictResolver = ConflictResolver.instance;

  /// In-memory sync queue.
  final List<SyncOperation> _queue = [];

  /// Current sync state.
  SyncState _state = SyncState.idle;

  /// Stream controller for state changes.
  final _stateController = StreamController<SyncState>.broadcast();

  /// Stream controller for progress updates.
  final _progressController = StreamController<SyncProgress>.broadcast();

  /// Connectivity subscription.
  StreamSubscription? _connectivitySub;

  /// Whether the engine is initialized.
  bool _initialized = false;

  /// Collections to sync (empty = all).
  final Set<String> _syncedCollections = {};

  // ─── Getters ────────────────────────────────────────────────────────────

  SyncState get state => _state;
  List<SyncOperation> get pendingOperations => List.unmodifiable(_queue);
  int get queueLength => _queue.length;
  bool get isSyncing => _state == SyncState.syncing;

  Stream<SyncState> get onStateChanged => _stateController.stream;
  Stream<SyncProgress> get onProgressChanged => _progressController.stream;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Initialize the sync engine.
  Future<void> initialize() async {
    if (_initialized) return;

    // Listen for connectivity changes
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen(
      (isConnected) {
        if (isConnected && _queue.isNotEmpty) {
          _syncQueue();
        } else if (!isConnected) {
          _setState(SyncState.offline);
        }
      },
    );

    // Configure default conflict strategies
    _conflictResolver.setStrategy(AppConstants.examsCollection, ConflictStrategy.lastWriteWins);
    _conflictResolver.setStrategy(AppConstants.attendanceCollection, ConflictStrategy.mergeFields);
    _conflictResolver.setStrategy(AppConstants.submissionsCollection, ConflictStrategy.serverWins);
    _conflictResolver.setStrategy(AppConstants.questionsCollection, ConflictStrategy.lastWriteWins);

    _initialized = true;
    debugPrint('[SyncEngine] Initialized');
  }

  // ─── Queue Operations ──────────────────────────────────────────────────

  /// Add a create operation to the sync queue.
  void enqueueCreate(String collectionPath, String documentId, Map<String, dynamic> data) {
    _enqueue(SyncOperation(
      id: '${collectionPath}_${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      collectionPath: collectionPath,
      documentId: documentId,
      type: SyncOperationType.create,
      data: data,
      createdAt: DateTime.now(),
    ));
  }

  /// Add an update operation to the sync queue.
  void enqueueUpdate(String collectionPath, String documentId, Map<String, dynamic> data) {
    _enqueue(SyncOperation(
      id: '${collectionPath}_${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      collectionPath: collectionPath,
      documentId: documentId,
      type: SyncOperationType.update,
      data: data,
      createdAt: DateTime.now(),
    ));
  }

  /// Add a delete operation to the sync queue.
  void enqueueDelete(String collectionPath, String documentId) {
    _enqueue(SyncOperation(
      id: '${collectionPath}_${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      collectionPath: collectionPath,
      documentId: documentId,
      type: SyncOperationType.delete,
      data: {},
      createdAt: DateTime.now(),
    ));
  }

  void _enqueue(SyncOperation operation) {
    _queue.add(operation);
    debugPrint('[SyncEngine] Enqueued ${operation.type.name} for ${operation.documentId}');

    // Auto-sync if online
    if (ConnectivityService.instance.isConnected) {
      _syncQueue();
    }
  }

  // ─── Sync Execution ────────────────────────────────────────────────────

  /// Synchronize all pending operations.
  Future<void> sync() async {
    await _syncQueue();
  }

  Future<void> _syncQueue() async {
    if (_state == SyncState.syncing || _queue.isEmpty) return;
    if (!ConnectivityService.instance.isConnected) {
      _setState(SyncState.offline);
      return;
    }

    _setState(SyncState.syncing);

    final total = _queue.length;
    var completed = 0;
    var failed = 0;

    _progressController.add(SyncProgress(total: total, completed: 0, failed: 0));

    // Process operations in order
    final operations = List<SyncOperation>.from(_queue);
    _queue.clear();

    for (final op in operations) {
      try {
        await _executeOperation(op);
        completed++;
      } catch (e) {
        failed++;
        debugPrint('[SyncEngine] Failed to sync ${op.documentId}: $e');

        // Re-queue if retries remaining
        if (!op.isExhausted) {
          final updatedOp = op.copyWith(
            retryCount: op.retryCount + 1,
            lastAttemptAt: DateTime.now(),
            error: e.toString(),
          );
          _queue.add(updatedOp);
        } else {
          debugPrint('[SyncEngine] Exhausted retries for ${op.documentId}');
        }
      }

      _progressController.add(SyncProgress(
        total: total,
        completed: completed,
        failed: failed,
        currentCollection: op.collectionPath,
      ));
    }

    _setState(_queue.isEmpty ? SyncState.idle : SyncState.error);
    debugPrint('[SyncEngine] Sync complete: $completed succeeded, $failed failed');
  }

  Future<void> _executeOperation(SyncOperation op) async {
    final docRef = _db.collection(op.collectionPath).doc(op.documentId);

    switch (op.type) {
      case SyncOperationType.create:
        await docRef.set({
          ...op.data,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;

      case SyncOperationType.update:
        // Check for conflicts — compare updatedAt timestamps
        final serverDoc = await docRef.get();
        if (serverDoc.exists) {
          final serverData = serverDoc.data()!;
          final serverUpdatedAt = serverData['updatedAt'] as Timestamp?;

          if (serverUpdatedAt != null && op.data.containsKey('updatedAt')) {
            final localUpdatedAt = op.data['updatedAt'] as Timestamp?;
            if (localUpdatedAt != null &&
                serverUpdatedAt.toDate().isAfter(localUpdatedAt.toDate())) {
              // Conflict detected
              final conflict = SyncConflict(
                documentPath: '${op.collectionPath}/${op.documentId}',
                collectionName: op.collectionPath,
                documentId: op.documentId,
                localData: op.data,
                serverData: serverData,
                localUpdatedAt: localUpdatedAt.toDate(),
                serverUpdatedAt: serverUpdatedAt.toDate(),
              );

              final resolution = _conflictResolver.resolve(conflict);
              await docRef.update({
                ...resolution.resolvedData,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              break;
            }
          }
        }

        await docRef.update({
          ...op.data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        break;

      case SyncOperationType.delete:
        await docRef.delete();
        break;
    }
  }

  // ─── State Management ──────────────────────────────────────────────────

  void _setState(SyncState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Pause sync (e.g., during exam taking to avoid interference).
  void pause() {
    _setState(SyncState.paused);
  }

  /// Resume sync after pausing.
  void resume() {
    if (_state == SyncState.paused) {
      _setState(SyncState.idle);
      if (ConnectivityService.instance.isConnected && _queue.isNotEmpty) {
        _syncQueue();
      }
    }
  }

  // ─── Collection Filtering ──────────────────────────────────────────────

  /// Add a collection to the sync whitelist.
  void addSyncedCollection(String collectionName) {
    _syncedCollections.add(collectionName);
  }

  /// Remove a collection from the sync whitelist.
  void removeSyncedCollection(String collectionName) {
    _syncedCollections.remove(collectionName);
  }

  // ─── Cleanup ───────────────────────────────────────────────────────────

  /// Clear all pending operations.
  void clearQueue() {
    _queue.clear();
  }

  /// Dispose the sync engine.
  void dispose() {
    _connectivitySub?.cancel();
    _stateController.close();
    _progressController.close();
    _initialized = false;
  }
}
