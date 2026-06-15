import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Centralized performance tracing service for Klasivo.
///
/// Wraps Firebase Performance SDK with convenience methods for tracing
/// Firestore operations, authentication flows, and app startup.
///
/// Usage:
///   final trace = PerformanceTraceService.instance;
///   await trace.traceOperation('exam_create', () async {
///     await examService.createExam(...);
///   });
class PerformanceTraceService {
  PerformanceTraceService._();
  static final PerformanceTraceService instance = PerformanceTraceService._();

  final FirebasePerformance _performance = FirebasePerformance.instance;
  bool _initialized = false;
  bool _enabled = true;

  /// Whether performance monitoring is enabled.
  /// Disabled automatically in debug mode unless explicitly overridden.
  bool get isEnabled => _enabled && _initialized;

  /// Initialize Firebase Performance monitoring.
  Future<void> initialize({bool? forceEnable}) async {
    if (_initialized) return;

    try {
      // In debug mode, performance monitoring is disabled by default
      // unless explicitly enabled via forceEnable
      if (kDebugMode && forceEnable != true) {
        _enabled = false;
        debugPrint('[PerformanceTrace] Disabled in debug mode (set forceEnable=true to override)');
      } else {
        await _performance.setPerformanceCollectionEnabled(true);
        _enabled = true;
        debugPrint('[PerformanceTrace] Performance monitoring enabled');
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[PerformanceTrace] Initialization failed: $e');
      _enabled = false;
      _initialized = true; // Mark as initialized to prevent retry loop
    }
  }

  /// Disable performance monitoring at runtime.
  Future<void> disable() async {
    _enabled = false;
    try {
      await _performance.setPerformanceCollectionEnabled(false);
    } catch (_) {}
    debugPrint('[PerformanceTrace] Performance monitoring disabled');
  }

  // ─── Trace Wrappers ──────────────────────────────────────────────────

  /// Trace an async operation with a named trace.
  ///
  /// Automatically starts/stops a Firebase Performance trace and records
  /// duration. Optional [attributes] are added as trace attributes.
  Future<T> traceOperation<T>(
    String name,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
    Map<String, int>? metrics,
  }) async {
    if (!isEnabled) {
      return await operation();
    }

    final trace = _performance.newTrace(name);
    try {
      trace.start();
      attributes?.forEach((key, value) => trace.putAttribute(key, value));
      final result = await operation();
      metrics?.forEach((key, value) => trace.incrementMetric(key, value));
      trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('error', e.toString().substring(0, (e.toString().length).clamp(0, 100)));
      trace.stop();
      rethrow;
    }
  }

  /// Trace a Firestore read operation.
  Future<T> traceFirestoreRead<T>(
    String collection,
    String operation,
    Future<T> Function() read, {
    String? docId,
    Map<String, String>? extraAttributes,
  }) async {
    return traceOperation<T>(
      'firestore_read_$operation',
      read,
      attributes: {
        'collection': collection,
        if (docId != null) 'doc_id': docId,
        ...?extraAttributes,
      },
    );
  }

  /// Trace a Firestore write operation.
  Future<T> traceFirestoreWrite<T>(
    String collection,
    String operation,
    Future<T> Function() write, {
    String? docId,
    Map<String, String>? extraAttributes,
  }) async {
    return traceOperation<T>(
      'firestore_write_$operation',
      write,
      attributes: {
        'collection': collection,
        if (docId != null) 'doc_id': docId,
        ...?extraAttributes,
      },
    );
  }

  /// Trace an authentication operation.
  Future<T> traceAuth<T>(
    String operation,
    Future<T> Function() authOp, {
    Map<String, String>? extraAttributes,
  }) async {
    return traceOperation<T>(
      'auth_$operation',
      authOp,
      attributes: {
        'operation': operation,
        ...?extraAttributes,
      },
    );
  }

  /// Trace app startup with specific phases.
  Future<void> traceStartup(Future<void> Function() startupSequence) async {
    if (!isEnabled) {
      await startupSequence();
      return;
    }

    final trace = _performance.newTrace('app_startup');
    try {
      trace.start();
      trace.putAttribute('platform', defaultTargetPlatform.name);
      await startupSequence();
      trace.stop();
    } catch (e) {
      trace.putAttribute('error', 'startup_failed');
      trace.stop();
      rethrow;
    }
  }

