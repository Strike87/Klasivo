import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/rbac/rbac.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/rbac_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_permission_gate.dart';
import '../../../widgets/klasivo_toast.dart';

// ─── Organization Settings Screen ──────────────────────────────────────────────

class OrganizationSettingsScreen extends ConsumerStatefulWidget {
  const OrganizationSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends ConsumerState<OrganizationSettingsScreen> {
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _orgId;
  Map<String, dynamic>? _orgData;

  @override
  void initState() {
    super.initState();
    _loadOrganization();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganization() async {
    _orgId = ref.read(organizationIdProvider);
    if (_orgId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.organizationsCollection)
          .doc(_orgId)
          .get();

      if (doc.exists) {
        _orgData = doc.data();
        _nameController.text = _orgData?['name'] ?? '';
        _slugController.text = _orgData?['slug'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading organization: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveOrganization() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_slugController.text.trim().isNotEmpty) {
        updates['slug'] = _slugController.text.trim().toLowerCase().replaceAll(' ', '-');
      }

      await FirebaseFirestore.instance
          .collection(AppConstants.organizationsCollection)
          .doc(_orgId)
          .update(updates);

      if (mounted) {
        KlasivoToast.success(context, message: 'Organization updated successfully');
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed to update: ${formatAuthError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return KlasivoPermissionGate(
      permission: Permission.orgSettings,
      fallback: Scaffold(
        appBar: AppBar(title: const Text('Workspace Settings')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Access Denied', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 8),
              Text('You need organization settings permission', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Workspace Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Workspace Icon ──
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: KlasivoColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                      ),
                      child: const Icon(
                        Icons.business_outlined,
                        size: 40,
                        color: KlasivoColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxl),

                  // ── Workspace Name ──
                  KlasivoTextField(
                    controller: _nameController,
                    label: 'Workspace Name',
                    hint: 'e.g. Ahmed Academy',
                    prefixIcon: Icons.business_outlined,
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),

                  // ── Workspace Slug ──
                  KlasivoTextField(
                    controller: _slugController,
                    label: 'Workspace Slug',
                    hint: 'ahmed-academy',
                    prefixIcon: Icons.link_outlined,
                    helperText: 'Creates: ${AppConstants.appDomain}/org/your-slug',
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Info Card ──
                  KlasivoCard(
                    variant: KlasivoCardVariant.filled,
                    padding: const EdgeInsets.all(KlasivoSpacing.md),
                    margin: EdgeInsets.zero,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: KlasivoColors.primary, size: 20),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Expanded(
                          child: Text(
                            'Changing the workspace name affects all teachers and students in your organization. The slug is used for deep links.',
                            style: KlasivoTypography.bodySmall.copyWith(color: KlasivoColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Save Button ──
                  KlasivoButton(
                    label: 'Save Changes',
                    fullWidth: true,
                    loading: _isSaving,
                    onPressed: _saveOrganization,
                  ),
                  const SizedBox(height: KlasivoSpacing.xxl),

                  // ── Feature Flags ──
                  _SectionHeader(title: 'Feature Management'),
                  const SizedBox(height: KlasivoSpacing.sm),
                  KlasivoCard(
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(KlasivoSpacing.sm),
                        decoration: BoxDecoration(
                          color: KlasivoColors.primarySurface,
                          borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                        ),
                        child: const Icon(Icons.tune_outlined, color: KlasivoColors.primary, size: 20),
                      ),
                      title: Text('Feature Flags', style: KlasivoTypography.titleMedium),
                      subtitle: Text(
                        'Control which features are available in your organization',
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/settings/feature-flags'),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Danger Zone ──
                  _SectionHeader(title: 'Danger Zone'),
                  const SizedBox(height: KlasivoSpacing.sm),
                  KlasivoCard(
                    accentColor: KlasivoColors.error,
                    margin: EdgeInsets.zero,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: KlasivoColors.error),
                      title: Text('Delete Workspace', style: KlasivoTypography.titleMedium.copyWith(color: KlasivoColors.error)),
                      subtitle: Text(
                        'Permanently delete this workspace and all its data. This action cannot be undone.',
                        style: KlasivoTypography.bodySmall.copyWith(color: KlasivoColors.error.withValues(alpha: 0.7)),
                      ),
                      onTap: () {
                        KlasivoToast.error(context, message: 'Please contact support to delete your workspace');
                      },
                    ),
                  ),
                ],
              ),
            ),
    ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title.toUpperCase(),
      style: KlasivoTypography.labelSmall.copyWith(
        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
        letterSpacing: 1,
      ),
    );
  }
}
