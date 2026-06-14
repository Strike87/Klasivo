import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/excel_import_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_toast.dart';

class ExcelImportScreen extends ConsumerStatefulWidget {
  final String classId;
  const ExcelImportScreen({Key? key, required this.classId}) : super(key: key);

  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  final _excelService = ExcelImportService();
  bool _isLoading = false;
  bool _isImporting = false;
  ExcelParseResult? _parseResult;

  // Column mapping
  String? _nameColumn;
  String? _codeColumn;
  String? _classColumn;
  String? _passwordColumn;
  String? _phoneColumn;
  String? _emailColumn;
  String? _parentPhoneColumn;

  List<MappedStudent> _mappedStudents = [];

  Future<void> _pickAndParseFile() async {
    setState(() => _isLoading = true);
    try {
      final filePath = await _excelService.pickExcelFile();
      if (filePath == null) {
        setState(() => _isLoading = false);
        return;
      }
      final result = await _excelService.parseExcel(filePath);
      setState(() {
        _parseResult = result;
        _isLoading = false;
        // Auto-detect common column names
        for (final col in result.columns) {
          final lower = col.toLowerCase();
          if (_nameColumn == null && (lower.contains('name') || lower.contains('الاسم'))) {
            _nameColumn = col;
          } else if (_codeColumn == null && (lower.contains('code') || lower.contains('كود'))) {
            _codeColumn = col;
          } else if (_classColumn == null && (lower.contains('class') || lower.contains('الصف') || lower.contains('الفصل'))) {
            _classColumn = col;
          } else if (_passwordColumn == null && (lower.contains('password') || lower.contains('كلمة') || lower.contains('باسورد'))) {
            _passwordColumn = col;
          } else if (_phoneColumn == null && (lower.contains('phone') || lower.contains('هاتف') || lower.contains('موبايل'))) {
            _phoneColumn = col;
          } else if (_emailColumn == null && (lower.contains('email') || lower.contains('بريد'))) {
            _emailColumn = col;
          } else if (_parentPhoneColumn == null && (lower.contains('parent') || lower.contains('ولي'))) {
            _parentPhoneColumn = col;
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) KlasivoToast.error(context, message: 'Failed to parse file: $e');
    }
  }

  void _previewStudents() {
    if (_parseResult == null || _nameColumn == null) {
      KlasivoToast.error(context, message: 'Please map at least the Name column');
      return;
    }

    final students = <MappedStudent>[];
    for (final row in _parseResult!.rows) {
      final name = row[_nameColumn!]?.trim() ?? '';
      if (name.isEmpty) continue;
      students.add(MappedStudent(
        name: name,
        studentCode: row[_codeColumn ?? '']?.trim() ?? '',
        className: row[_classColumn ?? '']?.trim() ?? '',
        password: row[_passwordColumn ?? '']?.trim() ?? '',
        phone: row[_phoneColumn ?? '']?.trim() ?? '',
        email: row[_emailColumn ?? '']?.trim() ?? '',
        parentPhone: row[_parentPhoneColumn ?? '']?.trim() ?? '',
      ));
    }
    setState(() => _mappedStudents = students);
  }

  Future<void> _importStudents() async {
    if (_mappedStudents.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final teacherId = ref.read(userIdProvider) ?? '';
      final orgId = ref.read(currentOrganizationIdProvider) ?? '';
      final classes = ref.read(classesProvider);
      final classData = classes.firstWhere(
        (c) => c.id == widget.classId,
        orElse: () => ClassData(id: widget.classId, organizationId: orgId, stageId: '', name: 'Unknown'),
      );

      final result = await _excelService.importStudents(
        organizationId: orgId,
        classId: widget.classId,
        students: _mappedStudents,
        createdBy: teacherId,
      );

      setState(() => _isImporting = false);

      if (mounted) {
        KlasivoModal.showForm(
          context: context,
          title: 'Import Complete',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Successfully imported: ${result.successCount} students', style: const TextStyle(color: Colors.green)),
              if (result.failCount > 0)
                Text('Failed: ${result.failCount}', style: const TextStyle(color: Colors.red)),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...result.errors.take(5).map((e) => Text(e, style: const TextStyle(fontSize: 12, color: Colors.red))),
              ],
              const SizedBox(height: 16),
              KlasivoButton(
                label: 'Done',
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) KlasivoToast.error(context, message: 'Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Students from Excel'), centerTitle: true),
      body: _isImporting
          ? const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importing students...'),
              ]),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1: Upload
                  _StepCard(
                    step: 1,
                    title: 'Upload Excel File',
                    child: KlasivoButton(
                      label: _isLoading ? 'Parsing...' : 'Select Excel File',
                      icon: Icons.upload_file,
                      onPressed: _isLoading ? null : _pickAndParseFile,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step 2: Map columns
                  if (_parseResult != null) ...[
                    _StepCard(
                      step: 2,
                      title: 'Map Columns',
                      subtitle: 'Match your Excel columns to student fields',
                      child: Column(
                        children: [
                          _ColumnMapper(label: 'Name *', value: _nameColumn, columns: _parseResult!.columns, onChanged: (v) => setState(() => _nameColumn = v), isRequired: true),
                          _ColumnMapper(label: 'Password', value: _passwordColumn, columns: _parseResult!.columns, onChanged: (v) => setState(() => _passwordColumn = v)),
                          _ColumnMapper(label: 'Phone', value: _phoneColumn, columns: _parseResult!.columns, onChanged: (v) => setState(() => _phoneColumn = v)),
                          _ColumnMapper(label: 'Email', value: _emailColumn, columns: _parseResult!.columns, onChanged: (v) => setState(() => _emailColumn = v)),
                          _ColumnMapper(label: 'Parent Phone', value: _parentPhoneColumn, columns: _parseResult!.columns, onChanged: (v) => setState(() => _parentPhoneColumn = v)),
                          const SizedBox(height: 12),
                          KlasivoButton(
                            label: 'Preview Students',
                            icon: Icons.preview,
                            onPressed: _previewStudents,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Step 3: Preview
                  if (_mappedStudents.isNotEmpty) ...[
                    _StepCard(
                      step: 3,
                      title: 'Preview (${_mappedStudents.length} students)',
                      child: Column(
                        children: [
                          ..._mappedStudents.take(10).map((s) => ListTile(
                                dense: true,
                                leading: KlasivoAvatar(
                                  name: s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                                  size: KlasivoAvatarSize.md,
                                ),
                                title: Text(s.name),
                                subtitle: Text(s.password.isNotEmpty ? 'Password: ${s.password}' : 'Default password will be used'),
                              )),
                          if (_mappedStudents.length > 10)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('... and ${_mappedStudents.length - 10} more', style: TextStyle(color: Colors.grey[600])),
                            ),
                          const SizedBox(height: 12),
                          KlasivoButton(
                            label: 'Import ${_mappedStudents.length} Students',
                            icon: Icons.import_contacts,
                            fullWidth: true,
                            onPressed: _importStudents,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String title;
  final String? subtitle;
  final Widget child;

  const _StepCard({required this.step, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return KlasivoCard(
      variant: KlasivoCardVariant.elevated,
      padding: const EdgeInsets.all(16),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KlasivoAvatar(name: '$step', size: KlasivoAvatarSize.sm),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          ]),
          if (subtitle != null)
            Padding(padding: const EdgeInsets.only(left: 40, top: 4), child: Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 12))),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ColumnMapper extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> columns;
  final ValueChanged<String?> onChanged;
  final bool isRequired;

  const _ColumnMapper({required this.label, this.value, required this.columns, required this.onChanged, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('-- None --')),
          ...columns.map((col) => DropdownMenuItem(value: col, child: Text(col))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
