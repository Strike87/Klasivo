import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_permission_gate.dart';

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
            Card(
              margin: const EdgeInsets.all(KlasivoSpacing.lg),
              child: InkWell(
                onTap: () => context.go('/settings/profile'),
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(KlasivoSpacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: KlasivoColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: KlasivoTypography.headlineSmall.copyWith(
                            color: KlasivoColors.primary,
                          ),
                        ),
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
                                color: userRole == AppConstants.roleOwner
                                    ? KlasivoColors.primary.withValues(alpha: 0.1)
                                    : KlasivoColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                              ),
                              child: Text(
                                userRole == AppConstants.roleOwner ? 'Owner' : 'Teacher',
                                style: KlasivoTypography.labelSmall.copyWith(
                                  color: userRole == AppConstants.roleOwner
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
              ),
            ),

            // ── Organization Section (Owner/Admin only) ──
            KlasivoRoleGate(
              allowedRoles: [AppConstants.roleOwner, AppConstants.roleAdmin],
              fallback: const SizedBox.shrink(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(title: 'Organization'),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
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
            Card(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
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
            Card(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
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
            Card(
              margin: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
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
                    subtitle: 'Version 1.7.1',
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),

            // ── Logout ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _handleLogout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KlasivoColors.error,
                    side: const BorderSide(color: KlasivoColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KlasivoRadius.md),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, size: 20),
                      SizedBox(width: KlasivoSpacing.sm),
                      Text('Logout'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? You will need to sign in again.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.lg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: KlasivoColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KlasivoRadius.lg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, controller) => _InviteCodesSheet(
          orgId: orgId,
          scrollController: controller,
        ),
      ),
    );
  }

  void _showTeacherList(BuildContext context, String? orgId) {
    if (orgId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KlasivoRadius.lg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, controller) => _TeacherListSheet(
          orgId: orgId,
          scrollController: controller,
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change Password'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KlasivoRadius.lg),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.md),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.md),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null && user.email != null) {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);
                    await user.updatePassword(newPasswordController.text);
                  }
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Settings'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.lg),
        ),
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.lg),
        ),
        content: Column(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Klasivo',
      applicationVersion: '1.7.1',
      applicationIcon: Container(
        padding: const EdgeInsets.all(KlasivoSpacing.md),
        decoration: BoxDecoration(
          color: KlasivoColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
        ),
        child: const Icon(Icons.school_outlined, size: 40, color: KlasivoColors.primary),
      ),
      children: [
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

class _ThemeToggleTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ThemeToggleTile> createState() => _ThemeToggleTileState();
}

class _ThemeToggleTileState extends ConsumerState<_ThemeToggleTile> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(KlasivoSpacing.sm),
        decoration: BoxDecoration(
          color: KlasivoColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        ),
        child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: KlasivoColors.accent, size: 20),
      ),
      title: Text('Appearance', style: KlasivoTypography.titleMedium),
      subtitle: Text(
        isDark ? 'Dark mode' : 'Light mode',
        style: KlasivoTypography.bodySmall.copyWith(
          color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
        ),
      ),
      trailing: Switch(
        value: isDark,
        onChanged: (v) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Theme follows your system settings'), duration: Duration(seconds: 2)),
          );
        },
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

// ─── Invite Codes Bottom Sheet ─────────────────────────────────────────────────

class _InviteCodesSheet extends ConsumerStatefulWidget {
  final String orgId;
  final ScrollController scrollController;
  const _InviteCodesSheet({required this.orgId, required this.scrollController});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: KlasivoSpacing.md),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invite Codes', style: KlasivoTypography.headlineSmall),
              ElevatedButton.icon(
                onPressed: _generateCode,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Generate'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _codes.isEmpty
                  ? KlasivoEmptyState(
                      icon: Icons.vpn_key_outlined,
                      title: 'No Invite Codes',
                      subtitle: 'Generate a code to invite teachers to your workspace',
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
                      itemCount: _codes.length,
                      itemBuilder: (context, index) {
                        final code = _codes[index];
                        final isActive = code['isActive'] ?? true;
                        return Card(
                          child: Padding(
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Code copied: ${code['code']}')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── Teacher List Bottom Sheet ──────────────────────────────────────────────────

class _TeacherListSheet extends ConsumerStatefulWidget {
  final String orgId;
  final ScrollController scrollController;
  const _TeacherListSheet({required this.orgId, required this.scrollController});

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
          .where('role', whereIn: [AppConstants.roleTeacher, AppConstants.roleOwner])
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
    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: KlasivoSpacing.md),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Row(
            children: [
              Text('Teachers', style: KlasivoTypography.headlineSmall),
              const SizedBox(width: KlasivoSpacing.sm),
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
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
                  itemCount: _teachers.length,
                  itemBuilder: (context, index) {
                    final teacher = _teachers[index];
                    final isOwner = teacher['role'] == AppConstants.roleOwner;
                    final isActive = teacher['isActive'] ?? true;
                    final name = teacher['fullName'] ?? 'Unknown';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(KlasivoSpacing.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: (isOwner ? KlasivoColors.primary : KlasivoColors.secondary).withValues(alpha: 0.1),
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: KlasivoTypography.titleMedium.copyWith(
                                  color: isOwner ? KlasivoColors.primary : KlasivoColors.secondary)),
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
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
