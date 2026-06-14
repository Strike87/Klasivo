import 'dart:async';
import '../connectivity_service.dart';

/// Mock implementation of [IConnectivityService] for testing.
///
/// The current status can be set directly via [setStatus], and the
/// [statusStream] will emit changes to all subscribers.
class MockConnectivityService implements IConnectivityService {
  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  /// Manually set the current connectivity status.
  /// Emits the new status on [statusStream].
  void setStatus(ConnectivityStatus status) {
    _currentStatus = status;
    if (!_controller.isClosed) {
      _controller.add(status);
    }
  }

  // ─── IConnectivityService ───────────────────────────────────────────────

  @override
  ConnectivityStatus get currentStatus => _currentStatus;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  Future<void> checkNow() async {
    // No-op in mock — status is controlled externally via [setStatus].
    // Re-emit current status so callers receive a value.
    if (!_controller.isClosed) {
      _controller.add(_currentStatus);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }

  // ─── Test Helpers ───────────────────────────────────────────────────────

  /// Simulate going online.
  void goOnline() => setStatus(ConnectivityStatus.online);

  /// Simulate going offline.
  void goOffline() => setStatus(ConnectivityStatus.offline);

  /// Simulate a poor connection.
  void goPoor() => setStatus(ConnectivityStatus.poor);

  /// Reset to default state (online).
  void reset() {
    _currentStatus = ConnectivityStatus.online;
  }
}
