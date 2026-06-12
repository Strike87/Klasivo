import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/gradebook_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GRADEBOOK SCREEN — Klasivo v1.7
// Full gradebook view with class selector, category management,
// and a horizontally + vertically scrollable student grades table.
// ═══════════════════════════════════════════════════════════════════════════════

class GradebookScreen extends ConsumerStatefulWidget {
  const GradebookScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GradebookScreen> createState() => _GradebookScreenState();
}

class _GradebookScreenState extends ConsumerState<GradebookScreen> {
  String? _selectedClassId;
  bool _isLoading = false;

  // ─── Category type options ────────────────────────────────────────────────

  static const List<MapEntry<String, String>> _categoryTypes = [
    MapEntry(AppConstants.categoryExam, 'Exam'),
    MapEntry(AppConstants.categoryHomework, 'Homework'),
    MapEntry(AppConstants.categoryQuiz, 'Quiz'),
    MapEntry(AppConstants.categoryParticipation, 'Participation'),
    MapEntry(AppConstants.categoryProject, 'Project'),
    MapEntry(AppConstants.categoryFinal, 'Final'),
  ];

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Color _gradeColor(double percentage) {
    if (percentage >= 80) return KlasivoColors.secondary;
    if (percentage >= 60) return KlasivoColors.accent;
    if (percentage >= 50) return KlasivoColors.primary;
    return KlasivoColors.error;
  }

  /// Compute per-category average for a given student from a list of entries.
  double _categoryAverage(List<GradebookEntryData> entries, String categoryId) {
    final catEntries =
        entries.where((e) => e.categoryId == categoryId).toList();
    if (catEntries.isEmpty) return -1; // signals "no data"
    double sum = 0;
    double maxSum = 0;
    for (final e in catEntries) {
      sum += e.score;
      maxSum += e.maxScore;
    }
    return maxSum > 0 ? (sum / maxSum) * 100 : 0;
  }

  /// Compute weighted average for a student given categories & entries.
  double _weightedAverage(
    List<GradebookCategoryData> categories,
    List<GradebookEntryData> entries,
  ) {
    double weightedSum = 0;
    double totalWeight = 0;
    for (final cat in categories) {
      final avg = _categoryAverage(entries, cat.id);
      if (avg < 0) continue; // skip categories with no entries
      weightedSum += (avg / 100) * cat.weight;
      totalWeight += cat.weight;
    }
    return totalWeight > 0 ? (weightedSum / totalWeight) * 100 : 0;
  }

