import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/rbac/roles.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/config/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_permission_gate.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

// ─── Settings Screen — Full implementation replacing placeholder ────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = ref.watch(userNameProvider) ?? 'User';
    final userEmail = Hive.box(AppConstants.authBox).get('userEmail') as String? ?? '';
    final userRole = ref.watch(userRoleProvider);
    final orgId = ref.watch(organizationIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Card ──
            KlasivoCard(
              variant: KlasivoCardVariant.interactive,
              margin: const EdgeInsets.all(KlasivoSpacing.lg),
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              onTap: () => context.go('/settings/profile'),
              child: Row(
                children: [
                  KlasivoAvatar(
                    name: userName,
                    backgroundColor: KlasivoColors.primary,
                    size: KlasivoAvatarSize.lg,
                  ),
                  const SizedBox(width: KlasivoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: KlasivoTypography.titleLarge),
                        const SizedBox(height: KlasivoSpacing.xs),
                        Text(
                          userEmail,
                          style: KlasivoTypography.bodySmall.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextTertiary
                                : KlasivoColors.lightTextTertiary,
                          ),
                        ),
                        const SizedBox(height: KlasivoSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KlasivoSpacing.sm,
                            vertical: KlasivoSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: userRole == KlasivoRole.owner
                                ? KlasivoColors.primary.withValues(alpha: 0.1)
                                : KlasivoColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                          ),
                          child: Text(
                            userRole == KlasivoRole.owner ? 'Owner' : 'Teacher',
                            style: KlasivoTypography.labelSmall.copyWith(
                              color: userRole == KlasivoRole.owner
                                  ? KlasivoColors.primary
                                  : KlasivoColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Organization Section (org:settings permission) ──
            KlasivoPermissionGate(
              permission: Permission.orgSettings,
              fallback: const SizedBox.shrink(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Organization'),
                  KlasivoCard(
                    margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsTile(
                          icon: Icons.business_outlined,
                          iconColor: KlasivoColors.primary,
                          title: 'Workspace Settings',
                          subtitle: 'Name, details, and preferences',
                          onTap: () => context.go('/settings/organization'),
                        ),
                        const Divider(height: 1, indent: 56),
                        _SettingsTile(
                          icon: Icons.vpn_key_outlined,
                          iconColor: KlasivoColors.accent,
                          title: 'Invite Codes',
                          subtitle: 'Generate and manage teacher invite codes',
                          onTap: () => _showInviteCodes(context, ref, orgId),
                        ),
                        const Divider(height: 1, indent: 56),
                        _SettingsTile(
                          icon: Icons.people_outline_rounded,
                          iconColor: KlasivoColors.secondary,
                          title: 'Teachers',
                          subtitle: 'Manage teachers in your workspace',
                          onTap: () => _showTeacherList(context, orgId),
                        ),
                        const Divider(height: 1, indent: 56),
                        _SettingsTile(
                          icon: Icons.tune_outlined,
                          iconColor: const Color(0xFF845EF7),
                          title: 'Feature Flags',
                          subtitle: 'Control which features are enabled',
                          onTap: () => context.go('/settings/feature-flags'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),
                ],
              ),
            ),

            // ── Account Section ──
            _SectionHeader(title: 'Account'),
            KlasivoCard(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: KlasivoColors.primary,
                    title: 'Profile',
                    subtitle: 'Edit your name, email, and photo',
                    onTap: () => context.go('/settings/profile'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: KlasivoColors.accent,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => _showChangePassword(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Preferences Section ──
            _SectionHeader(title: 'Preferences'),
            KlasivoCard(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ThemeToggleTile(),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    iconColor: KlasivoColors.accent,
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    onTap: () => _showNotificationSettings(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Support Section ──
            _SectionHeader(title: 'Support'),
            KlasivoCard(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: KlasivoColors.info,
                    title: 'Help & Support',
                    subtitle: AppConstants.supportEmail,
                    onTap: () => _showHelp(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: KlasivoColors.primary,
                    title: 'About Klasivo',
                    subtitle: 'Version 2.0.0',
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── Logout ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              child: KlasivoButton(
                label: 'Logout',
                icon: Icons.logout_rounded,
                variant: KlasivoButtonVariant.danger,
                fullWidth: true,
                onPressed: () => _handleLogout(context, ref),
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout? You will need to sign in again.',
      confirmLabel: 'Logout',
      cancelLabel: 'Cancel',
      isDangerous: true,
    );
    if (confirmed == true && context.mounted) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.logout();
      } catch (_) {}
      await clearAuthData();
      if (context.mounted) context.go('/auth');
    }
  }

  void _showInviteCodes(BuildContext context, WidgetRef ref, String? orgId) {
    if (orgId == null) return;
    KlasivoModal.showContent(
      context: context,
      title: 'Invite Codes',
      child: _InviteCodesSheet(orgId: orgId),
    );
  }

  void _showTeacherList(BuildContext context, String? orgId) {
    if (orgId == null) return;
    KlasivoModal.showContent(
      context: context,
      title: 'Teachers',
      child: _TeacherListSheet(orgId: orgId),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    KlasivoModal.showForm(
      context: context,
      title: 'Change Password',
      child: const _ChangePasswordForm(),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    KlasivoModal.showContent(
      context: context,
      title: 'Notification Settings',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Exam Published'),
            subtitle: const Text('When a new exam is published'),
            value: true, onChanged: (v) {}, contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Exam Reminders'),
            subtitle: const Text('Before an exam starts'),
            value: true, onChanged: (v) {}, contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Results Published'),
            subtitle: const Text('When exam results are available'),
            value: true, onChanged: (v) {}, contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Announcements'),
            subtitle: const Text('Organization announcements'),
            value: true, onChanged: (v) {}, contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    KlasivoModal.showContent(
      context: context,
      title: 'Help & Support',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HelpItem(icon: Icons.email_outlined, title: 'Email Support', value: AppConstants.supportEmail),
          const SizedBox(height: KlasivoSpacing.md),
          _HelpItem(icon: Icons.language_outlined, title: 'Website', value: AppConstants.appBaseUrl),
          const SizedBox(height: KlasivoSpacing.md),
          _HelpItem(icon: Icons.description_outlined, title: 'Documentation', value: '${AppConstants.appBaseUrl}/docs'),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    KlasivoModal.showContent(
      context: context,
      title: 'About Klasivo',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(KlasivoSpacing.md),
              decoration: BoxDecoration(
                color: KlasivoColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
              ),
              child: const Icon(Icons.school_outlined, size: 40, color: KlasivoColors.primary),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.lg),
          Center(child: Text('Version 1.7.1', style: KlasivoTypography.bodyMedium)),
          const SizedBox(height: KlasivoSpacing.lg),
          const Text('Professional Exam Management Platform'),
          const SizedBox(height: KlasivoSpacing.sm),
          Text(
            'Built with Flutter & Firebase',
            style: KlasivoTypography.bodySmall.copyWith(color: KlasivoColors.lightTextTertiary),
          ),
          const SizedBox(height: KlasivoSpacing.lg),
          Text(
            'Support: ${AppConstants.supportEmail}',
            style: KlasivoTypography.bodySmall.copyWith(color: KlasivoColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(
        left: KlasivoSpacing.xxl, bottom: KlasivoSpacing.sm, top: KlasivoSpacing.md,
      ),
      child: Text(
        title.toUpperCase(),
        style: KlasivoTypography.labelSmall.copyWith(
          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(KlasivoSpacing.sm),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: KlasivoTypography.titleMedium),
      subtitle: Text(
        subtitle,
        style: KlasivoTypography.bodySmall.copyWith(
          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary, size: 20),
      onTap: onTap,
    );
  }
}

class _ThemeToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(KlasivoSpacing.sm),
        decoration: BoxDecoration(
          color: KlasivoColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        ),
        child: Icon(
          themeModeIcon(themeMode),
          color: KlasivoColors.accent,
          size: 20,
        ),
      ),
      title: Text('Appearance', style: KlasivoTypography.titleMedium),
      subtitle: Text(
        themeModeLabel(themeMode),
        style: KlasivoTypography.bodySmall.copyWith(
          color: isDark
              ? KlasivoColors.darkTextTertiary
              : KlasivoColors.lightTextTertiary,
        ),
      ),
      trailing: _ThemeSegmentedControl(
        currentMode: themeMode,
        onModeChanged: (mode) {
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onModeChanged;

  const _ThemeSegmentedControl({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark
            ? KlasivoColors.darkBorder.withValues(alpha: 0.6)
            : KlasivoColors.lightBorder,
        borderRadius: BorderRadius.circular(KlasivoRadius.sm + 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentButton(
            icon: Icons.light_mode_rounded,
            mode: ThemeMode.light,
            isSelected: currentMode == ThemeMode.light,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
          _segmentButton(
            icon: Icons.dark_mode_rounded,
            mode: ThemeMode.dark,
            isSelected: currentMode == ThemeMode.dark,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
          _segmentButton(
            icon: Icons.brightness_auto_rounded,
            mode: ThemeMode.system,
            isSelected: currentMode == ThemeMode.system,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _segmentButton({
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isSelected
              ? colorScheme.onPrimary
              : isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _HelpItem({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: KlasivoColors.primary),
        const SizedBox(width: KlasivoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KlasivoTypography.titleSmall),
              Text(value, style: KlasivoTypography.bodySmall.copyWith(
                color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
              )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Change Password Form ──────────────────────────────────────────────────────

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KlasivoTextField(
          controller: _currentPasswordController,
          label: 'Current Password',
          obscureText: _obscureCurrent,
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
          ),
        ),
        const SizedBox(height: KlasivoSpacing.md),
        KlasivoTextField(
          controller: _newPasswordController,
          label: 'New Password',
          obscureText: _obscureNew,
          prefixIcon: Icons.lock_outline_rounded,
          suffixIcon: IconButton(
            icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            onPressed: () => setState(() => _obscureNew = !_obscureNew),
          ),
        ),
        const SizedBox(height: KlasivoSpacing.md),
        KlasivoTextField(
          controller: _confirmPasswordController,
          label: 'Confirm New Password',
          obscureText: true,
          prefixIcon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: KlasivoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: KlasivoButton(
                label: 'Cancel',
                variant: KlasivoButtonVariant.tertiary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: KlasivoSpacing.md),
            Expanded(
              child: KlasivoButton(
                label: 'Update',
                onPressed: () async {
                  if (_newPasswordController.text != _confirmPasswordController.text) {
                    KlasivoToast.error(context, message: 'Passwords do not match');
                    return;
                  }
                  if (_newPasswordController.text.length < 6) {
                    KlasivoToast.error(context, message: 'Password must be at least 6 characters');
                    return;
                  }
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null && user.email != null) {
                      final credential = EmailAuthProvider.credential(
                        email: user.email!,
                        password: _currentPasswordController.text,
                      );
                      await user.reauthenticateWithCredential(credential);
                      await user.updatePassword(_newPasswordController.text);
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                      KlasivoToast.success(context, message: 'Password updated successfully');
                    }
                  } catch (e) {
                    KlasivoToast.error(context, message: formatAuthError(e));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Invite Codes Bottom Sheet ─────────────────────────────────────────────────

class _InviteCodesSheet extends ConsumerStatefulWidget {
  final String orgId;
  const _InviteCodesSheet({required this.orgId});

  @override
  ConsumerState<_InviteCodesSheet> createState() => _InviteCodesSheetState();
}

class _InviteCodesSheetState extends ConsumerState<_InviteCodesSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _codes = [];

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.inviteCodesCollection)
          .where('organizationId', isEqualTo: widget.orgId)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _codes = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateCode() async {
    try {
      final code = 'T-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(0, 7)}';
      await FirebaseFirestore.instance.collection(AppConstants.inviteCodesCollection).add({
        'code': code,
        'organizationId': widget.orgId,
        'type': AppConstants.inviteTypeTeacher,
        'isActive': true,
        'usedBy': [],
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadCodes();
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed to generate code: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KlasivoSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_codes.isEmpty) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KlasivoButton(
                label: 'Generate',
                icon: Icons.add_rounded,
                onPressed: _generateCode,
                size: KlasivoButtonSize.sm,
              ),
            ],
          ),
          const SizedBox(height: KlasivoSpacing.lg),
          KlasivoEmptyState(
            icon: Icons.vpn_key_outlined,
            title: 'No Invite Codes',
            subtitle: 'Generate a code to invite teachers to your workspace',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            KlasivoButton(
              label: 'Generate',
              icon: Icons.add_rounded,
              onPressed: _generateCode,
              size: KlasivoButtonSize.sm,
            ),
          ],
        ),
        const SizedBox(height: KlasivoSpacing.md),
        ..._codes.map((code) {
          final isActive = code['isActive'] ?? true;
          return KlasivoCard(
            margin: const EdgeInsets.symmetric(vertical: KlasivoSpacing.xs),
            padding: const EdgeInsets.all(KlasivoSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.sm),
                  decoration: BoxDecoration(
                    color: isActive
                        ? KlasivoColors.secondary.withValues(alpha: 0.1)
                        : KlasivoColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                  ),
                  child: Icon(
                    isActive ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                    color: isActive ? KlasivoColors.secondary : KlasivoColors.error, size: 20,
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code['code'] ?? '',
                        style: KlasivoTypography.titleMedium.copyWith(fontFamily: 'monospace')),
                      Text(isActive ? 'Active' : 'Deactivated',
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isActive ? KlasivoColors.secondary : KlasivoColors.error)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    KlasivoToast.success(context, message: 'Code copied: ${code['code']}');
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

// ─── Teacher List Bottom Sheet ──────────────────────────────────────────────────

class _TeacherListSheet extends ConsumerStatefulWidget {
  final String orgId;
  const _TeacherListSheet({required this.orgId});

  @override
  ConsumerState<_TeacherListSheet> createState() => _TeacherListSheetState();
}

class _TeacherListSheetState extends ConsumerState<_TeacherListSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .where('organizationId', isEqualTo: widget.orgId)
          .where('role', whereIn: [KlasivoRole.teacher, KlasivoRole.owner])
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _teachers = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: KlasivoSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_teachers.isEmpty) {
      return KlasivoEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No Teachers',
        subtitle: 'No teachers found in your workspace',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: KlasivoSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.sm, vertical: KlasivoSpacing.xs),
                decoration: BoxDecoration(
                  color: KlasivoColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                ),
                child: Text('${_teachers.length}',
                  style: KlasivoTypography.labelSmall.copyWith(color: KlasivoColors.primary)),
              ),
            ],
          ),
        ),
        ..._teachers.map((teacher) {
          final isOwner = teacher['role'] == KlasivoRole.owner;
          final name = teacher['fullName'] ?? 'Unknown';
          return KlasivoCard(
            margin: const EdgeInsets.symmetric(vertical: KlasivoSpacing.xs),
            padding: const EdgeInsets.all(KlasivoSpacing.md),
            child: Row(
              children: [
                KlasivoAvatar(
                  name: name,
                  backgroundColor: isOwner ? KlasivoColors.primary : KlasivoColors.secondary,
                  size: KlasivoAvatarSize.md,
                ),
                const SizedBox(width: KlasivoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: KlasivoTypography.titleMedium),
                      Text(teacher['email'] ?? '',
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.sm, vertical: KlasivoSpacing.xs),
                  decoration: BoxDecoration(
                    color: isOwner ? KlasivoColors.primary.withValues(alpha: 0.1) : KlasivoColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  child: Text(isOwner ? 'Owner' : 'Teacher',
                    style: KlasivoTypography.labelSmall.copyWith(
                      color: isOwner ? KlasivoColors.primary : KlasivoColors.secondary)),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
