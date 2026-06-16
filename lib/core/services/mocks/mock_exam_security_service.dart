import '../interfaces/i_exam_security_service.dart';

/// Mock implementation of [IExamSecurityService] that does nothing.
///
/// Suitable for unit-testing widgets and view-models without a
/// real device or platform channel.  Exposes internal state for
/// test assertions.
class MockExamSecurityService implements IExamSecurityService {
  bool _isLockdownActive = false;
  final List<Map<String, String>> _violations = [];

  /// Violations recorded via [reportViolation].
  List<Map<String, String>> get violations => List.unmodifiable(_violations);

  @override
  bool get isLockdownActive => _isLockdownActive;

  @override
  Future<void> enableScreenshotProtection() async {}

  @override
  Future<void> disableScreenshotProtection() async {}

  @override
  Future<void> lockPortrait() async {}

  @override
  Future<void> unlockOrientation() async {}

  @override
  Future<void> enterFullScreen() async {}

  @override
  Future<void> exitFullScreen() async {}

  @override
  void startClipboardMonitoring() {}

  @override
  void stopClipboardMonitoring() {}

  @override
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  }) async {
    _isLockdownActive = true;
  }

  @override
  Future<void> exitLockdownMode() async {
    _isLockdownActive = false;
  }

  @override
  void reportViolation(String type, {String? details}) {
    _violations.add({'type': type, 'details': details ?? ''});
  }

  @override
  Map<String, bool> getLockdownStatus() {
    return {
      'screenshotProtection': _isLockdownActive,
      'portraitLock': _isLockdownActive,
      'fullScreen': _isLockdownActive,
      'clipboardMonitoring': false,
    };
  }

  @override
  Future<void> enableAll() async {
    _isLockdownActive = true;
  }

  @override
  Future<void> disableAll() async {
    _isLockdownActive = false;
  }

  /// Reset all internal state. Useful between test cases.
  void reset() {
    _isLockdownActive = false;
    _violations.clear();
  }
}
