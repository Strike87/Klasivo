import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:excel/excel.dart';
import '../../providers/excel_import_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/excel_import_service.dart';
import '../../core/services/auth_service.dart';

/// Excel Import Screen - Import students or questions from .xlsx files
/// Features: file picker, column mapping, data preview, validation, import
class ExcelImportScreen extends ConsumerStatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  final ExcelImportService _service = ExcelImportService();
  int _currentStep = 0; // 0: Pick file, 1: Map columns, 2: Preview, 3: Import

  @override
  void dispose() {
    // Reset state on exit
    ref.read(excelFileBytesProvider.notifier).state = null;
    ref.read(excelSheetDataProvider.notifier).state = {};
    ref.read(selectedSheetProvider.notifier).state = '';
    ref.read(studentColumnMappingProvider.notifier).state = {};
    ref.read(questionColumnMappingProvider.notifier).state = {};
    ref.read(validationErrorsProvider.notifier).state = [];
    ref.read(importProgressProvider.notifier).state = 0.0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Excel'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(theme),
          // Step content
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildFilePickerStep(theme),
                _buildColumnMappingStep(theme),
                _buildPreviewStep(theme),
                _buildImportStep(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ThemeData theme) {
    final steps = ['Pick File', 'Map Columns', 'Preview', 'Import'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isCompleted = i < _currentStep;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (isCompleted) setState(() => _currentStep = i);
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isCompleted
                        ? Colors.green
                        : isActive
                            ? theme.colorScheme.primary
                            : Colors.grey[300],
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isActive || isCompleted ? Colors.white : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive
                            ? theme.colorScheme.primary
                            : isCompleted
                                ? Colors.green
                                : Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (i < steps.length - 1)
                    Expanded(child: Divider(color: isCompleted ? Colors.green : Colors.grey[300])),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== STEP 1: FILE PICKER ====================

  Widget _buildFilePickerStep(ThemeData theme) {
    final importMode = ref.watch(importModeProvider);
    final fileBytes = ref.watch(excelFileBytesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Import mode selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What do you want to import?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SegmentedButton<ImportMode>(
                    segments: const [
                      ButtonSegment(value: ImportMode.students, label: Text('Students'), icon: Icon(Icons.people)),
                      ButtonSegment(value: ImportMode.questions, label: Text('Questions'), icon: Icon(Icons.quiz)),
                    ],
                    selected: {importMode},
                    onSelectionChanged: (modes) {
                      ref.read(importModeProvider.notifier).state = modes.first;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Target selector (class or exam)
          if (importMode == ImportMode.students)
            _buildClassSelector(theme)
          else
            _buildQuestionTargetSelector(theme),

          const SizedBox(height: 16),

          // File picker
          Card(
            child: InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      fileBytes != null ? Icons.check_circle : Icons.upload_file,
                      size: 64,
                      color: fileBytes != null ? Colors.green : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fileBytes != null ? 'File loaded successfully!' : 'Tap to select Excel file',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supports .xlsx and .xls files',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (fileBytes != null) ...[
            const SizedBox(height: 16),
            // Sheet selector
            _buildSheetSelector(theme),
          ],

          const SizedBox(height: 24),

          // Next button
          FilledButton(
            onPressed: fileBytes != null ? () => setState(() => _currentStep = 1) : null,
            child: const Text('Next: Map Columns'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector(ThemeData theme) {
    final targetClassId = ref.watch(importTargetClassIdProvider);
    final targetClassName = ref.watch(importTargetClassNameProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import to Class', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (targetClassId != null)
              Chip(
                avatar: const Icon(Icons.class_, size: 18),
                label: Text(targetClassName ?? 'Selected Class'),
                onDeleted: () {
                  ref.read(importTargetClassIdProvider.notifier).state = null;
                  ref.read(importTargetClassNameProvider.notifier).state = null;
                },
              )
            else
              Text(
                'Select a class from the class list first, then come back to import.',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTargetSelector(ThemeData theme) {
    final target = ref.watch(questionImportTargetProvider);
    final examId = ref.watch(importTargetExamIdProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import Questions To', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<QuestionImportTarget>(
              segments: const [
                ButtonSegment(value: QuestionImportTarget.bank, label: Text('Question Bank')),
                ButtonSegment(value: QuestionImportTarget.exam, label: Text('Direct to Exam')),
              ],
              selected: {target},
              onSelectionChanged: (modes) {
                ref.read(questionImportTargetProvider.notifier).state = modes.first;
              },
            ),
            if (target == QuestionImportTarget.exam) ...[
              const SizedBox(height: 8),
              Text(
                examId != null ? 'Exam selected' : 'Select an exam from the exam list first.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            if (target == QuestionImportTarget.bank) ...[
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Mathematics, Physics',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => ref.read(importSubjectProvider.notifier).state = v,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSheetSelector(ThemeData theme) {
    final sheetData = ref.watch(excelSheetDataProvider);
    final selectedSheet = ref.watch(selectedSheetProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Sheet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedSheet.isNotEmpty ? selectedSheet : null,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: sheetData.keys.map((name) {
                return DropdownMenuItem(value: name, child: Text(name));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  ref.read(selectedSheetProvider.notifier).state = value;
                  _autoDetectMapping(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 2: COLUMN MAPPING ====================

  Widget _buildColumnMappingStep(ThemeData theme) {
    final importMode = ref.watch(importModeProvider);
    final sheetData = ref.watch(excelSheetDataProvider);
    final selectedSheet = ref.watch(selectedSheetProvider);

    if (selectedSheet.isEmpty || !sheetData.containsKey(selectedSheet)) {
      return const Center(child: Text('No sheet selected'));
    }

    final headers = _service.extractHeaders(sheetData[selectedSheet]!);
    final mapping = importMode == ImportMode.students
        ? ref.watch(studentColumnMappingProvider)
        : ref.watch(questionColumnMappingProvider);

    final targetFields = importMode == ImportMode.students
        ? ExcelImportService.studentTargetFields
        : ExcelImportService.questionTargetFields;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Map Columns', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _autoDetectMapping(selectedSheet),
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Auto-detect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Match your Excel columns to the app fields. Only "Full Name" / "Question Text" is required.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Column mapping dropdowns
          ...targetFields.map((field) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        _getFieldLabel(field),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: mapping[field],
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: mapping[field] != null
                              ? Colors.green.withOpacity(0.05)
                              : null,
                        ),
                        hint: const Text('Select column...'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('-- Skip --')),
                          ...headers.map((h) => DropdownMenuItem(value: h, child: Text(h))),
                        ],
                        onChanged: (value) {
                          final newMapping = Map<String, String>.from(mapping);
                          if (value == null || value.isEmpty) {
                            newMapping.remove(field);
                          } else {
                            newMapping[field] = value;
                          }
                          if (importMode == ImportMode.students) {
                            ref.read(studentColumnMappingProvider.notifier).state = newMapping;
                          } else {
                            ref.read(questionColumnMappingProvider.notifier).state = newMapping;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Data preview (first 3 rows)
          _buildMiniPreview(theme),

          const SizedBox(height: 16),

          // Navigation buttons
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _canProceedFromMapping()
                    ? () {
                        _validateData();
                        setState(() => _currentStep = 2);
                      }
                    : null,
                child: const Text('Next: Preview Data'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPreview(ThemeData theme) {
    final importMode = ref.watch(importModeProvider);
    final mappedData = importMode == ImportMode.students
        ? ref.watch(mappedStudentDataProvider)
        : ref.watch(mappedQuestionDataProvider);

    if (mappedData.isEmpty) {
      return const SizedBox.shrink();
    }

    final previewCount = mappedData.length > 3 ? 3 : mappedData.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preview (first $previewCount of ${mappedData.length} rows)',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...List.generate(previewCount, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  mappedData[i].entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== STEP 3: PREVIEW ====================

  Widget _buildPreviewStep(ThemeData theme) {
    final importMode = ref.watch(importModeProvider);
    final mappedData = importMode == ImportMode.students
        ? ref.watch(mappedStudentDataProvider)
        : ref.watch(mappedQuestionDataProvider);
    final validationErrors = ref.watch(validationErrorsProvider);

    return Column(
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surface,
          child: Row(
            children: [
              Icon(importMode == ImportMode.students ? Icons.people : Icons.quiz,
                  color: theme.colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${mappedData.length} ${importMode == ImportMode.students ? 'students' : 'questions'} ready to import',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (validationErrors.isNotEmpty)
                      Text(
                        '${validationErrors.length} validation warning(s)',
                        style: const TextStyle(color: Colors.orange),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Validation errors
        if (validationErrors.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Warnings:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 4),
                ...validationErrors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(e, style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ),
          ),

        // Data table
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: mappedData.length,
            itemBuilder: (context, index) {
              final row = mappedData[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(
                    row[importMode == ImportMode.students ? 'fullName' : 'questionText'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    row.entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
          ),
        ),

        // Navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: mappedData.isNotEmpty
                    ? () => setState(() => _currentStep = 3)
                    : null,
                child: Text('Import ${mappedData.length} ${importMode == ImportMode.students ? 'Students' : 'Questions'}'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STEP 4: IMPORT ====================

  Widget _buildImportStep(ThemeData theme) {
    final isImporting = ref.watch(isImportingProvider);
    final progress = ref.watch(importProgressProvider);
    final statusMessage = ref.watch(importStatusMessageProvider);
    final importMode = ref.watch(importModeProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isImporting) ...[
              CircularProgressIndicator(value: progress > 0 ? progress : null),
              const SizedBox(height: 24),
              Text(statusMessage, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 8),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ] else if (progress >= 1.0) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              Text(
                'Import Complete!',
                style: theme.textTheme.headlineSmall?.copyWith(color: Colors.green),
              ),
              const SizedBox(height: 16),
              Text(statusMessage, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ] else ...[
              const Icon(Icons.upload_file, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              Text('Ready to Import', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startImport,
                icon: const Icon(Icons.play_arrow),
                label: Text('Start Importing ${importMode == ImportMode.students ? 'Students' : 'Questions'}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

  Future<void> _pickFile() async {
    final bytes = await _service.pickExcelFile();
    if (bytes == null) return;

    ref.read(excelFileBytesProvider.notifier).state = bytes;

    // Parse the file
    final sheetData = await _service.parseExcel(bytes);
    ref.read(excelSheetDataProvider.notifier).state = sheetData;

    // Auto-select first sheet
    if (sheetData.keys.isNotEmpty) {
      final firstSheet = sheetData.keys.first;
      ref.read(selectedSheetProvider.notifier).state = firstSheet;
      _autoDetectMapping(firstSheet);
    }
  }

  void _autoDetectMapping(String sheetName) {
    final sheetData = ref.read(excelSheetDataProvider);
    final importMode = ref.read(importModeProvider);
    if (!sheetData.containsKey(sheetName)) return;

    final headers = _service.extractHeaders(sheetData[sheetName]!);

    final mapping = importMode == ImportMode.students
        ? _service.autoDetectStudentMapping(headers)
        : _service.autoDetectQuestionMapping(headers);

    if (importMode == ImportMode.students) {
      ref.read(studentColumnMappingProvider.notifier).state = mapping;
    } else {
      ref.read(questionColumnMappingProvider.notifier).state = mapping;
    }
  }

  bool _canProceedFromMapping() {
    final importMode = ref.read(importModeProvider);
    final mapping = importMode == ImportMode.students
        ? ref.read(studentColumnMappingProvider)
        : ref.read(questionColumnMappingProvider);

    // At minimum, fullName or questionText must be mapped
    if (importMode == ImportMode.students) {
      return mapping.containsKey('fullName');
    } else {
      return mapping.containsKey('questionText');
    }
  }

  void _validateData() {
    final importMode = ref.read(importModeProvider);
    final mappedData = importMode == ImportMode.students
        ? ref.read(mappedStudentDataProvider)
        : ref.read(mappedQuestionDataProvider);

    final errors = importMode == ImportMode.students
        ? _service.validateStudentData(mappedData)
        : _service.validateQuestionData(mappedData);

    ref.read(validationErrorsProvider.notifier).state = errors;
  }

  Future<void> _startImport() async {
    ref.read(isImportingProvider.notifier).state = true;
    ref.read(importProgressProvider.notifier).state = 0.0;

    final importMode = ref.read(importModeProvider);
    final teacherId = ref.read(userIdProvider) ?? '';

    try {
      if (importMode == ImportMode.students) {
        final classId = ref.read(importTargetClassIdProvider);
        final className = ref.read(importTargetClassNameProvider) ?? '';

        if (classId == null) {
          throw Exception('No class selected for student import');
        }

        final mappedData = ref.read(mappedStudentDataProvider);
        ref.read(importStatusMessageProvider.notifier).state = 'Importing students...';

        final count = await _service.importStudents(
          teacherId: teacherId,
          classId: classId,
          className: className,
          students: mappedData,
          hashPassword: AuthService.hashPassword,
        );

        ref.read(importProgressProvider.notifier).state = 1.0;
        ref.read(importStatusMessageProvider.notifier).state =
            'Successfully imported $count students!';
      } else {
        final target = ref.read(questionImportTargetProvider);
        final mappedData = ref.read(mappedQuestionDataProvider);
        ref.read(importStatusMessageProvider.notifier).state = 'Importing questions...';

        if (target == QuestionImportTarget.bank) {
          final subject = ref.read(importSubjectProvider);
          final count = await _service.importQuestionsToBank(
            teacherId: teacherId,
            questions: mappedData,
            subject: subject.isNotEmpty ? subject : 'General',
          );
          ref.read(importProgressProvider.notifier).state = 1.0;
          ref.read(importStatusMessageProvider.notifier).state =
              'Successfully imported $count questions to the bank!';
        } else {
          final examId = ref.read(importTargetExamIdProvider);
          if (examId == null) {
            throw Exception('No exam selected for question import');
          }

          final count = await _service.importQuestionsToExam(
            teacherId: teacherId,
            examId: examId,
            questions: mappedData,
          );
          ref.read(importProgressProvider.notifier).state = 1.0;
          ref.read(importStatusMessageProvider.notifier).state =
              'Successfully imported $count questions to the exam!';
        }
      }
    } catch (e) {
      ref.read(importStatusMessageProvider.notifier).state = 'Error: $e';
      ref.read(importProgressProvider.notifier).state = 0.0;
    } finally {
      ref.read(isImportingProvider.notifier).state = false;
    }
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'fullName':
        return 'Full Name *';
      case 'password':
        return 'Password';
      case 'grade':
        return 'Grade';
      case 'questionText':
        return 'Question *';
      case 'questionType':
        return 'Type';
      case 'optionA':
        return 'Option A';
      case 'optionB':
        return 'Option B';
      case 'optionC':
        return 'Option C';
      case 'optionD':
        return 'Option D';
      case 'correctAnswer':
        return 'Answer';
      case 'marks':
        return 'Marks';
      case 'difficulty':
        return 'Difficulty';
      case 'subject':
        return 'Subject';
      case 'tags':
        return 'Tags';
      default:
        return field;
    }
  }
}
