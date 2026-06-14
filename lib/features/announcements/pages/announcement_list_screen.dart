import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/config/app_constants.dart';
import '../../../core/config/theme.dart';
import '../../../providers/announcement_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/paginated_providers.dart';
import '../../../core/services/pagination_service.dart';
import '../../../widgets/klasivo_paginated_list.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_avatar.dart';
import 'announcement_form_screen.dart';
import 'announcement_detail_screen.dart';

class AnnouncementListScreen extends ConsumerWidget {
  const AnnouncementListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinned = ref.watch(pinnedAnnouncementsProvider);
    final orgId = ref.watch(currentOrganizationIdProvider);
    final userId = ref.watch(userIdProvider);
    final paginationService = ref.watch(paginationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Filter bottom sheet
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AnnouncementFormScreen(isEditing: false)),
          );
        },
        backgroundColor: KlasivoColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Pinned announcements (kept as stream — small, needs real-time) ──
          if (pinned.isNotEmpty)
            Container(
              color: KlasivoColors.secondary.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KlasivoSpacing.lg, KlasivoSpacing.md, KlasivoSpacing.lg, 0),
                    child: KlasivoSectionHeader(title: 'Pinned'),
                  ),
                  ...pinned.map((a) => _AnnouncementCard(
                    announcement: a,
                    userId: userId ?? '',
                    isPinned: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnnouncementDetailScreen(announcementId: a.id),
                        ),
                      );
                    },
                  )),
                  const Divider(height: KlasivoSpacing.xxxl),
                ],
              ),
            ),

          // ── Recent announcements (paginated) ──
          Expanded(
            child: KlasivoPaginatedList<AnnouncementData>(
              loader: (cursor) => paginationService.fetchPage(
                collectionPath: 'announcements',
                fromFirestore: AnnouncementData.fromFirestore,
                cursor: cursor,
                pageSize: 20,
                orderBy: 'createdAt',
                descending: true,
                filters: [
                  if (orgId != null) QueryFilter.equalTo('organizationId', orgId),
                  QueryFilter.equalTo('isActive', true),
                ],
              ),
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              separator: const SizedBox(height: KlasivoSpacing.md),
              emptyWidget: KlasivoEmptyState(
                icon: Icons.campaign_outlined,
                title: 'No Announcements',
                subtitle: 'Create your first announcement to reach your organization',
                actionLabel: 'Create Announcement',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnnouncementFormScreen(isEditing: false)),
                  );
                },
              ),
              itemBuilder: (context, announcement, index) {
                return _AnnouncementCard(
                  announcement: announcement,
                  userId: userId ?? '',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnnouncementDetailScreen(announcementId: announcement.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  final AnnouncementData announcement;
  final String userId;
  final bool isPinned;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.announcement,
    required this.userId,
    this.isPinned = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRead = announcement.isReadBy(userId);

    return KlasivoCard(
      margin: EdgeInsets.zero,
      variant: isPinned ? KlasivoCardVariant.elevated : KlasivoCardVariant.outlined,
      onTap: () {
        // Mark as read
        if (!isRead) {
          ref.read(announcementServiceProvider).markAsRead(announcement.id, userId);
        }
        onTap();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: KlasivoSpacing.sm),
                  child: Icon(Icons.push_pin, size: 16, color: KlasivoColors.secondary),
                ),
              Expanded(
                child: Text(
                  announcement.title,
                  style: KlasivoTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isRead ? null : KlasivoColors.primary,
                  ),
                ),
              ),
              _TargetBadge(targetType: announcement.targetType),
            ],
          ),
          const SizedBox(height: KlasivoSpacing.sm),
          Text(
            announcement.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KlasivoTypography.bodyMedium.copyWith(
              color: theme.brightness == Brightness.dark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.md),
          Row(
            children: [
              if (announcement.createdByName != null) ...[
                KlasivoAvatar(
                  name: announcement.createdByName![0].toUpperCase(),
                  size: KlasivoAvatarSize.sm,
                  backgroundColor: KlasivoColors.primary.withOpacity(0.1),
                ),
                    const SizedBox(width: KlasivoSpacing.xs),
                    Text(
                      announcement.createdByName!,
                      style: KlasivoTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),
                  ],
                  if (announcement.createdAt != null)
                    Text(
                      timeago.format(announcement.createdAt!),
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  const Spacer(),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: KlasivoColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
  }
}

class _TargetBadge extends StatelessWidget {
  final String targetType;
  const _TargetBadge({required this.targetType});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (targetType) {
      'organization' => ('Everyone', KlasivoColors.primary),
      'class' => ('Class', KlasivoColors.secondary),
      'group' => ('Group', KlasivoColors.accent),
      _ => (targetType, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(KlasivoRadius.xs),
      ),
      child: Text(
        label,
        style: KlasivoTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}
