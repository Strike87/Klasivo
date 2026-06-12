import 'package:flutter/services.dart';
import 'dart:async';
import 'interfaces/i_exam_security_service.dart';

/// Enhanced exam security service with lockdown mode, screenshot detection,
/// clipboard monitoring, and comprehensive violation reporting.
///
/// Implements [IExamSecurityService] for testability via dependency injection.
/// Existing static call-sites (e.g. `ExamSecurityService.enableAll()`) continue
/// to work unchanged; new code should prefer injecting [IExamSecurityService].
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
  // STATIC API — Backward-compatible static methods
  // ══════════════════════════════════════════════════════════════════════════

  /// Enable screenshot prevention (Android only).
  static Future<void> enableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('enableScreenshotProtection');
    } on PlatformException catch (_) {} on MissingPluginException catch (_) {}
  }

  /// Disable screenshot prevention.
  static Future<void> disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableScreenshotProtection');
    } on PlatformException catch (_) {} on MissingPluginException catch (_) {}
  }

  /// Lock to portrait mode during exam.
  static Future<void> lockPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// Unlock all orientations.
  static Future<void> unlockOrientation() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Enter immersive/full-screen mode during exam.
  static Future<void> enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Exit full-screen mode.
  static Future<void> exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Start monitoring clipboard for copy/paste activity during exam
  static void startClipboardMonitoring() {
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
  static void stopClipboardMonitoring() {
    _clipboardCheckTimer?.cancel();
    _clipboardCheckTimer = null;
  }

  /// Enter full lockdown mode: screenshot protection + portrait lock +
  /// full screen + clipboard monitoring + violation callback
  static Future<void> enterLockdownMode({
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
  static Future<void> exitLockdownMode() async {
    _isLockdownActive = false;
    _onViolationDetected = null;
    await disableScreenshotProtection();
    await unlockOrientation();
    await exitFullScreen();
    stopClipboardMonitoring();
  }

  /// Enable all security features (legacy API)
  static Future<void> enableAll() async {
    await enableScreenshotProtection();
    await lockPortrait();
    await enterFullScreen();
  }

  /// Disable all security features (legacy API)
  static Future<void> disableAll() async {
    await exitLockdownMode();
  }

  /// Report a detected violation through the callback
  static void reportViolation(String type, {String? details}) {
    _onViolationDetected?.call(type, details);
  }

  /// Get lockdown status summary for display
  static Map<String, bool> getLockdownStatus() {
    return {
      'screenshotProtection': _isLockdownActive,
      'portraitLock': _isLockdownActive,
      'fullScreen': _isLockdownActive,
      'clipboardMonitoring': _clipboardCheckTimer != null,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INSTANCE API — IExamSecurityService contract
  //
  // Each instance method delegates to the static implementation.
  // Use these via DI: `ref.read(examSecurityProvider).enableAll()`
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> enableScreenshotProtection() async =>
      await ExamSecurityService.enableScreenshotProtection();

  @override
  Future<void> disableScreenshotProtection() async =>
      await ExamSecurityService.disableScreenshotProtection();

  @override
  Future<void> lockPortrait() async =>
      await ExamSecurityService.lockPortrait();

  @override
  Future<void> unlockOrientation() async =>
      await ExamSecurityService.unlockOrientation();

  @override
  Future<void> enterFullScreen() async =>
      await ExamSecurityService.enterFullScreen();

  @override
  Future<void> exitFullScreen() async =>
      await ExamSecurityService.exitFullScreen();

  @override
  void startClipboardMonitoring() =>
      ExamSecurityService.startClipboardMonitoring();

  @override
  void stopClipboardMonitoring() =>
      ExamSecurityService.stopClipboardMonitoring();

  @override
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  }) async =>
      await ExamSecurityService.enterLockdownMode(onViolation: onViolation);

  @override
  Future<void> exitLockdownMode() async =>
      await ExamSecurityService.exitLockdownMode();

  @override
  void reportViolation(String type, {String? details}) =>
      ExamSecurityService.reportViolation(type, details: details);

  @override
  Map<String, bool> getLockdownStatus() =>
      ExamSecurityService.getLockdownStatus();

  @override
  Future<void> enableAll() async => await ExamSecurityService.enableAll();

  @override
  Future<void> disableAll() async => await ExamSecurityService.disableAll();
}
