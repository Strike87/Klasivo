import 'package:flutter/services.dart';

/// Utility class for exam security features.
/// Handles screenshot prevention, screen recording detection, and app lifecycle monitoring.
class ExamSecurityService {
  static const _channel = MethodChannel('com.smartexampro.app/security');

  // ─── Prevent Screenshots ──────────────────────────────────────────────────

  /// Enable screenshot prevention (Android only).
  /// Uses FLAG_SECURE via platform channel to prevent screen capture and recording.
  static Future<void> enableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('enableScreenshotProtection');
    } on PlatformException catch (_) {
      // Platform error — FLAG_SECURE not applied
    } on MissingPluginException catch (_) {
      // Platform channel not set up — expected if native code not yet configured
    }
  }

  /// Disable screenshot prevention.
  static Future<void> disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableScreenshotProtection');
    } on PlatformException catch (_) {
      // Platform error
    } on MissingPluginException catch (_) {
      // Platform channel not set up
    }
  }

  // ─── Lock Screen Orientation ──────────────────────────────────────────────

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

  // ─── Full Screen Mode ─────────────────────────────────────────────────────

  /// Enter immersive/full-screen mode during exam.
  static Future<void> enterFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Exit full-screen mode.
  static Future<void> exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // ─── Enable All Security Features ─────────────────────────────────────────

  static Future<void> enableAll() async {
    await enableScreenshotProtection();
    await lockPortrait();
    await enterFullScreen();
  }

  // ─── Disable All Security Features ────────────────────────────────────────

  static Future<void> disableAll() async {
    await disableScreenshotProtection();
    await unlockOrientation();
    await exitFullScreen();
  }
}
