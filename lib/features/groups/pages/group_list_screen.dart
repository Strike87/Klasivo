import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/group_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../core/config/theme.dart';
import '../../../widgets/klasivo_components.dart';

class GroupListScreen extends ConsumerWidget {
  final String classId;
  const GroupListScreen({Key? key, required this.classId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsByClassListProvider(classId));

    return Scaffold(
      appBar: AppBar(title: const Text('Groups'), centerTitle: true),
      body: groups.isEmpty
          ? const KlasivoEmptyState(
              icon: Icons.group_work_outlined,
              title: 'No Groups Yet',
              subtitle: 'Create groups within this class',
              iconColor: KlasivoColors.secondary,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Card(
                  margin: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KlasivoRadius.md),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: KlasivoColors.secondarySurface,
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.group_work_outlined, color: KlasivoColors.secondary, size: 24),
                    ),
                    title: Text(
                      group.name,
                      style: KlasivoTypography.titleMedium.copyWith(
                        color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: KlasivoColors.error),
                      onPressed: () async {
                        final confirmed = await showConfirmationDialog(
                          context: context,
                          title: 'Delete Group',
                          message: 'Delete "${group.name}"?',
                          isDangerous: true,
                        );
                        if (confirmed == true) {
                          try {
                            await ref.read(groupServiceProvider).deleteGroup(group.id);
                            if (context.mounted) showSnackBar(context, message: 'Group deleted');
                          } catch (e) {
                            if (context.mounted) showSnackBar(context, message: 'Failed: $e', isError: true);
                          }
                        }
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGroupDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
      ),
    );
  }

  void _showAddGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Group',
          style: KlasivoTypography.titleLarge.copyWith(
            color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
          ),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g. Group A',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KlasivoRadius.md),
            ),
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
                await ref.read(groupServiceProvider).createGroup(
                      organizationId: orgId,
                      classId: classId,
                      name: nameController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) showSnackBar(context, message: 'Group created');
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
