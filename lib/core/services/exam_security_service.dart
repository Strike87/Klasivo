import 'package:flutter/services.dart';
import 'dart:async';
import 'interfaces/i_exam_security_service.dart';

/// Enhanced exam security service with lockdown mode, screenshot detection,
/// clipboard monitoring, and comprehensive violation reporting.
///
/// Implements [IExamSecurityService] for testability via dependency injection.
/// Uses a singleton factory, so call-sites can use either:
///   - DI:           `ref.read(examSecurityServiceProvider).enableAll()`
///   - Singleton:    `ExamSecurityService().enableAll()`
class ExamSecurityService implements IExamSecurityService {
  static const _channel = MethodChannel('com.klasivo.app/security');

  // ─── Singleton for DI ──────────────────────────────────────────────────

  static final ExamSecurityService _instance = ExamSecurityService._();
  factory ExamSecurityService() => _instance;
  ExamSecurityService._();

  // ─── Lockdown State ─────────────────────────────────────────────────────

  static bool _isLockdownActive = false;

  /// Static accessor for backward compatibility.
  static bool get isLockdownActiveStatic => _isLockdownActive;

  @override
  bool get isLockdownActive => _isLockdownActive;

  // Violation callback for real-time reporting
  static void Function(String type, String? details)? _onViolationDetected;
  static Timer? _clipboardCheckTimer;

  // ══════════════════════════════════════════════════════════════════════════
  // INSTANCE API — IExamSecurityService contract
  // ══════════════════════════════════════════════════════════════════════════

  /// Enable screenshot prevention (Android only).
  @override
  Future<void> enableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('enableScreenshotProtection');
    } on PlatformException catch (_) {} on MissingPluginException catch (_) {}
  }

  /// Disable screenshot prevention.
  @override
  Future<void> disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableScreenshotProtection');
    } on PlatformException catch (_) {} on MissingPluginException catch (_) {}
  }

  /// Lock to portrait mode during exam.
  @override
  Future<void> lockPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// Unlock all orientations.
  @override
  Future<void> unlockOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Enter immersive/full-screen mode during exam.
  @override
  Future<void> enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Exit full-screen mode.
  @override
  Future<void> exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Start monitoring clipboard for copy/paste activity during exam
  @override
  void startClipboardMonitoring() {
    _clipboardCheckTimer?.cancel();
    _clipboardCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.isNotEmpty) {
          _onViolationDetected?.call(
            'clipboard_activity',
            'Clipboard contains text: "${data.text!.substring(0, data.text!.length > 50 ? 50 : data.text!.length)}..."',
          );
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
  }

  /// Stop clipboard monitoring
  @override
  void stopClipboardMonitoring() {
    _clipboardCheckTimer?.cancel();
    _clipboardCheckTimer = null;
  }

  /// Enter full lockdown mode: screenshot protection + portrait lock +
  /// full screen + clipboard monitoring + violation callback
  @override
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  }) async {
    _onViolationDetected = onViolation;
    _isLockdownActive = true;
    await enableScreenshotProtection();
    await lockPortrait();
    await enterFullScreen();
    startClipboardMonitoring();
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  /// Exit lockdown mode and restore normal device behavior
  @override
  Future<void> exitLockdownMode() async {
    _isLockdownActive = false;
    _onViolationDetected = null;
    await disableScreenshotProtection();
    await unlockOrientation();
    await exitFullScreen();
    stopClipboardMonitoring();
  }

  /// Enable all security features (legacy API)
  @override
  Future<void> enableAll() async {
    await enableScreenshotProtection();
    await lockPortrait();
    await enterFullScreen();
  }

  /// Disable all security features (legacy API)
  @override
  Future<void> disableAll() async {
    await exitLockdownMode();
  }

  /// Report a detected violation through the callback
  @override
  void reportViolation(String type, {String? details}) {
    _onViolationDetected?.call(type, details);
  }

  /// Get lockdown status summary for display
  @override
  Map<String, bool> getLockdownStatus() {
    return {
      'screenshotProtection': _isLockdownActive,
      'portraitLock': _isLockdownActive,
      'fullScreen': _isLockdownActive,
      'clipboardMonitoring': _clipboardCheckTimer != null,
    };
  }
}
