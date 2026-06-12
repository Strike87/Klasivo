import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// THEME MODE ENUM — Light, Dark, System
// ═══════════════════════════════════════════════════════════════════════════════

enum AppThemeMode {
  light,
  dark,
  system;

  String get label {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode_rounded;
      case AppThemeMode.dark:
        return Icons.dark_mode_rounded;
      case AppThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  /// Convert to Flutter's ThemeMode
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// From Hive storage key
  static AppThemeMode fromString(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.system;
    }
  }

  /// To Hive storage key
  String get key => name;
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME NOTIFIER — Manages theme mode with Hive persistence
// ═══════════════════════════════════════════════════════════════════════════════

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const _themeKey = 'themeMode';

  ThemeNotifier() : super(AppThemeMode.system) {
    _loadFromHive();
  }

  void _loadFromHive() {
    try {
      final box = Hive.box(AppConstants.authBox);
      final savedTheme = box.get(_themeKey) as String?;
      state = AppThemeMode.fromString(savedTheme);
    } catch (_) {
      state = AppThemeMode.system;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    try {
      final box = Hive.box(AppConstants.authBox);
      await box.put(_themeKey, mode.key);
    } catch (_) {}
  }

  /// Convenience: cycle through light → dark → system
  Future<void> cycleTheme() async {
    final next = switch (state) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
      AppThemeMode.system => AppThemeMode.light,
    };
    await setThemeMode(next);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RIVERPOD PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Provider for the ThemeNotifier
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

/// Derived provider: Flutter ThemeMode from current AppThemeMode
final themeModeProvider = Provider<ThemeMode>((ref) {
  final appThemeMode = ref.watch(themeProvider);
  return appThemeMode.themeMode;
});

/// Derived provider: whether dark mode is currently active
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  if (themeMode == ThemeMode.system) {
    // This will be resolved at the widget level using PlatformDispatcher
    // For provider-level access, we default to false
    return false;
  }
  return themeMode == ThemeMode.dark;
});
