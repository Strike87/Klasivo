import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/paginated_providers.dart';
import '../../../core/services/pagination_service.dart';
import '../../../widgets/klasivo_paginated_list.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_avatar.dart';

class AllStudentsScreen extends ConsumerWidget {
  const AllStudentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgId = ref.watch(currentOrganizationIdProvider);
    final classes = ref.watch(classesProvider);
    final paginationService = ref.watch(paginationServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Students'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Student count header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${classes.length} Class${classes.length != 1 ? 'es' : ''}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Paginated Student list ──
          Expanded(
            child: KlasivoPaginatedList<StudentData>(
              loader: (cursor) => paginationService.fetchPage(
                collectionPath: 'users',
                fromFirestore: StudentData.fromFirestore,
                cursor: cursor,
                pageSize: 20,
                orderBy: 'createdAt',
                descending: true,
                filters: [
                  if (orgId != null)
                    QueryFilter.equalTo('organizationId', orgId),
                  QueryFilter.equalTo('role', 'student'),
                  QueryFilter.equalTo('isActive', true),
                ],
              ),
              padding: const EdgeInsets.all(16),
              separator: const SizedBox(height: 8),
              emptyWidget: EmptyState(
                icon: Icons.people_outline,
                title: 'No Students Yet',
                subtitle: 'Add students to your classes to see them here',
                actionLabel: 'Go to Classes',
                onAction: () => context.go('/teacher/classes'),
              ),
              itemBuilder: (context, student, index) {
                return KlasivoCard(
                  margin: EdgeInsets.zero,
                  variant: KlasivoCardVariant.elevated,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // ── Avatar ──
                        KlasivoAvatar(
                          name: student.fullName.isNotEmpty
                              ? student.fullName[0].toUpperCase()
                              : '?',
                          size: KlasivoAvatarSize.md,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
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
                                      color: Colors.green
                                          .withValues(alpha: 0.1),
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
                                  Icon(Icons.class_outlined,
                                      size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    classes
                                            .where((c) =>
                                                c.id == student.classId)
                                            .firstOrNull
                                            ?.name ??
                                        '-',
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
                          icon:
                              const Icon(Icons.open_in_new, size: 18),
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
  }
}
