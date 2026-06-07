import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                        color: KlasivoColors.primary.withOpacity(0.1),
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
                  Text('Workspace Name', style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                  )),
                  const SizedBox(height: KlasivoSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Ahmed Academy',
                      prefixIcon: Icon(Icons.business_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),

                  // ── Workspace Slug ──
                  Text('Workspace Slug', style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                  )),
                  const SizedBox(height: KlasivoSpacing.sm),
                  TextFormField(
                    controller: _slugController,
                    decoration: InputDecoration(
                      hintText: 'ahmed-academy',
                      prefixIcon: const Icon(Icons.link_outlined, size: 20),
                      prefixText: '${AppConstants.appDomain}/org/',
                      prefixStyle: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.sm),
                  Text(
                    'This creates a shareable link for your workspace',
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Info Card ──
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.md),
                    decoration: BoxDecoration(
                      color: KlasivoColors.infoSurface,
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    ),
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveOrganization,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxl),

                  // ── Danger Zone ──
                  _SectionHeader(title: 'Danger Zone'),
                  const SizedBox(height: KlasivoSpacing.sm),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                      side: const BorderSide(color: KlasivoColors.error, width: 1),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: KlasivoColors.error),
                      title: Text('Delete Workspace', style: KlasivoTypography.titleMedium.copyWith(color: KlasivoColors.error)),
                      subtitle: Text(
                        'Permanently delete this workspace and all its data. This action cannot be undone.',
                        style: KlasivoTypography.bodySmall.copyWith(color: KlasivoColors.error.withOpacity(0.7)),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please contact support to delete your workspace'),
                            backgroundColor: KlasivoColors.error,
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
