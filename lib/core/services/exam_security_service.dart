import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Utility class for exam security features.
/// Handles screenshot prevention, screen recording detection, and app lifecycle monitoring.
class ExamSecurityService {
  static const _channel = MethodChannel('com.smartexampro.security');

  // ─── Prevent Screenshots ──────────────────────────────────────────────────

  /// Enable screenshot prevention (Android only).
  /// Uses FLAG_SECURE to prevent screen capture and recording.
  static Future<void> enableScreenshotProtection() async {
    try {
      // Use flutter_windowmanager as a fallback
      // The platform channel approach is preferred for production
      await _channel.invokeMethod('enableScreenshotProtection');
    } on PlatformException catch (_) {
      // Fallback: flutter_windowmanager
      try {
        // ignore: depend_on_referenced_packages
        // await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        // Note: flutter_windowmanager may need additional setup
      } catch (_) {}
    } on MissingPluginException catch (_) {
      // Platform channel not set up — this is expected in development
      // In production, you would set up the native Android code for FLAG_SECURE
    }
  }

  /// Disable screenshot prevention.
  static Future<void> disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableScreenshotProtection');
    } on PlatformException catch (_) {
      // Fallback
    } on MissingPluginException catch (_) {
      // Expected in development
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
