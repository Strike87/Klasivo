import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/student_provider.dart';
import '../../../widgets/common_widgets.dart';

class StudentListScreen extends ConsumerWidget {
  final String classId;

  const StudentListScreen({
    Key? key,
    required this.classId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsByClassProvider(classId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        centerTitle: true,
      ),
      body: studentsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading students...'),
        error: (error, stack) => ErrorWidgetCustom(
          message: 'Failed to load students: $error',
          onRetry: () => ref.invalidate(studentsByClassProvider(classId)),
        ),
        data: (snapshot) {
          final students = snapshot.docs
              .map((doc) => StudentData.fromFirestore(doc))
              .toList();

          if (students.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'No Students Yet',
              subtitle: 'Add students to this class',
              actionLabel: 'Add Student',
              onAction: () =>
                  context.go('/teacher/classes/$classId/students/create'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentsByClassProvider(classId));
            },
            child: Column(
              children: [
                // ── Student count header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${students.length} Student${students.length != 1 ? 's' : ''}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Student list ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _StudentCard(
                        student: student,
                        onEdit: () {
                          context.go(
                            '/teacher/classes/$classId/students/edit/${student.id}',
                            extra: student,
                          );
                        },
                        onDelete: () async {
                          final confirmed = await showConfirmationDialog(
                            context: context,
                            title: 'Delete Student',
                            message:
                                'Are you sure you want to remove "${student.fullName}" from this class?',
                            confirmLabel: 'Delete',
                            isDangerous: true,
                          );
                          if (confirmed == true) {
                            try {
                              await ref
                                  .read(studentServiceProvider)
                                  .deleteStudent(student.id, classId);
                              if (context.mounted) {
                                showSnackBar(context,
                                    message: 'Student removed');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showSnackBar(
                                  context,
                                  message: 'Failed: $e',
                                  isError: true,
                                );
                              }
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.go('/teacher/classes/$classId/students/create'),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentData student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // ── Avatar ──
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          student.studentCode,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (student.grade != null)
                        Text(
                          student.grade!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Actions ──
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit',
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: Colors.red[400]),
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
