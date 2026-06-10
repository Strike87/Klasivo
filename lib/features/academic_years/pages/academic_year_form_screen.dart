import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/academic_year_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';

class AcademicYearFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final AcademicYearData? yearData;

  const AcademicYearFormScreen({
    Key? key,
    required this.isEditing,
    this.yearData,
  }) : super(key: key);

  @override
  ConsumerState<AcademicYearFormScreen> createState() => _AcademicYearFormScreenState();
}

class _AcademicYearFormScreenState extends ConsumerState<AcademicYearFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime(DateTime.now().year, 9, 1); // Default: Sep 1
  DateTime _endDate = DateTime(DateTime.now().year + 1, 6, 30); // Default: Jun 30
  bool _isCurrent = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.yearData != null) {
      _nameController.text = widget.yearData!.name;
      _startDate = widget.yearData!.startDate;
      _endDate = widget.yearData!.endDate;
      _isCurrent = widget.yearData!.isCurrent;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final orgId = ref.read(currentOrganizationIdProvider);
      final userId = ref.read(userIdProvider);

      if (widget.isEditing) {
        await ref.read(academicYearServiceProvider).updateAcademicYear(
          widget.yearData!.id,
          name: _nameController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          isCurrent: _isCurrent,
        );
      } else {
        await ref.read(academicYearServiceProvider).createAcademicYear(
          organizationId: orgId!,
          name: _nameController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          isCurrent: _isCurrent,
          createdBy: userId,
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
        title: Text(widget.isEditing ? 'Edit Academic Year' : 'New Academic Year'),
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
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., 2026/2027',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: (v) => v?.trim().isEmpty == true ? 'Name is required' : null,
            ),
            const SizedBox(height: 24),

            // Start Date
            ListTile(
              leading: const Icon(Icons.play_arrow, color: Color(0xFF12B886)),
              title: Text('Start: ${_formatDate(_startDate)}'),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                );
                if (date != null) setState(() => _startDate = date);
              },
            ),
            const SizedBox(height: 8),

            // End Date
            ListTile(
              leading: const Icon(Icons.stop, color: Color(0xFFF59F00)),
              title: Text('End: ${_formatDate(_endDate)}'),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: _startDate,
                  lastDate: DateTime(2040),
                );
                if (date != null) setState(() => _endDate = date);
              },
            ),
            const SizedBox(height: 8),

            // Duration display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B5BDB).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF3B5BDB)),
                  const SizedBox(width: 8),
                  Text(
                    'Duration: ${_endDate.difference(_startDate).inDays} days',
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF3B5BDB)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Current toggle
            SwitchListTile(
              title: const Text('Set as current academic year'),
              subtitle: const Text('Only one year can be current at a time'),
              value: _isCurrent,
              onChanged: (v) => setState(() => _isCurrent = v),
              activeColor: const Color(0xFF12B886),
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
