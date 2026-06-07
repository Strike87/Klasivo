import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../core/config/theme.dart';
import '../../../widgets/klasivo_components.dart';

class ClassListScreen extends ConsumerWidget {
  const ClassListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
        centerTitle: true,
      ),
      body: classesAsync.when(
        loading: () => const KlasivoLoading(message: 'Loading classes...'),
        error: (error, stack) => _KlasivoErrorWidget(
          message: 'Failed to load classes: $error',
          onRetry: () => ref.invalidate(classesStreamProvider),
        ),
        data: (snapshot) {
          final classes = snapshot.docs
              .map((doc) => ClassData.fromFirestore(doc))
              .toList();

          if (classes.isEmpty) {
            return KlasivoEmptyState(
              icon: Icons.class_outlined,
              title: 'No Classes Yet',
              subtitle: 'Create your first class to start adding students',
              actionLabel: 'Create Class',
              onAction: () => context.go('/teacher/classes/create'),
              iconColor: KlasivoColors.primary,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(classesStreamProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
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

/// Klasivo-styled inline error widget replacing ErrorWidgetCustom.
class _KlasivoErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _KlasivoErrorWidget({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.xxl),
              decoration: const BoxDecoration(
                color: KlasivoColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: KlasivoColors.error,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),
            Text(
              message,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextSecondary
                    : KlasivoColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KlasivoSpacing.xxl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: KlasivoSpacing.md),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.md),
                decoration: BoxDecoration(
                  color: KlasivoColors.primarySurface,
                  borderRadius: BorderRadius.circular(KlasivoRadius.md),
                ),
                child: const Icon(
                  Icons.class_outlined,
                  color: KlasivoColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: KlasivoSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData.name,
                      style: KlasivoTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: KlasivoSpacing.xs),
                    Row(
                      children: [
                        if (classData.grade != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KlasivoSpacing.sm,
                              vertical: KlasivoSpacing.xs - 2,
                            ),
                            decoration: BoxDecoration(
                              color: KlasivoColors.accentSurface,
                              borderRadius: BorderRadius.circular(KlasivoRadius.xs),
                            ),
                            child: Text(
                              classData.grade!,
                              style: KlasivoTypography.labelSmall.copyWith(
                                color: KlasivoColors.accentDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: KlasivoSpacing.sm),
                        ],
                        Icon(
                          Icons.people_outline,
                          size: 14,
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        const SizedBox(width: KlasivoSpacing.xs),
                        Text(
                          '${classData.studentCount} students',
                          style: KlasivoTypography.bodySmall.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextSecondary
                                : KlasivoColors.lightTextSecondary,
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
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: isDark
                              ? KlasivoColors.darkIconDefault
                              : KlasivoColors.lightIconDefault,
                        ),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Text(
                          'Edit',
                          style: KlasivoTypography.bodyMedium.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextPrimary
                                : KlasivoColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'qr',
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, size: 20, color: KlasivoColors.primary),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Text(
                          'QR Enrollment Code',
                          style: KlasivoTypography.bodyMedium.copyWith(
                            color: KlasivoColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 20, color: KlasivoColors.error),
                        const SizedBox(width: KlasivoSpacing.sm),
                        Text(
                          'Delete',
                          style: KlasivoTypography.bodyMedium.copyWith(
                            color: KlasivoColors.error,
                          ),
                        ),
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
