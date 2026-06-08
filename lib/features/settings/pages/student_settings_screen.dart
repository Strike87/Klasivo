import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

// ─── Student Settings Screen ───────────────────────────────────────────────────

class StudentSettingsScreen extends ConsumerWidget {
  const StudentSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = ref.watch(userNameProvider) ?? 'Student';
    final studentCode = ref.watch(studentCodeProvider) ?? '—';
    final studentClass = ref.watch(studentClassNameProvider) ?? '—';
    final userEmail = Hive.box(AppConstants.authBox).get('userEmail') as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Card ──
            Card(
              margin: const EdgeInsets.all(KlasivoSpacing.lg),
              child: Padding(
                padding: const EdgeInsets.all(KlasivoSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: KlasivoColors.secondary.withValues(alpha: 0.1),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: KlasivoTypography.headlineSmall.copyWith(
                          color: KlasivoColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName, style: KlasivoTypography.titleLarge),
                          const SizedBox(height: KlasivoSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KlasivoSpacing.sm,
                              vertical: KlasivoSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: KlasivoColors.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                            ),
                            child: Text(
                              'Student',
                              style: KlasivoTypography.labelSmall.copyWith(
                                color: KlasivoColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Student Info ──
            _SectionHeader(title: 'Student Info'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm),
                      decoration: BoxDecoration(
                        color: KlasivoColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.badge_outlined, color: KlasivoColors.secondary, size: 20),
                    ),
                    title: Text('Student Code', style: KlasivoTypography.titleMedium),
                    subtitle: Text(studentCode, style: KlasivoTypography.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                    )),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm),
                      decoration: BoxDecoration(
                        color: KlasivoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.class_outlined, color: KlasivoColors.primary, size: 20),
                    ),
                    title: Text('Class', style: KlasivoTypography.titleMedium),
                    subtitle: Text(studentClass, style: KlasivoTypography.bodySmall.copyWith(
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Preferences ──
            _SectionHeader(title: 'Preferences'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm),
                      decoration: BoxDecoration(
                        color: KlasivoColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: KlasivoColors.accent, size: 20),
                    ),
                    title: Text('Appearance', style: KlasivoTypography.titleMedium),
                    subtitle: Text(isDark ? 'Dark mode' : 'Light mode',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (v) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Theme follows your system settings'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm),
                      decoration: BoxDecoration(
                        color: KlasivoColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.notifications_outlined, color: KlasivoColors.accent, size: 20),
                    ),
                    title: Text('Notifications', style: KlasivoTypography.titleMedium),
                    subtitle: Text('Manage notification preferences',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                    trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary, size: 20),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notification settings coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Support ──
            _SectionHeader(title: 'Support'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm),
                      decoration: BoxDecoration(
                        color: KlasivoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: KlasivoColors.primary, size: 20),
                    ),
                    title: Text('Help & Support', style: KlasivoTypography.titleMedium),
                    subtitle: Text(AppConstants.supportEmail,
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                    trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary, size: 20),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Klasivo',
                        applicationVersion: '1.6.0',
                        children: [
                          Text('Support: ${AppConstants.supportEmail}'),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm),
                      decoration: BoxDecoration(
                        color: KlasivoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.info_outline_rounded, color: KlasivoColors.primary, size: 20),
                    ),
                    title: Text('About Klasivo', style: KlasivoTypography.titleMedium),
                    subtitle: Text('Version 1.6.0',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                    trailing: Icon(Icons.chevron_right_rounded,
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary, size: 20),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Klasivo',
                        applicationVersion: '1.6.0',
                        applicationIcon: Container(
                          padding: const EdgeInsets.all(KlasivoSpacing.md),
                          decoration: BoxDecoration(
                            color: KlasivoColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(KlasivoRadius.md),
                          ),
                          child: const Icon(Icons.school_outlined, size: 40, color: KlasivoColors.secondary),
                        ),
                        children: [
                          const Text('Professional Exam Management for Students'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── Logout ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(foregroundColor: KlasivoColors.error),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      try {
                        final authService = ref.read(authServiceProvider);
                        await authService.logout();
                      } catch (_) {}
                      await clearAuthData();
                      if (context.mounted) context.go('/auth');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KlasivoColors.error,
                    side: const BorderSide(color: KlasivoColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 20),
                      SizedBox(width: KlasivoSpacing.sm),
                      Text('Logout'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(
        left: KlasivoSpacing.xxl,
        bottom: KlasivoSpacing.sm,
        top: KlasivoSpacing.md,
      ),
      child: Text(
        title.toUpperCase(),
        style: KlasivoTypography.labelSmall.copyWith(
          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
