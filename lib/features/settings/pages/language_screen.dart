import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/locale_provider.dart';
import '../../../core/config/theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO LANGUAGE SELECTION SCREEN
// Allows users to switch the app locale between en, fr, tr.
// Persisted via Hive through LocaleNotifier.
// NOTE: Arabic/RTL removed — app is LTR-only.
// ═══════════════════════════════════════════════════════════════════════════════

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(currentLocaleProvider);
    final notifier = ref.read(localeNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: KlasivoSpacing.sm),
        children: [
          // ─── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KlasivoSpacing.lg,
              vertical: KlasivoSpacing.md,
            ),
            child: Text(
              'Select your preferred language',
              style: KlasivoTypography.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: KlasivoSpacing.sm),

          // ─── Language options ──────────────────────────────────────────
          ...kSupportedLocales.map((locale) {
            final code = locale.languageCode;
            final isSelected = currentLocale.languageCode == code;
            final nativeName = kLocaleNativeNames[code] ?? code;

            return _LanguageTile(
              code: code,
              nativeName: nativeName,
              isSelected: isSelected,
              currentLocaleCode: currentLocale.languageCode,
              onTap: () {
                notifier.setLocale(code);
              },
            );
          }),

          const Divider(height: KlasivoSpacing.xxl),

          // ─── Reset to system ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KlasivoSpacing.lg,
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                notifier.resetToSystem();
              },
              icon: const Icon(Icons.settings_backup_restore, size: 18),
              label: const Text('Reset to System Language'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KlasivoColors.lightTextSecondary,
                side: const BorderSide(color: KlasivoColors.lightBorder),
              ),
            ),
          ),

          const SizedBox(height: KlasivoSpacing.lg),
        ],
      ),
    );
  }
}

// ─── Language List Tile ──────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  final String code;
  final String nativeName;
  final bool isSelected;
  final String currentLocaleCode;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.code,
    required this.nativeName,
    required this.isSelected,
    required this.currentLocaleCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.lg,
          vertical: KlasivoSpacing.md,
        ),
        child: Row(
          children: [
            // ─── Flag / locale icon ─────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? KlasivoColors.primarySurface
                    : theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(KlasivoRadius.iconButton),
              ),
              child: Center(
                child: Text(
                  _flagEmoji(code),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: KlasivoSpacing.md),

            // ─── Name + subtitle ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeName,
                    style: KlasivoTypography.titleMedium.copyWith(
                      color: isSelected
                          ? KlasivoColors.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _englishName(code),
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Radio indicator ────────────────────────────────────────
            Radio<String>(
              value: code,
              groupValue: currentLocaleCode,
              onChanged: (_) => onTap(),
              activeColor: KlasivoColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a flag emoji for the given locale code.
  String _flagEmoji(String code) {
    switch (code) {
      case 'en':
        return '\u{1F1EC}\u{1F1E7}'; // GB
      case 'fr':
        return '\u{1F1EB}\u{1F1F7}'; // FR
      case 'tr':
        return '\u{1F1F9}\u{1F1F7}'; // TR
      default:
        return '\u{1F310}'; // globe
    }
  }

  /// Returns the English name for the locale.
  String _englishName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'fr':
        return 'French';
      case 'tr':
        return 'Turkish';
      default:
        return code.toUpperCase();
    }
  }
}
