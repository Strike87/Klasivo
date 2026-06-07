import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/stage_provider.dart';
import '../../../providers/grade_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';

class StageListScreen extends ConsumerWidget {
  const StageListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = ref.watch(stagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Stages'), centerTitle: true),
      body: stages.isEmpty
          ? const EmptyState(
              icon: Icons.school_outlined,
              title: 'No Stages Yet',
              subtitle: 'Create stages to organize your educational hierarchy',
              actionLabel: 'Add Stage',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(stagesStreamProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stages.length,
                itemBuilder: (context, index) {
                  final stage = stages[index];
                  return _StageCard(stage: stage);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStageDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Stage'),
      ),
    );
  }

  void _showAddStageDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stage'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Stage Name',
            hintText: 'e.g. Secondary Stage',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                final orgId = ref.read(currentOrganizationIdProvider) ?? '';
                final stages = ref.read(stagesProvider);
                final maxOrder = stages.isEmpty ? 0 : stages.map((s) => s.order).reduce((a, b) => a > b ? a : b);
                await ref.read(stageServiceProvider).createStage(
                      organizationId: orgId,
                      name: nameController.text.trim(),
                      order: maxOrder + 1,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) showSnackBar(context, message: 'Stage created successfully');
              } catch (e) {
                if (context.mounted) showSnackBar(context, message: 'Failed: $e', isError: true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _StageCard extends ConsumerWidget {
  final StageData stage;
  const _StageCard({required this.stage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesByStageListProvider(stage.id));
    final gradeCount = gradesAsync.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.school_outlined, color: Colors.indigo, size: 28),
        ),
        title: Text(stage.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$gradeCount grade${gradeCount != 1 ? 's' : ''}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'delete') {
              final confirmed = await showConfirmationDialog(
                context: context,
                title: 'Delete Stage',
                message: 'Delete "${stage.name}" and all its grades?',
                confirmLabel: 'Delete',
                isDangerous: true,
              );
              if (confirmed == true) {
                try {
                  await ref.read(stageServiceProvider).deleteStage(stage.id);
                  if (context.mounted) showSnackBar(context, message: 'Stage deleted');
                } catch (e) {
                  if (context.mounted) showSnackBar(context, message: 'Failed: $e', isError: true);
                }
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