  /// Compute overall class average.
  double _classAverage(
    List<GradebookCategoryData> categories,
    List<GradebookEntryData> entries,
    List<String> studentIds,
  ) {
    if (studentIds.isEmpty) return 0;
    double total = 0;
    int count = 0;
    for (final sid in studentIds) {
      final studentEntries =
          entries.where((e) => e.studentId == sid).toList();
      final avg = _weightedAverage(categories, studentEntries);
      if (avg > 0) {
        total += avg;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gradebook'),
        centerTitle: true,
      ),
      body: classes.isEmpty
          ? const KlasivoEmptyState(
              icon: Icons.class_outlined,
              title: 'No Classes Yet',
              subtitle:
                  'Create a class first to start managing your gradebook.',
              iconColor: KlasivoColors.primary,
            )
          : Column(
              children: [
                // ── Class Selector ─────────────────────────────────────────
                _buildClassSelector(classes, isDark),
                // ── Class Content ──────────────────────────────────────────
                Expanded(
                  child: _selectedClassId == null
                      ? KlasivoEmptyState(
                          icon: Icons.menu_book_outlined,
                          title: 'Select a Class',
                          subtitle:
                              'Choose a class above to view its gradebook.',
                          iconColor: KlasivoColors.accent,
                        )
                      : _buildClassContent(isDark),
                ),
              ],
            ),
      floatingActionButton: _selectedClassId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddEntryDialog(isDark),
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            ),
    );
  }

  // ─── Class Selector ───────────────────────────────────────────────────────

  Widget _buildClassSelector(List<ClassData> classes, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        KlasivoSpacing.lg,
        KlasivoSpacing.lg,
        KlasivoSpacing.lg,
        KlasivoSpacing.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        border: Border.all(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedClassId,
          isExpanded: true,
          hint: Text(
            'Select a class...',
            style: KlasivoTypography.bodyMedium.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
          ),
          icon: Icon(
            Icons.expand_more,
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
          items: classes.map((cls) {
            return DropdownMenuItem<String>(
              value: cls.id,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.xs + 2),
                    decoration: BoxDecoration(
                      color: KlasivoColors.primarySurface,
                      borderRadius:
                          BorderRadius.circular(KlasivoRadius.sm),
                    ),
                    child: const Icon(
                      Icons.class_outlined,
                      color: KlasivoColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Expanded(
                    child: Text(
                      cls.name,
                      style: KlasivoTypography.titleMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                  ),
                  if (cls.studentCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KlasivoSpacing.sm,
                        vertical: KlasivoSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: KlasivoColors.accentSurface,
                        borderRadius:
                            BorderRadius.circular(KlasivoRadius.pill),
                      ),
                      child: Text(
                        '${cls.studentCount}',
                        style: KlasivoTypography.labelSmall.copyWith(
                          color: KlasivoColors.accent,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedClassId = value);
          },
        ),
      ),
    );
  }

  // ─── Class Content (Overview + Categories + Table) ────────────────────────

  Widget _buildClassContent(bool isDark) {
    final categories =
        ref.watch(gradebookCategoriesListProvider(_selectedClassId!));
    final entries =
        ref.watch(gradebookEntriesByStudentProvider(_selectedClassId!));
    final students =
        ref.watch(studentsByClassListProvider(_selectedClassId!));

    // Check loading state from the underlying stream providers
    final asyncCats =
        ref.watch(gradebookCategoriesByClassProvider(_selectedClassId!));
    final asyncEntries =
        ref.watch(gradebookEntriesByClassProvider(_selectedClassId!));

    if (asyncCats.isLoading || asyncEntries.isLoading) {
      return const KlasivoLoading(message: 'Loading gradebook...');
    }

    // Compute analytics
    final studentIds = students.map((s) => s.id).toList();
    final classAvg =
        _classAverage(categories, entries, studentIds);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        KlasivoSpacing.lg,
        KlasivoSpacing.sm,
        KlasivoSpacing.lg,
        KlasivoSpacing.xxxl * 2 + KlasivoSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Analytics Cards ────────────────────────────────────────────
          _buildAnalyticsCards(students.length, classAvg, entries.length),
          const SizedBox(height: KlasivoSpacing.xxl),

          // ── Categories Section ─────────────────────────────────────────
          _buildCategoriesSection(categories, isDark),
          const SizedBox(height: KlasivoSpacing.xxl),

          // ── Student Grades Table ───────────────────────────────────────
          if (categories.isEmpty)
            KlasivoEmptyState(
              icon: Icons.category_outlined,
              title: 'No Categories Defined',
              subtitle:
                  'Add grade categories first (e.g. Exam, Homework) to build the gradebook table.',
              actionLabel: 'Add Category',
              onAction: () => _showCategoryDialog(isDark),
              iconColor: KlasivoColors.accent,
            )
          else
            _buildGradesTable(categories, entries, students, isDark),
        ],
      ),
    );
  }

  // ─── Analytics Cards Row ──────────────────────────────────────────────────

  Widget _buildAnalyticsCards(int totalStudents, double classAvg, int totalEntries) {
    return Row(
      children: [
        Expanded(
          child: KlasivoAnalyticsCard(
            value: '$totalStudents',
            label: 'Total Students',
            icon: Icons.people_outline,
            color: KlasivoColors.primary,
          ),
        ),
        const SizedBox(width: KlasivoSpacing.sm),
        Expanded(
          child: KlasivoAnalyticsCard(
            value: '${classAvg.toStringAsFixed(1)}%',
            label: 'Class Average',
            icon: Icons.trending_up_outlined,
            color: classAvg >= 60
                ? KlasivoColors.secondary
                : classAvg >= 50
                    ? KlasivoColors.accent
                    : KlasivoColors.error,
          ),
        ),
        const SizedBox(width: KlasivoSpacing.sm),
        Expanded(
          child: KlasivoAnalyticsCard(
            value: '$totalEntries',
            label: 'Total Entries',
            icon: Icons.assignment_outlined,
            color: KlasivoColors.accent,
          ),
        ),
      ],
    );
  }

  // ─── Categories Section ───────────────────────────────────────────────────

  Widget _buildCategoriesSection(
      List<GradebookCategoryData> categories, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KlasivoSectionHeader(
          title: 'Categories & Weights',
          actionLabel: 'Add Category',
          onAction: () => _showCategoryDialog(isDark),
        ),
        const SizedBox(height: KlasivoSpacing.md),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: KlasivoSpacing.lg),
            child: Center(
              child: Text(
                'No categories yet. Tap "Add Category" to begin.',
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                ),
              ),
            ),
          )
        else
          ...categories.map((cat) => _buildCategoryCard(cat, isDark)),
      ],
    );
  }

  Widget _buildCategoryCard(GradebookCategoryData cat, bool isDark) {
    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: () => _showCategoryDialog(isDark, existing: cat),
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      margin: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
      child: Row(
        children: [
          // ── Type Icon ──
          Container(
            padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
            decoration: BoxDecoration(
              color: _categoryTypeColor(cat.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            ),
            child: Icon(
              _categoryTypeIcon(cat.type),
              color: _categoryTypeColor(cat.type),
              size: 20,
            ),
          ),
          const SizedBox(width: KlasivoSpacing.md),

          // ── Name & Type ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: KlasivoTypography.titleMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xs),
                Text(
                  cat.typeLabel,
                  style: KlasivoTypography.bodySmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),

          // ── Weight Badge ──
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KlasivoSpacing.md,
              vertical: KlasivoSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: KlasivoColors.accentSurface,
              borderRadius: BorderRadius.circular(KlasivoRadius.pill),
            ),
            child: Text(
              '${cat.weight.toStringAsFixed(0)}%',
              style: KlasivoTypography.labelMedium.copyWith(
                color: KlasivoColors.accent,
              ),
            ),
          ),

          // ── Actions ──
          const SizedBox(width: KlasivoSpacing.sm),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
            onPressed: () => _showCategoryDialog(isDark, existing: cat),
            tooltip: 'Edit Category',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: KlasivoColors.error,
            ),
            onPressed: () => _deleteCategory(cat),
            tooltip: 'Delete Category',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Student Grades Table ─────────────────────────────────────────────────

  Widget _buildGradesTable(
    List<GradebookCategoryData> categories,
    List<GradebookEntryData> entries,
    List<StudentData> students,
    bool isDark,
  ) {
    // Column widths
    const double studentColWidth = 160.0;
    const double categoryColWidth = 110.0;
    const double avgColWidth = 120.0;
    final double totalWidth =
        studentColWidth +
        (categoryColWidth * categories.length) +
        avgColWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KlasivoSectionHeader(
          title: 'Student Grades',
          actionLabel: students.isEmpty ? null : '${students.length} students',
        ),
        const SizedBox(height: KlasivoSpacing.md),

        if (students.isEmpty)
          const KlasivoEmptyState(
            icon: Icons.people_outline,
            title: 'No Students',
            subtitle:
                'Add students to this class to see their grades here.',
            iconColor: KlasivoColors.primary,
          )
        else
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KlasivoRadius.md),
              border: Border.all(
                color: isDark
                    ? KlasivoColors.darkBorder
                    : KlasivoColors.lightBorder,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Row ──
                      _buildTableHeader(
                        categories,
                        isDark,
                        studentColWidth,
                        categoryColWidth,
                        avgColWidth,
                      ),
                      // ── Divider ──
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? KlasivoColors.darkBorder
                            : KlasivoColors.lightBorder,
                      ),
                      // ── Student Rows ──
                      ...students.asMap().entries.map((entry) {
                        final index = entry.key;
                        final student = entry.value;
                        return _buildStudentRow(
                          student,
                          categories,
                          entries
                              .where((e) => e.studentId == student.id)
                              .toList(),
                          isDark,
                          studentColWidth,
                          categoryColWidth,
                          avgColWidth,
                          index,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTableHeader(
    List<GradebookCategoryData> categories,
    bool isDark,
    double studentColWidth,
    double categoryColWidth,
    double avgColWidth,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      color: isDark
          ? KlasivoColors.darkSurface
          : KlasivoColors.primarySurface,
      child: Row(
        children: [
          // Student Name column
          SizedBox(
            width: studentColWidth,
            child: Text(
              'Student',
              style: KlasivoTypography.labelMedium.copyWith(
                color: KlasivoColors.primary,
              ),
            ),
          ),
          // Category columns
          ...categories.map((cat) => SizedBox(
                width: categoryColWidth,
                child: Tooltip(
                  message:
                      '${cat.name} (${cat.typeLabel}) — ${cat.weight.toStringAsFixed(0)}%',
                  child: Text(
                    cat.name,
                    style: KlasivoTypography.labelMedium.copyWith(
                      color: KlasivoColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )),
          // Weighted Average column
          SizedBox(
            width: avgColWidth,
            child: Text(
              'Weighted Avg',
              style: KlasivoTypography.labelMedium.copyWith(
                color: KlasivoColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(
    StudentData student,
    List<GradebookCategoryData> categories,
    List<GradebookEntryData> studentEntries,
    bool isDark,
    double studentColWidth,
    double categoryColWidth,
    double avgColWidth,
    int rowIndex,
  ) {
    final bgColor = rowIndex.isEven
        ? Colors.transparent
        : (isDark
            ? KlasivoColors.darkSurface.withValues(alpha: 0.3)
            : KlasivoColors.lightBackground.withValues(alpha: 0.5));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      color: bgColor,
      child: Row(
        children: [
          // ── Student Name ──
          SizedBox(
            width: studentColWidth,
            child: Row(
              children: [
                KlasivoAvatar(
                  name: student.fullName.isNotEmpty
                      ? student.fullName[0].toUpperCase()
                      : '?',
                  size: KlasivoAvatarSize.sm,
                  backgroundColor: KlasivoColors.primarySurface,
                ),
                const SizedBox(width: KlasivoSpacing.sm),
                Expanded(
                  child: Text(
                    student.fullName,
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // ── Category Grade Cells ──
          ...categories.map((cat) {
            final avg = _categoryAverage(studentEntries, cat.id);
            return SizedBox(
              width: categoryColWidth,
              child: _GradeCell(
                average: avg,
                isDark: isDark,
                onTap: () => _showGradeEntryDialog(
                  isDark,
                  studentId: student.id,
                  studentName: student.fullName,
                  category: cat,
                  existingEntries: studentEntries
                      .where((e) => e.categoryId == cat.id)
                      .toList(),
                ),
              ),
            );
          }),
          // ── Weighted Average ──
          SizedBox(
            width: avgColWidth,
            child: _WeightedAverageCell(
              average: _weightedAverage(categories, studentEntries),
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Category Dialog ──────────────────────────────────────────────────────

  void _showCategoryDialog(
    bool isDark, {
    GradebookCategoryData? existing,
  }) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    String selectedType =
        existing?.type ?? AppConstants.categoryExam;
    double weight = existing?.weight ?? 20.0;
    final isEditing = existing != null;

    KlasivoModal.showForm(
      context: context,
      title: isEditing ? 'Edit Category' : 'Add Category',
      child: StatefulBuilder(
        builder: (ctx, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Name ──
            KlasivoTextField(
              controller: nameController,
              label: 'Category Name',
              hint: 'e.g. Midterm Exam',
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Type Dropdown ──
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: KlasivoSpacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? KlasivoColors.darkSurface
                    : KlasivoColors.lightSurface,
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
                border: Border.all(
                  color: isDark
                      ? KlasivoColors.darkBorder
                      : KlasivoColors.lightBorder,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  items: _categoryTypes.map((e) {
                    return DropdownMenuItem<String>(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(
                            _categoryTypeIcon(e.key),
                            size: 18,
                            color: _categoryTypeColor(e.key),
                          ),
                          const SizedBox(width: KlasivoSpacing.sm),
                          Text(e.value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Weight Slider ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weight',
                  style: KlasivoTypography.labelMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.md,
                    vertical: KlasivoSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: KlasivoColors.accentSurface,
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  child: Text(
                    '${weight.toStringAsFixed(0)}%',
                    style: KlasivoTypography.labelMedium.copyWith(
                      color: KlasivoColors.accent,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: weight,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${weight.toStringAsFixed(0)}%',
              onChanged: (val) {
                setDialogState(() => weight = val);
              },
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Action Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KlasivoButton(
                  label: 'Cancel',
                  variant: KlasivoButtonVariant.tertiary,
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(width: KlasivoSpacing.sm),
                KlasivoButton(
                  label: isEditing ? 'Update' : 'Create',
                  loading: _isLoading,
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            KlasivoToast.error(context,
                                message: 'Please enter a category name');
                            return;
                          }
                          setState(() => _isLoading = true);
                          try {
                            final orgId =
                                ref.read(currentOrganizationIdProvider) ?? '';
                            final service =
                                ref.read(gradebookServiceProvider);

                            if (isEditing) {
                              await service.updateCategory(
                                categoryId: existing.id,
                                name: name,
                                type: selectedType,
                                weight: weight,
                              );
                              if (mounted) {
                                KlasivoToast.success(context,
                                    message: 'Category updated');
                              }
                            } else {
                              await service.createCategory(
                                organizationId: orgId,
                                classId: _selectedClassId!,
                                name: name,
                                type: selectedType,
                                weight: weight,
                              );
                              if (mounted) {
                                KlasivoToast.success(context,
                                    message: 'Category created');
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              KlasivoToast.error(context,
                                  message: 'Failed: $e');
                            }
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
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

  // ─── Delete Category ─────────────────────────────────────────────────────

  Future<void> _deleteCategory(GradebookCategoryData cat) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Delete Category',
      message:
          'Delete "${cat.name}" and all its grade entries? This cannot be undone.',
      confirmLabel: 'Delete',
      isDangerous: true,
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(gradebookServiceProvider).deleteCategory(cat.id);
      if (mounted) KlasivoToast.success(context, message: 'Category deleted');
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Grade Entry Dialog ──────────────────────────────────────────────────

  void _showGradeEntryDialog(
    bool isDark, {
    required String studentId,
    required String studentName,
    required GradebookCategoryData category,
    required List<GradebookEntryData> existingEntries,
  }) {
    final titleController = TextEditingController();
    final scoreController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');
    final feedbackController = TextEditingController();
    GradebookEntryData? editingEntry;

    // If entries exist, let user pick one to edit or add new
    if (existingEntries.isNotEmpty) {
      editingEntry = existingEntries.first;
      titleController.text = editingEntry.title;
      scoreController.text = editingEntry.score.toStringAsFixed(1);
      maxScoreController.text = editingEntry.maxScore.toStringAsFixed(1);
      feedbackController.text = editingEntry.feedback ?? '';
    }

    KlasivoModal.showForm(
      context: context,
      title: editingEntry != null ? 'Edit Grade' : 'Add Grade',
      child: StatefulBuilder(
        builder: (ctx, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student & Category info ──
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.md),
              decoration: BoxDecoration(
                color: KlasivoColors.primarySurface,
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: KlasivoColors.primary,
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Expanded(
                    child: Text(
                      studentName,
                      style: KlasivoTypography.labelMedium.copyWith(
                        color: KlasivoColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KlasivoSpacing.sm,
                      vertical: KlasivoSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: KlasivoColors.accentSurface,
                      borderRadius:
                          BorderRadius.circular(KlasivoRadius.pill),
                    ),
                    child: Text(
                      category.name,
                      style: KlasivoTypography.labelSmall.copyWith(
                        color: KlasivoColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── If multiple entries exist, show selector ──
            if (existingEntries.length > 1) ...[
              Text(
                'Entries in this category',
                style: KlasivoTypography.labelMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextSecondary
                      : KlasivoColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: KlasivoSpacing.sm),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(KlasivoRadius.md),
                  border: Border.all(
                    color: isDark
                        ? KlasivoColors.darkBorder
                        : KlasivoColors.lightBorder,
                  ),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: existingEntries.length,
                  itemBuilder: (_, i) {
                    final entry = existingEntries[i];
                    final isSelected = editingEntry?.id == entry.id;
                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      selectedTileColor:
                          KlasivoColors.primarySurface.withValues(alpha: 0.3),
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: isSelected
                            ? KlasivoColors.primary
                            : null,
                      ),
                      title: Text(
                        entry.title,
                        style: KlasivoTypography.bodySmall,
                      ),
                      trailing: Text(
                        '${entry.score.toStringAsFixed(1)}/${entry.maxScore.toStringAsFixed(1)}',
                        style: KlasivoTypography.labelSmall.copyWith(
                          color: _gradeColor(entry.percentage),
                        ),
                      ),
                      onTap: () {
                        setDialogState(() {
                          editingEntry = entry;
                          titleController.text = entry.title;
                          scoreController.text =
                              entry.score.toStringAsFixed(1);
                          maxScoreController.text =
                              entry.maxScore.toStringAsFixed(1);
                          feedbackController.text =
                              entry.feedback ?? '';
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: KlasivoSpacing.lg),
            ],

            // ── Title ──
            KlasivoTextField(
              controller: titleController,
              label: 'Title',
              hint: 'e.g. Quiz 1, Homework 3',
            ),
            const SizedBox(height: KlasivoSpacing.md),

            // ── Score & Max Score ──
            Row(
              children: [
                Expanded(
                  child: KlasivoTextField(
                    controller: scoreController,
                    label: 'Score',
                    hint: '0',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.md),
                Expanded(
                  child: KlasivoTextField(
                    controller: maxScoreController,
                    label: 'Max Score',
                    hint: '100',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KlasivoSpacing.md),

            // ── Feedback ──
            KlasivoTextField(
              controller: feedbackController,
              label: 'Feedback (optional)',
              hint: 'Additional notes...',
              maxLines: 2,
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Action Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KlasivoButton(
                  label: 'Cancel',
                  variant: KlasivoButtonVariant.tertiary,
                  onPressed: () => Navigator.pop(ctx),
                ),
                if (editingEntry != null)
                  Padding(
                    padding: const EdgeInsets.only(left: KlasivoSpacing.sm),
                    child: KlasivoButton(
                      label: 'Delete',
                      variant: KlasivoButtonVariant.danger,
                      onPressed: () async {
                        final confirmed = await KlasivoModal.confirm(
                          context: context,
                          title: 'Delete Entry',
                          message:
                              'Delete "${editingEntry!.title}"? This cannot be undone.',
                          confirmLabel: 'Delete',
                          isDangerous: true,
                        );
                        if (confirmed != true) return;
                        try {
                          await ref
                              .read(gradebookServiceProvider)
                              .deleteEntry(editingEntry!.id);
                          if (mounted) {
                            KlasivoToast.success(context, message: 'Entry deleted');
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (mounted) {
                            KlasivoToast.error(context,
                                message: 'Failed: $e');
                          }
                        }
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: KlasivoSpacing.sm),
                  child: KlasivoButton(
                    label: editingEntry != null ? 'Update' : 'Add',
                    loading: _isLoading,
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            final score = double.tryParse(
                                    scoreController.text.trim()) ??
                                0;
                            final maxScore = double.tryParse(
                                    maxScoreController.text.trim()) ??
                                100;

                            if (title.isEmpty) {
                              KlasivoToast.error(context,
                                  message: 'Please enter a title');
                              return;
                            }
                            if (maxScore <= 0) {
                              KlasivoToast.error(context,
                                  message: 'Max score must be greater than 0');
                              return;
                            }
                            if (score < 0 || score > maxScore) {
                              KlasivoToast.error(context,
                                  message:
                                      'Score must be between 0 and $maxScore');
                              return;
                            }

                            setState(() => _isLoading = true);
                            try {
                              final orgId =
                                  ref.read(currentOrganizationIdProvider) ?? '';
                              final service =
                                  ref.read(gradebookServiceProvider);

                              if (editingEntry != null) {
                                await service.updateEntry(
                                  entryId: editingEntry!.id,
                                  title: title,
                                  score: score,
                                  maxScore: maxScore,
                                  feedback:
                                      feedbackController.text.trim().isEmpty
                                          ? null
                                          : feedbackController.text.trim(),
                                );
                                if (mounted) {
                                  KlasivoToast.success(context,
                                      message: 'Grade updated');
                                }
                              } else {
                                await service.createEntry(
                                  organizationId: orgId,
                                  classId: _selectedClassId!,
                                  studentId: studentId,
                                  categoryId: category.id,
                                  title: title,
                                  score: score,
                                  maxScore: maxScore,
                                );
                                if (mounted) {
                                  KlasivoToast.success(context,
                                      message: 'Grade added');
                                }
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (mounted) {
                                KlasivoToast.error(context,
                                    message: 'Failed: $e');
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Add Entry Dialog (from FAB) ─────────────────────────────────────────

  void _showAddEntryDialog(bool isDark) {
    if (_selectedClassId == null) return;

    final categories =
        ref.read(gradebookCategoriesListProvider(_selectedClassId!));
    final students =
        ref.read(studentsByClassListProvider(_selectedClassId!));

    if (categories.isEmpty) {
      KlasivoToast.error(context,
          message: 'Add at least one category first');
      return;
    }
    if (students.isEmpty) {
      KlasivoToast.error(context,
          message: 'No students in this class');
      return;
    }

    String? selectedStudentId = students.first.id;
    String? selectedCategoryId = categories.first.id;
    final titleController = TextEditingController();
    final scoreController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');

    KlasivoModal.showForm(
      context: context,
      title: 'Add Grade Entry',
      child: StatefulBuilder(
        builder: (ctx, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student Selector ──
            Text(
              'Student',
              style: KlasivoTypography.labelMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextSecondary
                    : KlasivoColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KlasivoSpacing.lg),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(KlasivoRadius.md),
                border: Border.all(
                  color: isDark
                      ? KlasivoColors.darkBorder
                      : KlasivoColors.lightBorder,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedStudentId,
                  isExpanded: true,
                  items: students.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(s.fullName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(
                          () => selectedStudentId = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Category Selector ──
            Text(
              'Category',
              style: KlasivoTypography.labelMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextSecondary
                    : KlasivoColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KlasivoSpacing.lg),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(KlasivoRadius.md),
                border: Border.all(
                  color: isDark
                      ? KlasivoColors.darkBorder
                      : KlasivoColors.lightBorder,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCategoryId,
                  isExpanded: true,
                  items: categories.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(
                          '${c.name} (${c.weight.toStringAsFixed(0)}%)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(
                          () => selectedCategoryId = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Title ──
            KlasivoTextField(
              controller: titleController,
              label: 'Title',
              hint: 'e.g. Quiz 1',
            ),
            const SizedBox(height: KlasivoSpacing.md),

            // ── Score & Max Score ──
            Row(
              children: [
                Expanded(
                  child: KlasivoTextField(
                    controller: scoreController,
                    label: 'Score',
                    hint: '0',
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.md),
                Expanded(
                  child: KlasivoTextField(
                    controller: maxScoreController,
                    label: 'Max Score',
                    hint: '100',
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KlasivoSpacing.lg),

            // ── Action Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KlasivoButton(
                  label: 'Cancel',
                  variant: KlasivoButtonVariant.tertiary,
                  onPressed: () => Navigator.pop(ctx),
                ),
                const SizedBox(width: KlasivoSpacing.sm),
                KlasivoButton(
                  label: 'Add',
                  loading: _isLoading,
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final score = double.tryParse(
                                  scoreController.text.trim()) ??
                              0;
                          final maxScore = double.tryParse(
                                  maxScoreController.text.trim()) ??
                              100;

                          if (title.isEmpty) {
                            KlasivoToast.error(context,
                                message: 'Please enter a title');
                            return;
                          }
                          if (maxScore <= 0) {
                            KlasivoToast.error(context,
                                message: 'Max score must be > 0');
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            final orgId =
                                ref.read(currentOrganizationIdProvider) ?? '';
                            await ref
                                .read(gradebookServiceProvider)
                                .createEntry(
                                  organizationId: orgId,
                                  classId: _selectedClassId!,
                                  studentId: selectedStudentId!,
                                  categoryId: selectedCategoryId!,
                                  title: title,
                                  score: score,
                                  maxScore: maxScore,
                                );
                            if (mounted) {
                              KlasivoToast.success(context,
                                  message: 'Grade entry added');
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              KlasivoToast.error(context,
                                  message: 'Failed: $e');
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
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

  // ─── Category Type Helpers ────────────────────────────────────────────────

  IconData _categoryTypeIcon(String type) {
    switch (type) {
      case AppConstants.categoryExam:
        return Icons.quiz_outlined;
      case AppConstants.categoryHomework:
        return Icons.assignment_outlined;
      case AppConstants.categoryQuiz:
        return Icons.lightbulb_outline;
      case AppConstants.categoryParticipation:
        return Icons.handshake_outlined;
      case AppConstants.categoryProject:
        return Icons.folder_outlined;
      case AppConstants.categoryFinal:
        return Icons.emoji_events_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _categoryTypeColor(String type) {
    switch (type) {
      case AppConstants.categoryExam:
        return KlasivoColors.primary;
      case AppConstants.categoryHomework:
        return KlasivoColors.secondary;
      case AppConstants.categoryQuiz:
        return KlasivoColors.accent;
      case AppConstants.categoryParticipation:
        return const Color(0xFF845EF7); // Purple
      case AppConstants.categoryProject:
        return const Color(0xFFF76707); // Orange
      case AppConstants.categoryFinal:
        return const Color(0xFFE64980); // Pink
      default:
        return KlasivoColors.primary;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRADE CELL — Tap to add/edit a grade for a student×category intersection
// ═══════════════════════════════════════════════════════════════════════════════

class _GradeCell extends StatelessWidget {
  final double average; // -1 means no data
  final bool isDark;
  final VoidCallback onTap;

  const _GradeCell({
    required this.average,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = average >= 0;
    final color = hasData ? _cellColor(average) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KlasivoRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.sm,
          vertical: KlasivoSpacing.xs + 2,
        ),
        decoration: hasData
            ? BoxDecoration(
                color: color?.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasData ? '${average.toStringAsFixed(1)}%' : '—',
              style: (hasData
                      ? KlasivoTypography.labelMedium
                      : KlasivoTypography.bodySmall)
                  .copyWith(
                color: hasData
                    ? color
                    : (isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary),
              ),
            ),
            if (!hasData) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.add_circle_outline,
                size: 14,
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _cellColor(double pct) {
    if (pct >= 80) return KlasivoColors.secondary;
    if (pct >= 60) return KlasivoColors.accent;
    if (pct >= 50) return KlasivoColors.primary;
    return KlasivoColors.error;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEIGHTED AVERAGE CELL — Displays the computed weighted average for a student
// ═══════════════════════════════════════════════════════════════════════════════

class _WeightedAverageCell extends StatelessWidget {
  final double average;
  final bool isDark;

  const _WeightedAverageCell({
    required this.average,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avgColor(average);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.md,
        vertical: KlasivoSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
      ),
      child: Text(
        average > 0 ? '${average.toStringAsFixed(1)}%' : '—',
        style: KlasivoTypography.labelMedium.copyWith(
          color: average > 0
              ? color
              : (isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _avgColor(double pct) {
    if (pct >= 80) return KlasivoColors.secondary;
    if (pct >= 60) return KlasivoColors.accent;
    if (pct >= 50) return KlasivoColors.primary;
    return KlasivoColors.error;
  }
}
