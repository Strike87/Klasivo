import '../connectivity_service.dart' show ConnectivityStatus;

/// Abstract interface for connectivity monitoring.
///
/// Implementations may use Firestore pings, platform connectivity
/// plugins, or a controllable mock for testing.
abstract class IConnectivityService {
  /// Whether the device currently has connectivity (online or poor).
  bool get isOnline;

  /// Whether the device is currently offline.
  bool get isOffline;

  /// Stream of connectivity status changes.
  Stream<ConnectivityStatus> get statusStream;

  /// The current connectivity status.
  ConnectivityStatus get currentStatus;

  /// Start monitoring connectivity.
  Future<void> startMonitoring();

  /// Stop monitoring and clean up resources.
  Future<void> stopMonitoring();
}
