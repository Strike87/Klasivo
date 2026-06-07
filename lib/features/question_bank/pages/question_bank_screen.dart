import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../providers/question_bank_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common_widgets.dart';

class QuestionBankScreen extends ConsumerWidget {
  const QuestionBankScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(filteredQuestionBankProvider);
    final subjects = ref.watch(bankSubjectsProvider);
    final selectedSubject = ref.watch(bankSubjectFilterProvider);
    final selectedDifficulty = ref.watch(bankDifficultyFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Question Bank'), centerTitle: true),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: selectedSubject == null,
                  onSelected: (_) => ref.read(bankSubjectFilterProvider.notifier).state = null,
                ),
                ...subjects.map((subject) => FilterChip(
                      label: Text(subject),
                      selected: selectedSubject == subject,
                      onSelected: (_) => ref.read(bankSubjectFilterProvider.notifier).state =
                          selectedSubject == subject ? null : subject,
                    )),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Easy'),
                  selected: selectedDifficulty == AppConstants.difficultyEasy,
                  onSelected: (_) => ref.read(bankDifficultyFilterProvider.notifier).state =
                      selectedDifficulty == AppConstants.difficultyEasy ? null : AppConstants.difficultyEasy,
                ),
                FilterChip(
                  label: const Text('Medium'),
                  selected: selectedDifficulty == AppConstants.difficultyMedium,
                  onSelected: (_) => ref.read(bankDifficultyFilterProvider.notifier).state =
                      selectedDifficulty == AppConstants.difficultyMedium ? null : AppConstants.difficultyMedium,
                ),
                FilterChip(
                  label: const Text('Hard'),
                  selected: selectedDifficulty == AppConstants.difficultyHard,
                  onSelected: (_) => ref.read(bankDifficultyFilterProvider.notifier).state =
                      selectedDifficulty == AppConstants.difficultyHard ? null : AppConstants.difficultyHard,
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: questions.isEmpty
                ? const EmptyState(
                    icon: Icons.library_books_outlined,
                    title: 'No Questions',
                    subtitle: 'Add questions to your question bank for reuse across exams',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return _QuestionBankCard(question: q);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddQuestionDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Question'),
      ),
    );
  }

  void _showAddQuestionDialog(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    final subjectController = TextEditingController();
    final correctAnswerController = TextEditingController();
    final marksController = TextEditingController(text: '1');
    String type = AppConstants.questionTypeMultipleChoice;
    String difficulty = AppConstants.difficultyMedium;
    List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Question to Bank'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'Subject *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: AppConstants.questionTypeMultipleChoice, child: const Text('Multiple Choice')),
                      DropdownMenuItem(value: AppConstants.questionTypeTrueFalse, child: const Text('True / False')),
                      DropdownMenuItem(value: AppConstants.questionTypeShortAnswer, child: const Text('Short Answer')),
                    ],
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: AppConstants.difficultyEasy, child: const Text('Easy')),
                      DropdownMenuItem(value: AppConstants.difficultyMedium, child: const Text('Medium')),
                      DropdownMenuItem(value: AppConstants.difficultyHard, child: const Text('Hard')),
                    ],
                    onChanged: (v) => setState(() => difficulty = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: textController, decoration: const InputDecoration(labelText: 'Question Text *', border: OutlineInputBorder()), maxLines: 3),
                  const SizedBox(height: 12),
                  if (type == AppConstants.questionTypeMultipleChoice) ...[
                    for (int i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: optionControllers[i],
                          decoration: InputDecoration(labelText: 'Option ${String.fromCharCode(65 + i)}', border: const OutlineInputBorder()),
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: correctAnswerController, decoration: const InputDecoration(labelText: 'Correct Answer *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: marksController, decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (textController.text.trim().isEmpty || subjectController.text.trim().isEmpty) return;
                try {
                  final teacherId = ref.read(userIdProvider) ?? '';
                  await ref.read(questionBankServiceProvider).addQuestionToBank(
                        teacherId: teacherId,
                        subject: subjectController.text.trim(),
                        type: type,
                        difficulty: difficulty,
                        text: textController.text.trim(),
                        options: type == AppConstants.questionTypeMultipleChoice
                            ? optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
                            : type == AppConstants.questionTypeTrueFalse
                                ? ['True', 'False']
                                : [],
                        correctAnswer: correctAnswerController.text.trim(),
                        marks: int.tryParse(marksController.text) ?? 1,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) showSnackBar(context, message: 'Question added to bank');
                } catch (e) {
                  if (context.mounted) showSnackBar(context, message: 'Failed: $e', isError: true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBankCard extends ConsumerWidget {
  final QuestionBankData question;
  const _QuestionBankCard({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(question.typeIcon, size: 18, color: question.difficultyColor),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: question.difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(question.difficulty.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: question.difficultyColor)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(question.subject,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue)),
                ),
                const Spacer(),
                Text('${question.usageCount}x used', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () async {
                    final confirmed = await showConfirmationDialog(
                      context: context,
                      title: 'Delete Question',
                      message: 'Remove this question from the bank?',
                      isDangerous: true,
                    );
                    if (confirmed == true) {
                      try {
                        await ref.read(questionBankServiceProvider).deleteQuestionFromBank(question.id);
                        if (context.mounted) showSnackBar(context, message: 'Question deleted');
                      } catch (e) {
                        if (context.mounted) showSnackBar(context, message: 'Failed: $e', isError: true);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(question.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (question.marks != 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${question.marks} marks', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
          ],
        ),
      ),
    );
  }
}
