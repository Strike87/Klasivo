import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/unit_provider.dart';
import '../../../providers/lesson_provider.dart';
import '../../../providers/material_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../core/services/unit_service.dart';
import '../../../core/services/lesson_service.dart';
import '../../../core/services/material_service.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SUBJECT CONTENT SCREEN — LMS Content Browser
// Hierarchy: Subject → Unit → Lesson → Material
// Teachers browse and manage learning content for a specific subject.
// ═══════════════════════════════════════════════════════════════════════════════

class SubjectContentScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String subjectName;
  final String classId;

  const SubjectContentScreen({
    Key? key,
    required this.subjectId,
    required this.subjectName,
    required this.classId,
  }) : super(key: key);

  @override
  ConsumerState<SubjectContentScreen> createState() =>
      _SubjectContentScreenState();
}

class _SubjectContentScreenState extends ConsumerState<SubjectContentScreen> {
  // Track which units are expanded
  final Set<String> _expandedUnits = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unitsAsync = ref.watch(unitsBySubjectProvider(widget.subjectId));

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(unitsBySubjectProvider(widget.subjectId));
          ref.invalidate(lessonsBySubjectProvider(widget.subjectId));
          ref.invalidate(materialsBySubjectProvider(widget.subjectId));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Sliver App Bar ─────────────────────────────────────────────
            SliverAppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: Text(
                widget.subjectName,
                style: KlasivoTypography.titleLarge.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
              floating: true,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              backgroundColor: isDark
                  ? KlasivoColors.darkSurface
                  : KlasivoColors.lightSurface,
              surfaceTintColor: Colors.transparent,
            ),

