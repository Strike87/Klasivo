import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/group_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../core/config/theme.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

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

                return KlasivoCard(
                  margin: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: KlasivoColors.secondarySurface,
                        borderRadius: BorderRadius.circular(KlasivoSpacing.sm),
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
                        final confirmed = await KlasivoModal.confirm(
                          context: context,
                          title: 'Delete Group',
                          message: 'Delete "${group.name}"?',
                          confirmLabel: 'Delete',
                          isDangerous: true,
                        );
                        if (confirmed == true) {
                          try {
                            await ref.read(groupServiceProvider).deleteGroup(group.id);
                            if (context.mounted) KlasivoToast.success(context, message: 'Group deleted');
                          } catch (e) {
                            if (context.mounted) KlasivoToast.error(context, message: 'Failed: $e');
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

    KlasivoModal.showForm(
      context: context,
      title: 'Add Group',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KlasivoTextField(
              label: 'Group Name',
              hint: 'e.g. Group A',
              controller: nameController,
              prefixIcon: Icons.group_work_outlined,
            ),
            const SizedBox(height: KlasivoSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KlasivoButton(
                  variant: KlasivoButtonVariant.tertiary,
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: KlasivoSpacing.sm),
                KlasivoButton(
                  label: 'Create',
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    try {
                      final orgId = ref.read(currentOrganizationIdProvider) ?? '';
                      await ref.read(groupServiceProvider).createGroup(
                            organizationId: orgId,
                            classId: classId,
                            name: nameController.text.trim(),
                          );
                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) KlasivoToast.success(context, message: 'Group created');
                    } catch (e) {
                      if (context.mounted) KlasivoToast.error(context, message: 'Failed: $e');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
