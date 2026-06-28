import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/grade_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../core/config/theme.dart';
import '../../../widgets/klasivo_components.dart';

class GradeListScreen extends ConsumerWidget {
  final String stageId;
  const GradeListScreen({Key? key, required this.stageId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradesByStageListProvider(stageId));
    final stages = ref.watch(stagesProvider);
    final stageName = stages.where((s) => s.id == stageId).firstOrNull?.name ?? 'Stage';

    return Scaffold(
      appBar: AppBar(title: Text('Grades - $stageName'), centerTitle: true),
      body: grades.isEmpty
          ? const KlasivoEmptyState(
              icon: Icons.grade_outlined,
              title: 'No Grades Yet',
              subtitle: 'Add grades under this stage',
              iconColor: KlasivoColors.accent,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              itemCount: grades.length,
              itemBuilder: (context, index) {
                final grade = grades[index];
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
                        color: KlasivoColors.accentSurface,
                        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(Icons.grade_outlined, color: KlasivoColors.accent, size: 24),
                    ),
                    title: Text(
                      grade.name,
                      style: KlasivoTypography.titleMedium.copyWith(
                        color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: KlasivoColors.error),
                      onPressed: () async {
                        final confirmed = await showConfirmationDialog(
                          context: context,
                          title: 'Delete Grade',
                          message: 'Delete "${grade.name}"?',
                          isDangerous: true,
                        );
                        if (confirmed == true) {
                          try {
                            await ref.read(gradeServiceProvider).deleteGrade(grade.id);
                            if (context.mounted) showSnackBar(context, message: 'Grade deleted');
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
        onPressed: () => _showAddGradeDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Grade'),
      ),
    );
  }

  void _showAddGradeDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Grade',
          style: KlasivoTypography.titleLarge.copyWith(
            color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
          ),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Grade Name',
            hintText: 'e.g. Grade 10',
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
                final orgId = ref.read(currentOrganizationIdProvider);
                if (orgId == null || orgId.isEmpty) {
                  throw StateError('Organization context missing. Please re-login and retry.');
                }
                await ref.read(gradeServiceProvider).createGrade(
                      stageId: stageId,
                      name: nameController.text.trim(),
                      organizationId: orgId,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) showSnackBar(context, message: 'Grade created');
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