            // ── Hero Section with Emerald Gradient ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.lg,
                  0,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(KlasivoSpacing.xxl),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.lg),
                    gradient: const LinearGradient(
                      colors: [
                        KlasivoColors.secondary,
                        KlasivoColors.secondaryDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(
                                KlasivoSpacing.sm + 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                  KlasivoRadius.sm),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: KlasivoSpacing.md),
                          Expanded(
                            child: Text(
                              widget.subjectName,
                              style: KlasivoTypography.headlineMedium
                                  .copyWith(color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KlasivoSpacing.lg),
                      Text(
                        'Manage your units, lessons, and learning materials',
                        style: KlasivoTypography.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: KlasivoSpacing.lg),
                      _HeroStatsRow(
                          subjectId: widget.subjectId),
                    ],
                  ),
                ),
              ),
            ),

            // ── Content Section Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KlasivoSpacing.lg,
                  KlasivoSpacing.xxl,
                  KlasivoSpacing.lg,
                  KlasivoSpacing.md,
                ),
                child: KlasivoSectionHeader(
                  title: 'Content',
                  actionLabel: 'Add Unit',
                  onAction: () => _showAddUnitDialog(),
                ),
              ),
            ),

            // ── Units List / Loading / Error / Empty ────────────────────────
            unitsAsync.when(
              loading: () => const SliverFillRemaining(
                child: KlasivoLoading(message: 'Loading units...'),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: KlasivoEmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load content',
                  subtitle: 'Tap to retry',
                  iconColor: KlasivoColors.error,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(
                      unitsBySubjectProvider(widget.subjectId)),
                ),
              ),
              data: (units) {
                // Filter out archived units
                final activeUnits =
                    units.where((u) => !u.isArchived).toList();

                if (activeUnits.isEmpty) {
                  return SliverFillRemaining(
                    child: KlasivoEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'No units yet',
                      subtitle:
                          'Create your first unit to organize lessons and materials',
                      iconColor: KlasivoColors.secondary,
                      actionLabel: 'Create Unit',
                      onAction: () => _showAddUnitDialog(),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final unit = activeUnits[index];
                      return _UnitCard(
                        unit: unit,
                        isExpanded: _expandedUnits.contains(unit.id),
                        onToggle: () => _toggleUnit(unit.id),
                        subjectId: widget.subjectId,
                      );
                    },
                    childCount: activeUnits.length,
                  ),
                );
              },
            ),

            // Bottom padding for FAB clearance
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUnitDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Unit'),
        backgroundColor: KlasivoColors.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }

  // ── Toggle Unit Expansion ────────────────────────────────────────────────

  void _toggleUnit(String unitId) {
    setState(() {
      if (_expandedUnits.contains(unitId)) {
        _expandedUnits.remove(unitId);
      } else {
        _expandedUnits.add(unitId);
      }
    });
  }

  // ── Add Unit Dialog ──────────────────────────────────────────────────────

  void _showAddUnitDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    KlasivoModal.showForm(
      context: context,
      title: 'Create New Unit',
      child: StatefulBuilder(
        builder: (context, setDialogState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KlasivoTextField(
                label: 'Unit Title',
                hint: 'e.g. Unit 1: Introduction',
                controller: titleController,
                prefixIcon: Icons.title_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: KlasivoSpacing.md),
              KlasivoTextField(
                label: 'Description (optional)',
                hint: 'Brief description of this unit',
                controller: descController,
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: KlasivoSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KlasivoButton(
                    variant: KlasivoButtonVariant.tertiary,
                    label: 'Cancel',
                    onPressed: isCreating ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  KlasivoButton(
                    label: 'Create',
                    onPressed: isCreating
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isCreating = true);

                            try {
                              final unitService =
                                  ref.read(unitServiceProvider);
                              await unitService.createUnit(
                                organizationId: '', // populated by service
                                subjectId: widget.subjectId,
                                classId: widget.classId,
                                title: titleController.text.trim(),
                                description: descController.text.trim().isEmpty
                                    ? null
                                    : descController.text.trim(),
                              );

                              if (mounted) {
                                Navigator.pop(context);
                                KlasivoToast.success(
                                  context,
                                  message: 'Unit "${titleController.text.trim()}" created',
                                );
                                ref.invalidate(
                                    unitsBySubjectProvider(widget.subjectId));
                              }
                            } catch (e) {
                              if (mounted) {
                                setDialogState(() => isCreating = false);
                                KlasivoToast.error(
                                  context,
                                  message: 'Failed to create unit: $e',
                                );
                              }
                            }
                          },
                    loading: isCreating,
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

// ═══════════════════════════════════════════════════════════════════════════════
// HERO STATS ROW — Quick overview of subject content counts
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroStatsRow extends ConsumerWidget {
  final String subjectId;

  const _HeroStatsRow({required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(unitsBySubjectProvider(subjectId));
    final lessons = ref.watch(lessonsBySubjectProvider(subjectId));
    final materials = ref.watch(materialsBySubjectProvider(subjectId));

    final unitCount = unitsAsync.whenOrNull(
          data: (units) => units.where((u) => !u.isArchived).length,
        ) ??
        0;

    return Row(
      children: [
        _HeroStatChip(
          value: '$unitCount',
          label: 'Units',
          icon: Icons.folder_outlined,
        ),
        const SizedBox(width: KlasivoSpacing.md),
        _HeroStatChip(
          value: '${lessons.length}',
          label: 'Lessons',
          icon: Icons.play_circle_outline,
        ),
        const SizedBox(width: KlasivoSpacing.md),
        _HeroStatChip(
          value: '${materials.length}',
          label: 'Materials',
          icon: Icons.attach_file_outlined,
        ),
      ],
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _HeroStatChip({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.md,
        vertical: KlasivoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            value,
            style: KlasivoTypography.titleSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            label,
            style: KlasivoTypography.caption.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UNIT CARD — Expandable card showing unit info + lessons + materials
// ═══════════════════════════════════════════════════════════════════════════════

class _UnitCard extends ConsumerWidget {
  final UnitData unit;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String subjectId;

  const _UnitCard({
    required this.unit,
    required this.isExpanded,
    required this.onToggle,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lessons = ref.watch(lessonsBySubjectProvider(subjectId))
        .where((l) => l.chapterId == unit.id)
        .toList();
    final materials = ref.watch(materialsBySubjectProvider(subjectId))
        .where((m) => m.chapterId == unit.id)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.sm,
      ),
      child: KlasivoCard(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Unit Header (tappable) ───────────────────────────────────
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(KlasivoRadius.md),
                bottom: isExpanded
                    ? Radius.zero
                    : const Radius.circular(KlasivoRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(KlasivoSpacing.lg),
                child: Row(
                  children: [
                    // Unit icon
                    Container(
                      padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: KlasivoColors.secondary
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(KlasivoRadius.sm),
                      ),
                      child: const Icon(
                        Icons.folder_outlined,
                        color: KlasivoColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: KlasivoSpacing.md),

                    // Title + stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit.title,
                            style: KlasivoTypography.titleLarge.copyWith(
                              color: isDark
                                  ? KlasivoColors.darkTextPrimary
                                  : KlasivoColors.lightTextPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (unit.description != null &&
                              unit.description!.isNotEmpty) ...[
                            const SizedBox(height: KlasivoSpacing.xs),
                            Text(
                              unit.description!,
                              style: KlasivoTypography.bodySmall.copyWith(
                                color: isDark
                                    ? KlasivoColors.darkTextTertiary
                                    : KlasivoColors.lightTextTertiary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: KlasivoSpacing.sm),
                          Row(
                            children: [
                              KlasivoStatPill(
                                value: '${lessons.length}',
                                label: 'Lessons',
                                color: KlasivoColors.primary,
                              ),
                              const SizedBox(width: KlasivoSpacing.sm),
                              KlasivoStatPill(
                                value: '${materials.length}',
                                label: 'Materials',
                                color: KlasivoColors.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Overflow menu
                    PopupMenuButton<String>(
                      onSelected: (value) =>
                          _handleUnitMenuAction(value, ref, context),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: KlasivoSpacing.sm),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.archive_outlined, size: 20),
                              SizedBox(width: KlasivoSpacing.sm),
                              Text('Archive'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_lesson',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 20),
                              SizedBox(width: KlasivoSpacing.sm),
                              Text('Add Lesson'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_material',
                          child: Row(
                            children: [
                              Icon(Icons.attach_file_outlined, size: 20),
                              SizedBox(width: KlasivoSpacing.sm),
                              Text('Add Material'),
                            ],
                          ),
                        ),
                      ],
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),

                    // Expand/collapse chevron
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: isExpanded ? 0.5 : 0,
                      child: Icon(
                        Icons.expand_more,
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded Content ──────────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(
                  left: KlasivoSpacing.lg,
                  right: KlasivoSpacing.lg,
                  bottom: KlasivoSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lessons section
                    if (lessons.isNotEmpty) ...[
                      _SubsectionHeader(
                        icon: Icons.play_circle_outline,
                        title: 'Lessons',
                        count: lessons.length,
                        color: KlasivoColors.primary,
                      ),
                      const SizedBox(height: KlasivoSpacing.sm),
                      ...lessons.map((lesson) => _LessonTile(
                            lesson: lesson,
                          )),
                    ],

                    // Materials section
                    if (materials.isNotEmpty) ...[
                      if (lessons.isNotEmpty)
                        const SizedBox(height: KlasivoSpacing.lg),
                      _SubsectionHeader(
                        icon: Icons.attach_file_outlined,
                        title: 'Materials',
                        count: materials.length,
                        color: KlasivoColors.accent,
                      ),
                      const SizedBox(height: KlasivoSpacing.sm),
                      ...materials.map((material) => _MaterialTile(
                            material: material,
                          )),
                    ],

                    // Empty state inside expanded unit
                    if (lessons.isEmpty && materials.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: KlasivoSpacing.lg,
                        ),
                        child: Center(
                          child: Text(
                            'No lessons or materials yet',
                            style: KlasivoTypography.bodySmall.copyWith(
                              color: isDark
                                  ? KlasivoColors.darkTextTertiary
                                  : KlasivoColors.lightTextTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }

  // ── Unit Overflow Menu Actions ───────────────────────────────────────────

  void _handleUnitMenuAction(
    String action,
    WidgetRef ref,
    BuildContext context,
  ) {
    switch (action) {
      case 'edit':
        _showEditUnitDialog(context, ref);
        break;
      case 'archive':
        _archiveUnit(ref, context);
        break;
      case 'add_lesson':
        _showAddLessonDialog(context, ref);
        break;
      case 'add_material':
        _showAddMaterialDialog(context, ref);
        break;
    }
  }

  void _showEditUnitDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController(text: unit.title);
    final descController =
        TextEditingController(text: unit.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    KlasivoModal.showForm(
      context: context,
      title: 'Edit Unit',
      child: StatefulBuilder(
        builder: (context, setDialogState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KlasivoTextField(
                label: 'Unit Title',
                controller: titleController,
                prefixIcon: Icons.title_outlined,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
              ),
              const SizedBox(height: KlasivoSpacing.md),
              KlasivoTextField(
                label: 'Description (optional)',
                controller: descController,
                prefixIcon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: KlasivoSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KlasivoButton(
                    variant: KlasivoButtonVariant.tertiary,
                    label: 'Cancel',
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  KlasivoButton(
                    label: 'Save',
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isSaving = true);

                            try {
                              final service = ref.read(unitServiceProvider);
                              await service.updateUnit(
                                unit.id,
                                title: titleController.text.trim(),
                                description: descController.text.trim().isEmpty
                                    ? null
                                    : descController.text.trim(),
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                KlasivoToast.success(context, message: 'Unit updated');
                                ref.invalidate(unitsBySubjectProvider(subjectId));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setDialogState(() => isSaving = false);
                                KlasivoToast.error(context, message: 'Failed: $e');
                              }
                            }
                          },
                    loading: isSaving,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _archiveUnit(WidgetRef ref, BuildContext context) async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Archive Unit',
      message: 'Are you sure you want to archive "${unit.title}"? This unit and its content will be hidden.',
      confirmLabel: 'Archive',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        final service = ref.read(unitServiceProvider);
        await service.archiveUnit(unit.id);
        if (context.mounted) {
          KlasivoToast.success(context, message: '"${unit.title}" archived');
          ref.invalidate(unitsBySubjectProvider(subjectId));
        }
      } catch (e) {
        if (context.mounted) {
          KlasivoToast.error(context, message: 'Failed to archive: $e');
        }
      }
    }
  }

  void _showAddLessonDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedType = 'recorded';
    bool isCreating = false;

    KlasivoModal.showForm(
      context: context,
      title: 'Add Lesson',
      child: StatefulBuilder(
        builder: (context, setDialogState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KlasivoTextField(
                label: 'Lesson Title',
                hint: 'e.g. Introduction to Algebra',
                controller: titleController,
                prefixIcon: Icons.title_outlined,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
              ),
              const SizedBox(height: KlasivoSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Lesson Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'recorded',
                    child: Row(
                      children: [
                        Icon(Icons.videocam_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Recorded Lesson'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'youtube',
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 18),
                        SizedBox(width: 8),
                        Text('YouTube'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'zoom',
                    child: Row(
                      children: [
                        Icon(Icons.video_call_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Zoom Meeting'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
              const SizedBox(height: KlasivoSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KlasivoButton(
                    variant: KlasivoButtonVariant.tertiary,
                    label: 'Cancel',
                    onPressed: isCreating ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  KlasivoButton(
                    label: 'Add',
                    onPressed: isCreating
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isCreating = true);

                            try {
                              final service =
                                  ref.read(lessonServiceProvider);
                              await service.createLesson(
                                organizationId: unit.organizationId,
                                subjectId: subjectId,
                                classId: unit.classId,
                                chapterId: unit.id,
                                title: titleController.text.trim(),
                                type: selectedType,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                KlasivoToast.success(context, message: 'Lesson added');
                                ref.invalidate(
                                    lessonsBySubjectProvider(subjectId));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setDialogState(() => isCreating = false);
                                KlasivoToast.error(context, message: 'Failed: $e');
                              }
                            }
                          },
                    loading: isCreating,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMaterialDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedType = 'pdf';
    bool isCreating = false;

    KlasivoModal.showForm(
      context: context,
      title: 'Add Material',
      child: StatefulBuilder(
        builder: (context, setDialogState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KlasivoTextField(
                label: 'Material Title',
                hint: 'e.g. Chapter 1 Notes',
                controller: titleController,
                prefixIcon: Icons.title_outlined,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Title is required'
                        : null,
              ),
              const SizedBox(height: KlasivoSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Material Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'pdf',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('PDF'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'word',
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Word Document'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'powerpoint',
                    child: Row(
                      children: [
                        Icon(Icons.slideshow_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('PowerPoint'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'image',
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Image'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'video',
                    child: Row(
                      children: [
                        Icon(Icons.videocam_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Video'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'link',
                    child: Row(
                      children: [
                        Icon(Icons.link_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('External Link'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
              ),
              const SizedBox(height: KlasivoSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KlasivoButton(
                    variant: KlasivoButtonVariant.tertiary,
                    label: 'Cancel',
                    onPressed: isCreating ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  KlasivoButton(
                    label: 'Add',
                    onPressed: isCreating
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;

                            setDialogState(() => isCreating = true);

                            try {
                              final service =
                                  ref.read(materialServiceProvider);
                              await service.createMaterial(
                                organizationId: unit.organizationId,
                                subjectId: subjectId,
                                classId: unit.classId,
                                chapterId: unit.id,
                                title: titleController.text.trim(),
                                type: selectedType,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                KlasivoToast.success(context, message: 'Material added');
                                ref.invalidate(
                                    materialsBySubjectProvider(subjectId));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setDialogState(() => isCreating = false);
                                KlasivoToast.error(context, message: 'Failed: $e');
                              }
                            }
                          },
                    loading: isCreating,
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

// ═══════════════════════════════════════════════════════════════════════════════
// SUBSECTION HEADER — Lessons / Materials sub-headers inside a unit
// ═══════════════════════════════════════════════════════════════════════════════

class _SubsectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SubsectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: KlasivoSpacing.sm),
        Text(
          title,
          style: KlasivoTypography.labelMedium.copyWith(
            color: color,
          ),
        ),
        const SizedBox(width: KlasivoSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.sm,
            vertical: KlasivoSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(KlasivoRadius.pill),
          ),
          child: Text(
            '$count',
            style: KlasivoTypography.labelSmall.copyWith(
              color: color,
            ),
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: KlasivoSpacing.sm),
            child: Divider(),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LESSON TILE — Individual lesson row inside a unit
// ═══════════════════════════════════════════════════════════════════════════════

class _LessonTile extends StatelessWidget {
  final LessonData lesson;

  const _LessonTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeConfig = _lessonTypeConfig(lesson.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        onTap: () {
          // TODO: Navigate to lesson detail / player
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.md,
            vertical: KlasivoSpacing.md,
          ),
          decoration: BoxDecoration(
            color: typeConfig.color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            border: Border.all(
              color: typeConfig.color.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.sm),
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(KlasivoRadius.xs),
                ),
                child: Icon(
                  typeConfig.icon,
                  color: typeConfig.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: KlasivoSpacing.md),

              // Title + type label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: KlasivoTypography.titleSmall.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.typeLabel,
                      style: KlasivoTypography.caption.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Duration + views
              if (lesson.duration > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      left: KlasivoSpacing.sm),
                  child: Text(
                    lesson.durationFormatted,
                    style: KlasivoTypography.caption.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ),
              if (lesson.viewCount > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      left: KlasivoSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${lesson.viewCount}',
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _TypeConfig _lessonTypeConfig(String type) {
    switch (type) {
      case 'recorded':
        return _TypeConfig(
          icon: Icons.videocam_outlined,
          color: KlasivoColors.primary,
          label: 'Recorded',
        );
      case 'youtube':
        return _TypeConfig(
          icon: Icons.play_circle_outline,
          color: const Color(0xFFFF0000),
          label: 'YouTube',
        );
      case 'zoom':
        return _TypeConfig(
          icon: Icons.video_call_outlined,
          color: const Color(0xFF2D8CFF),
          label: 'Zoom',
        );
      case 'google_drive':
        return _TypeConfig(
          icon: Icons.cloud_outlined,
          color: const Color(0xFF4285F4),
          label: 'Google Drive',
        );
      default:
        return _TypeConfig(
          icon: Icons.play_circle_outline,
          color: KlasivoColors.primary,
          label: type,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATERIAL TILE — Individual material row inside a unit
// ═══════════════════════════════════════════════════════════════════════════════

class _MaterialTile extends StatelessWidget {
  final MaterialData material;

  const _MaterialTile({required this.material});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeConfig = _materialTypeConfig(material.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        onTap: () {
          // TODO: Navigate to material detail / download
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.md,
            vertical: KlasivoSpacing.md,
          ),
          decoration: BoxDecoration(
            color: typeConfig.color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            border: Border.all(
              color: typeConfig.color.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Type icon
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.sm),
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(KlasivoRadius.xs),
                ),
                child: Icon(
                  typeConfig.icon,
                  color: typeConfig.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: KlasivoSpacing.md),

              // Title + type label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.title,
                      style: KlasivoTypography.titleSmall.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      typeConfig.label,
                      style: KlasivoTypography.caption.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // File size + download count
              if (material.fileSize > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      left: KlasivoSpacing.sm),
                  child: Text(
                    material.formattedSize,
                    style: KlasivoTypography.caption.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ),
              if (material.downloadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      left: KlasivoSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 14,
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${material.downloadCount}',
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _TypeConfig _materialTypeConfig(String type) {
    switch (type) {
      case 'pdf':
        return _TypeConfig(
          icon: Icons.picture_as_pdf_outlined,
          color: const Color(0xFFE03131),
          label: 'PDF',
        );
      case 'word':
        return _TypeConfig(
          icon: Icons.description_outlined,
          color: const Color(0xFF2B579A),
          label: 'Word',
        );
      case 'powerpoint':
        return _TypeConfig(
          icon: Icons.slideshow_outlined,
          color: const Color(0xFFD24726),
          label: 'PowerPoint',
        );
      case 'image':
        return _TypeConfig(
          icon: Icons.image_outlined,
          color: KlasivoColors.secondary,
          label: 'Image',
        );
      case 'video':
        return _TypeConfig(
          icon: Icons.videocam_outlined,
          color: KlasivoColors.primary,
          label: 'Video',
        );
      case 'link':
        return _TypeConfig(
          icon: Icons.link_outlined,
          color: const Color(0xFF3B5BDB),
          label: 'Link',
        );
      default:
        return _TypeConfig(
          icon: Icons.insert_drive_file_outlined,
          color: KlasivoColors.accent,
          label: type,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE CONFIG — Shared config for lesson/material type icons & colors
// ═══════════════════════════════════════════════════════════════════════════════

class _TypeConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _TypeConfig({
    required this.icon,
    required this.color,
    required this.label,
  });
}
