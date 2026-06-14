import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_toast.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _suggestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Generate suggestions based on the user's name
    final userName = ref.read(userNameProvider) ?? 'Your';
    final authService = ref.read(authServiceProvider);
    _suggestions = authService.generateWorkspaceSuggestions(userName);
    _nameController.text = _suggestions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final userId = ref.read(userIdProvider);
      final orgId = ref.read(organizationIdProvider);

      if (userId == null || orgId == null || orgId.isEmpty) {
        // Log the missing data to Crashlytics for diagnostics
        final detail = 'userId=${userId ?? "null"}, orgId=${orgId ?? "null"}';
        FirebaseCrashlytics.instance.recordError(
          'Missing user or organization data ($detail)',
          StackTrace.current,
          reason: 'Welcome screen _completeSetup: providers returned null/empty',
        );

        // Providers may be stale — read directly from Hive as fallback
        final box = Hive.box(AppConstants.authBox);
        final hiveUserId = userId ?? box.get('userId') as String?;
        var hiveOrgId = orgId?.isEmpty == true ? null : (orgId ?? box.get('organizationId') as String?);

        if (hiveUserId == null || hiveOrgId == null || hiveOrgId.isEmpty) {
          throw Exception('Missing user or organization data. Please sign out and try again.');
        }

        // Sync providers with Hive values
        ref.read(userIdProvider.notifier).state = hiveUserId;
        ref.read(organizationIdProvider.notifier).state = hiveOrgId;

        await authService.completeOwnerSetup(
          userId: hiveUserId,
          organizationId: hiveOrgId,
          workspaceName: _nameController.text.trim(),
        );
      } else {
        await authService.completeOwnerSetup(
          userId: userId,
          organizationId: orgId,
          workspaceName: _nameController.text.trim(),
        );
      }

      // Persist to both Riverpod AND Hive so the GoRouter redirect
      // and splash screen see the updated value immediately.
      ref.read(hasCompletedSetupProvider.notifier).state = true;
      final box = Hive.box(AppConstants.authBox);
      await box.put('hasCompletedSetup', true);

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, reason: 'Welcome screen _completeSetup failed');
      if (mounted) {
        KlasivoToast.error(context, message: e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = ref.watch(userNameProvider) ?? 'there';

    return Scaffold(
      // No back button — this is mandatory setup
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: KlasivoSpacing.hero),

                // ── Welcome Illustration ──
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.xxl),
                    decoration: BoxDecoration(
                      color: KlasivoColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch_outlined,
                      size: 56,
                      color: KlasivoColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),

                // ── Welcome Message ──
                Center(
                  child: Text(
                    'Welcome to Klasivo!',
                    style: KlasivoTypography.headlineLarge.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                Center(
                  child: Text(
                    'What would you like to call your workspace, $userName?',
                    style: KlasivoTypography.bodyLarge.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxxl),

                // ── Workspace Name Input ──
                KlasivoTextField(
                  label: 'Workspace Name',
                  controller: _nameController,
                  hint: 'e.g. Ahmed Academy',
                  prefixIcon: Icons.business_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a workspace name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: KlasivoSpacing.lg),

                // ── Auto-Suggest Chips ──
                Text(
                  'Suggestions',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                Wrap(
                  spacing: KlasivoSpacing.sm,
                  runSpacing: KlasivoSpacing.sm,
                  children: _suggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextPrimary
                              : KlasivoColors.lightTextPrimary,
                        ),
                      ),
                      onPressed: () {
                        _nameController.text = suggestion;
                      },
                      backgroundColor: isDark
                          ? KlasivoColors.darkSurface
                          : KlasivoColors.lightSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                        side: BorderSide(
                          color: KlasivoColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: KlasivoSpacing.xxxl),

                // ── Continue Button ──
                KlasivoButton(
                  label: 'Continue',
                  onPressed: _isLoading ? null : _completeSetup,
                  loading: _isLoading,
                  fullWidth: true,
                  size: KlasivoButtonSize.lg,
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: KlasivoSpacing.xl),

                // ── Skip Option ──
                Center(
                  child: KlasivoButton(
                    label: 'Use default name for now',
                    variant: KlasivoButtonVariant.tertiary,
                    onPressed: _isLoading ? null : () async {
                      // Use the default name and continue
                      await _completeSetup();
                    },
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
