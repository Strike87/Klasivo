import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO LOCALE PROVIDER
// Manages the app's locale with Riverpod StateNotifier + Hive persistence.
//
// Supported locales: en, fr, tr (Arabic/RTL removed — app is LTR-only)
// Persists to Hive box 'app_settings' with key 'locale'.
// Defaults to English on first launch.
// ═══════════════════════════════════════════════════════════════════════════════

const String _localeKey = 'locale';

/// All locales supported by the app (LTR-only — no Arabic).
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('fr'),
  Locale('tr'),
];

/// Map of locale code → human-readable native name.
const Map<String, String> kLocaleNativeNames = {
  'en': 'English',
  'fr': 'Français',
  'tr': 'Türkçe',
};

// ─── State Notifier ─────────────────────────────────────────────────────────

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(_resolveInitialLocale());

  /// Resolve the initial locale: persisted > system > fallback (en).
  static Locale _resolveInitialLocale() {
    try {
      final box = Hive.box(AppConstants.appSettingsBox);
      final saved = box.get(_localeKey) as String?;
      if (saved != null && _isValid(saved)) {
        return Locale(saved);
      }
    } catch (_) {
      // Hive not initialized yet or box doesn't exist — fall through
    }

    // Try to match a supported locale from the system
    final systemLocale = PlatformDispatcher.instance.locale;
    if (_isValid(systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }

    // Default fallback
    return const Locale('en');
  }

  /// Set a new locale and persist the choice.
  void setLocale(String languageCode) {
    if (!_isValid(languageCode)) return;
    final newLocale = Locale(languageCode);
    if (state == newLocale) return;

    state = newLocale;
    _persist(languageCode);
  }

  /// Reset to system locale.
  void resetToSystem() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final resolved = _isValid(systemLocale.languageCode)
        ? Locale(systemLocale.languageCode)
        : const Locale('en');

    state = resolved;
    try {
      final box = Hive.box(AppConstants.appSettingsBox);
      box.delete(_localeKey);
    } catch (_) {
      // Silently ignore — not critical
    }
  }

  void _persist(String languageCode) {
    try {
      final box = Hive.box(AppConstants.appSettingsBox);
      box.put(_localeKey, languageCode);
    } catch (_) {
      // Silently ignore — not critical
    }
  }

  static bool _isValid(String code) {
    return kSupportedLocales.any((l) => l.languageCode == code);
  }
}

// ─── Riverpod Providers ─────────────────────────────────────────────────────

/// Provider for the [LocaleNotifier].
final localeNotifierProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Convenience provider that returns the current [Locale].
final currentLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(localeNotifierProvider);
});
