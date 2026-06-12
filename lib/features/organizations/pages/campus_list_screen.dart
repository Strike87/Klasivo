import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';
import '../domain/campus_model.dart';
import '../providers/campus_provider.dart';
import 'campus_form_screen.dart';

/// Displays a list of campuses for the current organization.
///
/// Features:
/// - Real-time campus list from Firestore
/// - Empty state with illustration
/// - Pull-to-refresh
/// - Campus cards showing name, city, student/teacher count, active/main badges
/// - Edit and archive actions via popup menu
class CampusListScreen extends ConsumerWidget {
  const CampusListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campusesAsync = ref.watch(campusListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campuses'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Campus',
            onPressed: () => _navigateToCreate(context),
          ),
        ],
      ),
      body: campusesAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading campuses…'),
        error: (error, _) => ErrorWidgetCustom(
          message: 'Failed to load campuses: $error',
          onRetry: () => ref.invalidate(campusListProvider),
        ),
        data: (campuses) {
          if (campuses.isEmpty) {
            return EmptyState(
              icon: Icons.location_city_outlined,
              title: 'No Campuses Yet',
              subtitle:
                  'Add campuses to represent physical locations\n'
                  'of your school (e.g. Main Campus, Branch).',
              actionLabel: 'Add Campus',
              onAction: () => _navigateToCreate(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(campusListProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: campuses.length,
              itemBuilder: (context, index) {
                return _CampusCard(
                  campus: campuses[index],
                  onEdit: () => _navigateToEdit(context, campuses[index]),
                  onArchive: () => _handleArchive(context, ref, campuses[index]),
                  onDelete: () => _handleDelete(context, ref, campuses[index]),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Campus'),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CampusFormScreen(),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, CampusModel campus) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampusFormScreen(
          isEditing: true,
          campus: campus,
        ),
      ),
    );
  }

  Future<void> _handleArchive(
    BuildContext context,
    WidgetRef ref,
    CampusModel campus,
  ) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Archive Campus',
      message:
          'Archive "${campus.name}"? It will be hidden but data is preserved.',
      confirmLabel: 'Archive',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(campusServiceProvider).archiveCampus(campus.id);
        if (context.mounted) {
          KlasivoToast.success(context, message: 'Campus archived');
        }
      } catch (e) {
        if (context.mounted) {
          KlasivoToast.error(context, message: 'Failed: $e');
        }
      }
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    CampusModel campus,
  ) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Delete Campus',
      message:
          'Permanently delete "${campus.name}"? This cannot be undone. '
          'Users assigned to this campus will be unlinked.',
      confirmLabel: 'Delete',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        await ref.read(campusServiceProvider).deleteCampus(campus.id);
        if (context.mounted) {
          KlasivoToast.success(context, message: 'Campus deleted');
        }
      } catch (e) {
        if (context.mounted) {
          KlasivoToast.error(context, message: 'Failed: $e');
        }
      }
    }
  }
}

// ─── Campus Card Widget ─────────────────────────────────────────────────────

class _CampusCard extends ConsumerWidget {
  final CampusModel campus;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _CampusCard({
    required this.campus,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      variant: KlasivoCardVariant.interactive,
      onTap: onEdit,
      child: Row(
        children: [
          // ── Icon ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KlasivoColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              campus.isMain
                  ? Icons.stars_rounded
                  : Icons.location_city_outlined,
              color: campus.isMain
                  ? KlasivoColors.accent
                  : KlasivoColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row with badges
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        campus.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (campus.isMain)
                      KlasivoBadge(
                        label: 'MAIN',
                        variant: KlasivoBadgeVariant.accent,
                        size: KlasivoBadgeSize.sm,
                        icon: Icons.stars_rounded,
                      ),
                    if (!campus.isActive)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: KlasivoBadge(
                          label: 'INACTIVE',
                          variant: KlasivoBadgeVariant.danger,
                          size: KlasivoBadgeSize.sm,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Location line
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      campus.locationText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Stats row
                Row(
                  children: [
                    Icon(Icons.school_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${campus.studentCount ?? 0} students',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.person_outline,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${campus.teacherCount ?? 0} teachers',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Actions Menu ──
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'archive') onArchive();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined,
                        size: 20, color: Colors.orange[700]),
                    SizedBox(width: 8),
                    Text('Archive',
                        style: TextStyle(color: Colors.orange[700])),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 20, color: KlasivoColors.error),
                    SizedBox(width: 8),
                    Text('Delete',
                        style: TextStyle(color: KlasivoColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
