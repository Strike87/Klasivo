import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/config/theme.dart';
import '../../../providers/announcement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_toast.dart';

class AnnouncementFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final AnnouncementData? announcementData;

  const AnnouncementFormScreen({
    Key? key,
    required this.isEditing,
    this.announcementData,
  }) : super(key: key);

  @override
  ConsumerState<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends ConsumerState<AnnouncementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _targetType = 'organization';
  String _targetId = '';
  bool _isPinned = false;
  DateTime? _expiresAt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.announcementData != null) {
      _titleController.text = widget.announcementData!.title;
      _contentController.text = widget.announcementData!.content;
      _targetType = widget.announcementData!.targetType;
      _targetId = widget.announcementData!.targetId;
      _isPinned = widget.announcementData!.isPinned;
      _expiresAt = widget.announcementData!.expiresAt;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final orgId = ref.read(currentOrganizationIdProvider);
      final userId = ref.read(userIdProvider);
      final userName = ref.read(userNameProvider);

      if (widget.isEditing) {
        await ref.read(announcementServiceProvider).updateAnnouncement(
          widget.announcementData!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          targetType: _targetType,
          targetId: _targetId.isEmpty ? orgId! : _targetId,
          isPinned: _isPinned,
          expiresAt: _expiresAt,
        );
      } else {
        await ref.read(announcementServiceProvider).createAnnouncement(
          organizationId: orgId!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          targetType: _targetType,
          targetId: _targetId.isEmpty ? orgId : _targetId,
          createdBy: userId,
          createdByName: userName,
          isPinned: _isPinned,
          expiresAt: _expiresAt,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Announcement' : 'New Announcement'),
        actions: [
          KlasivoButton(
            label: 'Save',
            onPressed: _isLoading ? null : _save,
            variant: KlasivoButtonVariant.tertiary,
            icon: Icons.check,
            loading: _isLoading,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          children: [
            // Title
            KlasivoTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'e.g., School Closed Tomorrow',
              validator: (v) => v?.trim().isEmpty == true ? 'Title is required' : null,
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // Content
            KlasivoTextField(
              controller: _contentController,
              label: 'Content',
              hint: 'Write your announcement...',
              maxLines: 5,
              validator: (v) => v?.trim().isEmpty == true ? 'Content is required' : null,
            ),
            const SizedBox(height: KlasivoSpacing.xxl),

            // Target Section
            Text('Audience', style: KlasivoTypography.titleSmall),
            const SizedBox(height: KlasivoSpacing.sm),
            DropdownButtonFormField<String>(
              value: _targetType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              items: const [
                DropdownMenuItem(value: 'organization', child: Text('Everyone (Organization-wide)')),
                DropdownMenuItem(value: 'class', child: Text('Specific Class')),
                DropdownMenuItem(value: 'group', child: Text('Specific Group')),
              ],
              onChanged: (v) => setState(() { _targetType = v!; _targetId = ''; }),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // Pin Toggle
            SwitchListTile(
              title: const Text('Pin this announcement'),
              subtitle: const Text('Pinned announcements appear at the top'),
              value: _isPinned,
              onChanged: (v) => setState(() => _isPinned = v),
              activeColor: KlasivoColors.secondary,
            ),
            const SizedBox(height: KlasivoSpacing.sm),

            // Expiry Date
            ListTile(
              title: Text(_expiresAt == null ? 'Set expiry date' : 'Expires: ${_formatDate(_expiresAt!)}'),
              subtitle: _expiresAt != null ? const Text('Tap to change or clear') : const Text('Optional'),
              leading: const Icon(Icons.event),
              trailing: _expiresAt != null
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _expiresAt = null))
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) setState(() => _expiresAt = date);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
