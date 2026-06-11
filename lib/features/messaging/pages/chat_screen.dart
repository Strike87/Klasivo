import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/messaging_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT SCREEN — Full conversation view with message bubbles
// Displays messages for a single conversation with send input, read receipts,
// auto-scroll, and message deletion.
// ═══════════════════════════════════════════════════════════════════════════════

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({
    Key? key,
    required this.conversationId,
  }) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening the conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await ref.read(messagingServiceProvider).markMessagesAsRead(
            conversationId: widget.conversationId,
            userId: userId,
          );
    } catch (_) {
      // Silently fail — non-critical operation
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(messagingServiceProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: userId,
            text: text,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context,
            message: 'Failed to send message: $e');
      }
      // Restore the message text so the user doesn't lose it
      _messageController.text = text;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _showDeleteConfirmation(MessageData message) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Delete Message',
      message:
          'Are you sure you want to delete this message? This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(messagingServiceProvider).deleteMessage(message.id);
      } catch (e) {
        if (mounted) {
          KlasivoToast.error(context,
              message: 'Failed to delete message: $e');
        }
      }
    }
  }

  String _getConversationDisplayName(ConversationData conversation) {
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
        return 'Chat';
    }
  }

  IconData _getConversationIcon(String type) {
    switch (type) {
      case 'class':
        return Icons.school_outlined;
      case 'group':
        return Icons.group_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final messagesAsync =
        ref.watch(conversationMessagesProvider(widget.conversationId));

    // Find the conversation from the user's conversations list to get the name
    final conversationsAsync = ref.watch(userConversationsProvider);
    ConversationData? currentConversation;
    conversationsAsync.whenData((snapshot) {
      for (final doc in snapshot.docs) {
        if (doc.id == widget.conversationId) {
          currentConversation = ConversationData.fromFirestore(doc);
          break;
        }
      }
    });

    final conversationName = currentConversation != null
        ? _getConversationDisplayName(currentConversation!)
        : 'Chat';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (currentConversation != null &&
                currentConversation!.type != 'direct')
              Padding(
                padding: const EdgeInsets.only(right: KlasivoSpacing.sm),
                child: Icon(
                  _getConversationIcon(currentConversation!.type),
                  size: 20,
                  color: isDark
                      ? KlasivoColors.primaryLight
                      : KlasivoColors.primary,
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversationName,
                    style: KlasivoTypography.titleMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                  if (currentConversation != null &&
                      currentConversation!.type != 'direct')
                    Text(
                      '${currentConversation!.participantIds.length} participants',
                      style: KlasivoTypography.caption.copyWith(
                        color: isDark
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
      body: Column(
        children: [
          // ─── Message List ────────────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const KlasivoLoading(message: 'Loading messages...'),
              error: (error, stack) => KlasivoEmptyState(
                icon: Icons.error_outline,
                title: 'Something went wrong',
                subtitle: 'Could not load messages. Pull to retry.',
                iconColor: KlasivoColors.error,
              ),
              data: (snapshot) {
                final messages = snapshot.docs
                    .map((doc) => MessageData.fromFirestore(doc))
                    .toList();

                // Auto-scroll when new messages arrive
                if (messages.isNotEmpty) {
                  _scrollToBottom();
                  // Mark as read when viewing messages
                  _markAsRead();
                }

                if (messages.isEmpty) {
                  return KlasivoEmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Start the conversation',
                    subtitle:
                        'Send a message to begin chatting',
                    iconColor: KlasivoColors.primary,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.lg,
                    vertical: KlasivoSpacing.md,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOwnMessage =
                        currentUserId != null &&
                        message.senderId == currentUserId;

                    // Check if this is the first message from this sender
                    // in a consecutive group
                    final isFirstInGroup = index == 0 ||
                        messages[index - 1].senderId != message.senderId;

                    return _MessageBubble(
                      message: message,
                      isOwnMessage: isOwnMessage,
                      isFirstInGroup: isFirstInGroup,
                      currentUserId: currentUserId ?? '',
                      onLongPress: isOwnMessage
                          ? () => _showDeleteConfirmation(message)
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          // ─── Input Bar ───────────────────────────────────────────────────
          _ChatInputBar(
            controller: _messageController,
            focusNode: _focusNode,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MESSAGE BUBBLE — Individual message display
// ═══════════════════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final MessageData message;
  final bool isOwnMessage;
  final bool isFirstInGroup;
  final String currentUserId;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
    required this.isFirstInGroup,
    required this.currentUserId,
    this.onLongPress,
  });

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Bubble colors
    final ownBubbleColor = isDark
        ? KlasivoColors.primaryDark
        : KlasivoColors.primary;
    final otherBubbleColor = isDark
        ? KlasivoColors.darkCard
        : KlasivoColors.lightSurface;

    final ownTextColor = Colors.white;
    final otherTextColor = isDark
        ? KlasivoColors.darkTextPrimary
        : KlasivoColors.lightTextPrimary;

    final timeColor = isOwnMessage
        ? Colors.white.withOpacity(0.7)
        : (isDark
            ? KlasivoColors.darkTextTertiary
            : KlasivoColors.lightTextTertiary);

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInGroup ? KlasivoSpacing.md : KlasivoSpacing.xs,
        bottom: KlasivoSpacing.xs,
      ),
      child: Align(
        alignment:
            isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.md,
                vertical: KlasivoSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isOwnMessage ? ownBubbleColor : otherBubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(KlasivoRadius.md),
                  topRight: const Radius.circular(KlasivoRadius.md),
                  bottomLeft: isOwnMessage
                      ? const Radius.circular(KlasivoRadius.md)
                      : const Radius.circular(KlasivoSpacing.xs),
                  bottomRight: isOwnMessage
                      ? const Radius.circular(KlasivoSpacing.xs)
                      : const Radius.circular(KlasivoRadius.md),
                ),
                border: isOwnMessage
                    ? null
                    : Border.all(
                        color: isDark
                            ? KlasivoColors.darkBorder
                            : KlasivoColors.lightBorder,
                        width: 1,
                      ),
                boxShadow: isOwnMessage
                    ? [
                        BoxShadow(
                          color: KlasivoColors.primary.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isOwnMessage
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // ─── Message Text ──────────────────────────────────────
                  Text(
                    message.text,
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isOwnMessage ? ownTextColor : otherTextColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.xs),

                  // ─── Time + Read Receipt ──────────────────────────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: KlasivoTypography.caption.copyWith(
                          color: timeColor,
                          fontSize: 10,
                        ),
                      ),
                      if (isOwnMessage) ...[
                        const SizedBox(width: KlasivoSpacing.xs),
                        _ReadReceiptIndicator(
                          isRead: message.isRead ||
                              (message.readBy.isNotEmpty &&
                                  message.readBy
                                      .where((id) => id != message.senderId)
                                      .isNotEmpty),
                          color: timeColor,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// READ RECEIPT INDICATOR — Double checkmark for message status
// ═══════════════════════════════════════════════════════════════════════════════

class _ReadReceiptIndicator extends StatelessWidget {
  final bool isRead;
  final Color color;

  const _ReadReceiptIndicator({
    required this.isRead,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      // Double checkmark — read
      return SizedBox(
        width: 16,
        height: 12,
        child: CustomPaint(
          painter: _DoubleCheckPainter(
            color: color,
            strokeWidth: 1.5,
          ),
        ),
      );
    } else {
      // Single checkmark — sent/delivered
      return Icon(
        Icons.check,
        size: 14,
        color: color,
      );
    }
  }
}

class _DoubleCheckPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DoubleCheckPainter({
    required this.color,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // First check (left, slightly behind)
    final path1 = Path()
      ..moveTo(0, h * 0.55)
      ..lineTo(w * 0.22, h * 0.8)
      ..lineTo(w * 0.42, h * 0.2);

    // Second check (right, slightly in front)
    final path2 = Path()
      ..moveTo(w * 0.28, h * 0.55)
      ..lineTo(w * 0.5, h * 0.8)
      ..lineTo(w * 0.75, h * 0.2);

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT INPUT BAR — Bottom input bar with text field and send button
// ═══════════════════════════════════════════════════════════════════════════════

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark
                ? KlasivoColors.darkBorder
                : KlasivoColors.lightBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ─── Text Input ──────────────────────────────────────────────
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 44,
                  maxHeight: 120,
                ),
                child: KlasivoTextField(
                  controller: controller,
                  focusNode: focusNode,
                  hint: 'Type a message...',
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
              ),
            ),
            const SizedBox(width: KlasivoSpacing.sm),

            // ─── Send Button ─────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: isSending
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: KlasivoColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(KlasivoRadius.md),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              isDark
                                  ? KlasivoColors.primaryLight
                                  : KlasivoColors.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: KlasivoColors.primary,
                        borderRadius: BorderRadius.circular(KlasivoRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color:
                                KlasivoColors.primary.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(KlasivoRadius.md),
                        child: InkWell(
                          onTap: onSend,
                          borderRadius:
                              BorderRadius.circular(KlasivoRadius.md),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
