/// Klasivo v2.0 - Localization setup
/// 
/// Centralized localization configuration supporting:
/// - English (default)
/// - Arabic (RTL)
/// - Additional languages as needed
/// 
/// Uses Flutter intl package for code generation.
library;

import "package:flutter/widgets.dart";

/// Supported locales in the Klasivo app.
const supportedLocales = [
  Locale("en"),
  Locale("ar"),
];

/// Default locale for the app.
const defaultLocale = Locale("en");

/// Localization delegate for Klasivo.
/// 
/// TODO: Generate localization files using:
/// `flutter gen-l10n`
/// 
/// For now, this returns a basic delegate setup.
class KlasivoLocalizations {
  static const LocalizationsDelegate<KlasivoLocalizations> delegate =
      _KlasivoLocalizationsDelegate();

  final Locale locale;

  const KlasivoLocalizations(this.locale);

  static KlasivoLocalizations of(BuildContext context) {
    return Localizations.of<KlasivoLocalizations>(
      context,
      KlasivoLocalizations,
    )!;
  }

  /// Whether the current locale is RTL.
  bool get isRTL => locale.languageCode == "ar";

  // TODO: Add all localized strings as getters
}

class _KlasivoLocalizationsDelegate
    extends LocalizationsDelegate<KlasivoLocalizations> {
  const _KlasivoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<KlasivoLocalizations> load(Locale locale) async {
    return KlasivoLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<KlasivoLocalizations> old) =>
      false;
}

