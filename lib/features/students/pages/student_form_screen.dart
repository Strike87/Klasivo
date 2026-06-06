import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/student_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';

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
      _passwordController.text = '123456';
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
        await studentService.updateStudent(
          studentId: widget.studentData!.id,
          fullName: _nameController.text.trim(),
          grade: _gradeController.text.trim().isEmpty
              ? null
              : _gradeController.text.trim(),
          password: _passwordController.text.trim().isEmpty
              ? null
              : _passwordController.text.trim(),
        );
        if (mounted) {
          showSnackBar(context, message: 'Student updated successfully');
          context.pop();
        }
      } else {
        final teacherId = ref.read(userIdProvider) ?? '';
        // Find the class name
        final classes = ref.read(classesProvider);
        final classData = classes.firstWhere(
          (c) => c.id == widget.classId,
          orElse: () => ClassData(
            id: widget.classId,
            teacherId: teacherId,
            name: 'Unknown Class',
          ),
        );

        await studentService.addStudent(
          teacherId: teacherId,
          classId: widget.classId,
          className: classData.name,
          fullName: _nameController.text.trim(),
          password: _passwordController.text.trim(),
          grade: _gradeController.text.trim().isEmpty
              ? null
              : _gradeController.text.trim(),
        );
        if (mounted) {
          showSnackBar(context, message: 'Student added successfully');
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
                  color: Colors.green.withOpacity(0.1),
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
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.2)),
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
                  color: theme.colorScheme.primary.withOpacity(0.05),
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
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      hintText: 'e.g. Ahmed Mohamed',
                      prefixIcon: const Icon(Icons.person_outline),
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
                      hintText: 'e.g. Grade 10',
                      prefixIcon: const Icon(Icons.school_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: widget.isEditing
                          ? 'New Password (leave empty to keep current)'
                          : 'Password *',
                      hintText: widget.isEditing
                          ? 'Leave empty to keep current'
                          : 'Min 4 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    enabled: !_isLoading,
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
                              widget.isEditing
                                  ? 'Update Student'
                                  : 'Add Student',
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
          ],
        ),
      ),
    );
  }
}
