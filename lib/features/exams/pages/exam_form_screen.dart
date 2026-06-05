import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../widgets/common_widgets.dart';

class ExamFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final ExamData? examData;

  const ExamFormScreen({
    Key? key,
    this.isEditing = false,
    this.examData,
  }) : super(key: key);

  @override
  ConsumerState<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends ConsumerState<ExamFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _passingScoreController = TextEditingController();

  String? _selectedClassId;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.examData != null) {
      _titleController.text = widget.examData!.title;
      _descriptionController.text = widget.examData!.description ?? '';
      _durationController.text = widget.examData!.durationMinutes.toString();
      _passingScoreController.text = widget.examData!.passingScore.toString();
      _selectedClassId = widget.examData!.classId;
      _startDate = widget.examData!.startDate;
      _startTime = TimeOfDay.fromDateTime(widget.examData!.startDate);
      _endDate = widget.examData!.endDate;
      _endTime = TimeOfDay.fromDateTime(widget.examData!.endDate);
    } else {
      _durationController.text = '30';
      _passingScoreController.text = '50';
      _startDate = DateTime.now().add(const Duration(days: 1));
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endDate = DateTime.now().add(const Duration(days: 1));
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _passingScoreController.dispose();
    super.dispose();
  }

  DateTime get _combinedStart {
    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
  }

  DateTime get _combinedEnd {
    return DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassId == null) {
      showSnackBar(context, message: 'Please select a class', isError: true);
      return;
    }
    if (_startDate == null || _startTime == null) {
      showSnackBar(context,
          message: 'Please set start date and time', isError: true);
      return;
    }
    if (_endDate == null || _endTime == null) {
      showSnackBar(context,
          message: 'Please set end date and time', isError: true);
      return;
    }
    if (_combinedEnd.isBefore(_combinedStart)) {
      showSnackBar(context,
          message: 'End time must be after start time', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final examService = ref.read(examServiceProvider);

      if (widget.isEditing) {
        await examService.updateExam(
          examId: widget.examData!.id,
          title: _titleController.text.trim(),
          classId: _selectedClassId!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          durationMinutes: int.parse(_durationController.text.trim()),
          startDate: _combinedStart,
          endDate: _combinedEnd,
          passingScore: int.parse(_passingScoreController.text.trim()),
        );
        if (mounted) {
          showSnackBar(context, message: 'Exam updated successfully');
          context.pop();
        }
      } else {
        final teacherId = ref.read(userIdProvider) ?? '';
        final examId = await examService.createExam(
          teacherId: teacherId,
          title: _titleController.text.trim(),
          classId: _selectedClassId!,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          durationMinutes: int.parse(_durationController.text.trim()),
          startDate: _combinedStart,
          endDate: _combinedEnd,
          passingScore: int.parse(_passingScoreController.text.trim()),
        );
        if (mounted) {
          showSnackBar(context, message: 'Exam created! Now add questions.');
          context.go('/teacher/exams/$examId/questions');
        }
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context,
            message: 'Failed: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Exam' : 'Create Exam'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    widget.isEditing
                        ? Icons.edit_outlined
                        : Icons.quiz_outlined,
                    size: 48,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Basic Info ──
              Text(
                'Exam Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Exam Title *',
                  hintText: 'e.g. Midterm Mathematics',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Title is required' : null,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional exam description or instructions',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // ── Class Selection ──
              DropdownButtonFormField<String>(
                value: _selectedClassId,
                decoration: InputDecoration(
                  labelText: 'Class *',
                  prefixIcon: const Icon(Icons.class_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: classes
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: !_isLoading
                    ? (value) => setState(() => _selectedClassId = value)
                    : null,
                validator: (v) => v == null ? 'Select a class' : null,
              ),
              const SizedBox(height: 24),

              // ── Schedule ──
              Text(
                'Schedule',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Start Date/Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isLoading ? null : _pickStartDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Date *',
                          prefixIcon: const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _startDate != null
                              ? dateFormat.format(_startDate!)
                              : 'Select date',
                          style: TextStyle(
                            color: _startDate != null
                                ? null
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _isLoading ? null : _pickStartTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Time *',
                          prefixIcon:
                              const Icon(Icons.access_time, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _startTime != null
                              ? _startTime!.format(context)
                              : 'Select time',
                          style: TextStyle(
                            color: _startTime != null
                                ? null
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // End Date/Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isLoading ? null : _pickEndDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Date *',
                          prefixIcon: const Icon(Icons.calendar_today, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _endDate != null
                              ? dateFormat.format(_endDate!)
                              : 'Select date',
                          style: TextStyle(
                            color: _endDate != null
                                ? null
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _isLoading ? null : _pickEndTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Time *',
                          prefixIcon:
                              const Icon(Icons.access_time, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _endTime != null
                              ? _endTime!.format(context)
                              : 'Select time',
                          style: TextStyle(
                            color: _endTime != null
                                ? null
                                : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Settings ──
              Text(
                'Settings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        labelText: 'Duration (min) *',
                        hintText: 'e.g. 30',
                        prefixIcon: const Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final val = int.tryParse(v!);
                        if (val == null || val < 1) return 'Min 1 min';
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _passingScoreController,
                      decoration: InputDecoration(
                        labelText: 'Passing Score (%) *',
                        hintText: 'e.g. 50',
                        prefixIcon: const Icon(Icons.stars_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        final val = int.tryParse(v!);
                        if (val == null || val < 0 || val > 100) {
                          return '0-100';
                        }
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                  ),
                ],
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
                          widget.isEditing
                              ? 'Update Exam'
                              : 'Create & Add Questions',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (!widget.isEditing) ...[
                const SizedBox(height: 12),
                Text(
                  'After creating the exam, you\'ll be taken to the question builder to add questions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
