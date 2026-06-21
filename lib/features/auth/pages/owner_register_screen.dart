import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sentry_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';

/// Owner Registration screen — accessed from the Welcome screen's
/// "Organization Owner" role card. Supports email+password and Google Sign-In.
class OwnerRegisterScreen extends ConsumerStatefulWidget {
  const OwnerRegisterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OwnerRegisterScreen> createState() => _OwnerRegisterScreenState();
}

class _OwnerRegisterScreenState extends ConsumerState<OwnerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.registerOwnerViaCF(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        organizationName: _nameController.text.trim(),  // v5: org name (can change in setup)
      );

      // v5: ViaCF returns {success: bool} - check before proceeding
      if (result['success'] != true) {
        final error = result['error'] ?? 'Registration failed';
        throw Exception(error);
      }

      await saveTeacherAuthData(
        role: AppConstants.roleOwner,
        name: _nameController.text.trim(),  // v5: ViaCF doesn't return fullName
        userId: result['uid'],  // v5: ViaCF returns 'uid' not 'id'
        email: _emailController.text.trim(),  // v5: ViaCF doesn't return email
        organizationId: result['organizationId'],
        hasCompletedSetup: false,
        authProvider: 'password',
        ref: ref,
      );

      if (mounted) {
        context.go('/welcome');
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Owner registration (email) failed');
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('screen', 'owner_register');
          scope.setTag('flow', 'owner_registration');
          scope.setTag('method', 'email');
          scope.setTag('step', 'UI_REGISTER_CATCH');
        },
      );
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
      final result = await authService.registerOwnerWithGoogle();

      await saveTeacherAuthData(
        role: result['role'] ?? AppConstants.roleOwner,
        name: result['fullName'] ?? 'User',
        userId: result['id'],
        email: result['email'] ?? '',
        organizationId: result['organizationId'],
        hasCompletedSetup: result['hasCompletedSetup'] ?? false,
        authProvider: 'google',
        ref: ref,
      );

      if (mounted) {
        final hasCompletedSetup = result['hasCompletedSetup'] ?? true;
        if (!hasCompletedSetup) {
          context.go('/welcome');
        } else {
          context.go('/dashboard');
        }
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Owner registration (Google) failed');
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('screen', 'owner_register');
          scope.setTag('flow', 'owner_registration');
          scope.setTag('method', 'google');
          scope.setTag('step', 'UI_REGISTER_GOOGLE_CATCH');
        },
      );
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

                // ── Header with icon ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.lg),
                    decoration: BoxDecoration(
                      color: KlasivoColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                    ),
                    child: const Icon(
                      Icons.business_outlined,
                      size: 48,
                      color: KlasivoColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),
                Center(
                  child: Text(
                    'Create Your Workspace',
                    style: KlasivoTypography.headlineLarge.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                Center(
                  child: Text(
                    'Set up your organization in minutes',
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxxl),

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

                // ── Create Workspace Button ──
                KlasivoButton(
                  label: 'Create Workspace',
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
                    GestureDetector(
                      onTap: () => context.go('/auth/teacher-login'),
                      child: Text(
                        'Sign in',
                        style: KlasivoTypography.labelMedium.copyWith(
                          color: KlasivoColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
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
