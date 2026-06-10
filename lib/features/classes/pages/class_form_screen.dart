import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../core/config/theme.dart';

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
  final _codeController = TextEditingController();
  final _capacityController = TextEditingController();
  String? _selectedStageId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.classData != null) {
      _nameController.text = widget.classData!.name;
      _codeController.text = widget.classData!.code;
      _capacityController.text =
          widget.classData!.capacity > 0 ? widget.classData!.capacity.toString() : '';
      _selectedStageId = widget.classData!.stageId;
    } else {
      _selectedStageId = widget.stageId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate stage selection
    if (_selectedStageId == null || _selectedStageId!.isEmpty) {
      showSnackBar(context, message: 'Please select a stage', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final classService = ref.read(classServiceProvider);
      final orgId = ref.read(currentOrganizationIdProvider) ?? '';
      final userId = ref.read(userIdProvider) ?? '';
      final capacity = int.tryParse(_capacityController.text.trim()) ?? 0;

      if (widget.isEditing) {
        await classService.updateClass(
          classId: widget.classData!.id,
          name: _nameController.text.trim(),
          stageId: _selectedStageId,
          code: _codeController.text.trim(),
          capacity: capacity,
        );
        if (mounted) {
          showSnackBar(context, message: 'Class updated successfully');
          context.pop();
        }
      } else {
        await classService.createClass(
          organizationId: orgId,
          stageId: _selectedStageId!,
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          capacity: capacity,
          createdBy: userId,
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

  String? _validateCapacity(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Enter a valid number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = ref.watch(stagesProvider);

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
                  color: KlasivoColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.isEditing
                      ? Icons.edit_outlined
                      : Icons.add_circle_outline,
                  size: 48,
                  color: KlasivoColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ── Form ──
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Stage selector
                  DropdownButtonFormField<String>(
                    value: (_selectedStageId != null &&
                            stages.any((s) => s.id == _selectedStageId))
                        ? _selectedStageId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Stage *',
                      prefixIcon: const Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: stages.map((stage) {
                      return DropdownMenuItem<String>(
                        value: stage.id,
                        child: Text(stage.name),
                      );
                    }).toList(),
                    onChanged: widget.isEditing
                        ? null // Don't allow changing stage on edit
                        : (value) {
                            setState(() => _selectedStageId = value);
                          },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a stage';
                      }
                      return null;
                    },
                    disabledHint: _selectedStageId != null
                        ? Text(stages
                                .firstWhere(
                                    (s) => s.id == _selectedStageId,
                                    orElse: () => StageData(
                                        id: '',
                                        organizationId: '',
                                        name: 'Unknown'))
                                .name)
                        : const Text('Select a stage'),
                  ),
                  const SizedBox(height: 16),

                  // Class Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Class Name *',
                      hintText: 'e.g. Grade 5',
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

                  // Class Code
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Class Code',
                      hintText: 'e.g. G5',
                      prefixIcon: const Icon(Icons.tag),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),

                  // Capacity
                  TextFormField(
                    controller: _capacityController,
                    decoration: InputDecoration(
                      labelText: 'Capacity',
                      hintText: 'e.g. 40',
                      prefixIcon: const Icon(Icons.event_seat_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    validator: _validateCapacity,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
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
                  color: KlasivoColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: KlasivoColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: KlasivoColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Classes belong to a stage. After creating a class, '
                        'you can add students to it. Each student will get a '
                        'unique code for login.',
                        style: TextStyle(
                          color: KlasivoColors.primary,
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
