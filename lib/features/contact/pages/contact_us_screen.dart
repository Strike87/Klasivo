import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/theme.dart';

/// Klasivo Contact Us Screen
///
/// Public-facing contact form that sends a notification email
/// to support@klasivo.app via the `sendContactForm` Cloud Function.
/// No authentication required — anyone can submit.
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({Key? key}) : super(key: key);

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;
  bool _isSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendContactForm')
          .call({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
      });

      if (result.data['success'] == true) {
        setState(() => _isSent = true);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Failed to send message. Please try again.'),
            backgroundColor: KlasivoColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: KlasivoColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _messageController.clear();
    setState(() => _isSent = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.xxl,
            vertical: KlasivoSpacing.lg,
          ),
          child: _isSent ? _buildSuccessView(isDark) : _buildFormView(isDark),
        ),
      ),
    );
  }

  // ─── Success View ──────────────────────────────────────────
  Widget _buildSuccessView(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: KlasivoSpacing.hero),

        // Success icon
        Container(
          padding: const EdgeInsets.all(KlasivoSpacing.xxl),
          decoration: BoxDecoration(
            color: KlasivoColors.accent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: KlasivoColors.accent,
          ),
        ),
        const SizedBox(height: KlasivoSpacing.xxl),

        Text(
          'Message Sent!',
          style: KlasivoTypography.headlineLarge.copyWith(
            color: isDark
                ? KlasivoColors.darkTextPrimary
                : KlasivoColors.lightTextPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KlasivoSpacing.sm),

        Text(
          'Thank you for reaching out. We\'ll get back to you within 24 hours.',
          style: KlasivoTypography.bodyLarge.copyWith(
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KlasivoSpacing.xxxl),

        // Send another message
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _resetForm,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: KlasivoSpacing.sm),
                Text('Send Another Message'),
              ],
            ),
          ),
        ),
        const SizedBox(height: KlasivoSpacing.lg),

        // Go back
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  // ─── Form View ─────────────────────────────────────────────
  Widget _buildFormView(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Center(
            child: Container(
              padding: const EdgeInsets.all(KlasivoSpacing.xl),
              decoration: BoxDecoration(
                color: KlasivoColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 48,
                color: KlasivoColors.primary,
              ),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.xl),

          Center(
            child: Text(
              'Get in Touch',
              style: KlasivoTypography.headlineMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.sm),

          Center(
            child: Text(
              'Have a question, suggestion, or need help?\nWe\'d love to hear from you.',
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.xxxl),

          // ── Name Field ──
          _buildLabel('Your Name', isDark),
          const SizedBox(height: KlasivoSpacing.sm),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Ahmed Mohamed',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // ── Email Field ──
          _buildLabel('Email Address', isDark),
          const SizedBox(height: KlasivoSpacing.sm),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              hintText: 'e.g. ahmed@school.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // ── Subject Field ──
          _buildLabel('Subject', isDark),
          const SizedBox(height: KlasivoSpacing.sm),
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(
              hintText: 'e.g. Question about pricing',
              prefixIcon: Icon(Icons.subject_rounded, size: 20),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a subject';
              }
              if (value.trim().length < 3) {
                return 'Subject must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // ── Message Field ──
          _buildLabel('Message', isDark),
          const SizedBox(height: KlasivoSpacing.sm),
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(
              hintText: 'Tell us how we can help you...',
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your message';
              }
              if (value.trim().length < 10) {
                return 'Message must be at least 10 characters';
              }
              if (value.length > 5000) {
                return 'Message must be under 5,000 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: KlasivoSpacing.xxxl),

          // ── Submit Button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : _submitForm,
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: KlasivoSpacing.sm),
                        Text('Send Message'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // ── Help Text ──
          Center(
            child: Text(
              'We typically respond within 24 hours.',
              style: KlasivoTypography.bodySmall.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.xxxl),

          // ── Direct Contact Methods ──
          _buildDivider(isDark),
          const SizedBox(height: KlasivoSpacing.xl),

          Center(
            child: Text(
              'Or reach us directly',
              style: KlasivoTypography.labelMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // Email
          _buildContactCard(
            icon: Icons.email_outlined,
            label: 'Email',
            value: 'support@klasivo.app',
            isDark: isDark,
            onTap: () => _launchUrl('mailto:support@klasivo.app'),
          ),
          const SizedBox(height: KlasivoSpacing.md),

          // Website
          _buildContactCard(
            icon: Icons.language_rounded,
            label: 'Website',
            value: 'klasivo.app',
            isDark: isDark,
            onTap: () => _launchUrl('https://klasivo.app'),
          ),
          const SizedBox(height: KlasivoSpacing.xl),
        ],
      ),
    );
  }

  // ─── Label Helper ──────────────────────────────────────────
  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: KlasivoTypography.labelMedium.copyWith(
        color: isDark
            ? KlasivoColors.darkTextSecondary
            : KlasivoColors.lightTextSecondary,
      ),
    );
  }

  // ─── Divider ───────────────────────────────────────────────
  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.md),
          child: Text(
            'or',
            style: KlasivoTypography.bodySmall.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  // ─── Contact Card ──────────────────────────────────────────
  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
      borderRadius: BorderRadius.circular(KlasivoRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KlasivoRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.md),
                decoration: BoxDecoration(
                  color: KlasivoColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(KlasivoRadius.md),
                ),
                child: Icon(icon, size: 20, color: KlasivoColors.primary),
              ),
              const SizedBox(width: KlasivoSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: KlasivoTypography.labelSmall.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: KlasivoColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── URL Launcher ──────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
