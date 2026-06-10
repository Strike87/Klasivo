import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_components.dart';

// ─── Parent Announcements Screen — View-Only Org Announcements ────────────────

class ParentAnnouncementsScreen extends ConsumerWidget {
  const ParentAnnouncementsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final organizationId = ref.watch(organizationIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Announcements',
          style: KlasivoTypography.titleLarge.copyWith(
            color: isDark
                ? KlasivoColors.darkTextPrimary
                : KlasivoColors.lightTextPrimary,
          ),
        ),
      ),
      body: organizationId == null || organizationId.isEmpty
          ? Center(
              child: KlasivoEmptyState(
                icon: Icons.domain_outlined,
                title: 'No organization found',
                subtitle: 'Your organization will appear once your account is set up.',
                iconColor: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            )
          : _ParentAnnouncementsList(
              organizationId: organizationId,
              parentId: ref.watch(userIdProvider) ?? '',
            ),
    );
  }
}

// ─── Announcements List (filtered for parent audience) ────────────────────────

class _ParentAnnouncementsList extends StatefulWidget {
  final String organizationId;
  final String parentId;

  const _ParentAnnouncementsList({
    required this.organizationId,
    required this.parentId,
  });

  @override
  State<_ParentAnnouncementsList> createState() =>
      _ParentAnnouncementsListState();
}

class _ParentAnnouncementsListState extends State<_ParentAnnouncementsList> {
  final Set<String> _readAnnouncements = {};

  Future<void> _markAsRead(String announcementId) async {
    if (_readAnnouncements.contains(announcementId)) return;

    setState(() {
      _readAnnouncements.add(announcementId);
    });

    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.announcementsCollection)
          .doc(announcementId)
          .set({
        'readBy': {widget.parentId: true},
      }, SetOptions(merge: true));
    } catch (_) {
      // Silently fail — read status is non-critical
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConstants.announcementsCollection)
          .where('organizationId', isEqualTo: widget.organizationId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: KlasivoLoading());
        }

        if (snapshot.hasError) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Error loading announcements',
              subtitle: 'Please try again later',
              iconColor: KlasivoColors.error,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Filter for targetAudience that includes 'parent' or 'all'
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetAudience = data['targetAudience'];

          if (targetAudience == null) return true; // No filter = visible to all

          if (targetAudience is String) {
            return targetAudience == 'parent' ||
                targetAudience == 'all';
          }

          if (targetAudience is List) {
            return targetAudience.contains('parent') ||
                targetAudience.contains('all');
          }

          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: KlasivoEmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements',
              subtitle:
                  'Announcements from your organization will appear here',
              iconColor: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          );
        }

        // Sort: pinned first, then by createdAt
        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aPinned = aData['isPinned'] as bool? ?? false;
          final bPinned = bData['isPinned'] as bool? ?? false;

          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          return 0; // Already sorted by createdAt descending
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.lg,
            vertical: KlasivoSpacing.sm,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final announcementId = filteredDocs[index].id;
            final title = data['title'] as String? ?? 'Announcement';
            final content = data['content'] as String? ?? '';
            final createdAt = data['createdAt'] as Timestamp?;
            final author = data['authorName'] as String? ?? data['author'] as String?;
            final isPinned = data['isPinned'] as bool? ?? false;
            final readBy = data['readBy'] as Map<String, dynamic>?;
            final isRead = readBy?[widget.parentId] as bool? ?? false ||
                _readAnnouncements.contains(announcementId);
            final dateFormat = DateFormat('MMM dd, yyyy');

            return Card(
              margin: const EdgeInsets.only(bottom: KlasivoSpacing.xs),
              elevation: isPinned ? 1.0 : 0.5,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(KlasivoRadius.sm),
                side: isPinned
                    ? BorderSide(
                        color: KlasivoColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      )
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () => _markAsRead(announcementId),
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.all(KlasivoSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top Row: Pin Badge + Read Status ──
                      Row(
                        children: [
                          if (isPinned) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KlasivoSpacing.sm,
                                vertical: KlasivoSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: KlasivoColors.primarySurface
                                    .withValues(alpha: isDark ? 0.15 : 1.0),
                                borderRadius:
                                    BorderRadius.circular(KlasivoRadius.pill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin_rounded,
                                    size: 12,
                                    color: KlasivoColors.primary,
                                  ),
                                  const SizedBox(width: KlasivoSpacing.xs),
                                  Text(
                                    'Pinned',
                                    style:
                                        KlasivoTypography.labelSmall.copyWith(
                                      color: KlasivoColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: KlasivoSpacing.sm),
                          ],
                          const Spacer(),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: KlasivoColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (isPinned)
                        const SizedBox(height: KlasivoSpacing.sm),

                      // ── Title ──
                      Text(
                        title,
                        style: KlasivoTypography.titleSmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextPrimary
                              : KlasivoColors.lightTextPrimary,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KlasivoSpacing.xs),

                      // ── Content Preview ──
                      Text(
                        content,
                        style: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: KlasivoSpacing.sm),

                      // ── Bottom Row: Date + Author ──
                      Row(
                        children: [
                          if (createdAt != null)
                            Text(
                              dateFormat.format(createdAt.toDate()),
                              style: KlasivoTypography.caption.copyWith(
                                color: isDark
                                    ? KlasivoColors.darkTextTertiary
                                    : KlasivoColors.lightTextTertiary,
                              ),
                            ),
                          if (createdAt != null && author != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KlasivoSpacing.sm,
                              ),
                              child: Text(
                                '·',
                                style: KlasivoTypography.caption.copyWith(
                                  color: isDark
                                      ? KlasivoColors.darkTextTertiary
                                      : KlasivoColors.lightTextTertiary,
                                ),
                              ),
                            ),
                          if (author != null)
                            Expanded(
                              child: Text(
                                author,
                                style: KlasivoTypography.caption.copyWith(
                                  color: isDark
                                      ? KlasivoColors.darkTextTertiary
                                      : KlasivoColors.lightTextTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
