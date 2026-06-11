import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/moderation_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_toast.dart';

// ─── Moderation Service Provider ──────────────────────────────────────────────

final moderationServiceProvider = Provider<ModerationService>((ref) => ModerationService());

final moderationPendingStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, orgId) {
  return ref.read(moderationServiceProvider).getPendingItemsStream(orgId);
});

final moderationAllStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, orgId) {
  return ref.read(moderationServiceProvider).getAllItemsStream(orgId);
});

// ─── Moderation Queue Screen ──────────────────────────────────────────────────

class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends ConsumerState<ModerationQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(currentOrganizationIdProvider) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Queue'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Review'),
            Tab(text: 'All Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(orgId),
          _buildAllList(orgId),
        ],
      ),
    );
  }

  Widget _buildPendingList(String orgId) {
    final asyncItems = ref.watch(moderationPendingStreamProvider(orgId));

    return asyncItems.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => ErrorWidgetCustom(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(moderationPendingStreamProvider(orgId)),
      ),
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.verified_outlined,
            title: 'All Clear',
            subtitle: 'No resources pending review.',
            iconColor: KlasivoColors.secondary,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.docs[index].data() as Map<String, dynamic>;
            return _ModerationCard(
              itemId: snapshot.docs[index].id,
              data: data,
              onApprove: () => _handleAction(snapshot.docs[index].id, 'approve'),
              onReject: () => _handleAction(snapshot.docs[index].id, 'reject'),
            );
          },
        );
      },
    );
  }

  Widget _buildAllList(String orgId) {
    final asyncItems = ref.watch(moderationAllStreamProvider(orgId));

    return asyncItems.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => ErrorWidgetCustom(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(moderationAllStreamProvider(orgId)),
      ),
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Items',
            subtitle: 'No resources have been submitted for review yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.docs[index].data() as Map<String, dynamic>;
            return _ModerationCard(
              itemId: snapshot.docs[index].id,
              data: data,
              onApprove: data['status'] == 'pending'
                  ? () => _handleAction(snapshot.docs[index].id, 'approve')
                  : null,
              onReject: data['status'] == 'pending'
                  ? () => _handleAction(snapshot.docs[index].id, 'reject')
                  : null,
            );
          },
        );
      },
    );
  }

  Future<void> _handleAction(String itemId, String action) async {
    final userId = ref.read(userIdProvider) ?? '';
    setState(() => _isLoading = true);

    try {
      if (action == 'approve') {
        await ref.read(moderationServiceProvider).approveItem(
              itemId: itemId,
              reviewedBy: userId,
            );
        if (mounted) KlasivoToast.success(context, message: 'Resource approved');
      } else {
        await ref.read(moderationServiceProvider).rejectItem(
              itemId: itemId,
              reviewedBy: userId,
            );
        if (mounted) KlasivoToast.success(context, message: 'Resource rejected');
      }
    } catch (e) {
      if (mounted) KlasivoToast.error(context, message: 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ModerationCard extends StatelessWidget {
  final String itemId;
  final Map<String, dynamic> data;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ModerationCard({
    required this.itemId,
    required this.data,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final title = data['title'] as String? ?? 'Untitled';
    final resourceType = data['resourceType'] as String? ?? 'resource';
    final submittedBy = data['submittedBy'] as String? ?? '';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = KlasivoColors.secondary;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = KlasivoColors.error;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = KlasivoColors.accent;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Pending';
    }

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${resourceType.toUpperCase()} · $statusLabel',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (status == 'pending') ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: KlasivoColors.secondary),
                  tooltip: 'Approve',
                  onPressed: onApprove,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: KlasivoColors.error),
                  tooltip: 'Reject',
                  onPressed: onReject,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
