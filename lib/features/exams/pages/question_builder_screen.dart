import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/question_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/question_service.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_avatar.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

class QuestionBuilderScreen extends ConsumerStatefulWidget {
  final String examId;

  const QuestionBuilderScreen({
    Key? key,
    required this.examId,
  }) : super(key: key);

  @override
  ConsumerState<QuestionBuilderScreen> createState() =>
      _QuestionBuilderScreenState();
}

class _QuestionBuilderScreenState extends ConsumerState<QuestionBuilderScreen> {
  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsStreamProvider(widget.examId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Builder'),
        centerTitle: true,
      ),
      body: questionsAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading questions...'),
        error: (error, stack) => ErrorWidgetCustom(
          message: 'Failed to load questions: $error',
          onRetry: () =>
              ref.invalidate(questionsStreamProvider(widget.examId)),
        ),
        data: (snapshot) {
          final questions = snapshot.docs
              .map((doc) => QuestionData.fromFirestore(doc))
              .toList();

          return Column(
            children: [
              // ── Exam Info Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      '${questions.length} Question${questions.length != 1 ? 's' : ''}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: ${_calculateTotalMarks(questions)} marks',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Questions List ──
              Expanded(
                child: questions.isEmpty
                    ? EmptyState(
                        icon: Icons.help_outline,
                        title: 'No Questions Yet',
                        subtitle:
                            'Add questions to this exam using the buttons below',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          final question = questions[index];
                          return _QuestionCard(
                            question: question,
                            questionNumber: index + 1,
                            onEdit: () => _showEditQuestionDialog(
                              context,
                              question,
                            ),
                            onDelete: () async {
                              final confirmed = await KlasivoModal.confirm(
                                context: context,
                                title: 'Delete Question',
                                message:
                                    'Are you sure you want to delete question #${index + 1}?',
                                confirmLabel: 'Delete',
                                isDangerous: true,
                              );
                              if (confirmed == true) {
                                try {
                                  await ref
                                      .read(questionServiceProvider)
                                      .deleteQuestion(
                                        question.id,
                                        widget.examId,
                                      );
                                  if (context.mounted) {
                                    KlasivoToast.success(context,
                                        message: 'Question deleted');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    KlasivoToast.error(context,
                                        message: 'Failed: $e');
                                  }
                                }
                              }
                            },
                          );
                        },
                      ),
              ),

              // ── Add Question Buttons ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Question',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AddQuestionButton(
                            icon: Icons.list_alt_outlined,
                            label: 'Multiple\nChoice',
                            color: const Color(0xFF2196F3),
                            onTap: () => _showAddQuestionDialog(
                              context,
                              AppConstants.questionTypeMultipleChoice,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AddQuestionButton(
                            icon: Icons.toggle_on_outlined,
                            label: 'True /\nFalse',
                            color: const Color(0xFF4CAF50),
                            onTap: () => _showAddQuestionDialog(
                              context,
                              AppConstants.questionTypeTrueFalse,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AddQuestionButton(
                            icon: Icons.short_text,
                            label: 'Short\nAnswer',
                            color: const Color(0xFFFF9800),
                            onTap: () => _showAddQuestionDialog(
                              context,
                              AppConstants.questionTypeShortAnswer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ── Import buttons (Phase C) ──
                    Row(
                      children: [
                        Expanded(
                          child: _AddQuestionButton(
                            icon: Icons.library_books,
                            label: 'From\nBank',
                            color: const Color(0xFF9C27B0),
                            onTap: () => context.go('/teacher/question-bank'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AddQuestionButton(
                            icon: Icons.upload_file,
                            label: 'From\nExcel',
                            color: const Color(0xFF009688),
                            onTap: () => context.go('/teacher/excel-import'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _calculateTotalMarks(List<QuestionData> questions) {
    return questions.fold(0, (sum, q) => sum + q.marks);
  }

  static String _getTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'true_false':
        return 'True/False';
      case 'short_answer':
        return 'Short Answer';
      default:
        return 'Question';
    }
  }

  void _showAddQuestionDialog(BuildContext context, String questionType) {
    KlasivoModal.showForm(
      context: context,
      title: 'Add ${_getTypeLabel(questionType)}',
      child: _QuestionFormSheet(
        examId: widget.examId,
        questionType: questionType,
        questionService: ref.read(questionServiceProvider),
        questions: ref.read(questionsProvider(widget.examId)),
      ),
    );
  }

  void _showEditQuestionDialog(BuildContext context, QuestionData question) {
    KlasivoModal.showForm(
      context: context,
      title: 'Edit ${_getTypeLabel(question.questionType)}',
      child: _QuestionFormSheet(
        examId: widget.examId,
        questionType: question.questionType,
        questionService: ref.read(questionServiceProvider),
        questions: ref.read(questionsProvider(widget.examId)),
        existingQuestion: question,
      ),
    );
  }
}

// ─── Question Card ───────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final QuestionData question;
  final int questionNumber;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.question,
    required this.questionNumber,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KlasivoCard(
      variant: KlasivoCardVariant.elevated,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              KlasivoAvatar(
                name: '$questionNumber',
                size: KlasivoAvatarSize.sm,
                backgroundColor: question.typeColor.withValues(alpha: 0.1),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: question.typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  question.typeLabel,
                  style: TextStyle(
                    color: question.typeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${question.marks} mark${question.marks != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: Colors.red[400]),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Question Text ──
          Text(
            question.questionText,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),

          // ── Options (for MCQ) ──
          if (question.questionType ==
              AppConstants.questionTypeMultipleChoice) ...[
            const SizedBox(height: 8),
            ...question.options.map(
              (opt) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: opt == question.correctAnswer
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.transparent,
                        border: Border.all(
                          color: opt == question.correctAnswer
                              ? Colors.green
                              : Colors.grey[400]!,
                        ),
                      ),
                      child: opt == question.correctAnswer
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.green)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt,
                      style: TextStyle(
                        fontSize: 13,
                        color: opt == question.correctAnswer
                            ? Colors.green[700]
                            : Colors.grey[700],
                        fontWeight: opt == question.correctAnswer
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Answer (for T/F and Short Answer) ──
          if (question.questionType ==
                  AppConstants.questionTypeTrueFalse ||
              question.questionType ==
                  AppConstants.questionTypeShortAnswer) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    question.correctAnswer,
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Add Question Button ─────────────────────────────────────────────────────

class _AddQuestionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddQuestionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Question Form Bottom Sheet ──────────────────────────────────────────────

class _QuestionFormSheet extends ConsumerStatefulWidget {
  final String examId;
  final String questionType;
  final QuestionService questionService;
  final List<QuestionData> questions;
  final QuestionData? existingQuestion;

  const _QuestionFormSheet({
    required this.examId,
    required this.questionType,
    required this.questionService,
    required this.questions,
    this.existingQuestion,
  });

  @override
  ConsumerState<_QuestionFormSheet> createState() =>
      _QuestionFormSheetState();
}

class _QuestionFormSheetState extends ConsumerState<_QuestionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _correctAnswerController = TextEditingController();
  final _marksController = TextEditingController();
  bool _isLoading = false;
  String? _selectedCorrectOption; // For MCQ: 'A', 'B', 'C', 'D'
  bool? _tfCorrectAnswer; // For T/F: true/false

  @override
  void initState() {
    super.initState();
    if (widget.existingQuestion != null) {
      final q = widget.existingQuestion!;
      _questionController.text = q.questionText;
      _marksController.text = q.marks.toString();

      if (q.questionType == AppConstants.questionTypeMultipleChoice) {
        _optionAController.text = q.options.isNotEmpty ? q.options[0] : '';
        _optionBController.text = q.options.length > 1 ? q.options[1] : '';
        _optionCController.text = q.options.length > 2 ? q.options[2] : '';
        _optionDController.text = q.options.length > 3 ? q.options[3] : '';
        // Reverse-lookup: find which option matches the correctAnswer text
        if (q.correctAnswer == _optionAController.text) {
          _selectedCorrectOption = 'A';
        } else if (q.correctAnswer == _optionBController.text) {
          _selectedCorrectOption = 'B';
        } else if (q.correctAnswer == _optionCController.text) {
          _selectedCorrectOption = 'C';
        } else if (q.correctAnswer == _optionDController.text) {
          _selectedCorrectOption = 'D';
        }
      } else if (q.questionType == AppConstants.questionTypeTrueFalse) {
        _tfCorrectAnswer = q.correctAnswer == 'True';
      } else {
        _correctAnswerController.text = q.correctAnswer;
      }
    } else {
      _marksController.text = '1';
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _correctAnswerController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  String get _typeLabel {
    switch (widget.questionType) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'true_false':
        return 'True / False';
      case 'short_answer':
        return 'Short Answer';
      default:
        return 'Question';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Extra validation for MCQ
    if (widget.questionType ==
            AppConstants.questionTypeMultipleChoice &&
        _selectedCorrectOption == null) {
      KlasivoToast.error(context,
          message: 'Please select the correct answer');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nextOrder = widget.questions.length;

      if (widget.existingQuestion != null) {
        // ── Update existing question ──
        if (widget.questionType ==
            AppConstants.questionTypeMultipleChoice) {
          // Store the actual option text as correctAnswer, not the label
          final options = [
            _optionAController.text.trim(),
            _optionBController.text.trim(),
            _optionCController.text.trim(),
            _optionDController.text.trim(),
          ];
          final correctAnswerText = _selectedCorrectOption == 'A' ? options[0]
              : _selectedCorrectOption == 'B' ? options[1]
              : _selectedCorrectOption == 'C' ? options[2]
              : options[3];

          await widget.questionService.updateQuestion(
            questionId: widget.existingQuestion!.id,
            examId: widget.examId,
            questionText: _questionController.text.trim(),
            options: options,
            correctAnswer: correctAnswerText,
            marks: int.parse(_marksController.text.trim()),
          );
        } else if (widget.questionType ==
            AppConstants.questionTypeTrueFalse) {
          await widget.questionService.updateQuestion(
            questionId: widget.existingQuestion!.id,
            examId: widget.examId,
            questionText: _questionController.text.trim(),
            correctAnswer: _tfCorrectAnswer! ? 'True' : 'False',
            marks: int.parse(_marksController.text.trim()),
          );
        } else {
          await widget.questionService.updateQuestion(
            questionId: widget.existingQuestion!.id,
            examId: widget.examId,
            questionText: _questionController.text.trim(),
            correctAnswer:
                _correctAnswerController.text.trim(),
            marks: int.parse(_marksController.text.trim()),
          );
        }
        if (mounted) {
          KlasivoToast.success(context, message: 'Question updated');
          Navigator.of(context).pop();
        }
      } else {
        // ── Create new question ──
        if (widget.questionType ==
            AppConstants.questionTypeMultipleChoice) {
          // Store the actual option text as correctAnswer, not the label
          final options = [
            _optionAController.text.trim(),
            _optionBController.text.trim(),
            _optionCController.text.trim(),
            _optionDController.text.trim(),
          ];
          final correctAnswerText = _selectedCorrectOption == 'A' ? options[0]
              : _selectedCorrectOption == 'B' ? options[1]
              : _selectedCorrectOption == 'C' ? options[2]
              : options[3];

          await widget.questionService.addMultipleChoiceQuestion(
            examId: widget.examId,
            organizationId: ref.read(currentOrganizationIdProvider) ?? '',   // ← NEW
            questionText: _questionController.text.trim(),
            options: options,
            correctAnswer: correctAnswerText,
            marks: int.parse(_marksController.text.trim()),
            order: nextOrder,
          );
        } else if (widget.questionType ==
            AppConstants.questionTypeTrueFalse) {
          await widget.questionService.addTrueFalseQuestion(
            examId: widget.examId,
            organizationId: ref.read(currentOrganizationIdProvider) ?? '',   // ← NEW
            questionText: _questionController.text.trim(),
            correctAnswer: _tfCorrectAnswer!,
            marks: int.parse(_marksController.text.trim()),
            order: nextOrder,
          );
        } else {
          await widget.questionService.addShortAnswerQuestion(
            examId: widget.examId,
            organizationId: ref.read(currentOrganizationIdProvider) ?? '',   // ← NEW
            questionText: _questionController.text.trim(),
            correctAnswer:
                _correctAnswerController.text.trim(),
            marks: int.parse(_marksController.text.trim()),
            order: nextOrder,
          );
        }
        if (mounted) {
          KlasivoToast.success(context, message: 'Question added');
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context,
            message: 'Failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _questionController.clear();
    _optionAController.clear();
    _optionBController.clear();
    _optionCController.clear();
    _optionDController.clear();
    _correctAnswerController.clear();
    _marksController.text = '1';
    _selectedCorrectOption = null;
    _tfCorrectAnswer = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: bottomPadding + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Title ──
              Row(
                children: [
                  Text(
                    widget.existingQuestion != null
                        ? 'Edit $_typeLabel'
                        : 'Add $_typeLabel',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Question Text ──
              KlasivoTextField(
                label: 'Question *',
                hint: 'Enter your question here',
                prefixIcon: Icons.help_outline,
                controller: _questionController,
                maxLines: 3,
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Question is required' : null,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // ── MCQ Options ──
              if (widget.questionType ==
                  AppConstants.questionTypeMultipleChoice) ...[
                Text(
                  'Options',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _OptionField(
                  label: 'A',
                  controller: _optionAController,
                  isSelected: _selectedCorrectOption == 'A',
                  onSelect: () => setState(() => _selectedCorrectOption = 'A'),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                _OptionField(
                  label: 'B',
                  controller: _optionBController,
                  isSelected: _selectedCorrectOption == 'B',
                  onSelect: () => setState(() => _selectedCorrectOption = 'B'),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                _OptionField(
                  label: 'C',
                  controller: _optionCController,
                  isSelected: _selectedCorrectOption == 'C',
                  onSelect: () => setState(() => _selectedCorrectOption = 'C'),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                _OptionField(
                  label: 'D',
                  controller: _optionDController,
                  isSelected: _selectedCorrectOption == 'D',
                  onSelect: () => setState(() => _selectedCorrectOption = 'D'),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the circle to mark the correct answer',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],

              // ── True/False Toggle ──
              if (widget.questionType ==
                  AppConstants.questionTypeTrueFalse) ...[
                Text(
                  'Correct Answer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('True'),
                        selected: _tfCorrectAnswer == true,
                        onSelected: !_isLoading
                            ? (selected) =>
                                setState(() => _tfCorrectAnswer = true)
                            : null,
                        selectedColor: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('False'),
                        selected: _tfCorrectAnswer == false,
                        onSelected: !_isLoading
                            ? (selected) =>
                                setState(() => _tfCorrectAnswer = false)
                            : null,
                        selectedColor: Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // ── Short Answer ──
              if (widget.questionType ==
                  AppConstants.questionTypeShortAnswer) ...[
                KlasivoTextField(
                  label: 'Correct Answer *',
                  hint: 'Enter the expected answer',
                  prefixIcon: Icons.check_circle_outline,
                  controller: _correctAnswerController,
                  validator: (v) => v?.trim().isEmpty ?? true
                      ? 'Correct answer is required'
                      : null,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 8),
                Text(
                  'Grading is case-insensitive for short answers',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 16),
              ],

              // ── Marks ──
              KlasivoTextField(
                label: 'Marks *',
                hint: 'Points for this question',
                prefixIcon: Icons.stars_outlined,
                controller: _marksController,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  final val = int.tryParse(v!);
                  if (val == null || val < 1) return 'Min 1 mark';
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // ── Submit Button ──
              KlasivoButton(
                label: widget.existingQuestion != null
                    ? 'Update Question'
                    : 'Add Question',
                onPressed: _handleSubmit,
                loading: _isLoading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Option Field with correct answer selector ───────────────────────────────

class _OptionField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool isSelected;
  final VoidCallback onSelect;
  final bool enabled;

  const _OptionField({
    required this.label,
    required this.controller,
    required this.isSelected,
    required this.onSelect,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: enabled ? onSelect : null,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey[400]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 16, color: Colors.green)
                : Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KlasivoTextField(
            hint: 'Option $label',
            controller: controller,
            validator: (v) =>
                v?.trim().isEmpty ?? true ? 'Option $label is required' : null,
            enabled: enabled,
          ),
        ),
      ],
    );
  }
}
