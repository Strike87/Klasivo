import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
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
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: KlasivoColors.primary.withOpacity(0.1),
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                            style: KlasivoTypography.displayMedium.copyWith(
                              color: KlasivoColors.primary,
                            ),
                          ),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Full Name', style: KlasivoTypography.labelMedium.copyWith(
                      color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                    )),
                  ),
                  const SizedBox(height: KlasivoSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),

                  // ── Email (read-only) ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Email', style: KlasivoTypography.labelMedium.copyWith(
                      color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                    )),
                  ),
                  const SizedBox(height: KlasivoSpacing.sm),
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    enabled: false,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined, size: 20),
                      suffixIcon: Icon(Icons.lock_outline_rounded, size: 16),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email cannot be changed. Contact support if needed.',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.lg),

                  // ── Phone ──
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Phone Number (Optional)', style: KlasivoTypography.labelMedium.copyWith(
                      color: isDark ? KlasivoColors.darkTextSecondary : KlasivoColors.lightTextSecondary,
                    )),
                  ),
                  const SizedBox(height: KlasivoSpacing.sm),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+20 1XX XXX XXXX',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xxxl),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
