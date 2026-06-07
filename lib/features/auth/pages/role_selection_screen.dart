import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.xxl,
            vertical: KlasivoSpacing.hero,
          ),
          child: Column(
            children: [
              // ── Logo ──
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.lg),
                decoration: BoxDecoration(
                  color: KlasivoColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 52,
                  color: KlasivoColors.primary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),
              Text(
                'Klasivo',
                style: KlasivoTypography.headlineLarge.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.sm),
              Text(
                'Professional Exam Management',
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxxl),

              // ── Role Selection ──
              Text(
                'I am a...',
                style: KlasivoTypography.titleLarge.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextSecondary
                      : KlasivoColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Teacher Card ──
              _RoleCard(
                icon: Icons.person_outline_rounded,
                title: 'Teacher',
                subtitle: 'Create exams, manage classes, and grade students',
                color: KlasivoColors.primary,
                onTap: () => context.go('/auth/teacher-login'),
              ),
              const SizedBox(height: KlasivoSpacing.lg),

              // ── Student Card ──
              _RoleCard(
                icon: Icons.school_outlined,
                title: 'Student',
                subtitle: 'Take exams, view results, and track progress',
                color: KlasivoColors.secondary,
                onTap: () => context.go('/auth/student-login'),
              ),
              const SizedBox(height: KlasivoSpacing.xxxl),

              // ── Footer ──
              Text(
                'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                textAlign: TextAlign.center,
                style: KlasivoTypography.caption.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.md),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(KlasivoRadius.md),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: KlasivoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KlasivoTypography.titleLarge.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: KlasivoSpacing.xs),
                    Text(
                      subtitle,
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
