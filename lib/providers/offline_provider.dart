import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/connectivity_service.dart';
import '../core/services/offline_manager.dart';
import '../core/services/cache_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO OFFLINE PROVIDERS — Riverpod providers for offline mode
//
// Provides connectivity status, sync state, and cache access to the
// widget tree via Riverpod. Follows the app's functional provider pattern.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Connectivity Service Provider ─────────────────────────────────────────

/// Provides the singleton ConnectivityService instance.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService.instance;
});

// ─── Connectivity Status Stream ────────────────────────────────────────────

/// Stream of connectivity status changes.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onStatusChange;
});

// ─── Is Online Provider ────────────────────────────────────────────────────

/// Whether the device is currently online.
/// Derived from [connectivityStatusProvider].
final isOnlineProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(connectivityStatusProvider);
  return statusAsync.when(
    data: (status) =>
        status == ConnectivityStatus.online ||
        status == ConnectivityStatus.poor,
    loading: () => true, // Assume online while loading
    error: (_, __) => true, // Assume online on error
  );
});

// ─── Offline Manager Provider ──────────────────────────────────────────────

/// Provides the singleton OfflineManager instance.
final offlineManagerProvider = Provider<OfflineManager>((ref) {
  return OfflineManager.instance;
});

// ─── Pending Writes Count Stream ───────────────────────────────────────────

/// Stream of pending writes count (for UI badges).
final pendingWritesCountProvider = StreamProvider<int>((ref) {
  final manager = ref.watch(offlineManagerProvider);
  return manager.pendingWritesCount;
});

// ─── Sync Status Stream ────────────────────────────────────────────────────

/// Stream of sync status changes.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final manager = ref.watch(offlineManagerProvider);
  return manager.syncStatus;
});

// ─── Cache Service Provider ────────────────────────────────────────────────

/// Provides the singleton CacheService instance.
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService.instance;
});

// ─── Current Pending Writes Count ──────────────────────────────────────────

/// Convenience provider that gives the latest pending writes count as an int.
/// Returns 0 if still loading or on error.
final currentPendingWritesProvider = Provider<int>((ref) {
  final countAsync = ref.watch(pendingWritesCountProvider);
  return countAsync.when(
    data: (count) => count,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ─── Current Sync Status ───────────────────────────────────────────────────

/// Convenience provider that gives the current sync status.
/// Returns SyncStatus.idle if still loading or on error.
final currentSyncStatusProvider = Provider<SyncStatus>((ref) {
  final statusAsync = ref.watch(syncStatusProvider);
  return statusAsync.when(
    data: (status) => status,
    loading: () => SyncStatus.idle,
    error: (_, __) => SyncStatus.idle,
  );
});
