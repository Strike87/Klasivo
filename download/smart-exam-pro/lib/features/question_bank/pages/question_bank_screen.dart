import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/question_bank_provider.dart';
import '../../providers/auth_provider.dart';

/// Question Bank Screen - Browse, search, filter, and manage reusable questions
class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  final _searchController = TextEditingController();
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    // Set teacher ID for bank queries
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacherId = ref.read(userIdProvider);
      ref.read(teacherIdForBankProvider.notifier).state = teacherId;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = ref.watch(questionBankListProvider);
    final selectedQuestions = ref.watch(selectedBankQuestionsProvider);
    final subjectFilter = ref.watch(bankSubjectFilterProvider);
    final difficultyFilter = ref.watch(bankDifficultyFilterProvider);
    final typeFilter = ref.watch(bankTypeFilterProvider);
    final subjectsAsync = ref.watch(bankSubjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${selectedQuestions.length} selected')
            : const Text('Question Bank'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isSelectionMode && selectedQuestions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_to_photos),
              tooltip: 'Import selected to exam',
              onPressed: () => _importSelectedToExam(),
            ),
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
            tooltip: _isSelectionMode ? 'Cancel selection' : 'Select questions',
            onPressed: () {
              setState(() => _isSelectionMode = !_isSelectionMode);
              if (!_isSelectionMode) {
                ref.read(selectedBankQuestionsProvider.notifier).state = {};
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          _buildSearchAndFilters(theme, subjectsAsync),
          // Stats bar
          _buildStatsBar(theme, questions),
          // Questions list
          Expanded(
            child: questions.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      final isSelected = selectedQuestions.contains(q.id);
                      return _buildQuestionCard(theme, q, isSelected);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addQuestion',
        onPressed: () => _showAddQuestionDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme, AsyncValue<List<String>> subjectsAsync) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search questions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(bankSearchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (value) {
              ref.read(bankSearchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Subject filter
                subjectsAsync.when(
                  data: (subjects) {
                    if (subjects.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DropdownButton<String>(
                        value: ref.read(bankSubjectFilterProvider),
                        hint: const Text('Subject'),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Subjects')),
                          ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) => ref.read(bankSubjectFilterProvider.notifier).state = v,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                // Difficulty filter
                FilterChip(
                  label: const Text('Easy'),
                  selected: difficultyFilter == 'easy',
                  onSelected: (s) => ref.read(bankDifficultyFilterProvider.notifier).state =
                      s ? 'easy' : null,
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Medium'),
                  selected: difficultyFilter == 'medium',
                  onSelected: (s) => ref.read(bankDifficultyFilterProvider.notifier).state =
                      s ? 'medium' : null,
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Hard'),
                  selected: difficultyFilter == 'hard',
                  onSelected: (s) => ref.read(bankDifficultyFilterProvider.notifier).state =
                      s ? 'hard' : null,
                ),
                const SizedBox(width: 8),
                // Type filter
                FilterChip(
                  label: const Text('MCQ'),
                  selected: typeFilter == 'mcq',
                  onSelected: (s) => ref.read(bankTypeFilterProvider.notifier).state =
                      s ? 'mcq' : null,
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('T/F'),
                  selected: typeFilter == 'true_false',
                  onSelected: (s) => ref.read(bankTypeFilterProvider.notifier).state =
                      s ? 'true_false' : null,
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Short'),
                  selected: typeFilter == 'short_answer',
                  onSelected: (s) => ref.read(bankTypeFilterProvider.notifier).state =
                      s ? 'short_answer' : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(ThemeData theme, List<QuestionBankData> questions) {
    final mcqCount = questions.where((q) => q.type == 'mcq').length;
    final tfCount = questions.where((q) => q.type == 'true_false').length;
    final shortCount = questions.where((q) => q.type == 'short_answer').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Total', questions.length, theme.colorScheme.primary),
          _buildStatChip('MCQ', mcqCount, Colors.blue),
          _buildStatChip('T/F', tfCount, Colors.orange),
          _buildStatChip('Short', shortCount, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuestionCard(ThemeData theme, QuestionBankData q, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(q.id);
          } else {
            _showQuestionDetail(context, q);
          }
        },
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() => _isSelectionMode = true);
          }
          _toggleSelection(q.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleSelection(q.id),
                      ),
                    ),
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getTypeColor(q.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      q.typeLabel,
                      style: TextStyle(fontSize: 10, color: _getTypeColor(q.type), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Difficulty badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(q.difficultyColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      q.difficultyLabel,
                      style: TextStyle(fontSize: 10, color: Color(q.difficultyColor), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  // Usage count
                  Icon(Icons.repeat, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text('${q.usageCount}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(width: 8),
                  // Marks
                  Text('${q.marks}pt', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                q.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              if (q.options.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: q.options.asMap().entries.map((entry) {
                    final letter = String.fromCharCode(65 + entry.key); // A, B, C, D
                    final isCorrect = entry.value == q.correctAnswer;
                    return Chip(
                      label: Text('$letter. ${entry.value}', style: TextStyle(fontSize: 11)),
                      backgroundColor: isCorrect ? Colors.green.withOpacity(0.1) : null,
                      side: isCorrect ? const BorderSide(color: Colors.green) : null,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ],
              if (q.tags.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: q.tags.map((tag) => Chip(
                    label: Text('#$tag', style: const TextStyle(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.subject, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(q.subject, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No questions in your bank yet', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Add questions manually or import from Excel', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/teacher/excel-import'),
            icon: const Icon(Icons.upload_file),
            label: const Text('Import from Excel'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String questionId) {
    final selected = Set<String>.from(ref.read(selectedBankQuestionsProvider));
    if (selected.contains(questionId)) {
      selected.remove(questionId);
    } else {
      selected.add(questionId);
    }
    ref.read(selectedBankQuestionsProvider.notifier).state = selected;
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'mcq':
        return Colors.blue;
      case 'true_false':
        return Colors.orange;
      case 'short_answer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showQuestionDetail(BuildContext context, QuestionBankData q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Question Details', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteQuestion(q.id)),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Type', q.typeLabel),
              _buildDetailRow('Difficulty', q.difficultyLabel),
              _buildDetailRow('Subject', q.subject),
              _buildDetailRow('Marks', '${q.marks}'),
              _buildDetailRow('Used', '${q.usageCount} times'),
              const Divider(height: 24),
              Text('Question:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(q.text, style: const TextStyle(fontSize: 16)),
              if (q.options.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Options:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                ...q.options.asMap().entries.map((entry) {
                  final letter = String.fromCharCode(65 + entry.key);
                  final isCorrect = entry.value == q.correctAnswer;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: isCorrect ? Colors.green : Colors.grey[200],
                      child: Text(letter, style: TextStyle(color: isCorrect ? Colors.white : Colors.black, fontSize: 12)),
                    ),
                    title: Text(entry.value),
                    trailing: isCorrect ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
              ],
              const SizedBox(height: 8),
              Text('Correct Answer: ${q.correctAnswer}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              if (q.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Tags:', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: q.tags.map((t) => Chip(label: Text('#$t'))).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _deleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question from the bank?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(questionBankServiceProvider).deleteQuestion(questionId);
      if (mounted) Navigator.pop(context); // Close bottom sheet
    }
  }

  Future<void> _importSelectedToExam() async {
    final selected = ref.read(selectedBankQuestionsProvider);
    if (selected.isEmpty) return;

    // Show exam picker dialog
    final examId = await showDialog<String>(
      context: context,
      builder: (ctx) => _ExamPickerDialog(teacherId: ref.read(userIdProvider) ?? ''),
    );

    if (examId == null || !mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ref.read(questionBankServiceProvider).importMultipleToExam(
            bankQuestionIds: selected.toList(),
            examId: examId,
          );

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${selected.length} questions to exam!')),
        );
        ref.read(selectedBankQuestionsProvider.notifier).state = {};
        setState(() => _isSelectionMode = false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddQuestionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddQuestionToBankForm(),
    );
  }
}

/// Dialog for picking an exam to import bank questions into
class _ExamPickerDialog extends ConsumerWidget {
  final String teacherId;
  const _ExamPickerDialog({required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Select Exam'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('exams')
              .where('teacherId', isEqualTo: teacherId)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No exams found'));
            }
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(data['title'] ?? 'Untitled'),
                  subtitle: Text(data['status'] ?? 'draft'),
                  onTap: () => Navigator.pop(context, doc.id),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

/// Form for adding a question to the bank manually
class _AddQuestionToBankForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddQuestionToBankForm> createState() => _AddQuestionToBankFormState();
}

class _AddQuestionToBankFormState extends ConsumerState<_AddQuestionToBankForm> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  final _marksController = TextEditingController(text: '1');
  final _tagsController = TextEditingController();

  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  String _type = 'mcq';
  String _difficulty = 'medium';
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    _subjectController.dispose();
    _correctAnswerController.dispose();
    _marksController.dispose();
    _tagsController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Add Question to Bank', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              // Type selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'mcq', label: Text('MCQ')),
                  ButtonSegment(value: 'true_false', label: Text('T/F')),
                  ButtonSegment(value: 'short_answer', label: Text('Short')),
                ],
                selected: {_type},
                onSelectionChanged: (types) => setState(() => _type = types.first),
              ),
              const SizedBox(height: 12),

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),

              // Question text
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(labelText: 'Question Text *', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Options (MCQ only)
              if (_type == 'mcq') ...[
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: _optionControllers[i],
                      decoration: InputDecoration(
                        labelText: 'Option ${String.fromCharCode(65 + i)}${i < 2 ? ' *' : ''}',
                        border: const OutlineInputBorder(),
                      ),
                      validator: i < 2 ? (v) => v?.trim().isEmpty == true ? 'Required' : null : null,
                    ),
                  ),
              ],

              // Correct answer
              if (_type == 'true_false')
                DropdownButtonFormField<String>(
                  value: _correctAnswerController.text.isEmpty ? 'True' : _correctAnswerController.text,
                  decoration: const InputDecoration(labelText: 'Correct Answer', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'True', child: Text('True')),
                    DropdownMenuItem(value: 'False', child: Text('False')),
                  ],
                  onChanged: (v) => _correctAnswerController.text = v ?? 'True',
                )
              else
                TextFormField(
                  controller: _correctAnswerController,
                  decoration: const InputDecoration(labelText: 'Correct Answer *', border: OutlineInputBorder()),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
              const SizedBox(height: 12),

              // Marks and Difficulty row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marksController,
                      decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('Easy')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'hard', child: Text('Hard')),
                      ],
                      onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tags
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., algebra, chapter5',
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add to Bank'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final teacherId = ref.read(userIdProvider) ?? '';
      final options = _type == 'mcq'
          ? _optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
          : _type == 'true_false'
              ? ['True', 'False']
              : <String>[];

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await ref.read(questionBankServiceProvider).addQuestion(
            teacherId: teacherId,
            subject: _subjectController.text.trim().isEmpty ? 'General' : _subjectController.text.trim(),
            type: _type,
            difficulty: _difficulty,
            text: _questionController.text.trim(),
            options: options,
            correctAnswer: _correctAnswerController.text.trim(),
            tags: tags,
            marks: int.tryParse(_marksController.text.trim()) ?? 1,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question added to bank!')),
        );
      }
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
}
