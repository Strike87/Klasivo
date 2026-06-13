/// Abstract interface for exam security operations.
///
/// Implementations:
/// - [ExamSecurityService] — production (uses MethodChannel + SystemChrome)
/// - [MockExamSecurityService] — testing (no-ops with recorded violations)
///
/// Usage: Inject [IExamSecurityService] via Riverpod provider.
/// Legacy singleton call-sites (`ExamSecurityService().enableAll()`) still work.
abstract class IExamSecurityService {
  bool get isLockdownActive;

  Future<void> enableScreenshotProtection();
  Future<void> disableScreenshotProtection();
  Future<void> lockPortrait();
  Future<void> unlockOrientation();
  Future<void> enterFullScreen();
  Future<void> exitFullScreen();
  void startClipboardMonitoring();
  void stopClipboardMonitoring();
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  });
  Future<void> exitLockdownMode();
  void reportViolation(String type, {String? details});
  Map<String, bool> getLockdownStatus();
  Future<void> enableAll();
  Future<void> disableAll();
}
