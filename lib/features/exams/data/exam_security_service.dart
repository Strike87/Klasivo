import 'package:flutter/services.dart';
import 'dart:async';

/// Enhanced exam security service with lockdown mode, screenshot detection,
/// clipboard monitoring, and comprehensive violation reporting.
class ExamSecurityService {
  static const _channel = MethodChannel('com.klasivo.app/security');

  // ─── Lockdown State ─────────────────────────────────────────────────────

  static bool _isLockdownActive = false;
  static bool get isLockdownActive => _isLockdownActive;

  // Violation callback for real-time reporting
  static void Function(String type, String? details)? _onViolationDetected;
  static Timer? _clipboardCheckTimer;

  // ══════════════════════════════════════════════════════════════════════════
  // SCREENSHOT PROTECTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Enable screenshot prevention (Android only).
  /// Uses FLAG_SECURE via platform channel to prevent screen capture and recording.
  static Future<void> enableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('enableScreenshotProtection');
    } on PlatformException catch (_) {
      // FLAG_SECURE not applied
    } on MissingPluginException catch (_) {
      // Platform channel not set up
    }
  }

  /// Disable screenshot prevention.
  static Future<void> disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableScreenshotProtection');
    } on PlatformException catch (_) {}
    on MissingPluginException catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCK SCREEN ORIENTATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Lock to portrait mode during exam.
  static Future<void> lockPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  /// Unlock all orientations.
  static Future<void> unlockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FULL SCREEN MODE
  // ══════════════════════════════════════════════════════════════════════════

  /// Enter immersive/full-screen mode during exam.
  static Future<void> enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Exit full-screen mode.
  static Future<void> exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLIPBOARD MONITORING
  // ══════════════════════════════════════════════════════════════════════════

  /// Start monitoring clipboard for copy/paste activity during exam
  static void startClipboardMonitoring() {
    _clipboardCheckTimer?.cancel();
    _clipboardCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.isNotEmpty) {
          // Log the event only — do NOT log clipboard content.
          // The clipboard may contain passwords, 2FA codes, or personal
          // messages copied before the exam; writing them to violations
          // would be a PII leak readable by staff.
          _onViolationDetected?.call(
            'clipboard_activity',
            'Clipboard activity detected — clipboard cleared.',
          );
          // Clear clipboard to prevent pasting
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {
        // Clipboard access may fail silently
      }
    });
  }

  /// Stop clipboard monitoring
  static void stopClipboardMonitoring() {
    _clipboardCheckTimer?.cancel();
    _clipboardCheckTimer = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENHANCED LOCKDOWN MODE
  // ══════════════════════════════════════════════════════════════════════════

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

    // Disable clipboard paste
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

  // ══════════════════════════════════════════════════════════════════════════
  // LEGACY COMPATIBILITY
  // ══════════════════════════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════════════════════════
  // VIOLATION REPORTING HELPERS
  // ══════════════════════════════════════════════════════════════════════════

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
}
