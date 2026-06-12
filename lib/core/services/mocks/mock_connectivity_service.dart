import 'dart:async';

import '../interfaces/i_connectivity_service.dart';
import '../connectivity_service.dart' show ConnectivityStatus;

/// Mock implementation of [IConnectivityService] with a controllable
/// [setStatus] method for test scenarios.
class MockConnectivityService implements IConnectivityService {
  ConnectivityStatus _status = ConnectivityStatus.online;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  /// Programmatically change the connectivity status and emit to
  /// [statusStream].
  void setStatus(ConnectivityStatus status) {
    _status = status;
    _controller.add(status);
  }

  @override
  bool get isOnline => _status == ConnectivityStatus.online;

  @override
  bool get isOffline => _status == ConnectivityStatus.offline;

  @override
  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  @override
  ConnectivityStatus get currentStatus => _status;

  @override
  Future<void> startMonitoring() async {}

  @override
  Future<void> stopMonitoring() async {
    await _controller.close();
  }
}
