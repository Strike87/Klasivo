import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_toast.dart';

// ─── Profile Settings Screen ───────────────────────────────────────────────────

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final userEmail = Hive.box(AppConstants.authBox).get('userEmail') as String? ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['fullName'] ?? '';
        _emailController.text = data['email'] ?? userEmail;
        _phoneController.text = data['phoneNumber'] ?? '';
      } else {
        _nameController.text = ref.read(userNameProvider) ?? '';
        _emailController.text = userEmail;
      }
    } catch (e) {
      _nameController.text = ref.read(userNameProvider) ?? '';
      _emailController.text = userEmail;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      KlasivoToast.error(context, message: 'Name cannot be empty');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = ref.read(userIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      // Update Firestore user document
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'fullName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local Hive data
      final box = Hive.box(AppConstants.authBox);
      await box.put('userName', _nameController.text.trim());

      if (mounted) {
        KlasivoToast.success(context, message: 'Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed to update: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = ref.watch(userNameProvider) ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              child: Column(
                children: [
                  // ── Avatar ──
                  Center(
                    child: Stack(
                      children: [
                        KlasivoAvatar(
                          name: userName,
                          backgroundColor: KlasivoColors.primary,
                          size: KlasivoAvatarSize.xl,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(KlasivoSpacing.sm),
                            decoration: BoxDecoration(
                              color: KlasivoColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Full Name ──
                  KlasivoTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),

                  // ── Email (read-only) ──
                  KlasivoTextField(
                    controller: _emailController,
                    label: 'Email',
                    readOnly: true,
                    enabled: false,
                    prefixIcon: Icons.email_outlined,
                    suffixIcon: const Icon(Icons.lock_outline_rounded, size: 16),
                    helperText: 'Email cannot be changed. Contact support if needed.',
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),

                  // ── Phone ──
                  KlasivoTextField(
                    controller: _phoneController,
                    label: 'Phone Number (Optional)',
                    hint: '+20 1XX XXX XXXX',
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Save Button ──
                  KlasivoButton(
                    label: 'Save Changes',
                    fullWidth: true,
                    loading: _isSaving,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
    );
  }
}
