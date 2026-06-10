import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/calendar_event_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';

class CalendarEventFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final CalendarEventData? eventData;

  const CalendarEventFormScreen({
    Key? key,
    required this.isEditing,
    this.eventData,
  }) : super(key: key);

  @override
  ConsumerState<CalendarEventFormScreen> createState() => _CalendarEventFormScreenState();
}

class _CalendarEventFormScreenState extends ConsumerState<CalendarEventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _eventType = 'event';
  DateTime _date = DateTime.now();
  DateTime? _endDate;
  String? _classId;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _eventTypes = [
    {'value': 'exam', 'label': 'Exam', 'icon': Icons.quiz, 'color': 0xFF3B5BDB},
    {'value': 'assignment', 'label': 'Assignment', 'icon': Icons.assignment, 'color': 0xFFF59F00},
    {'value': 'holiday', 'label': 'Holiday', 'icon': Icons.celebration, 'color': 0xFF12B886},
    {'value': 'event', 'label': 'Event', 'icon': Icons.event, 'color': 0xFF845EF7},
    {'value': 'meeting', 'label': 'Meeting', 'icon': Icons.people, 'color': 0xFF15AABF},
    {'value': 'deadline', 'label': 'Deadline', 'icon': Icons.alarm, 'color': 0xFFFA5252},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.eventData != null) {
      _titleController.text = widget.eventData!.title;
      _descriptionController.text = widget.eventData!.description ?? '';
      _eventType = widget.eventData!.eventType;
      _date = widget.eventData!.date;
      _endDate = widget.eventData!.endDate;
      _classId = widget.eventData!.classId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final orgId = ref.read(currentOrganizationIdProvider);
      final userId = ref.read(userIdProvider);
      final userName = ref.read(userNameProvider);

      final selectedType = _eventTypes.firstWhere((t) => t['value'] == _eventType);

      if (widget.isEditing) {
        await ref.read(calendarEventServiceProvider).updateEvent(
          widget.eventData!.id,
          title: _titleController.text.trim(),
          eventType: _eventType,
          date: _date,
          endDate: _endDate,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          classId: _classId,
          color: (selectedType['color'] as int).toRadixString(16).padLeft(8, '0').substring(2),
        );
      } else {
        await ref.read(calendarEventServiceProvider).createEvent(
          organizationId: orgId!,
          title: _titleController.text.trim(),
          eventType: _eventType,
          date: _date,
          endDate: _endDate,
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          classId: _classId,
          createdBy: userId,
          createdByName: userName,
          color: (selectedType['color'] as int).toRadixString(16).padLeft(8, '0').substring(2),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Event' : 'New Event'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Event Type Selection
            Text('Event Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _eventTypes.map((type) => ChoiceChip(
                avatar: Icon(type['icon'] as IconData, size: 16, color: _eventType == type['value'] ? Colors.white : Color(type['color'] as int)),
                label: Text(type['label'] as String),
                selected: _eventType == type['value'],
                selectedColor: Color(type['color'] as int),
                labelStyle: TextStyle(
                  color: _eventType == type['value'] ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _eventType = type['value'] as String),
              )).toList(),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Math Midterm Exam',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFF3B5BDB)),
              title: Text('Date: ${_formatDate(_date)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _date = date);
              },
            ),

            // End Date
            ListTile(
              leading: Icon(Icons.calendar_today, color: _endDate != null ? const Color(0xFF12B886) : Colors.grey),
              title: Text(_endDate != null ? 'End: ${_formatDate(_endDate!)}' : 'End date (optional)'),
              trailing: _endDate != null
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _endDate = null))
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? _date,
                  firstDate: _date,
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _endDate = date);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
