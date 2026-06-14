import 'dart:async';

import '../connectivity_service.dart';
import '../../services/connectivity_service.dart' as native;

/// Production implementation of [IConnectivityService] that delegates to
/// the singleton [native.ConnectivityService.instance].
class ConnectivityServiceImpl implements IConnectivityService {
  final native.ConnectivityService _delegate =
      native.ConnectivityService.instance;

  @override
  ConnectivityStatus get currentStatus {
    // The existing service uses its own ConnectivityStatus enum.
    // We map it to our abstraction's enum by name.
    return ConnectivityStatus.values.firstWhere(
      (e) => e.name == _delegate.currentStatus.name,
      orElse: () => ConnectivityStatus.online,
    );
  }

  @override
  Stream<ConnectivityStatus> get statusStream {
    return _delegate.onStatusChange.map((nativeStatus) {
      return ConnectivityStatus.values.firstWhere(
        (e) => e.name == nativeStatus.name,
        orElse: () => ConnectivityStatus.online,
      );
    });
  }

  @override
  Future<void> checkNow() async {
    // The existing service does not expose a public "checkNow" method.
    // Trigger a status re-evaluation by calling startMonitoring which
    // performs an immediate ping check. If monitoring is already active
    // this is safe to call again — it restarts the periodic timer.
    await _delegate.startMonitoring();
  }

  @override
  void dispose() {
    _delegate.dispose();
  }
}
