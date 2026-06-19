import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_toast.dart';
import 'package:klasivo/core/services/password_hasher.dart';

class StudentFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final StudentData? studentData;
  final String classId;

  const StudentFormScreen({
    Key? key,
    this.isEditing = false,
    this.studentData,
    required this.classId,
  }) : super(key: key);

  @override
  ConsumerState<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends ConsumerState<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gradeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.studentData != null) {
      _nameController.text = widget.studentData!.fullName;
      _gradeController.text = widget.studentData!.grade ?? '';
    }
    // Default password for new students
    if (!widget.isEditing) {
      _passwordController.text = PasswordHasher.instance.generateTemporaryPassword();  // C-18: random per-student
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final studentService = ref.read(studentServiceProvider);

      if (widget.isEditing) {
        final gradeValue = _gradeController.text.trim().isEmpty
            ? null
            : _gradeController.text.trim();
        await studentService.updateStudent(
          studentId: widget.studentData!.id,
          fullName: _nameController.text.trim(),
          grade: gradeValue,
          password: _passwordController.text.trim().isEmpty
              ? null
              : _passwordController.text.trim(),
        );
        if (mounted) {
          KlasivoToast.success(context, message: 'Student updated successfully');
          context.pop();
        }
      } else {
        final teacherId = ref.read(userIdProvider) ?? '';
        final orgId = ref.read(currentOrganizationIdProvider) ?? '';
        // Find the class name
        final classes = ref.read(classesProvider);
        final classData = classes.firstWhere(
          (c) => c.id == widget.classId,
          orElse: () => ClassData(
            id: widget.classId,
            organizationId: orgId,
            stageId: '',
            name: 'Unknown Class',
          ),
        );

        await studentService.addStudent(
          organizationId: orgId,
          classId: widget.classId,
          fullName: _nameController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          KlasivoToast.success(context, message: 'Student added successfully');
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateName(String? value) {
    if (value?.trim().isEmpty ?? true) {
      return 'Student name is required';
    }
    if (value!.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (!widget.isEditing && (value?.trim().isEmpty ?? true)) {
      return 'Password is required';
    }
    if (value != null && value.isNotEmpty && value.length < 4) {
      return 'Password must be at least 4 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Student' : 'Add Student'),
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
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.isEditing
                      ? Icons.edit_outlined
                      : Icons.person_add_outlined,
                  size: 48,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Info Card ──
            if (!widget.isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.green[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A unique student code will be auto-generated. The student will use this code and the password to login.',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (widget.isEditing && widget.studentData != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Code',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          widget.studentData!.studentCode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Form ──
            Form(
              key: _formKey,
              child: Column(
                children: [
                  KlasivoTextField(
                    controller: _nameController,
                    label: 'Full Name *',
                    hint: 'e.g. Ahmed Mohamed',
                    prefixIcon: Icons.person_outline,
                    validator: _validateName,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  KlasivoTextField(
                    controller: _gradeController,
                    label: 'Grade / Level',
                    hint: 'e.g. Grade 10',
                    prefixIcon: Icons.school_outlined,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  KlasivoTextField(
                    controller: _passwordController,
                    label: widget.isEditing
                        ? 'New Password (leave empty to keep current)'
                        : 'Password *',
                    hint: widget.isEditing
                        ? 'Leave empty to keep current'
                        : 'Min 4 characters',
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() =>
                            _obscurePassword = !_obscurePassword);
                      },
                    ),
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 32),

                  // ── Submit Button ──
                  KlasivoButton(
                    label: widget.isEditing
                        ? 'Update Student'
                        : 'Add Student',
                    onPressed: _isLoading ? null : _handleSubmit,
                    loading: _isLoading,
                    fullWidth: true,
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
