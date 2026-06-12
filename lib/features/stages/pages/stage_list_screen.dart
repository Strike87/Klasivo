import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/stage_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../core/config/theme.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

class StageListScreen extends ConsumerWidget {
  const StageListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stages = ref.watch(stagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Structure'),
        centerTitle: true,
        actions: [
          if (stages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.auto_fix_high_outlined),
              tooltip: 'Setup Wizard',
              onPressed: () => _showSetupWizard(context, ref),
            ),
        ],
      ),
      body: stages.isEmpty
          ? EmptyState(
              icon: Icons.school_outlined,
              title: 'No Stages Yet',
              subtitle:
                  'Create stages to organize your educational hierarchy.\n'
                  'e.g. Kindergarten, Primary, Preparatory, Secondary',
              actionLabel: 'Setup Structure',
              onAction: () => _showSetupWizard(context, ref),
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
    final descController = TextEditingController();
    KlasivoModal.showForm(
      context: context,
      title: 'Add Stage',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KlasivoTextField(
            controller: nameController,
            label: 'Stage Name *',
            hint: 'e.g. Primary',
          ),
          const SizedBox(height: 12),
          KlasivoTextField(
            controller: descController,
            label: 'Description',
            hint: 'e.g. Primary Education',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KlasivoButton(
                label: 'Cancel',
                variant: KlasivoButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              KlasivoButton(
                label: 'Create',
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    final orgId =
                        ref.read(currentOrganizationIdProvider) ?? '';
                    final stages = ref.read(stagesProvider);
                    final maxOrder = stages.isEmpty
                        ? 0
                        : stages.map((s) => s.order).reduce((a, b) => a > b ? a : b);
                    await ref.read(stageServiceProvider).createStage(
                          organizationId: orgId,
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
                          order: maxOrder + 1,
                        );
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      KlasivoToast.success(context, message: 'Stage created successfully');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      KlasivoToast.error(context, message: 'Failed: $e');
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

  void _showSetupWizard(BuildContext context, WidgetRef ref) {
    KlasivoModal.showForm(
      context: context,
      title: 'Setup Academic Structure',
      child: _SetupWizardSheet(ref: ref),
    );
  }
}

// ─── Stage Card ───────────────────────────────────────────────────────────────

class _StageCard extends ConsumerWidget {
  final StageData stage;
  const _StageCard({required this.stage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesByStageListProvider(stage.id));
    final classCount = classesAsync.length;
    final totalStudents = classesAsync.fold<int>(
        0, (sum, c) => sum + c.studentCount);

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: () {
        // Navigate to classes under this stage
        context.go('/academic/stages/${stage.id}/classes');
      },
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KlasivoColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_outlined,
              color: KlasivoColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (stage.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    stage.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.class_outlined,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '$classCount class${classCount != 1 ? 'es' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.people_outline,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '$totalStudents student${totalStudents != 1 ? 's' : ''}',
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                tooltip: 'Add Class',
                onPressed: () {
                  context.go(
                    '/academic/stages/${stage.id}/classes/create',
                    extra: stage.id,
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showEditStageDialog(context, ref, stage);
                  } else if (value == 'archive') {
                    final confirmed = await KlasivoModal.confirm(
                      context: context,
                      title: 'Archive Stage',
                      message:
                          'Archive "${stage.name}"? It will be hidden but data is preserved.',
                      confirmLabel: 'Archive',
                      isDangerous: true,
                    );
                    if (confirmed == true) {
                      try {
                        final userId =
                            ref.read(userIdProvider) ?? '';
                        await ref
                            .read(stageServiceProvider)
                            .archiveStage(stage.id, archivedBy: userId);
                        if (context.mounted) {
                          KlasivoToast.success(context,
                              message: 'Stage archived');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          KlasivoToast.error(context,
                              message: 'Failed: $e');
                        }
                      }
                    }
                  }
                },
                itemBuilder: (_) => [
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
                            style:
                                TextStyle(color: Colors.orange[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditStageDialog(
      BuildContext context, WidgetRef ref, StageData stage) {
    final nameController = TextEditingController(text: stage.name);
    final descController = TextEditingController(text: stage.description);
    KlasivoModal.showForm(
      context: context,
      title: 'Edit Stage',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KlasivoTextField(
            controller: nameController,
            label: 'Stage Name *',
          ),
          const SizedBox(height: 12),
          KlasivoTextField(
            controller: descController,
            label: 'Description',
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KlasivoButton(
                label: 'Cancel',
                variant: KlasivoButtonVariant.tertiary,
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              KlasivoButton(
                label: 'Update',
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  try {
                    await ref.read(stageServiceProvider).updateStage(
                          stageId: stage.id,
                          name: nameController.text.trim(),
                          description: descController.text.trim(),
                        );
                    if (context.mounted) Navigator.pop(context);
                    if (context.mounted) {
                      KlasivoToast.success(context, message: 'Stage updated');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      KlasivoToast.error(context, message: 'Failed: $e');
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
}

// ─── Smart Setup Wizard ───────────────────────────────────────────────────────

class _SetupWizardSheet extends StatefulWidget {
  final WidgetRef ref;
  const _SetupWizardSheet({required this.ref});

  @override
  State<_SetupWizardSheet> createState() => _SetupWizardSheetState();
}

class _SetupWizardSheetState extends State<_SetupWizardSheet> {
  String _selectedTemplate = 'egyptian';
  bool _isCreating = false;

  final Map<String, Map<String, dynamic>> _templates = {
    'egyptian': {
      'label': 'Egyptian School',
      'icon': Icons.school,
      'stages': [
        {
          'name': 'Kindergarten',
          'description': 'Pre-school education',
          'order': 1,
          'classes': [
            {'name': 'KG1', 'code': 'KG1'},
            {'name': 'KG2', 'code': 'KG2'},
          ],
        },
        {
          'name': 'Primary',
          'description': 'Primary education',
          'order': 2,
          'classes': [
            {'name': 'Grade 1', 'code': 'G1'},
            {'name': 'Grade 2', 'code': 'G2'},
            {'name': 'Grade 3', 'code': 'G3'},
            {'name': 'Grade 4', 'code': 'G4'},
            {'name': 'Grade 5', 'code': 'G5'},
            {'name': 'Grade 6', 'code': 'G6'},
          ],
        },
        {
          'name': 'Preparatory',
          'description': 'Preparatory education',
          'order': 3,
          'classes': [
            {'name': 'Grade 7', 'code': 'G7'},
            {'name': 'Grade 8', 'code': 'G8'},
            {'name': 'Grade 9', 'code': 'G9'},
          ],
        },
        {
          'name': 'Secondary',
          'description': 'Secondary education',
          'order': 4,
          'classes': [
            {'name': 'Grade 10', 'code': 'G10'},
            {'name': 'Grade 11', 'code': 'G11'},
            {'name': 'Grade 12', 'code': 'G12'},
          ],
        },
      ],
    },
    'american': {
      'label': 'American School',
      'icon': Icons.flag,
      'stages': [
        {
          'name': 'Elementary',
          'description': 'Elementary school',
          'order': 1,
          'classes': [
            {'name': 'Grade 1', 'code': 'G1'},
            {'name': 'Grade 2', 'code': 'G2'},
            {'name': 'Grade 3', 'code': 'G3'},
            {'name': 'Grade 4', 'code': 'G4'},
            {'name': 'Grade 5', 'code': 'G5'},
          ],
        },
        {
          'name': 'Middle School',
          'description': 'Middle school',
          'order': 2,
          'classes': [
            {'name': 'Grade 6', 'code': 'G6'},
            {'name': 'Grade 7', 'code': 'G7'},
            {'name': 'Grade 8', 'code': 'G8'},
          ],
        },
        {
          'name': 'High School',
          'description': 'High school',
          'order': 3,
          'classes': [
            {'name': 'Grade 9', 'code': 'G9'},
            {'name': 'Grade 10', 'code': 'G10'},
            {'name': 'Grade 11', 'code': 'G11'},
            {'name': 'Grade 12', 'code': 'G12'},
          ],
        },
      ],
    },
    'tutoring': {
      'label': 'Tutoring Center',
      'icon': Icons.groups,
      'stages': [
        {
          'name': 'Primary',
          'description': 'Primary level tutoring',
          'order': 1,
          'classes': [],
        },
        {
          'name': 'Preparatory',
          'description': 'Preparatory level tutoring',
          'order': 2,
          'classes': [],
        },
        {
          'name': 'Secondary',
          'description': 'Secondary level tutoring',
          'order': 3,
          'classes': [],
        },
      ],
    },
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Setup Academic Structure',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a template to auto-create stages and classes.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Template options
          ..._templates.entries.map((entry) {
            final key = entry.key;
            final template = entry.value;
            return RadioListTile<String>(
              value: key,
              groupValue: _selectedTemplate,
              onChanged: (v) => setState(() => _selectedTemplate = v!),
              title: Row(
                children: [
                  Icon(template['icon'] as IconData, size: 20),
                  const SizedBox(width: 8),
                  Text(template['label'] as String),
                ],
              ),
              contentPadding: EdgeInsets.zero,
            );
          }),

          const SizedBox(height: 16),

          // Preview
          _buildPreview(),

          const SizedBox(height: 24),

          // Create button
          KlasivoButton(
            label: 'Create Structure',
            onPressed: _isCreating ? null : _createStructure,
            loading: _isCreating,
            fullWidth: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final template = _templates[_selectedTemplate]!;
    final stages = template['stages'] as List;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KlasivoColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KlasivoColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preview:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: KlasivoColors.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...stages.map((stage) {
            final classes = stage['classes'] as List;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.school_outlined,
                      size: 16, color: KlasivoColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${stage['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (classes.isNotEmpty) ...[
                    Text(
                      ' (${classes.length} classes)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _createStructure() async {
    setState(() => _isCreating = true);
    try {
      final orgId = widget.ref.read(currentOrganizationIdProvider) ?? '';
      final template = _templates[_selectedTemplate]!;
      final stages = template['stages'] as List<Map<String, dynamic>>;

      await widget.ref.read(stageServiceProvider).createStagesBatch(
            organizationId: orgId,
            stages: stages,
          );

      if (mounted) {
        Navigator.pop(context);
        KlasivoToast.success(context, message: 'Academic structure created!');
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}
