import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_toast.dart';
import '../domain/campus_model.dart';
import '../providers/campus_provider.dart';

/// Form screen for creating or editing a campus.
///
/// When [isEditing] is true and [campus] is provided, the form is
/// pre-populated with the existing campus data. Otherwise, it's a blank
/// create form.
class CampusFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final CampusModel? campus;

  const CampusFormScreen({
    Key? key,
    this.isEditing = false,
    this.campus,
  }) : super(key: key);

  @override
  ConsumerState<CampusFormScreen> createState() => _CampusFormScreenState();
}

class _CampusFormScreenState extends ConsumerState<CampusFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isMain = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.campus != null) {
      final c = widget.campus!;
      _nameController.text = c.name;
      _addressController.text = c.address ?? '';
      _cityController.text = c.city ?? '';
      _countryController.text = c.country ?? '';
      _phoneController.text = c.phone ?? '';
      _emailController.text = c.email ?? '';
      _isMain = c.isMain;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ─── Validators ──────────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'Campus name is required';
    }
    if (value!.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    if (value.trim().length < 6) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  // ─── Submit ──────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final campusService = ref.read(campusServiceProvider);
      final orgId = ref.read(currentOrganizationIdProvider) ?? '';

      if (widget.isEditing) {
        await campusService.updateCampus(
          campusId: widget.campus!.id,
          organizationId: orgId,
          name: _nameController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          isMain: _isMain,
        );
        if (mounted) {
          KlasivoToast.success(context, message: 'Campus updated successfully');
          Navigator.of(context).pop();
        }
      } else {
        await campusService.createCampus(
          organizationId: orgId,
          name: _nameController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          isMain: _isMain,
        );
        if (mounted) {
          KlasivoToast.success(context, message: 'Campus created successfully');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Campus' : 'Create Campus'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Icon ──
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KlasivoColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.isEditing
                      ? Icons.edit_outlined
                      : Icons.location_city_outlined,
                  size: 48,
                  color: KlasivoColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Form ──
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Campus Name
                  KlasivoTextField(
                    controller: _nameController,
                    label: 'Campus Name *',
                    hint: 'e.g. Main Campus, North Branch',
                    prefixIcon: Icons.location_city_outlined,
                    validator: _validateName,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Address
                  KlasivoTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'e.g. 123 Education Street',
                    prefixIcon: Icons.map_outlined,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),

                  // City & Country in a row
                  Row(
                    children: [
                      Expanded(
                        child: KlasivoTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g. Cairo',
                          prefixIcon: Icons.location_on_outlined,
                          enabled: !_isLoading,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KlasivoTextField(
                          controller: _countryController,
                          label: 'Country',
                          hint: 'e.g. Egypt',
                          enabled: !_isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  KlasivoTextField(
                    controller: _phoneController,
                    label: 'Phone',
                    hint: 'e.g. +20 123 456 7890',
                    prefixIcon: Icons.phone_outlined,
                    validator: _validatePhone,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  KlasivoTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'e.g. campus@school.edu',
                    prefixIcon: Icons.email_outlined,
                    validator: _validateEmail,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  // Main Campus Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _isMain
                          ? KlasivoColors.accent.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isMain
                            ? KlasivoColors.accent.withOpacity(0.3)
                            : KlasivoColors.lightBorder,
                      ),
                    ),
                    child: SwitchListTile(
                      value: _isMain,
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() => _isMain = value);
                            },
                      title: const Text('Main Campus'),
                      subtitle: Text(
                        _isMain
                            ? 'This is the primary campus for your organization'
                            : 'Toggle to set as the primary campus',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      secondary: Icon(
                        Icons.stars_rounded,
                        color: _isMain
                            ? KlasivoColors.accent
                            : Colors.grey[400],
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Submit Button ──
                  KlasivoButton(
                    label:
                        widget.isEditing ? 'Update Campus' : 'Create Campus',
                    onPressed: _isLoading ? null : _handleSubmit,
                    loading: _isLoading,
                    fullWidth: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Help Text ──
            if (!widget.isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KlasivoColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: KlasivoColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: KlasivoColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Campuses represent physical locations of your school. '
                        'After creating a campus, you can assign students and '
                        'teachers to it. Only one campus can be marked as main.',
                        style: TextStyle(
                          color: KlasivoColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