  // ─── Startup Phase Tracing ───────────────────────────────────────────

  /// Create a trace for a specific startup phase.
  ///
  /// Returns the trace object — caller must call .start() and .stop().
  /// For convenience, use [traceStartupPhase] instead.
  Trace createStartupPhaseTrace(String phase) {
    final trace = _performance.newTrace('startup_$phase');
    return trace;
  }

  /// Trace a single startup phase.
  Future<T> traceStartupPhase<T>(String phase, Future<T> Function() phaseOp) async {
    if (!isEnabled) {
      return await phaseOp();
    }

    final trace = createStartupPhaseTrace(phase);
    try {
      trace.start();
      final result = await phaseOp();
      trace.stop();
      return result;
    } catch (e) {
      trace.putAttribute('error', 'phase_failed');
      trace.stop();
      rethrow;
    }
  }

  // ─── HTTP Metric ─────────────────────────────────────────────────────

  /// Trace an HTTP request.
  Future<HttpMetric> traceHttpRequest(
    String url,
    HttpMethod method,
  ) async {
    final metric = _performance.newHttpMetric(url, method);
    return metric;
  }

  // ─── Screen Tracing ──────────────────────────────────────────────────

  /// Trace screen rendering performance.
  Future<T> traceScreen<T>(
    String screenName,
    Future<T> Function() screenOp, {
    Map<String, String>? attributes,
  }) async {
    return traceOperation<T>(
      'screen_$screenName',
      screenOp,
      attributes: {
        'screen': screenName,
        ...?attributes,
      },
    );
  }

  // ─── Batch Operation Tracing ─────────────────────────────────────────

  /// Trace a batch Firestore operation (useful for bulk writes).
  Future<T> traceBatch<T>(
    String collection,
    int itemCount,
    Future<T> Function() batchOp, {
    String operation = 'batch_write',
  }) async {
    return traceOperation<T>(
      'firestore_batch_$operation',
      batchOp,
      attributes: {
        'collection': collection,
        'item_count': itemCount.toString(),
      },
    );
  }
}

// ─── Performance Trace Names (Constants) ─────────────────────────────────

/// Standardized trace names used across the app for consistent monitoring.
class PerformanceTraces {
  // Auth
  static const authRegister = 'auth_register';
  static const authLogin = 'auth_login';
  static const authLogout = 'auth_logout';
  static const authPasswordReset = 'auth_password_reset';
  static const authStudentCodeLogin = 'auth_student_code_login';

  // Exam Operations
  static const examCreate = 'exam_create';
  static const examUpdate = 'exam_update';
  static const examPublish = 'exam_publish';
  static const examDelete = 'exam_delete';
  static const examGetList = 'exam_get_list';
  static const examGetDetail = 'exam_get_detail';

  // Submission Operations
  static const submissionStart = 'submission_start';
  static const submissionSaveAnswer = 'submission_save_answer';
  static const submissionBulkSave = 'submission_bulk_save';
  static const submissionSubmit = 'submission_submit';
  static const submissionGrade = 'submission_grade';

  // Stats Operations
  static const statsRecalculate = 'stats_recalculate';
  static const statsGetPerformance = 'stats_get_performance';

  // Startup
  static const startupFirebase = 'startup_firebase';
  static const startupHive = 'startup_hive';
  static const startupOffline = 'startup_offline';
  static const startupImageCache = 'startup_image_cache';
  static const startupNotifications = 'startup_notifications';
  static const startupEnterprise = 'startup_enterprise';

  // Screens
  static const screenDashboard = 'screen_dashboard';
  static const screenExamList = 'screen_exam_list';
  static const screenExamTaking = 'screen_exam_taking';
  static const screenResults = 'screen_results';
  static const screenStudentList = 'screen_student_list';

  // Sync
  static const syncQueueProcess = 'sync_queue_process';
  static const syncForceSync = 'sync_force_sync';

  // Cache
  static const cacheImageLoad = 'cache_image_load';
  static const cacheInvalidate = 'cache_invalidate';
}
