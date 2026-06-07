import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/common_widgets.dart';

class ClassFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final ClassData? classData;
  final String? stageId;

  const ClassFormScreen({
    Key? key,
    this.isEditing = false,
    this.classData,
    this.stageId,
  }) : super(key: key);

  @override
  ConsumerState<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends ConsumerState<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.classData != null) {
      _nameController.text = widget.classData!.name;
      _gradeController.text = widget.classData!.grade ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final classService = ref.read(classServiceProvider);

      if (widget.isEditing) {
        final gradeValue = _gradeController.text.trim().isEmpty
            ? null
            : _gradeController.text.trim();
        await classService.updateClass(
          classId: widget.classData!.id,
          name: _nameController.text.trim(),
          grade: gradeValue,
        );
        if (mounted) {
          showSnackBar(context, message: 'Class updated successfully');
          context.pop();
        }
      } else {
        final orgId = ref.read(currentOrganizationIdProvider) ?? '';
        await classService.createClass(
          organizationId: orgId,
          stageId: widget.stageId ?? widget.classData?.stageId ?? '',
          name: _nameController.text.trim(),
        );
        if (mounted) {
          showSnackBar(context, message: 'Class created successfully');
          context.pop();
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

  String? _validateName(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'Class name is required';
    }
    if (value!.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Class' : 'Create Class'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Icon ──
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Form ──
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Class Name *',
                      hintText: 'e.g. Grade 10 - Section A',
                      prefixIcon: const Icon(Icons.class_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: _validateName,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _gradeController,
                    decoration: InputDecoration(
                      labelText: 'Grade / Level',
                      hintText: 'e.g. Grade 10, 3rd Year',
                      prefixIcon: const Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 32),

                  // ── Submit Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing ? 'Update Class' : 'Create Class',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Help Text ──
            if (!widget.isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'After creating a class, you can add students to it. Each student will get a unique code for login.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
