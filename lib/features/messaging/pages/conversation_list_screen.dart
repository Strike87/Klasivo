import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/messaging_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSATION LIST SCREEN — WhatsApp-style conversation list
// Shows all conversations for the current user with search, FAB, and pull-to-refresh.
// ═══════════════════════════════════════════════════════════════════════════════

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ConversationData> _filterConversations(
      List<ConversationData> conversations) {
    if (_searchQuery.isEmpty) return conversations;
    final query = _searchQuery.toLowerCase();
    return conversations
        .where((c) =>
            (c.name?.toLowerCase().contains(query) ?? false) ||
            c.type.toLowerCase().contains(query) ||
            (c.lastMessageText?.toLowerCase().contains(query) ?? false))
        .toList();
  }

  String _getConversationDisplayName(
      ConversationData conversation, String currentUserId) {
    if (conversation.name != null && conversation.name!.isNotEmpty) {
      return conversation.name!;
    }
    switch (conversation.type) {
      case 'direct':
        return 'Direct Message';
      case 'class':
        return 'Class Chat';
      case 'group':
        return 'Group Chat';
      default:
        return 'Conversation';
    }
  }

  IconData _getConversationIcon(String type) {
    switch (type) {
      case 'class':
        return Icons.school_outlined;
      case 'group':
        return Icons.group_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  void _showNewConversationDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    KlasivoModal.showContent(
      context: context,
      title: 'New Conversation',
      child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Direct Message ────────────────────────────────────────
              _NewConversationOption(
                icon: Icons.person_outline,
                iconColor: KlasivoColors.primary,
                title: 'Direct Message',
                subtitle: 'Start a private conversation',
                onTap: () {
                  Navigator.pop(context);
                  _showCreateDirectConversationDialog();
                },
              ),
              const SizedBox(height: KlasivoSpacing.md),
              // ─── Class Chat ────────────────────────────────────────────
              _NewConversationOption(
                icon: Icons.school_outlined,
                iconColor: KlasivoColors.secondary,
                title: 'Class Chat',
                subtitle: 'Message an entire class',
                onTap: () {
                  Navigator.pop(context);
                  KlasivoToast.info(context,
                      message: 'Class chat coming soon');
                },
              ),
              const SizedBox(height: KlasivoSpacing.md),
              // ─── Group Chat ────────────────────────────────────────────
              _NewConversationOption(
                icon: Icons.group_outlined,
                iconColor: KlasivoColors.accent,
                title: 'Group Chat',
                subtitle: 'Message a study group',
                onTap: () {
                  Navigator.pop(context);
                  KlasivoToast.info(context,
                      message: 'Group chat coming soon');
                },
              ),
              const SizedBox(height: KlasivoSpacing.lg),
            ],
          ),
    );
  }

  void _showCreateDirectConversationDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userIdController = TextEditingController();

    KlasivoModal.showForm(
      context: context,
      title: 'New Direct Message',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the user ID of the person you want to message',
            style: KlasivoTypography.bodySmall.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.lg),
          KlasivoTextField(
            controller: userIdController,
            label: 'User ID',
            hint: 'Paste user ID here',
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: KlasivoSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KlasivoButton(
                label: 'Cancel',
                variant: KlasivoButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: KlasivoSpacing.sm),
              KlasivoButton(
                label: 'Start Chat',
                onPressed: () async {
                  final otherUserId = userIdController.text.trim();
                  if (otherUserId.isEmpty) return;

                  final currentUserId = ref.read(currentUserIdProvider);
                  final orgId = ref.read(currentOrganizationIdProvider);
                  if (currentUserId == null || orgId == null) return;

                  Navigator.pop(context); // Close bottom sheet

                  try {
                    final conversationId = await ref
                        .read(messagingServiceProvider)
                        .getOrCreateDirectConversation(
                          organizationId: orgId,
                          userId1: currentUserId,
                          userId2: otherUserId,
                        );

                    if (mounted) {
                      context.go('/inbox/messages/$conversationId');
                    }
                  } catch (e) {
                    if (mounted) {
                      KlasivoToast.error(context,
                          message: 'Failed to create conversation: $e');
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final conversationsAsync = ref.watch(userConversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? KlasivoTextField(
                controller: _searchController,
                hint: 'Search conversations...',
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Messages'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationDialog,
        child: const Icon(Icons.chat_outlined),
      ),
      body: conversationsAsync.when(
        loading: () => const KlasivoLoading(message: 'Loading conversations...'),
        error: (error, stack) => KlasivoEmptyState(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          subtitle: 'Could not load conversations. Pull to retry.',
          iconColor: KlasivoColors.error,
        ),
        data: (snapshot) {
          final conversations = snapshot.docs
              .map((doc) => ConversationData.fromFirestore(doc))
              .toList();

          final filtered = _filterConversations(conversations);

          if (filtered.isEmpty && _searchQuery.isNotEmpty) {
            return KlasivoEmptyState(
              icon: Icons.search_off,
              title: 'No results',
              subtitle: 'No conversations match "$_searchQuery"',
            );
          }

          if (filtered.isEmpty) {
            return KlasivoEmptyState(
              icon: Icons.chat_outlined,
              title: 'No Messages Yet',
              subtitle: 'Start a conversation with a classmate or teacher',
              actionLabel: 'New Message',
              onAction: _showNewConversationDialog,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userConversationsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: KlasivoSpacing.sm,
              ),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76, // Aligned with text after avatar
                color: isDark
                    ? KlasivoColors.darkDivider
                    : KlasivoColors.lightDivider,
              ),
              itemBuilder: (context, index) {
                final conversation = filtered[index];
                return _ConversationTile(
                  conversation: conversation,
                  currentUserId: currentUserId ?? '',
                  isLast: index == filtered.length - 1,
                  onTap: () {
                    context.go('/inbox/messages/${conversation.id}');
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONVERSATION TILE — Individual conversation row
// ═══════════════════════════════════════════════════════════════════════════════

class _ConversationTile extends ConsumerWidget {
  final ConversationData conversation;
  final String currentUserId;
  final bool isLast;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    this.isLast = false,
    required this.onTap,
  });

  String _getDisplayName() {
    if (conversation.name != null && conversation.name!.isNotEmpty) {
      return conversation.name!;
    }
    switch (conversation.type) {
      case 'direct':
        return 'Direct Message';
      case 'class':
        return 'Class Chat';
      case 'group':
        return 'Group Chat';
      default:
        return 'Conversation';
    }
  }

  String _getInitials() {
    if (conversation.name != null && conversation.name!.isNotEmpty) {
      final parts = conversation.name!.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    switch (conversation.type) {
      case 'class':
        return 'C';
      case 'group':
        return 'G';
      default:
        return '?';
    }
  }

  Color _getAvatarColor() {
    switch (conversation.type) {
      case 'class':
        return KlasivoColors.secondary;
      case 'group':
        return KlasivoColors.accent;
      default:
        return KlasivoColors.primary;
    }
  }

  IconData _getIcon() {
    switch (conversation.type) {
      case 'class':
        return Icons.school_outlined;
      case 'group':
        return Icons.group_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    // Today: show time
    if (diff.inDays == 0 && now.day == dt.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // Yesterday
    if (diff.inDays == 1) return 'Yesterday';

    // This week
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }

    // Older
    return timeago.format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = conversation.lastMessageSenderId != null &&
        conversation.lastMessageSenderId != currentUserId &&
        conversation.lastMessageAt != null;

    // Determine if the last message was from current user
    final isOwnLastMessage =
        conversation.lastMessageSenderId == currentUserId;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.lg,
          vertical: KlasivoSpacing.md,
        ),
        child: Row(
          children: [
            // ─── Avatar ──────────────────────────────────────────────────
            if (conversation.type == 'direct')
              KlasivoAvatar(
                name: _getDisplayName(),
                backgroundColor: _getAvatarColor(),
                size: KlasivoAvatarSize.md,
              )
            else
              KlasivoAvatar(
                backgroundColor: _getAvatarColor(),
                size: KlasivoAvatarSize.md,
                name: _getInitials(),
              ),
            const SizedBox(width: KlasivoSpacing.md),

            // ─── Content ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getDisplayName(),
                          style: KlasivoTypography.titleMedium.copyWith(
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: isDark
                                ? KlasivoColors.darkTextPrimary
                                : KlasivoColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: KlasivoSpacing.sm),
                      if (conversation.type != 'direct')
                        KlasivoBadge(
                          label: conversation.type == 'class' ? 'Class' : 'Group',
                          variant: conversation.type == 'class'
                              ? KlasivoBadgeVariant.secondary
                              : KlasivoBadgeVariant.accent,
                          size: KlasivoBadgeSize.sm,
                        ),
                    ],
                  ),
                  const SizedBox(height: KlasivoSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessageText ?? 'No messages yet',
                          style: KlasivoTypography.bodySmall.copyWith(
                            color: isUnread
                                ? (isDark
                                    ? KlasivoColors.darkTextSecondary
                                    : KlasivoColors.lightTextSecondary)
                                : (isDark
                                    ? KlasivoColors.darkTextTertiary
                                    : KlasivoColors.lightTextTertiary),
                            fontWeight:
                                isUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: KlasivoSpacing.sm),
                      // ─── Timestamp ───────────────────────────────────
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Unread Indicator ────────────────────────────────────────
            if (isUnread) ...[
              const SizedBox(width: KlasivoSpacing.sm),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: KlasivoColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: KlasivoColors.primary.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NEW CONVERSATION OPTION — Bottom sheet option row
// ═══════════════════════════════════════════════════════════════════════════════

class _NewConversationOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NewConversationOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KlasivoRadius.md),
      child: Container(
        padding: const EdgeInsets.all(KlasivoSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
          ),
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: KlasivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KlasivoTypography.titleMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xs),
                  Text(
                    subtitle,
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
