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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            // ─── Header ───────────────────────────────────────────────────
            Padding(
              padding: edgeInsetsWithStart(
                context: context,
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                top: AppSpacing.md,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                'Select your preferred language',
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // ─── RTL indicator ─────────────────────────────────────────────
            if (isRtl)
              Padding(
                padding: edgeInsetsWithStart(
                  context: context,
                  start: AppSpacing.lg,
                  end: AppSpacing.lg,
                  top: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.format_textdirection_r_to_l,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'RTL',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Right-to-left layout active',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.sm),

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

            const Divider(height: AppSpacing.xxl),

            // ─── Reset to system ──────────────────────────────────────────
            Padding(
              padding: edgeInsetsWithStart(
                context: context,
                start: AppSpacing.lg,
                end: AppSpacing.lg,
              ),
              child: OutlinedButton.icon(
                onPressed: () {
                  notifier.resetToSystem();
                },
                icon: const Icon(Icons.settings_backup_restore, size: 18),
                label: const Text('Reset to System Language'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.lightTextSecondary,
                  side: const BorderSide(color: AppColors.lightBorder),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
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
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // ─── Flag / locale icon ─────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySurface
                    : theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.iconButton),
              ),
              child: Center(
                child: Text(
                  _flagEmoji(code),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // ─── Name + subtitle ────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nativeName,
                    style: AppTypography.titleMedium.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _englishName(code),
                    style: AppTypography.bodySmall.copyWith(
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
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Text(
                  'RTL',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],

            // ─── Radio indicator ────────────────────────────────────────
            Radio<String>(
              value: code,
              groupValue: currentLocaleCode,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
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
