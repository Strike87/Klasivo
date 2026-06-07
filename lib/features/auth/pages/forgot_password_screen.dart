import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';

// ─── Forgot Password Screen ────────────────────────────────────────────────────

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: KlasivoColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/auth/teacher-login'),
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

                // ── Illustration ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.xxl),
                    decoration: BoxDecoration(
                      color: KlasivoColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _emailSent ? Icons.mark_email_read_outlined : Icons.lock_reset_outlined,
                      size: 56,
                      color: KlasivoColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Header ──
                Center(
                  child: Text(
                    _emailSent ? 'Check Your Email' : 'Reset Password',
                    style: KlasivoTypography.headlineLarge.copyWith(
                      color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                Center(
                  child: Text(
                    _emailSent
                        ? 'We sent a password reset link to ${_emailController.text.trim()}'
                        : 'Enter your email and we\'ll send you a link to reset your password',
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxxl),

                if (!_emailSent) ...[
                  // ── Email Input ──
                  Text('Email', style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                  )),
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
                  const SizedBox(height: KlasivoSpacing.xxl),

                  // ── Send Reset Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendResetEmail,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Send Reset Link'),
                    ),
                  ),
                ] else ...[
                  // ── Success State ──
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.md),
                    decoration: BoxDecoration(
                      color: KlasivoColors.secondarySurface,
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: KlasivoColors.secondary, size: 20),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email sent!',
                                style: KlasivoTypography.titleSmall.copyWith(color: KlasivoColors.secondary)),
                              const SizedBox(height: KlasivoSpacing.xs),
                              Text(
                                'Check your inbox and spam folder. The link expires in 1 hour.',
                                style: KlasivoTypography.bodySmall.copyWith(color: KlasivoColors.secondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxl),

                  // ── Resend ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () {
                        setState(() => _emailSent = false);
                        _sendResetEmail();
                      },
                      child: const Text('Resend Email'),
                    ),
                  ),
                ],
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Back to Login ──
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/auth/teacher-login'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                        SizedBox(width: KlasivoSpacing.xs),
                        Text('Back to Login'),
                      ],
                    ),
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
