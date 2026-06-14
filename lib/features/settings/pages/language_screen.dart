import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/locale_provider.dart';
import '../../../core/config/theme.dart';
import '../../../core/utils/rtl_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO LANGUAGE SELECTION SCREEN
// Allows users to switch the app locale between en, ar, fr, tr.
// Shows an RTL indicator badge for Arabic.
// Persisted via Hive through LocaleNotifier.
// ═══════════════════════════════════════════════════════════════════════════════

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(currentLocaleProvider);
    final isRtl = ref.watch(isRtlProvider);
    final notifier = ref.read(localeNotifierProvider.notifier);

    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Language'),
          leading: IconButton(
            icon: maybeFlipIcon(context, Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: KlasivoSpacing.sm),
          children: [
            // ─── Header ───────────────────────────────────────────────────
            Padding(
              padding: edgeInsetsWithStart(
                context: context,
                start: KlasivoSpacing.lg,
                end: KlasivoSpacing.lg,
                top: KlasivoSpacing.md,
                bottom: KlasivoSpacing.xs,
              ),
              child: Text(
                'Select your preferred language',
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // ─── RTL indicator ─────────────────────────────────────────────
            if (isRtl)
              Padding(
                padding: edgeInsetsWithStart(
                  context: context,
                  start: KlasivoSpacing.lg,
                  end: KlasivoSpacing.lg,
                  top: KlasivoSpacing.xs,
                  bottom: KlasivoSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KlasivoSpacing.sm,
                        vertical: KlasivoSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: KlasivoColors.primarySurface,
                        borderRadius: BorderRadius.circular(KlasivoRadius.badge),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_textdirection_r_to_l,
                            size: 14,
                            color: KlasivoColors.primary,
                          ),
                          const SizedBox(width: KlasivoSpacing.xs),
                          Text(
                            'RTL',
                            style: KlasivoTypography.labelSmall.copyWith(
                              color: KlasivoColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: KlasivoSpacing.sm),
                    Text(
                      'Right-to-left layout active',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: KlasivoColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: KlasivoSpacing.sm),

            // ─── Language options ──────────────────────────────────────────
            ...kSupportedLocales.map((locale) {
              final code = locale.languageCode;
              final isSelected = currentLocale.languageCode == code;
              final nativeName = kLocaleNativeNames[code] ?? code;
              final isLocaleRtl = kRtlLocales.contains(code);

              return _LanguageTile(
                code: code,
                nativeName: nativeName,
                isSelected: isSelected,
                isRtl: isLocaleRtl,
                currentLocaleCode: currentLocale.languageCode,
                onTap: () {
                  notifier.setLocale(code);
                },
              );
            }),

            const Divider(height: KlasivoSpacing.xxl),

            // ─── Reset to system ──────────────────────────────────────────
            Padding(
              padding: edgeInsetsWithStart(
                context: context,
                start: KlasivoSpacing.lg,
                end: KlasivoSpacing.lg,
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
      ),
    );
  }
}

// ─── Language List Tile ──────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  final String code;
  final String nativeName;
  final bool isSelected;
  final bool isRtl;
  final String currentLocaleCode;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.code,
    required this.nativeName,
    required this.isSelected,
    required this.isRtl,
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

            // ─── RTL badge ──────────────────────────────────────────────
            if (isRtl) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KlasivoSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: KlasivoColors.primarySurface,
                  borderRadius: BorderRadius.circular(KlasivoRadius.badge),
                ),
                child: Text(
                  'RTL',
                  style: KlasivoTypography.labelSmall.copyWith(
                    color: KlasivoColors.primary,
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(width: KlasivoSpacing.sm),
            ],

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
        return '🇬🇧';
      case 'ar':
        return '🇸🇦';
      case 'fr':
        return '🇫🇷';
      case 'tr':
        return '🇹🇷';
      default:
        return '🌐';
    }
  }

  /// Returns the English name for the locale.
  String _englishName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ar':
        return 'Arabic';
      case 'fr':
        return 'French';
      case 'tr':
        return 'Turkish';
      default:
        return code.toUpperCase();
    }
  }
}
