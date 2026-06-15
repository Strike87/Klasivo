import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'offline_exam_service.dart';
import 'sync_queue_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SYNC ORCHESTRATOR — Coordinates offline exam sync with Firestore
//
// Bridges OfflineExamService, SyncQueueService, and ConnectivityService:
//   - Listens to connectivity changes
//   - When coming back online, flushes all pending writes to Firestore
//   - Marks local exam data as synced after successful Firestore writes
//   - Provides a stream of exam-specific sync status for UI indicators
//
// IMPORTANT: This service replaces the SyncQueueService processor with an
// enhanced one that handles both general Firestore writes AND exam-specific
// local sync marking. It must be initialized AFTER OfflineManager.
// ═══════════════════════════════════════════════════════════════════════════════

/// Exam-specific sync status for UI indicators.
///
/// Distinct from the general [SyncStatus] in OfflineManager — this focuses
/// on the exam submission lifecycle.
enum ExamSyncStatus {
  /// No active exam sync in progress.
  idle,

  /// Currently syncing exam data to Firestore.
  syncing,

  /// All exam data has been synced to the server.
  synced,

  /// An error occurred during exam sync.
  error,
}

class SyncOrchestrator {
  SyncOrchestrator._();
  static final SyncOrchestrator instance = SyncOrchestrator._();

  // ─── Dependencies ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SyncQueueService _syncQueue = SyncQueueService.instance;
  final OfflineExamService _offlineExam = OfflineExamService.instance;

  // ─── Streams & Controllers ─────────────────────────────────────────────
  StreamSubscription<ConnectivityStatus>? _connectivitySub;
  final _syncStatusController = StreamController<ExamSyncStatus>.broadcast();

  // ─── State ─────────────────────────────────────────────────────────────
  bool _isSyncing = false;
  ExamSyncStatus _currentStatus = ExamSyncStatus.idle;

  // ─── Public API ────────────────────────────────────────────────────────

  /// Stream of exam-specific sync status changes.
  Stream<ExamSyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Current exam sync status.
  ExamSyncStatus get currentStatus => _currentStatus;

  /// Whether a sync is currently in progress.
  bool get isSyncing => _isSyncing;

  /// Initializes the orchestrator.
  ///
  /// Must be called AFTER OfflineManager.enableOfflineMode() so that
  /// the enhanced processor replaces the base one.
  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivitySub = _connectivity.onStatusChange.listen((status) {
      if (status == ConnectivityStatus.online) {
        _onBackOnline();
      }
    });

    // Register the enhanced Firestore processor with the sync queue.
    // This REPLACES OfflineManager's basic processor with one that also
    // marks exam data as synced locally after successful writes.
    _syncQueue.registerProcessor(_processSyncEntry);

    // Check for any pending exam submissions from previous sessions
    await _recoverPendingSubmissions();

    _emitStatus(ExamSyncStatus.idle);

