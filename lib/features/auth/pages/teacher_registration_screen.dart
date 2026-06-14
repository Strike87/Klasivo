import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';

class TeacherRegistrationScreen extends ConsumerStatefulWidget {
  const TeacherRegistrationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TeacherRegistrationScreen> createState() =>
      _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState
    extends ConsumerState<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _isOwnerFlow = true; // true = Owner (no invite code), false = Teacher (needs invite code)

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);

      if (_isOwnerFlow) {
        // Owner registration — creates workspace
        final result = await authService.registerOwner(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );

        await saveTeacherAuthData(
          role: KlasivoRole.owner,
          name: result['fullName'],
          userId: result['id'],
          email: result['email'],
          organizationId: result['organizationId'],
          hasCompletedSetup: false,
          authProvider: 'password',
        );

        if (mounted) {
          context.go('/welcome');
        }
      } else {
        // Teacher registration — needs invite code
        final result = await authService.registerTeacherWithInvite(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          inviteCode: _inviteCodeController.text.trim(),
        );

        await saveTeacherAuthData(
          role: KlasivoRole.teacher,
          name: result['fullName'],
          userId: result['id'],
          email: result['email'],
          organizationId: result['organizationId'],
          hasCompletedSetup: true,
          authProvider: 'password',
        );

        if (mounted) {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      ref.read(authErrorProvider.notifier).state =
          e.toString().replaceAll('Exception: ', '');
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _registerWithGoogle() async {
    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);

      if (_isOwnerFlow) {
        // Owner Google registration
        final result = await authService.registerOwnerWithGoogle();

        await saveTeacherAuthData(
          role: result['role'] ?? KlasivoRole.owner,
          name: result['fullName'] ?? 'User',
          userId: result['id'],
          email: result['email'] ?? '',
          organizationId: result['organizationId'],
          hasCompletedSetup: result['hasCompletedSetup'] ?? false,
          authProvider: 'google',
        );

        if (mounted) {
          final hasCompletedSetup = result['hasCompletedSetup'] ?? true;
          if (!hasCompletedSetup) {
            context.go('/welcome');
          } else {
            context.go('/dashboard');
          }
        }
      } else {
        // Teacher Google registration — needs invite code
        if (_inviteCodeController.text.trim().isEmpty) {
          ref.read(authErrorProvider.notifier).state =
              'Invite code is required for teachers';
          ref.read(authLoadingProvider.notifier).state = false;
          return;
        }

        final result = await authService.registerTeacherWithGoogle(
          inviteCode: _inviteCodeController.text.trim(),
        );

        await saveTeacherAuthData(
          role: result['role'] ?? KlasivoRole.teacher,
          name: result['fullName'] ?? 'Teacher',
          userId: result['id'],
          email: result['email'] ?? '',
          organizationId: result['organizationId'],
          hasCompletedSetup: result['hasCompletedSetup'] ?? true,
          authProvider: 'google',
        );

        if (mounted) {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      ref.read(authErrorProvider.notifier).state =
          e.toString().replaceAll('Exception: ', '');
    } finally {
      ref.read(authLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final error = ref.watch(authErrorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/auth'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Header ──
                Text(
                  'Create your account',
                  style: KlasivoTypography.headlineLarge.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                Text(
                  'Start managing exams with Klasivo',
                  style: KlasivoTypography.bodyMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Role Toggle ──
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.xs),
                  decoration: BoxDecoration(
                    color: isDark
                        ? KlasivoColors.darkSurface
                        : KlasivoColors.lightBackground,
                    borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    border: Border.all(
                      color: isDark
                          ? KlasivoColors.darkBorder
                          : KlasivoColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ToggleOption(
                          label: 'Organization Owner',
                          subtitle: 'Create new workspace',
                          isSelected: _isOwnerFlow,
                          onTap: () => setState(() => _isOwnerFlow = true),
                        ),
                      ),
                      const SizedBox(width: KlasivoSpacing.xs),
                      Expanded(
                        child: _ToggleOption(
                          label: 'Teacher',
                          subtitle: 'Join with invite code',
                          isSelected: !_isOwnerFlow,
                          onTap: () => setState(() => _isOwnerFlow = false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Invite Code (Teacher flow — shown FIRST) ──
                if (!_isOwnerFlow) ...[
                  KlasivoTextField(
                    label: 'Invite Code',
                    controller: _inviteCodeController,
                    hint: 'T-XXXXXXXX or klasivo.app/join/XXXXXXX',
                    prefixIcon: Icons.vpn_key_outlined,
                    validator: (value) {
                      if (!_isOwnerFlow && (value == null || value.trim().isEmpty)) {
                        return 'Invite code is required for teachers';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),
                ],

                // ── Full Name ──
                KlasivoTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Name is required';
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Email ──
                KlasivoTextField(
                  label: 'Email',
                  controller: _emailController,
                  hint: 'you@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Email is required';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Password ──
                KlasivoTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hint: 'At least 6 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password is required';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Error Message ──
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.md),
                    decoration: BoxDecoration(
                      color: KlasivoColors.errorSurface,
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                      border: Border.all(color: KlasivoColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: KlasivoColors.error, size: 20),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Expanded(
                          child: Text(
                            error,
                            style: KlasivoTypography.bodySmall.copyWith(
                              color: KlasivoColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),
                ],

                // ── Register Button ──
                KlasivoButton(
                  label: _isOwnerFlow ? 'Create Workspace' : 'Join Organization',
                  onPressed: isLoading ? null : _register,
                  loading: isLoading,
                  fullWidth: true,
                  size: KlasivoButtonSize.lg,
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Divider ──
                Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? KlasivoColors.darkDivider : KlasivoColors.lightDivider)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.md),
                      child: Text(
                        'OR',
                        style: KlasivoTypography.labelSmall.copyWith(
                          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: isDark ? KlasivoColors.darkDivider : KlasivoColors.lightDivider)),
                  ],
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Google Sign-Up ──
                KlasivoButton(
                  label: 'Continue with Google',
                  variant: KlasivoButtonVariant.secondary,
                  icon: Icons.g_mobiledata,
                  onPressed: isLoading ? null : _registerWithGoogle,
                  fullWidth: true,
                  size: KlasivoButtonSize.lg,
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Login Link ──
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                    KlasivoButton(
                      label: 'Sign in',
                      variant: KlasivoButtonVariant.tertiary,
                      onPressed: () => context.go('/auth/teacher-login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KlasivoRadius.sm + 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.md,
          vertical: KlasivoSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? KlasivoColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(KlasivoRadius.sm + 2),
          border: isSelected
              ? Border.all(color: KlasivoColors.primary.withValues(alpha: 0.3))
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: KlasivoTypography.labelMedium.copyWith(
                color: isSelected
                    ? KlasivoColors.primary
                    : (isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary),
              ),
            ),
            Text(
              subtitle,
              style: KlasivoTypography.caption.copyWith(
                color: isSelected
                    ? KlasivoColors.primaryLight
                    : (isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
