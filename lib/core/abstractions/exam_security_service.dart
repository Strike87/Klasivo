/// Abstract interface for exam security services.
///
/// Provides lockdown mode, screenshot protection, orientation locking,
/// full-screen mode, clipboard monitoring, and violation reporting.
/// Implementations may wrap platform-specific native code or provide
/// mock behaviour for testing.
abstract class IExamSecurityService {
  /// Whether lockdown mode is currently active.
  bool get isLockdownActive;

  /// Enable screenshot prevention (Android FLAG_SECURE).
  Future<void> enableScreenshotProtection();

  /// Disable screenshot prevention.
  Future<void> disableScreenshotProtection();

  /// Lock device orientation to portrait during an exam.
  Future<void> lockPortrait();

  /// Unlock all device orientations.
  Future<void> unlockOrientation();

  /// Enter immersive / full-screen mode.
  Future<void> enterFullScreen();

  /// Exit full-screen mode and restore system UI.
  Future<void> exitFullScreen();

  /// Start periodic clipboard monitoring.
  /// Detected clipboard content triggers the violation callback.
  void startClipboardMonitoring();

  /// Stop clipboard monitoring.
  void stopClipboardMonitoring();

  /// Enter full lockdown mode:
  /// screenshot protection + portrait lock + full screen +
  /// clipboard monitoring + violation callback.
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  });

  /// Exit lockdown mode and restore normal device behaviour.
  Future<void> exitLockdownMode();

  /// Report a detected violation through the registered callback.
  void reportViolation(String type, {String? details});

  /// Returns a map of individual security feature states.
  Map<String, bool> getLockdownStatus();

  /// Enable all security features (legacy convenience API).
  Future<void> enableAll();

  /// Disable all security features (legacy convenience API).
  Future<void> disableAll();
}
