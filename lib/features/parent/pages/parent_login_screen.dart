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
import '../../../widgets/klasivo_toast.dart';

// ─── Parent Login Screen ──────────────────────────────────────────────────────

class ParentLoginScreen extends ConsumerStatefulWidget {
  const ParentLoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends ConsumerState<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await saveParentAuthData(
        name: result['fullName'] ?? 'Parent',
        userId: result['id'],
        email: result['email'] ?? _emailController.text.trim(),
        organizationId: result['organizationId'],
        hasCompletedSetup: result['hasCompletedSetup'] ?? true,
        authProvider: 'password',
      );

      if (mounted) {
        context.go(AppConstants.routeParentHome);
      }
    } catch (e) {
      if (mounted) {
        ref.read(authErrorProvider.notifier).state =
            e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.loginWithGoogle(
        expectedRole: KlasivoRole.parent,
      );

      await saveParentAuthData(
        name: result['fullName'] ?? 'Parent',
        userId: result['id'],
        email: result['email'] ?? '',
        organizationId: result['organizationId'],
        hasCompletedSetup: result['hasCompletedSetup'] ?? true,
        authProvider: 'google',
      );

      if (mounted) {
        final hasCompletedSetup = result['hasCompletedSetup'] ?? true;
        if (!hasCompletedSetup) {
          context.go(AppConstants.routeParentLink);
        } else {
          context.go(AppConstants.routeParentHome);
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(authErrorProvider.notifier).state =
            e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
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
          onPressed: () => context.go(AppConstants.routeAuth),
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

                // ── Icon ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF845EF7).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                    ),
                    child: const Icon(
                      Icons.family_restroom_outlined,
                      size: 48,
                      color: Color(0xFF845EF7),
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Title ──
                Center(
                  child: Text(
                    'Parent Portal',
                    style: KlasivoTypography.headlineLarge.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),

                // ── Subtitle ──
                Center(
                  child: Text(
                    'Monitor your child\'s academic progress',
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxxl),

                // ── Email Field ──
                KlasivoTextField(
                  label: 'Email',
                  hint: 'parent@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Password Field ──
                KlasivoTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline_rounded,
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
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.sm),

                // ── Forgot Password ──
                Align(
                  alignment: Alignment.centerRight,
                  child: KlasivoButton(
                    variant: KlasivoButtonVariant.tertiary,
                    label: 'Forgot password?',
                    onPressed: () => context.go('/auth/forgot-password'),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xl),

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

                // ── Login Button ──
                KlasivoButton(
                  label: 'Sign In',
                  onPressed: _login,
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

                // ── Google Sign-In ──
                KlasivoButton(
                  label: 'Continue with Google',
                  variant: KlasivoButtonVariant.secondary,
                  icon: Icons.g_mobiledata,
                  onPressed: _loginWithGoogle,
                  loading: isLoading,
                  fullWidth: true,
                  size: KlasivoButtonSize.lg,
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Register Link ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                    KlasivoButton(
                      variant: KlasivoButtonVariant.tertiary,
                      label: 'Create one',
                      onPressed: () => context.go('/auth/parent-register'),
                    ),
                  ],
                ),

                // ── Link Child Action ──
                Center(
                  child: KlasivoButton(
                    variant: KlasivoButtonVariant.tertiary,
                    label: 'Link your child',
                    onPressed: () {
                      context.go(AppConstants.routeParentLink);
                    },
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
