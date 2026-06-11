import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../core/services/feature_flag_service.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../providers/permission_provider.dart';
import '../../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE FLAGS MANAGEMENT SCREEN — Klasivo v1.8
// Admin-only screen for managing feature flags (enable/disable, rollout %).
// Accessible from Organization Settings.
// ═══════════════════════════════════════════════════════════════════════════════

class FeatureFlagsScreen extends ConsumerWidget {
  const FeatureFlagsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featureFlagsStreamProvider);
          ref.invalidate(allFeatureFlagsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          children: [
            // ── Info Banner ──
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              decoration: BoxDecoration(
                color: KlasivoColors.primarySurface,
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
                border: Border.all(color: KlasivoColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                    color: KlasivoColors.primary,
                    size: KlasivoSpacing.iconSizeLg),
                  const SizedBox(width: KlasivoSpacing.md),
                  Expanded(
                    child: Text(
                      'Control which features are available in your organization. '
                      'Changes take effect immediately for all users.',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: KlasivoColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── v1.6 Features (Always On) ──
            _SectionHeader(title: 'v1.6 — Core Features', subtitle: 'Foundation features, always enabled'),
            ..._buildV16Flags(ref, isDark),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── v1.7 Features ──
            _SectionHeader(title: 'v1.7 — LMS & Parent Portal', subtitle: 'Gradual rollout features'),
            ..._buildV17Flags(ref, isDark),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── v1.8 Features ──
            _SectionHeader(title: 'v1.8 — Cross-Cutting', subtitle: 'Upcoming features'),
            ..._buildV18Flags(ref, isDark),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── v1.9 Features ──
            _SectionHeader(title: 'v1.9 — ERP', subtitle: 'Enterprise resource planning'),
            ..._buildV19Flags(ref, isDark),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── v2.0 Features ──
            _SectionHeader(title: 'v2.0 — Future', subtitle: 'Planned features'),
            ..._buildV20Flags(ref, isDark),
            const SizedBox(height: KlasivoSpacing.hero),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildV16Flags(WidgetRef ref, bool isDark) {
    return [
      _FeatureFlagTile(
        flagKey: FeatureFlags.exams,
        label: 'Exams',
        description: 'Create, publish, and manage exams with auto-grading',
        icon: Icons.quiz_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.questionBank,
        label: 'Question Bank',
        description: 'Reusable question bank across exams',
        icon: Icons.library_books_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.attendance,
        label: 'Attendance',
        description: 'Track student attendance with status codes',
        icon: Icons.how_to_reg_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.assignments,
        label: 'Assignments',
        description: 'Create and grade assignments with due dates',
        icon: Icons.assignment_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.analytics,
        label: 'Analytics',
        description: 'Teacher analytics dashboard and reports',
        icon: Icons.analytics_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.notifications,
        label: 'Notifications',
        description: 'Push and in-app notifications',
        icon: Icons.notifications_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.qrEnrollment,
        label: 'QR Enrollment',
        description: 'Enroll students via QR code scanning',
        icon: Icons.qr_code_scanner,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.excelImport,
        label: 'Excel Import',
        description: 'Bulk import students from Excel files',
        icon: Icons.table_chart_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.violationTracking,
        label: 'Violation Tracking',
        description: 'Detect and track exam integrity violations',
        icon: Icons.shield_outlined,
        isCore: true,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.deepLinks,
        label: 'Deep Links',
        description: 'Shareable links for exams, results, and enrollment',
        icon: Icons.link_outlined,
        isCore: true,
      ),
    ];
  }

  List<Widget> _buildV17Flags(WidgetRef ref, bool isDark) {
    return [
      _FeatureFlagTile(
        flagKey: FeatureFlags.lms,
        label: 'LMS Content Browser',
        description: 'Browse subjects, units, lessons, and materials',
        icon: Icons.school_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.parentPortal,
        label: 'Parent Portal',
        description: 'Parent dashboard with progress, results, and announcements',
        icon: Icons.family_restroom_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.progressTracking,
        label: 'Progress Tracking',
        description: 'Track student progress across exams and assignments',
        icon: Icons.trending_up_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.lessonPlans,
        label: 'Lesson Plans',
        description: 'Create and manage lesson plans for each unit',
        icon: Icons.menu_book_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.communicationHub,
        label: 'Communication Hub',
        description: 'Direct messaging between teachers, parents, and students',
        icon: Icons.forum_outlined,
      ),
    ];
  }

  List<Widget> _buildV18Flags(WidgetRef ref, bool isDark) {
    return [
      _FeatureFlagTile(
        flagKey: FeatureFlags.globalSearch,
        label: 'Global Search',
        description: 'Search across students, classes, exams, and assignments',
        icon: Icons.search_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.commandPalette,
        label: 'Command Palette',
        description: 'Quick actions via keyboard-style command palette',
        icon: Icons.terminal_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.dashboardPriorityMatrix,
        label: 'Priority Matrix',
        description: 'Eisenhower-style priority matrix on teacher dashboard',
        icon: Icons.grid_view_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.enhancedEmptyStates,
        label: 'Enhanced Empty States',
        description: 'Illustrated empty states with actionable CTAs',
        icon: Icons.inbox_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.academicSetupWizard,
        label: 'Academic Setup Wizard',
        description: 'Guided wizard for initial academic structure setup',
        icon: Icons.auto_fix_high_outlined,
      ),
    ];
  }

  List<Widget> _buildV19Flags(WidgetRef ref, bool isDark) {
    return [
      _FeatureFlagTile(
        flagKey: FeatureFlags.fees,
        label: 'Fee Management',
        description: 'Create fee structures and track student fees',
        icon: Icons.receipt_long_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.payments,
        label: 'Payment Processing',
        description: 'Online payment collection and receipt generation',
        icon: Icons.payment_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.payroll,
        label: 'Payroll',
        description: 'Teacher and staff payroll management',
        icon: Icons.account_balance_wallet_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.inventory,
        label: 'Inventory',
        description: 'Track school inventory and supplies',
        icon: Icons.inventory_2_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.frenchLocalization,
        label: 'French Localization',
        description: 'Full French language support',
        icon: Icons.language_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.azureAdSso,
        label: 'Azure AD SSO',
        description: 'Single sign-on via Microsoft Azure AD',
        icon: Icons.login_outlined,
      ),
    ];
  }

  List<Widget> _buildV20Flags(WidgetRef ref, bool isDark) {
    return [
      _FeatureFlagTile(
        flagKey: FeatureFlags.samlSso,
        label: 'SAML SSO',
        description: 'SAML-based single sign-on for enterprise',
        icon: Icons.vpn_key_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.turkishLocalization,
        label: 'Turkish Localization',
        description: 'Full Turkish language support',
        icon: Icons.translate_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.publicApi,
        label: 'Public API',
        description: 'REST API for third-party integrations',
        icon: Icons.api_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.ltiIntegration,
        label: 'LTI Integration',
        description: 'Learning Tools Interoperability standard support',
        icon: Icons.extension_outlined,
      ),
      _FeatureFlagTile(
        flagKey: FeatureFlags.campusManagement,
        label: 'Campus Management',
        description: 'Multi-campus organization support',
        icon: Icons.domain_outlined,
      ),
    ];
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: KlasivoTypography.titleLarge),
        const SizedBox(height: KlasivoSpacing.xs),
        Text(subtitle, style: KlasivoTypography.bodySmall.copyWith(
          color: KlasivoColors.lightTextTertiary,
        )),
        const SizedBox(height: KlasivoSpacing.md),
      ],
    );
  }
}

// ─── Feature Flag Tile ──────────────────────────────────────────────────────

class _FeatureFlagTile extends ConsumerWidget {
  final String flagKey;
  final String label;
  final String description;
  final IconData icon;
  final bool isCore; // v1.6 core features can't be disabled

  const _FeatureFlagTile({
    required this.flagKey,
    required this.label,
    required this.description,
    required this.icon,
    this.isCore = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(featureFlagEnabledProvider(flagKey));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
      child: Material(
        color: isDark ? KlasivoColors.darkCard : KlasivoColors.lightCard,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        child: InkWell(
          onTap: isCore ? null : () => _showFlagDetail(context, ref),
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
          child: Container(
            padding: const EdgeInsets.all(KlasivoSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KlasivoRadius.md),
              border: Border.all(
                color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                // ── Icon ──
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.md),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? KlasivoColors.primarySurface
                        : (isDark ? KlasivoColors.darkBackground : KlasivoColors.lightBackground),
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: KlasivoSpacing.iconSizeLg,
                    color: isEnabled
                        ? KlasivoColors.primary
                        : (isDark ? KlasivoColors.darkTextDisabled : KlasivoColors.lightTextDisabled),
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.md),

                // ── Text Content ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(label, style: KlasivoTypography.titleSmall.copyWith(
                            color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
                          )),
                          if (isCore) ...[
                            const SizedBox(width: KlasivoSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KlasivoSpacing.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: KlasivoColors.secondarySurface,
                                borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                              ),
                              child: Text('Core',
                                style: KlasivoTypography.labelSmall.copyWith(
                                  color: KlasivoColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: KlasivoSpacing.xs),
                      Text(description, style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                      )),
                    ],
                  ),
                ),

                // ── Toggle ──
                Switch(
                  value: isEnabled,
                  onChanged: isCore ? null : (value) => _toggleFlag(ref, value),
                  activeColor: KlasivoColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFlag(WidgetRef ref, bool value) {
    ref.read(featureFlagUpdateProvider(FeatureFlagUpdate(
      flagKey: flagKey,
      enabled: value,
    )).future);
  }

  void _showFlagDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KlasivoRadius.bottomSheet)),
      ),
      builder: (context) => _FlagDetailSheet(flagKey: flagKey, label: label),
    );
  }
}

