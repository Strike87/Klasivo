import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/grade_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';

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
          ? const EmptyState(
              icon: Icons.grade_outlined,
              title: 'No Grades Yet',
              subtitle: 'Add grades under this stage',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grades.length,
              itemBuilder: (context, index) {
                final grade = grades[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.grade_outlined, color: Colors.orange),
                    title: Text(grade.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Grade'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Grade Name',
            hintText: 'e.g. Grade 10',
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
                final teacherId = ref.read(userIdProvider) ?? '';
                await ref.read(gradeServiceProvider).createGrade(
                      stageId: stageId,
                      name: nameController.text.trim(),
                      teacherId: teacherId,
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
