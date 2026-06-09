import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import 'academic_year_form_screen.dart';

class AcademicYearListScreen extends ConsumerWidget {
  const AcademicYearListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(academicYearsProvider);
    final activeYears = ref.watch(activeAcademicYearsProvider);
    final archivedYears = ref.watch(archivedAcademicYearsProvider);
    final theme = Theme.of(context);
    final userRole = ref.watch(userRoleProvider);
    final canEdit = userRole == AppConstants.roleOwner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Years'),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AcademicYearFormScreen(isEditing: false)),
                );
              },
              backgroundColor: const Color(0xFF3B5BDB),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: years.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No Academic Years', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Create your first academic year to get started',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  if (canEdit) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AcademicYearFormScreen(isEditing: false)),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Year'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B5BDB)),
                    ),
                  ],
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeYears.isNotEmpty) ...[
                  Text('Active', style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: const Color(0xFF12B886),
                  )),
                  const SizedBox(height: 8),
                  ...activeYears.map((y) => _YearCard(year: y, canEdit: canEdit)),
                  const SizedBox(height: 24),
                ],
                if (archivedYears.isNotEmpty) ...[
                  Text('Archived', style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.grey,
                  )),
                  const SizedBox(height: 8),
                  ...archivedYears.map((y) => _YearCard(year: y, canEdit: canEdit)),
                ],
              ],
            ),
    );
  }
}

class _YearCard extends ConsumerWidget {
  final AcademicYearData year;
  final bool canEdit;

  const _YearCard({required this.year, required this.canEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: year.isCurrent ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: year.isCurrent
            ? const BorderSide(color: Color(0xFF12B886), width: 1.5)
            : BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    year.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (year.isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12B886).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Current',
                        style: TextStyle(fontSize: 11, color: Color(0xFF12B886), fontWeight: FontWeight.w600)),
                  ),
                if (year.isArchived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Archived',
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.date_range, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(year.dateRange, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text('${year.durationInDays} days', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
              ],
            ),
            if (canEdit && !year.isArchived) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!year.isCurrent)
                    TextButton.icon(
                      onPressed: () async {
                        final orgId = ref.read(currentOrganizationIdProvider);
                        if (orgId != null) {
                          await ref.read(academicYearServiceProvider).setCurrentAcademicYear(orgId, year.id);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Set Current'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF12B886)),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Archive Academic Year'),
                          content: Text('Archive "${year.name}"? This will hide it from active views.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Archive', style: TextStyle(color: Colors.amber)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(academicYearServiceProvider).archiveAcademicYear(year.id);
                      }
                    },
                    icon: const Icon(Icons.archive_outlined, size: 16),
                    label: const Text('Archive'),
                    style: TextButton.styleFrom(foregroundColor: Colors.amber[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