    debugPrint('[SyncOrchestrator] Initialized and listening for connectivity');
  }

  /// Force an immediate sync attempt (e.g., when user taps "sync now").
  ///
  /// Returns the number of queue entries successfully processed.
  Future<int> syncNow() async {
    if (_isSyncing) return 0;

    // If offline, can't sync
    if (_connectivity.isOffline) {
      debugPrint('[SyncOrchestrator] Cannot sync while offline');
      return 0;
    }

    _isSyncing = true;
    _emitStatus(ExamSyncStatus.syncing);

    try {
      // First, retry any previously failed entries
      await _syncQueue.retryFailed();

      // Then process the main queue
      final count = await _syncQueue.processQueue();

      // Clean up completed/dead-letter entries
      await _syncQueue.clearCompleted();

      // Check if there are still pending exam submissions
      final pendingSubmissions = _offlineExam.getPendingSubmissions();
      if (pendingSubmissions.isEmpty) {
        _emitStatus(ExamSyncStatus.synced);
      } else {
        // Still pending — likely still offline or errors
        _emitStatus(ExamSyncStatus.error);
      }

      debugPrint('[SyncOrchestrator] Sync complete — $count entries processed');
      return count;
    } catch (e) {
      debugPrint('[SyncOrchestrator] Sync failed: $e');
      _emitStatus(ExamSyncStatus.error);
      return 0;
    } finally {
      _isSyncing = false;
    }
  }

  /// Returns the count of pending exam submissions waiting to sync.
  int getPendingSubmissionCount() {
    return _offlineExam.getPendingSubmissionCount();
  }

  /// Returns the count of unsynced answers for a specific exam.
  int getUnsyncedAnswerCount({
    required String examInstanceId,
    required String studentId,
  }) {
    return _offlineExam.getUnsyncedAnswerCount(
      examInstanceId: examInstanceId,
      studentId: studentId,
    );
  }

  /// Disposes all resources. Call on app shutdown.
  void dispose() {
    _connectivitySub?.cancel();
    _syncStatusController.close();
    debugPrint('[SyncOrchestrator] Disposed');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private: Sync Processing
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enhanced sync processor that writes to Firestore AND marks exam
  /// data as synced locally after successful writes.
  ///
  /// This replaces the OfflineManager's basic processor to add
  /// exam-specific post-sync marking.
  Future<bool> _processSyncEntry(SyncQueueEntry entry) async {
    try {
      // Apply the write to Firestore
      await _applyFirestoreWrite(
        entry.collection,
        entry.docId,
        entry.operation,
        entry.data,
      );

      // If this was an exam-related write, mark it as synced locally
      if (entry.collection == 'exam_instances') {
        final studentId = entry.data['studentId'] as String?;
        if (studentId != null) {
          await _offlineExam.markExamSynced(
            examInstanceId: entry.docId,
            studentId: studentId,
          );
          debugPrint(
            '[SyncOrchestrator] Marked exam ${entry.docId} as synced '
            'for student $studentId',
          );
        }
      }

      return true;
    } on FirebaseException catch (e) {
      // Conflict detection — server wins by default
      if (e.code == 'cancelled' || e.code == 'aborted') {
        debugPrint(
          '[SyncOrchestrator] Conflict on ${entry.collection}/${entry.docId} '
          '— server wins',
        );
        // Server wins — still mark as synced to prevent retry loops
        if (entry.collection == 'exam_instances') {
          final studentId = entry.data['studentId'] as String?;
          if (studentId != null) {
            await _offlineExam.markExamSynced(
              examInstanceId: entry.docId,
              studentId: studentId,
            );
          }
        }
        return true; // Treat as success (discard local change)
      }
      debugPrint(
        '[SyncOrchestrator] Firestore error on ${entry.collection}/${entry.docId}: $e',
      );
      return false;
    } catch (e) {
      debugPrint(
        '[SyncOrchestrator] Failed to process ${entry.operation.name} '
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Private: Connectivity Handler
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onBackOnline() async {
    if (_isSyncing) return;

    debugPrint('[SyncOrchestrator] Back online — starting exam sync');
    await syncNow();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private: Recovery
  // ═══════════════════════════════════════════════════════════════════════════

  /// Recovers any pending exam submissions from previous sessions.
  ///
  /// Called during initialization to re-queue submissions that were saved
  /// locally but not yet synced (e.g., after an app crash).
  Future<void> _recoverPendingSubmissions() async {
    try {
      final pending = _offlineExam.getPendingSubmissions();
      if (pending.isEmpty) return;

      debugPrint(
        '[SyncOrchestrator] Found ${pending.length} pending submission(s) '
        'from previous session(s)',
      );

      // Re-queue each pending submission to ensure they're in the sync queue
      for (final submission in pending) {
        final examInstanceId =
            submission['examInstanceId'] as String? ??
            submission['docId'] as String?;
        final studentId = submission['studentId'] as String?;

        if (examInstanceId == null || studentId == null) continue;

        // Check if already in the sync queue (avoid duplicates)
        final queueEntries = _syncQueue.getPendingEntries();
        final alreadyQueued = queueEntries.any(
          (e) =>
              e.collection == 'exam_instances' && e.docId == examInstanceId,
        );

        if (!alreadyQueued) {
          await _syncQueue.enqueue(
            collection: 'exam_instances',
            docId: examInstanceId,
            operation: SyncOperation.update,
            data: {
              ...submission,
              'status': 'submitted',
              'recoveredAt': DateTime.now().toIso8601String(),
            },
          );
          debugPrint(
            '[SyncOrchestrator] Re-queued pending submission for exam '
            '$examInstanceId',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[SyncOrchestrator] Failed to recover pending submissions: $e',
      );
    }
  }

  // ─── Private: Status Emitter ──────────────────────────────────────────

  void _emitStatus(ExamSyncStatus status) {
    _currentStatus = status;
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }
}
