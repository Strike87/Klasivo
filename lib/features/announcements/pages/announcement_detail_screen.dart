import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/config/theme.dart';
import '../../../providers/announcement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_permission_gate.dart';
import 'announcement_form_screen.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final String announcementId;

  const AnnouncementDetailScreen({Key? key, required this.announcementId}) : super(key: key);

  @override
  ConsumerState<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends ConsumerState<AnnouncementDetailScreen> {
  AnnouncementData? _announcement;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    try {
      final data = await ref.read(announcementServiceProvider).getAnnouncement(widget.announcementId);
      if (data != null && mounted) {
        setState(() {
          _announcement = AnnouncementData(
            id: data['id'],
            organizationId: data['organizationId'] ?? '',
            title: data['title'] ?? '',
            content: data['content'] ?? '',
            targetType: data['targetType'] ?? 'organization',
            targetId: data['targetId'] ?? '',
            createdBy: data['createdBy'],
            createdByName: data['createdByName'],
            isPinned: data['isPinned'] ?? false,
            isActive: data['isActive'] ?? true,
            expiresAt: (data['expiresAt'] as dynamic)?.toDate(),
            readBy: List<String>.from(data['readBy'] ?? []),
            createdAt: (data['createdAt'] as dynamic)?.toDate(),
            updatedAt: (data['updatedAt'] as dynamic)?.toDate(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(userIdProvider);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_announcement == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Announcement not found')),
      );
    }

    final a = _announcement!;
    final isOwnerOrCreator = ref.read(userRoleProvider) == AppConstants.roleOwner || a.createdBy == userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: [
          IconButton(
            icon: Icon(a.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            color: a.isPinned ? KlasivoColors.secondary : null,
            onPressed: () async {
              await ref.read(announcementServiceProvider).togglePin(a.id, !a.isPinned);
              _loadAnnouncement();
            },
          ),
          if (isOwnerOrCreator)
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: KlasivoColors.error))),
              ],
              onSelected: (value) async {
                if (value == 'edit') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnnouncementFormScreen(isEditing: true, announcementData: a),
                    ),
                  ).then((_) => _loadAnnouncement());
                } else if (value == 'delete') {
                  final confirm = await KlasivoModal.confirm(
                    context: context,
                    title: 'Delete Announcement',
                    message: 'Are you sure you want to delete this announcement?',
                    confirmLabel: 'Delete',
                    isDangerous: true,
                  );
                  if (confirm == true) {
                    await ref.read(announcementServiceProvider).deleteAnnouncement(a.id);
                    if (mounted) Navigator.of(context).pop();
                  }
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KlasivoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              a.title,
              style: KlasivoTypography.headlineSmall.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // Meta row
            Row(
              children: [
                if (a.createdByName != null) ...[
                  KlasivoAvatar(
                    name: a.createdByName![0].toUpperCase(),
                    size: KlasivoAvatarSize.sm,
                    backgroundColor: KlasivoColors.primary.withOpacity(0.1),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Text(a.createdByName!, style: KlasivoTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(width: KlasivoSpacing.lg),
                ],
                _buildBadge(a.targetLabel, _getColorForType(a.targetType)),
                const Spacer(),
                if (a.isPinned)
                  const Icon(Icons.push_pin, size: 16, color: KlasivoColors.secondary),
                if (a.createdAt != null) ...[
                  const SizedBox(width: KlasivoSpacing.sm),
                  Text(
                    _formatDate(a.createdAt!),
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: KlasivoSpacing.xxxl),

            // Content
            Text(
              a.content,
              style: KlasivoTypography.bodyLarge.copyWith(height: 1.7),
            ),

            const SizedBox(height: KlasivoSpacing.xxxl),

            // Read receipts
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.md),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 18, color: theme.brightness == Brightness.dark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Text(
                    '${a.readBy.length} people read this',
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
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

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(KlasivoRadius.xs),
      ),
      child: Text(label, style: KlasivoTypography.labelSmall.copyWith(color: color)),
    );
  }

  Color _getColorForType(String type) {
    return switch (type) {
      'organization' => KlasivoColors.primary,
      'class' => KlasivoColors.secondary,
      'group' => KlasivoColors.accent,
      _ => Colors.grey,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
