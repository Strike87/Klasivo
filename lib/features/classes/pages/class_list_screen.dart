import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        centerTitle: true,
      ),
      body: classesAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading classes...'),
        error: (error, stack) => ErrorWidgetCustom(
          message: 'Failed to load classes: $error',
          onRetry: () => ref.invalidate(classesStreamProvider),
        ),
        data: (snapshot) {
          final classes = snapshot.docs
              .map((doc) => ClassData.fromFirestore(doc))
              .toList();

          if (classes.isEmpty) {
            return EmptyState(
              icon: Icons.class_outlined,
              title: 'No Classes Yet',
              subtitle: 'Create your first class to start adding students',
              actionLabel: 'Create Class',
              onAction: () => context.go('/teacher/classes/create'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(classesStreamProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classData = classes[index];
                return _ClassCard(
                  classData: classData,
                  onTap: () {
                    context.go('/teacher/classes/${classData.id}/students');
                  },
                  onEdit: () {
                    context.go(
                      '/teacher/classes/edit/${classData.id}',
                      extra: classData,
                    );
                  },
                  onDelete: () async {
                    final confirmed = await showConfirmationDialog(
                      context: context,
                      title: 'Delete Class',
                      message:
                          'Are you sure you want to delete "${classData.name}"? All students in this class will also be deleted. This action cannot be undone.',
                      confirmLabel: 'Delete',
                      isDangerous: true,
                    );
                    if (confirmed == true) {
                      try {
                        await ref
                            .read(classServiceProvider)
                            .deleteClass(classData.id);
                        if (context.mounted) {
                          showSnackBar(context, message: 'Class deleted');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showSnackBar(
                            context,
                            message: 'Failed to delete: $e',
                            isError: true,
                          );
                        }
                      }
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/teacher/classes/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Class'),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final ClassData classData;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.classData,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.class_outlined,
                  color: theme.colorScheme.primary,
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
                    Row(
                      children: [
                        if (classData.grade != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              classData.grade!,
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
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
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'qr') {
                    context.go(
                      '/teacher/classes/${classData.id}/students/qr',
                      extra: {
                        'className': classData.name,
                        'grade': classData.grade,
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
                        Icon(Icons.qr_code, size: 20, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text('QR Enrollment Code', style: TextStyle(color: Colors.indigo)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
