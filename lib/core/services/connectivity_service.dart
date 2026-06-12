import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO CONNECTIVITY SERVICE — Monitors network status for offline mode
//
// Uses Firestore ping + periodic health checks to determine connectivity.
// Debounces rapid status changes (500ms) to avoid UI flicker.
// Persists last known status to Hive for cold-start awareness.
// ═══════════════════════════════════════════════════════════════════════════════

/// Connectivity status levels.
enum ConnectivityStatus {
  /// Device has a stable connection to Firestore.
  online,

  /// Device has no connectivity — reads served from cache, writes queued.
  offline,

  /// Device has connectivity but latency is high (>2s round-trip).
  poor,
}

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  // ─── Dependencies ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Streams & Controllers ─────────────────────────────────────────────
  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription? _pingSubscription;
  Timer? _periodicTimer;

  // ─── State ─────────────────────────────────────────────────────────────
  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  ConnectivityStatus? _debouncedPending;
  Timer? _debounceTimer;

  // ─── Constants ─────────────────────────────────────────────────────────
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _poorThreshold = Duration(seconds: 2);
  static const String _hiveBox = AppConstants.authBox;
  static const String _lastStatusKey = 'last_connectivity_status';

  // ─── Public API ────────────────────────────────────────────────────────

  /// Stream of connectivity status changes (debounced).
  Stream<ConnectivityStatus> get onStatusChange => _statusController.stream;

  /// Current connectivity status.
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Whether the device is currently online (includes poor).
  bool get isOnline =>
      _currentStatus == ConnectivityStatus.online ||
      _currentStatus == ConnectivityStatus.poor;

  /// Whether the device is currently offline.
  bool get isOffline => _currentStatus == ConnectivityStatus.offline;

  /// Starts monitoring connectivity.
  ///
  /// Call once during app initialization (after Firebase is ready).
  Future<void> startMonitoring() async {
    // Restore last known status from Hive
    _restoreLastStatus();

    // Perform an initial connectivity check
    await _performPingCheck();

    // Start periodic ping every 30 seconds
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_pingInterval, (_) async {
      await _performPingCheck();
    });

    // Also listen to Firestore snapshot metadata for real-time detection
    _listenToFirestoreMetadata();

    debugPrint('[ConnectivityService] Monitoring started — status: $_currentStatus');
  }

  /// Stops monitoring and cleans up resources.
  void stopMonitoring() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _pingSubscription?.cancel();
    _pingSubscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    debugPrint('[ConnectivityService] Monitoring stopped');
  }

  /// Manually set the status (for testing or external signals).
  void updateStatus(ConnectivityStatus status) {
    _emitStatus(status);
  }

  // ─── Private Methods ───────────────────────────────────────────────────

  /// Restores the last known connectivity status from Hive.
  void _restoreLastStatus() {
    try {
      final box = Hive.box(_hiveBox);
      final saved = box.get(_lastStatusKey) as String?;
      if (saved != null) {
        _currentStatus = _parseStatus(saved);
        // Immediately emit so subscribers know the restored state
        _statusController.add(_currentStatus);
      }
    } catch (e) {
      debugPrint('[ConnectivityService] Failed to restore status: $e');
    }
  }

  /// Persists the current status to Hive.
  void _persistStatus(ConnectivityStatus status) {
    try {
      final box = Hive.box(_hiveBox);
      box.put(_lastStatusKey, status.name);
    } catch (e) {
      debugPrint('[ConnectivityService] Failed to persist status: $e');
    }
  }

  /// Performs a Firestore ping to check connectivity and latency.
  Future<void> _performPingCheck() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Attempt to fetch a lightweight document (Firestore health check)
      await _firestore.collection('.health_check').limit(1).get(
        const GetOptions(source: Source.server),
      );

      stopwatch.stop();
      final latency = stopwatch.elapsed;

      if (latency > _poorThreshold) {
        _emitStatus(ConnectivityStatus.poor);
      } else {
        _emitStatus(ConnectivityStatus.online);
      }
    } catch (e) {
      // Any error means we can't reach Firestore
      _emitStatus(ConnectivityStatus.offline);
    }
  }

  /// Listens to Firestore snapshot metadata for real-time online/offline detection.
  void _listenToFirestoreMetadata() {
    _pingSubscription?.cancel();

    // Listen to a lightweight snapshot to detect metadata changes
    _pingSubscription = _firestore
        .collection('.health_check')
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen(
      (snapshot) {
        final isFromCache = snapshot.metadata.isFromCache;
        final pendingWrites = snapshot.metadata.hasPendingWrites;

        if (isFromCache && !pendingWrites) {
          // Data is from cache — likely offline
          _emitStatus(ConnectivityStatus.offline);
        } else if (!isFromCache) {
          // Data is from server — online
          _emitStatus(ConnectivityStatus.online);
        }
        // If from cache with pending writes, we might be temporarily offline
        // but Firestore is still trying — don't change status yet
      },
      onError: (error) {
        // Stream error — likely offline
        _emitStatus(ConnectivityStatus.offline);
      },
    );
  }

  /// Emits a status change with debouncing.
  ///
  /// Rapid toggling between online/offline is common on poor connections.
  /// We debounce by 500ms to avoid UI flicker.
  void _emitStatus(ConnectivityStatus newStatus) {
    if (newStatus == _currentStatus && _debouncedPending == null) {
      return; // No change needed
    }

    _debouncedPending = newStatus;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (_debouncedPending != null && _debouncedPending != _currentStatus) {
        _currentStatus = _debouncedPending!;
        _persistStatus(_currentStatus);
        _statusController.add(_currentStatus);
        debugPrint('[ConnectivityService] Status changed → $_currentStatus');
      }
      _debouncedPending = null;
    });
  }

  /// Parses a saved status string back to enum.
  ConnectivityStatus _parseStatus(String name) {
    return ConnectivityStatus.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ConnectivityStatus.online,
    );
  }

  /// Disposes all resources. Call when the app is shutting down.
  void dispose() {
    stopMonitoring();
    _statusController.close();
  }
}
