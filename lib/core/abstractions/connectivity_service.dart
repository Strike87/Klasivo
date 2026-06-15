/// Connectivity status levels.
enum ConnectivityStatus {
  /// Device has a stable connection.
  online,

  /// Device has no connectivity — reads served from cache, writes queued.
  offline,

  /// Device has connectivity but latency is high.
  poor,
}

/// Abstract interface for connectivity monitoring.
///
/// Provides the current connectivity status and a real-time stream of
/// status changes. Implementations may use DNS lookups, Firestore metadata,
/// or controllable state for testing.
abstract class IConnectivityService {
  /// The current connectivity status.
  ConnectivityStatus get currentStatus;

  /// A broadcast stream of connectivity status changes.
  Stream<ConnectivityStatus> get statusStream;

  /// Manually trigger a connectivity check.
  Future<void> checkNow();

  /// Clean up resources (timers, subscriptions, stream controllers).
  void dispose();
}
