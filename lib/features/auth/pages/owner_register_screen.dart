import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/auth_provider.dart';

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
      final result = await authService.registerOwner(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      await saveTeacherAuthData(
        role: AppConstants.roleOwner,
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
      final result = await authService.registerOwnerWithGoogle();

      await saveTeacherAuthData(
        role: result['role'] ?? AppConstants.roleOwner,
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
                Text(
                  'Full Name',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Name is required';
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Email ──
                Text(
                  'Email',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Email is required';
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Password ──
                Text(
                  'Password',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'At least 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Workspace'),
                  ),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : _registerWithGoogle,
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                    ),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KlasivoRadius.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Login Link ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth/teacher-login'),
                      child: const Text('Sign in'),
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