// ─── Flag Detail Bottom Sheet ───────────────────────────────────────────────

class _FlagDetailSheet extends ConsumerStatefulWidget {
  final String flagKey;
  final String label;

  const _FlagDetailSheet({required this.flagKey, required this.label});

  @override
  ConsumerState<_FlagDetailSheet> createState() => _FlagDetailSheetState();
}

class _FlagDetailSheetState extends ConsumerState<_FlagDetailSheet> {
  late bool _isEnabled;
  int? _rolloutPercentage;
  final _userIdController = TextEditingController();
  List<String> _allowedUserIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = ref.read(featureFlagEnabledProvider(widget.flagKey));
    final flag = ref.read(featureFlagDetailProvider(widget.flagKey));
    _rolloutPercentage = flag?.rolloutPercentage;
    _allowedUserIds = List.from(flag?.allowedUserIds ?? []);
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(KlasivoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: KlasivoSpacing.xxl),
                  decoration: BoxDecoration(
                    color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Title ──
              Text(widget.label, style: KlasivoTypography.headlineSmall),
              const SizedBox(height: KlasivoSpacing.xs),
              Text('Flag: ${widget.flagKey}', style: KlasivoTypography.caption.copyWith(
                color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                fontFamily: 'RobotoMono',
              )),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Enable/Disable ──
              _SettingRow(
                label: 'Enabled',
                description: 'Turn this feature on or off for your organization',
                child: Switch(
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                  activeColor: KlasivoColors.primary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Rollout Percentage ──
              Text('Rollout Percentage', style: KlasivoTypography.titleSmall),
              const SizedBox(height: KlasivoSpacing.xs),
              Text(
                'Control what percentage of users see this feature. '
                'Uses deterministic hashing so each user always sees the same result.',
                style: KlasivoTypography.bodySmall.copyWith(
                  color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: (_rolloutPercentage ?? 100).toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_rolloutPercentage ?? 100}%',
                      onChanged: (v) => setState(() => _rolloutPercentage = v.round()),
                      activeColor: KlasivoColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${_rolloutPercentage ?? 100}%',
                      style: KlasivoTypography.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Allowed User IDs ──
              Text('Targeted Users', style: KlasivoTypography.titleSmall),
              const SizedBox(height: KlasivoSpacing.xs),
              Text(
                'When users are specified, only those users will see the feature. '
                'Leave empty to use percentage rollout instead.',
                style: KlasivoTypography.bodySmall.copyWith(
                  color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        hintText: 'Enter user ID',
                        isDense: true,
                      ),
                      style: KlasivoTypography.bodySmall,
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  IconButton.filled(
                    onPressed: () {
                      final id = _userIdController.text.trim();
                      if (id.isNotEmpty && !_allowedUserIds.contains(id)) {
                        setState(() {
                          _allowedUserIds.add(id);
                          _userIdController.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
              if (_allowedUserIds.isNotEmpty) ...[
                const SizedBox(height: KlasivoSpacing.sm),
                Wrap(
                  spacing: KlasivoSpacing.xs,
                  runSpacing: KlasivoSpacing.xs,
                  children: _allowedUserIds.map((id) => Chip(
                    label: Text(id, style: KlasivoTypography.caption),
                    onDeleted: () => setState(() => _allowedUserIds.remove(id)),
                    deleteIconColor: KlasivoColors.error,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              const SizedBox(height: KlasivoSpacing.xxxl),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: KlasivoSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KlasivoRadius.button),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes'),
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(featureFlagUpdateProvider(FeatureFlagUpdate(
        flagKey: widget.flagKey,
        enabled: _isEnabled,
        rolloutPercentage: _rolloutPercentage,
        allowedUserIds: _allowedUserIds.isEmpty ? null : _allowedUserIds,
      )).future);

      if (mounted) {
        KlasivoToast.success(context, message: '${widget.label} updated');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed to update: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ─── Setting Row ─────────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  final String label;
  final String description;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: KlasivoTypography.titleSmall),
              const SizedBox(height: KlasivoSpacing.xs),
              Text(description, style: KlasivoTypography.bodySmall.copyWith(
                color: KlasivoColors.lightTextTertiary,
              )),
            ],
          ),
        ),
        child,
      ],
    );
  }
}
