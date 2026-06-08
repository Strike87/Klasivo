import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/auth_provider.dart';

class StudentLoginScreen extends ConsumerStatefulWidget {
  const StudentLoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends ConsumerState<StudentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.loginStudent(
        studentCode: _codeController.text.trim(),
        password: _passwordController.text,
      );

      await saveStudentAuthData(
        name: result['fullName'],
        userId: result['id'],
        classId: result['classId'],
        studentCode: result['studentCode'],
        organizationId: result['organizationId'],
      );

      if (mounted) {
        context.go('/student');
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
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.lg),
                    decoration: BoxDecoration(
                      color: KlasivoColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      size: 48,
                      color: KlasivoColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),
                Center(
                  child: Text(
                    'Student Login',
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
                    'Enter your student code and password',
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxxl),

                // ── Student Code ──
                Text(
                  'Student Code',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'STU-XXXXXX',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Student code is required';
                    }
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
                    hintText: 'Enter your password',
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
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KlasivoColors.secondary,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Help Text ──
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.md),
                  decoration: BoxDecoration(
                    color: KlasivoColors.infoSurface,
                    borderRadius: BorderRadius.circular(KlasivoRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: KlasivoColors.primary, size: 20),
                      const SizedBox(width: KlasivoSpacing.sm),
                      Expanded(
                        child: Text(
                          'Your student code and password are provided by your teacher. Contact them if you need help.',
                          style: KlasivoTypography.bodySmall.copyWith(
                            color: KlasivoColors.primary,
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
      ),
    );
  }
}
