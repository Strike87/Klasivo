import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_constants.dart';
import '../config/theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO THEME PROVIDER
// Riverpod StateNotifier that manages light/dark/system theme mode.
// Persists the user's choice to Hive box 'app_settings' with key 'theme_mode'.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Hive storage keys ──────────────────────────────────────────────────────
const String _themeModeKey = 'theme_mode';

// ─── Theme Mode Notifier ────────────────────────────────────────────────────
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadFromHive();
  }

  /// Load persisted theme mode from Hive. Defaults to system.
  void _loadFromHive() {
    try {
      final box = Hive.box(AppConstants.appSettingsBox);
      final saved = box.get(_themeModeKey) as String?;
      if (saved != null) {
        state = _fromString(saved);
      }
    } catch (_) {
      // If box isn't open or read fails, keep default (system)
    }
  }

  /// Persist the chosen theme mode to Hive and update state.
  void setThemeMode(ThemeMode mode) {
    state = mode;
    try {
      final box = Hive.box(AppConstants.appSettingsBox);
      box.put(_themeModeKey, _toString(mode));
    } catch (_) {
      // Silent fail — theme will revert to system on next launch
    }
  }

  /// Convenience: cycle through light → dark → system.
  void cycleThemeMode() {
    switch (state) {
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
      case ThemeMode.dark:
        setThemeMode(ThemeMode.system);
      case ThemeMode.system:
        setThemeMode(ThemeMode.light);
    }
  }

  // ─── Serialization helpers ───────────────────────────────────────────────
  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

// ─── Provider Definitions ───────────────────────────────────────────────────

/// StateNotifierProvider for the current ThemeMode.
/// Watch this to reactively rebuild UI when theme changes.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Convenience provider that returns the resolved ThemeData based on
/// the current theme mode and the platform brightness.
///
/// Usage in a ConsumerWidget:
///   final theme = ref.watch(themeProvider);
///   // or just use Theme.of(context) since MaterialApp is already wired.
final themeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  switch (mode) {
    case ThemeMode.light:
      return AppTheme.lightTheme;
    case ThemeMode.dark:
      return AppTheme.darkTheme;
    case ThemeMode.system:
      // We cannot access platform brightness from a provider (no context),
      // so we return light as default. MaterialApp.themeMode handles the
      // actual resolution at the widget level.
      return AppTheme.lightTheme;
  }
});

/// Helper: human-readable label for a ThemeMode.
String themeModeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System';
  }
}

/// Helper: icon for a ThemeMode.
IconData themeModeIcon(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Icons.light_mode_rounded;
    case ThemeMode.dark:
      return Icons.dark_mode_rounded;
    case ThemeMode.system:
      return Icons.brightness_auto_rounded;
  }
}
