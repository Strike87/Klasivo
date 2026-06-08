import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/assignment_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/subject_provider.dart';
import '../../../providers/group_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ASSIGNMENT FORM SCREEN — Klasivo v1.7
// Create / Edit assignment with Save as Draft & Publish actions
// ═══════════════════════════════════════════════════════════════════════════════

class AssignmentFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final AssignmentData? assignmentData;

  const AssignmentFormScreen({
    Key? key,
    this.isEditing = false,
    this.assignmentData,
  }) : super(key: key);

  @override
  ConsumerState<AssignmentFormScreen> createState() =>
      _AssignmentFormScreenState();
}

class _AssignmentFormScreenState extends ConsumerState<AssignmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latePenaltyController = TextEditingController();

  String? _selectedClassId;
  String? _selectedSubjectId;
  String? _selectedGroupId;
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.assignmentData != null) {
      final a = widget.assignmentData!;
      _titleController.text = a.title;
      _descriptionController.text = a.description ?? '';
      _selectedClassId = a.classId;
      _selectedSubjectId = a.subjectId;
      _selectedGroupId = a.groupId;
      _dueDate = a.dueDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _latePenaltyController.dispose();
    super.dispose();
  }

  // ─── Date Picker ──────────────────────────────────────────────────────────

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  // ─── Input Decoration ─────────────────────────────────────────────────────

  InputDecoration _buildInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      filled: true,
      fillColor: isDark ? KlasivoColors.darkSurface : KlasivoColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: BorderSide(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: BorderSide(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: BorderSide(
          color: isDark ? KlasivoColors.primaryLight : KlasivoColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.error, width: 1.5),
      ),
    );
  }

  // ─── Save Handler ─────────────────────────────────────────────────────────

  Future<void> _handleSave({bool publish = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassId == null) {
      showSnackBar(context, message: 'Please select a class', isError: true);
      return;
    }

    if (_dueDate == null) {
      showSnackBar(context, message: 'Please select a due date', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final assignmentService = ref.read(assignmentServiceProvider);
      final orgId = ref.read(currentOrganizationIdProvider) ?? '';
      final teacherId = ref.read(userIdProvider) ?? '';

      if (widget.isEditing) {
        // ── Update existing assignment ──
        await assignmentService.updateAssignment(
          assignmentId: widget.assignmentData!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          subjectId: _selectedSubjectId,
          groupId: _selectedGroupId,
          dueDate: _dueDate!,
        );

        if (publish && widget.assignmentData!.isDraft) {
          await assignmentService.publishAssignment(widget.assignmentData!.id);
        }

        if (mounted) {
          showSnackBar(
            context,
            message: publish
                ? 'Assignment published successfully!'
                : 'Assignment updated',
          );
          context.pop();
        }
      } else {
        // ── Create new assignment ──
        final assignmentId = await assignmentService.createAssignment(
          organizationId: orgId,
          classId: _selectedClassId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          subjectId: _selectedSubjectId,
          groupId: _selectedGroupId,
          dueDate: _dueDate!,
          createdBy: teacherId,
        );

        // Publish immediately if requested
        if (publish) {
          await assignmentService.publishAssignment(assignmentId);
        }

        if (mounted) {
          showSnackBar(
            context,
            message: publish
                ? 'Assignment created and published!'
                : 'Assignment saved as draft',
          );
          context.go('/teacher/assignments/$assignmentId');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(
          context,
          message: 'Failed: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, yyyy');

    // Watch subjects for selected class
    final subjects = _selectedClassId != null
        ? ref.watch(subjectsByClassListProvider(_selectedClassId!))
        : <SubjectData>[];

    // Watch groups for selected class
    final groups = _selectedClassId != null
        ? ref.watch(groupsByClassListProvider(_selectedClassId!))
        : <GroupData>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Assignment' : 'New Assignment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KlasivoSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Icon ──
              Center(
                child: Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.xxl),
                  decoration: BoxDecoration(
                    color: KlasivoColors.primarySurface.withValues(
                      alpha: isDark ? 0.15 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(KlasivoRadius.xl),
                  ),
                  child: Icon(
                    widget.isEditing
                        ? Icons.edit_note_rounded
                        : Icons.assignment_outlined,
                    size: 48,
                    color: KlasivoColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Section: Assignment Details ──
              KlasivoSectionHeader(title: 'Assignment Details'),
              const SizedBox(height: KlasivoSpacing.md),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Chapter 5 Homework',
                  prefixIcon: Icons.title_rounded,
                ),
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Title is required' : null,
                enabled: !_isLoading,
              ),
              const SizedBox(height: KlasivoSpacing.lg),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: _buildInputDecoration(
                  labelText: 'Description',
                  hintText: 'Instructions or details for students...',
                  prefixIcon: Icons.description_outlined,
                ),
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                maxLines: 3,
                minLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Section: Class & Subject ──
              KlasivoSectionHeader(title: 'Class & Subject'),
              const SizedBox(height: KlasivoSpacing.md),

              // Class selector
              DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: _buildInputDecoration(
                  labelText: 'Class *',
                  hintText: 'Select a class',
                  prefixIcon: Icons.class_outlined,
                ),
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                items: classes
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: !_isLoading
                    ? (value) {
                        setState(() {
                          _selectedClassId = value;
                          // Reset subject & group when class changes
                          _selectedSubjectId = null;
                          _selectedGroupId = null;
                        });
                      }
                    : null,
                validator: (v) => v == null ? 'Select a class' : null,
              ),
              const SizedBox(height: KlasivoSpacing.lg),

              // Subject (optional)
              DropdownButtonFormField<String>(
                value: _selectedSubjectId,
                decoration: _buildInputDecoration(
                  labelText: 'Subject (optional)',
                  hintText: 'Select a subject',
                  prefixIcon: Icons.menu_book_outlined,
                ),
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...subjects.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      )),
                ],
                onChanged: !_isLoading
                    ? (value) {
                        setState(() => _selectedSubjectId = value);
                      }
                    : null,
              ),
              const SizedBox(height: KlasivoSpacing.lg),

              // Group (optional, filtered by class)
              DropdownButtonFormField<String>(
                value: _selectedGroupId,
                decoration: _buildInputDecoration(
                  labelText: 'Group (optional)',
                  hintText: 'Select a group',
                  prefixIcon: Icons.group_outlined,
                ),
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...groups.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name),
                      )),
                ],
                onChanged: !_isLoading
                    ? (value) {
                        setState(() => _selectedGroupId = value);
                      }
                    : null,
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Section: Schedule ──
              KlasivoSectionHeader(title: 'Schedule'),
              const SizedBox(height: KlasivoSpacing.md),

              // Due Date picker
              InkWell(
                onTap: _isLoading ? null : _pickDueDate,
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
                child: InputDecorator(
                  decoration: _buildInputDecoration(
                    labelText: 'Due Date *',
                    prefixIcon: Icons.event_outlined,
                  ),
                  child: Text(
                    _dueDate != null
                        ? dateFormat.format(_dueDate!)
                        : 'Select a date',
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: _dueDate != null
                          ? (isDark
                              ? KlasivoColors.darkTextPrimary
                              : KlasivoColors.lightTextPrimary)
                          : (isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KlasivoSpacing.lg),

              // Late Penalty (optional)
              TextFormField(
                controller: _latePenaltyController,
                decoration: _buildInputDecoration(
                  labelText: 'Late Penalty % (optional)',
                  hintText: 'e.g. 10',
                  prefixIcon: Icons.trending_down_rounded,
                ),
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final val = double.tryParse(v);
                    if (val == null || val < 0 || val > 100) {
                      return 'Enter 0-100';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: KlasivoSpacing.xxxl),

              // ── Action Buttons ──
              Row(
                children: [
                  // Save as Draft
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => _handleSave(publish: false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KlasivoRadius.md),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                widget.isEditing ? 'Save Changes' : 'Save as Draft',
                                style: KlasivoTypography.labelLarge,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.md),

                  // Publish
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _handleSave(publish: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KlasivoColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(KlasivoRadius.md),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Publish',
                                style: KlasivoTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
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
