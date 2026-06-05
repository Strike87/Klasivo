import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../widgets/common_widgets.dart';

class AllStudentsScreen extends ConsumerWidget {
  const AllStudentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(allStudentsStreamProvider);
    final classes = ref.watch(classesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Students'),
        centerTitle: true,
      ),
      body: studentsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading students...'),
        error: (error, stack) => ErrorWidgetCustom(
          message: 'Failed to load students: $error',
          onRetry: () => ref.invalidate(allStudentsStreamProvider),
        ),
        data: (snapshot) {
          final students = snapshot.docs
              .map((doc) => StudentData.fromFirestore(doc))
              .toList();

          if (students.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'No Students Yet',
              subtitle: 'Add students to your classes to see them here',
              actionLabel: 'Go to Classes',
              onAction: () => context.go('/teacher/classes'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allStudentsStreamProvider);
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
                        '${students.length} Student${students.length != 1 ? 's' : ''} across ${classes.length} Class${classes.length != 1 ? 'es' : ''}',
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
                                radius: 22,
                                backgroundColor:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                child: Text(
                                  student.fullName.isNotEmpty
                                      ? student.fullName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
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
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
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
                                            color: Colors.green
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
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
                                        Icon(Icons.class_outlined,
                                            size: 12, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          student.className,
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

                              // ── Navigate to class ──
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                onPressed: () => context.go(
                                  '/teacher/classes/${student.classId}/students',
                                ),
                                tooltip: 'View in Class',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
