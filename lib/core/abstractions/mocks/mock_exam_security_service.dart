import '../exam_security_service.dart';

/// Mock implementation of [IExamSecurityService] for testing.
///
/// All methods are no-ops or simple state trackers.
/// Violation reports are recorded in [violationLog] for assertions.
class MockExamSecurityService implements IExamSecurityService {
  bool _isLockdownActive = false;
  bool _screenshotProtectionEnabled = false;
  bool _portraitLocked = false;
  bool _fullScreenActive = false;
  bool _clipboardMonitoring = false;
  void Function(String type, String? details)? _onViolation;

  /// Recorded violation reports for test assertions.
  final List<_ViolationRecord> violationLog = [];

  // ─── IExamSecurityService ───────────────────────────────────────────────

  @override
  bool get isLockdownActive => _isLockdownActive;

  @override
  Future<void> enableScreenshotProtection() async {
    _screenshotProtectionEnabled = true;
  }

  @override
  Future<void> disableScreenshotProtection() async {
    _screenshotProtectionEnabled = false;
  }

  @override
  Future<void> lockPortrait() async {
    _portraitLocked = true;
  }

  @override
  Future<void> unlockOrientation() async {
    _portraitLocked = false;
  }

  @override
  Future<void> enterFullScreen() async {
    _fullScreenActive = true;
  }

  @override
  Future<void> exitFullScreen() async {
    _fullScreenActive = false;
  }

  @override
  void startClipboardMonitoring() {
    _clipboardMonitoring = true;
  }

  @override
  void stopClipboardMonitoring() {
    _clipboardMonitoring = false;
  }

  @override
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  }) async {
    _onViolation = onViolation;
    _isLockdownActive = true;
    _screenshotProtectionEnabled = true;
    _portraitLocked = true;
    _fullScreenActive = true;
    _clipboardMonitoring = true;
  }

  @override
  Future<void> exitLockdownMode() async {
    _isLockdownActive = false;
    _onViolation = null;
    _screenshotProtectionEnabled = false;
    _portraitLocked = false;
    _fullScreenActive = false;
    _clipboardMonitoring = false;
  }

  @override
  void reportViolation(String type, {String? details}) {
    violationLog.add(_ViolationRecord(type: type, details: details));
    _onViolation?.call(type, details);
  }

  @override
  Map<String, bool> getLockdownStatus() {
    return {
      'screenshotProtection': _screenshotProtectionEnabled,
      'portraitLock': _portraitLocked,
      'fullScreen': _fullScreenActive,
      'clipboardMonitoring': _clipboardMonitoring,
    };
  }

  @override
  Future<void> enableAll() async {
    await enterLockdownMode();
  }

  @override
  Future<void> disableAll() async {
    await exitLockdownMode();
  }

  // ─── Test Helpers ───────────────────────────────────────────────────────

  /// Reset all state and logs. Call in `setUp` or between tests.
  void reset() {
    _isLockdownActive = false;
    _screenshotProtectionEnabled = false;
    _portraitLocked = false;
    _fullScreenActive = false;
    _clipboardMonitoring = false;
    _onViolation = null;
    violationLog.clear();
  }
}

/// Internal record for violation reports.
class _ViolationRecord {
  final String type;
  final String? details;
  const _ViolationRecord({required this.type, this.details});

  @override
  String toString() => 'Violation($type${details != null ? ': $details' : ''})';
}
