import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';
import '../../../core/config/theme.dart';

/// Shows classes filtered by a specific stage, or all classes org-wide
/// if [stageId] is null or empty.
class ClassListScreen extends ConsumerWidget {
  final String? stageId;
  const ClassListScreen({Key? key, this.stageId}) : super(key: key);

  bool get _isStageScoped => stageId != null && stageId!.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pick the right data source
    final stageClasses = _isStageScoped
        ? ref.watch(classesByStageListProvider(stageId!))
        : <ClassData>[];
    final allClasses = ref.watch(classesProvider);
    final classes = _isStageScoped ? stageClasses : allClasses;

    final stageName = _isStageScoped
        ? (ref.watch(stageByIdProvider(stageId!))?.name ?? 'Stage')
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isStageScoped ? 'Classes - $stageName' : 'All Classes',
        ),
        centerTitle: true,
      ),
      body: classes.isEmpty
          ? EmptyState(
              icon: Icons.class_outlined,
              title: 'No Classes Yet',
              subtitle: _isStageScoped
                  ? 'Create classes under $stageName.\n'
                      'e.g. Grade 1, Grade 2, Section A'
                  : 'Create stages first, then add classes to them.',
              actionLabel: 'Add Class',
              onAction: () => _navigateToCreate(context),
            )
          : RefreshIndicator(
              onRefresh: () async {
                if (_isStageScoped) {
                  ref.invalidate(classesByStageProvider(stageId!));
                } else {
                  ref.invalidate(classesByOrgProvider);
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final classData = classes[index];
                  return _ClassCard(
                    classData: classData,
                    showStageName: !_isStageScoped,
                    onTap: () {
                      context.go(
                        '/teacher/classes/${classData.id}/students',
                      );
                    },
                    onEdit: () {
                      context.go(
                        '/teacher/classes/edit/${classData.id}',
                        extra: classData,
                      );
                    },
                    onArchive: () async {
                      final confirmed = await KlasivoModal.confirm(
                        context: context,
                        title: 'Archive Class',
                        message:
                            'Archive "${classData.name}"? It will be hidden but data is preserved.',
                        confirmLabel: 'Archive',
                        isDangerous: true,
                      );
                      if (confirmed == true) {
                        try {
                          final userId = ref.read(userIdProvider) ?? '';
                          await ref
                              .read(classServiceProvider)
                              .archiveClass(classData.id, archivedBy: userId);
                          if (context.mounted) {
                            KlasivoToast.success(context, message: 'Class archived');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            KlasivoToast.error(context,
                                message: 'Failed: $e');
                          }
                        }
                      }
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    if (_isStageScoped) {
      context.go(
        '/academic/stages/$stageId/classes/create',
        extra: stageId,
      );
    } else {
      // Org-wide: go to class form with no stage pre-selected
      context.go('/teacher/classes/create');
    }
  }
}

class _ClassCard extends ConsumerWidget {
  final ClassData classData;
  final bool showStageName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _ClassCard({
    required this.classData,
    this.showStageName = false,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stageName = showStageName
        ? (ref.watch(stageByIdProvider(classData.stageId))?.name ?? '')
        : null;

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      variant: KlasivoCardVariant.interactive,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KlasivoColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.class_outlined,
              color: KlasivoColors.secondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classData.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (stageName != null && stageName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: KlasivoColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          stageName,
                          style: TextStyle(
                            color: KlasivoColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (classData.code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: KlasivoColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          classData.code,
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (classData.capacity > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_seat_outlined,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${classData.capacity}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${classData.studentCount} students',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'archive') onArchive();
              if (value == 'qr') {
                context.go(
                  '/teacher/classes/${classData.id}/students/qr',
                  extra: {
                    'className': classData.name,
                    'code': classData.code,
                  },
                );
              }
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
              const PopupMenuItem(
                value: 'qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code,
                        size: 20, color: KlasivoColors.primary),
                    SizedBox(width: 8),
                    Text('QR Enrollment Code',
                        style: TextStyle(color: KlasivoColors.primary)),
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
            ],
          ),
        ],
      ),
    );
  }
}
