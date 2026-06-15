import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'sync_queue_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO OFFLINE EXAM SERVICE — Offline-first exam state manager
//
// Wraps the exam-taking experience with offline resilience:
//   - Every auto-save writes to a local Hive box FIRST (instant, never fails)
//   - Then attempts to push to Firestore via the SyncQueueService
//   - If offline, the write stays in the Hive queue until connectivity returns
//   - When connectivity is restored, all queued writes flush to Firestore
//   - Exam submissions are NEVER lost — they persist in Hive even if app crashes
//
// Hive boxes used:
//   'offline_exam_state'   — exam session state + submission flags
//   'offline_exam_answers' — individual answer snapshots
// ═══════════════════════════════════════════════════════════════════════════════

class OfflineExamService {
  OfflineExamService._();
  static final OfflineExamService instance = OfflineExamService._();

  // ─── Hive Box Names ───────────────────────────────────────────────────
  static const String _examStateBox = 'offline_exam_state';
  static const String _examAnswersBox = 'offline_exam_answers';

  // ─── Box References ───────────────────────────────────────────────────
  Box? _stateBox;
  Box? _answersBox;

  // ─── Initialization ───────────────────────────────────────────────────

  /// Opens the Hive boxes used by this service.
  /// Must be called after Hive.initFlutter().
  Future<void> initialize() async {
    _stateBox = await Hive.openBox(_examStateBox);
    _answersBox = await Hive.openBox(_examAnswersBox);
    debugPrint(
      '[OfflineExamService] Initialized — '
      'state entries: ${_stateBox!.length}, '
      'answer entries: ${_answersBox!.length}',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Exam Session State (local-first)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save exam session state locally (instant, never fails).
  /// This is called on every auto-save during an exam.
  ///
  /// The state is persisted to Hive immediately, then enqueued in the
  /// SyncQueueService for background Firestore sync.
  Future<void> saveExamState({
    required String examInstanceId,
    required String studentId,
    required Map<String, dynamic> state,
  }) async {
    _ensureInitialized();

    final key = '${studentId}_$examInstanceId';
    await _stateBox!.put(key, {
      ...state,
      'lastSavedAt': DateTime.now().toIso8601String(),
      'savedLocally': true,
      'syncedToServer': false,
    });

    // Also enqueue for background sync
    await SyncQueueService.instance.enqueue(
      collection: 'exam_instances',
      docId: examInstanceId,
      operation: SyncOperation.update,
      data: state,
    );

    debugPrint(
      '[OfflineExamService] Exam state saved locally for $examInstanceId',
    );
  }

  /// Get locally saved exam state (returns null if not found).
  ///
  /// This reads from Hive only — no network call.
  Map<String, dynamic>? getExamState({
    required String examInstanceId,
    required String studentId,
  }) {
    _ensureInitialized();

    final key = '${studentId}_$examInstanceId';
    final data = _stateBox?.get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Answer State (local-first)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save a single answer locally (instant, never fails).
  ///
  /// Each answer is stored individually so that partial progress
  /// is preserved even if the app crashes mid-exam.
  Future<void> saveAnswer({
    required String examInstanceId,
    required String questionId,
    required String studentId,
    required Map<String, dynamic> answer,
  }) async {
    _ensureInitialized();

    final key = '${studentId}_${examInstanceId}_$questionId';
    await _answersBox!.put(key, {
      ...answer,
      'questionId': questionId,
      'lastSavedAt': DateTime.now().toIso8601String(),
      'syncedToServer': false,
    });

    debugPrint(
      '[OfflineExamService] Answer saved locally for question $questionId '
      'in exam $examInstanceId',
    );
  }

  /// Get a single saved answer by question ID.
  ///
  /// Returns null if the question hasn't been answered yet.
  Map<String, dynamic>? getAnswer({
    required String examInstanceId,
    required String questionId,
    required String studentId,
  }) {
    _ensureInitialized();

    final key = '${studentId}_${examInstanceId}_$questionId';
    final data = _answersBox?.get(key);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Get all saved answers for an exam instance.
  ///
  /// Returns answers in the order they were stored (key iteration order).
  List<Map<String, dynamic>> getAnswers({
    required String examInstanceId,
    required String studentId,
  }) {
    _ensureInitialized();

    final prefix = '${studentId}_${examInstanceId}_';
    final answers = <Map<String, dynamic>>[];

    for (final key in _answersBox!.keys) {
      if ((key as String).startsWith(prefix)) {
        final data = _answersBox!.get(key);
        if (data != null) {
          answers.add(Map<String, dynamic>.from(data as Map));
        }
      }
    }

    return answers;
  }

  /// Get the count of answered questions for an exam instance.
  int getAnswerCount({
    required String examInstanceId,
    required String studentId,
  }) {
    _ensureInitialized();

    final prefix = '${studentId}_${examInstanceId}_';
    int count = 0;
    for (final key in _answersBox!.keys) {
      if ((key as String).startsWith(prefix)) {
        count++;
      }
    }
    return count;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Exam Submission (local-first, never lost)
  //
  // This is the CRITICAL path. The submission MUST never be lost.
  // The three-step process guarantees durability:
  //   1. Write to Hive (instant, guaranteed)
  //   2. Mark exam state as submitted locally
  //   3. Enqueue for high-priority background sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Submit exam — writes locally first, then syncs when online.
  ///
  /// This is the CRITICAL path. The submission MUST never be lost.
  /// Even if the app crashes immediately after this call, the submission
  /// will be recovered on next launch and synced to the server.
  Future<void> submitExam({
    required String examInstanceId,
    required String studentId,
    required Map<String, dynamic> submissionData,
  }) async {
    _ensureInitialized();

    final submissionKey = '${studentId}_${examInstanceId}_submission';
    final now = DateTime.now().toIso8601String();

    // 1. Write to local Hive (instant, guaranteed)
    await _stateBox!.put(submissionKey, {
      ...submissionData,
      'studentId': studentId,
      'examInstanceId': examInstanceId,
      'submittedAt': now,
      'submittedLocally': true,
      'syncedToServer': false,
    });

    // 2. Mark exam state as submitted locally
    await saveExamState(
      examInstanceId: examInstanceId,
      studentId: studentId,
      state: {
        ...submissionData,
        'status': 'submitted_locally',
      },
    );

    // 3. Enqueue for sync — high priority
    await SyncQueueService.instance.enqueue(
      collection: 'exam_instances',
      docId: examInstanceId,
      operation: SyncOperation.update,
      data: {
        ...submissionData,
        'studentId': studentId,
        'status': 'submitted',
        'submittedAt': now,
      },
    );

    debugPrint(
      '[OfflineExamService] Exam $examInstanceId submitted locally '
      'and enqueued for sync',
    );
  }

  /// Check if exam was submitted locally but not yet synced to server.
  ///
  /// Used on app startup to detect pending submissions that need to
  /// be flushed to Firestore.
  bool isExamPendingSubmission({
    required String examInstanceId,
    required String studentId,
  }) {
    _ensureInitialized();

    final key = '${studentId}_${examInstanceId}_submission';
    final submission = _stateBox?.get(key);
    if (submission == null) return false;
    return (submission as Map)['syncedToServer'] == false;
  }

  /// Mark exam submission as synced to server.
  ///
  /// Called by the SyncOrchestrator after a successful Firestore write.
  /// Updates both the submission record and the exam state.
  Future<void> markExamSynced({
    required String examInstanceId,
    required String studentId,
  }) async {
    _ensureInitialized();

    // Mark submission as synced
    final submissionKey = '${studentId}_${examInstanceId}_submission';
    final submission = _stateBox?.get(submissionKey);
    if (submission != null) {
      await _stateBox!.put(submissionKey, {
        ...Map<String, dynamic>.from(submission as Map),
        'syncedToServer': true,
      });
    }

    // Also mark exam state as synced
    final stateKey = '${studentId}_$examInstanceId';
    final state = _stateBox?.get(stateKey);
    if (state != null) {
      await _stateBox!.put(stateKey, {
        ...Map<String, dynamic>.from(state as Map),
        'syncedToServer': true,
      });
    }

    // Mark all answers as synced
    final prefix = '${studentId}_${examInstanceId}_';
    for (final key in _answersBox!.keys.toList()) {
      if ((key as String).startsWith(prefix)) {
        final answer = _answersBox!.get(key);
        if (answer != null) {
          await _answersBox!.put(key, {
            ...Map<String, dynamic>.from(answer as Map),
            'syncedToServer': true,
          });
        }
      }
    }

    debugPrint(
      '[OfflineExamService] Exam $examInstanceId marked as synced to server',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Cleanup & Housekeeping
  // ═══════════════════════════════════════════════════════════════════════════

  /// Clear local exam data after successful sync (housekeeping).
  ///
  /// Only call this after confirming the exam data is fully synced
  /// to the server. Removes state, submission flag, and all answers.
  Future<void> clearExamState({
    required String examInstanceId,
    required String studentId,
  }) async {
    _ensureInitialized();

    final stateKey = '${studentId}_$examInstanceId';
    final submissionKey = '${studentId}_${examInstanceId}_submission';
    await _stateBox?.delete(stateKey);
    await _stateBox?.delete(submissionKey);

    // Clear answers
    final prefix = '${studentId}_${examInstanceId}_';
    final keysToDelete = <dynamic>[];
    for (final key in _answersBox!.keys) {
      if ((key as String).startsWith(prefix)) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      await _answersBox!.delete(key);
    }

    debugPrint(
      '[OfflineExamService] Cleared local data for exam $examInstanceId '
      '(${keysToDelete.length} answers removed)',
    );
  }

  /// Get all pending (unsynced) exam submissions.
  ///
  /// Used by the SyncOrchestrator to detect submissions that need
  /// to be flushed to Firestore (e.g., after a crash recovery).
  List<Map<String, dynamic>> getPendingSubmissions() {
    _ensureInitialized();

    final pending = <Map<String, dynamic>>[];
    for (final key in _stateBox!.keys) {
      if ((key as String).endsWith('_submission')) {
        final data = _stateBox!.get(key);
        if (data != null) {
          final map = Map<String, dynamic>.from(data as Map);
          if (map['syncedToServer'] == false) {
            pending.add(map);
          }
        }
      }
    }
    return pending;
  }

  /// Get count of unsynced answers for an exam.
  ///
  /// Useful for showing a "X answers pending sync" indicator.
  int getUnsyncedAnswerCount({
    required String examInstanceId,
    required String studentId,
  }) {
    _ensureInitialized();

    final prefix = '${studentId}_${examInstanceId}_';
    int count = 0;
    for (final key in _answersBox!.keys) {
      if ((key as String).startsWith(prefix)) {
        final data = _answersBox!.get(key);
        if (data != null) {
          final map = Map<String, dynamic>.from(data as Map);
          if (map['syncedToServer'] == false) {
            count++;
          }
        }
      }
    }
    return count;
  }

  /// Get count of total pending (unsynced) exam submissions across all exams.
  int getPendingSubmissionCount() {
    _ensureInitialized();

    int count = 0;
    for (final key in _stateBox!.keys) {
      if ((key as String).endsWith('_submission')) {
        final data = _stateBox!.get(key);
        if (data != null) {
          final map = Map<String, dynamic>.from(data as Map);
          if (map['syncedToServer'] == false) {
            count++;
          }
        }
      }
    }
    return count;
  }

  /// Get all exam instance IDs that have pending local data for a student.
  List<String> getPendingExamIds({required String studentId}) {
    _ensureInitialized();

    final examIds = <String>[];
    final prefix = '${studentId}_';

    for (final key in _stateBox!.keys) {
      final keyStr = key as String;
      if (keyStr.startsWith(prefix) && !keyStr.endsWith('_submission')) {
        // Extract examInstanceId from key: "{studentId}_{examInstanceId}"
        final examId = keyStr.substring(prefix.length);
        if (examId.isNotEmpty) {
          examIds.add(examId);
        }
      }
    }

    return examIds;
  }

  // ─── Disposal ─────────────────────────────────────────────────────────

  /// Closes the Hive boxes. Call only on app shutdown.
  Future<void> dispose() async {
    await _stateBox?.close();
    _stateBox = null;
    await _answersBox?.close();
    _answersBox = null;
    debugPrint('[OfflineExamService] Disposed');
  }

  // ─── Private Helpers ──────────────────────────────────────────────────

  void _ensureInitialized() {
    if (_stateBox == null || !_stateBox!.isOpen) {
      throw StateError(
        'OfflineExamService not initialized. Call initialize() first.',
      );
    }
    if (_answersBox == null || !_answersBox!.isOpen) {
      throw StateError(
        'OfflineExamService not initialized. Call initialize() first.',
      );
    }
  }
}
