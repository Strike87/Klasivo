import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/config/theme.dart';
import '../../../providers/question_bank_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/klasivo_components.dart';
import '../../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// QUESTION BANK SCREEN v1.7 — Klasivo Design Token System
// ═══════════════════════════════════════════════════════════════════════════════

class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Statistics helpers ──────────────────────────────────────────────────────

  String _mostUsedDifficulty(List<QuestionBankData> questions) {
    if (questions.isEmpty) return '—';
    final counts = <String, int>{};
    for (final q in questions) {
      counts[q.difficulty] = (counts[q.difficulty] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final raw = sorted.first.key;
    switch (raw) {
      case AppConstants.difficultyEasy:
        return 'Easy';
      case AppConstants.difficultyMedium:
        return 'Medium';
      case AppConstants.difficultyHard:
        return 'Hard';
      default:
        return raw;
    }
  }

  Color _difficultyStatColor(List<QuestionBankData> questions) {
    if (questions.isEmpty) return KlasivoColors.accent;
    final counts = <String, int>{};
    for (final q in questions) {
      counts[q.difficulty] = (counts[q.difficulty] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first.key;
    switch (top) {
      case AppConstants.difficultyEasy:
        return const Color(0xFF4CAF50);
      case AppConstants.difficultyMedium:
        return const Color(0xFFFF9800);
      case AppConstants.difficultyHard:
        return const Color(0xFFF44336);
      default:
        return KlasivoColors.accent;
    }
  }

  List<QuestionBankData> _applySearch(List<QuestionBankData> questions) {
    if (_searchQuery.isEmpty) return questions;
    final q = _searchQuery.toLowerCase();
    return questions
        .where((item) =>
            item.text.toLowerCase().contains(q) ||
            item.subject.toLowerCase().contains(q) ||
            item.typeLabel.toLowerCase().contains(q) ||
            item.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allQuestions = ref.watch(questionBankProvider);
    final filteredQuestions = ref.watch(filteredQuestionBankProvider);
    final subjects = ref.watch(bankSubjectsProvider);
    final selectedSubject = ref.watch(bankSubjectFilterProvider);
    final selectedDifficulty = ref.watch(bankDifficultyFilterProvider);
    final selectedType = ref.watch(bankTypeFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayedQuestions = _applySearch(filteredQuestions);

    return Scaffold(
      appBar: _buildAppBar(isDark),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Statistics Row ──────────────────────────────────────────────
          _buildStatisticsRow(allQuestions, isDark),

          // ─── Filter Chips ────────────────────────────────────────────────
          _buildFilterChips(subjects, selectedSubject, selectedDifficulty,
              selectedType, isDark),

          // ─── Question List ───────────────────────────────────────────────
          Expanded(
            child: displayedQuestions.isEmpty
                ? KlasivoEmptyState(
                    icon: Icons.library_books_outlined,
                    title: _searchQuery.isNotEmpty
                        ? 'No Matches'
                        : 'No Questions',
                    subtitle: _searchQuery.isNotEmpty
                        ? 'Try a different search term'
                        : 'Add questions to your question bank for reuse across exams',
                    actionLabel: _searchQuery.isEmpty ? 'Add Question' : null,
                    onAction:
                        _searchQuery.isEmpty ? _showAddQuestionDialog : null,
                    iconColor: KlasivoColors.primary,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KlasivoSpacing.lg,
                      vertical: KlasivoSpacing.sm,
                    ),
                    itemCount: displayedQuestions.length,
                    itemBuilder: (context, index) {
                      return _QuestionBankCard(
                        question: displayedQuestions[index],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddQuestionDialog,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add Question',
          style: KlasivoTypography.labelLarge.copyWith(color: Colors.white),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.lg),
        ),
      ),
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: KlasivoTypography.bodyLarge.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search questions, subjects, tags…',
                hintStyle: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            )
          : Text(
              'Question Bank',
              style: KlasivoTypography.headlineSmall.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
            ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
          ),
          tooltip: _isSearching ? 'Close search' : 'Search questions',
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
      ],
    );
  }

  // ─── Statistics Row ─────────────────────────────────────────────────────────

  Widget _buildStatisticsRow(List<QuestionBankData> allQuestions, bool isDark) {
    final totalQuestions = allQuestions.length;
    final totalSubjects = ref.watch(bankSubjectsProvider).length;
    final mostUsed = _mostUsedDifficulty(allQuestions);
    final diffColor = _difficultyStatColor(allQuestions);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KlasivoSpacing.lg,
        KlasivoSpacing.md,
        KlasivoSpacing.lg,
        KlasivoSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: KlasivoAnalyticsCard(
              value: '$totalQuestions',
              label: 'Questions',
              icon: Icons.quiz_outlined,
              color: KlasivoColors.primary,
            ),
          ),
          const SizedBox(width: KlasivoSpacing.sm),
          Expanded(
            child: KlasivoAnalyticsCard(
              value: '$totalSubjects',
              label: 'Subjects',
              icon: Icons.category_outlined,
              color: KlasivoColors.secondary,
            ),
          ),
          const SizedBox(width: KlasivoSpacing.sm),
          Expanded(
            child: KlasivoAnalyticsCard(
              value: mostUsed,
              label: 'Top Difficulty',
              icon: Icons.signal_cellular_alt_rounded,
              color: diffColor,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ───────────────────────────────────────────────────────────

  Widget _buildFilterChips(
    List<String> subjects,
    String? selectedSubject,
    String? selectedDifficulty,
    String? selectedType,
    bool isDark,
  ) {
    final chipBorderSide = BorderSide(
      color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Subject chips ───────────────────────────────────────────────
            FilterChip(
              label: Text(
                'All Subjects',
                style: KlasivoTypography.labelMedium.copyWith(
                  color: selectedSubject == null
                      ? Colors.white
                      : isDark
                          ? KlasivoColors.darkTextSecondary
                          : KlasivoColors.lightTextSecondary,
                ),
              ),
              selected: selectedSubject == null,
              selectedColor: KlasivoColors.primary,
              backgroundColor: isDark
                  ? KlasivoColors.darkSurface
                  : KlasivoColors.lightSurface,
              side: chipBorderSide,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KlasivoRadius.pill),
              ),
              onSelected: (_) =>
                  ref.read(bankSubjectFilterProvider.notifier).state = null,
            ),
            ...subjects.map(
              (subject) => Padding(
                padding: const EdgeInsets.only(left: KlasivoSpacing.xs),
                child: FilterChip(
                  label: Text(
                    subject,
                    style: KlasivoTypography.labelMedium.copyWith(
                      color: selectedSubject == subject
                          ? Colors.white
                          : isDark
                              ? KlasivoColors.darkTextSecondary
                              : KlasivoColors.lightTextSecondary,
                    ),
                  ),
                  selected: selectedSubject == subject,
                  selectedColor: KlasivoColors.primary,
                  backgroundColor: isDark
                      ? KlasivoColors.darkSurface
                      : KlasivoColors.lightSurface,
                  side: chipBorderSide,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  onSelected: (_) => ref
                          .read(bankSubjectFilterProvider.notifier)
                          .state =
                      selectedSubject == subject ? null : subject,
                ),
              ),
            ),

            const SizedBox(width: KlasivoSpacing.sm),

            // ── Difficulty chips ────────────────────────────────────────────
            _buildDifficultyChip(
              label: 'Easy',
              value: AppConstants.difficultyEasy,
              selectedValue: selectedDifficulty,
              color: const Color(0xFF4CAF50),
              isDark: isDark,
              chipBorderSide: chipBorderSide,
            ),
            _buildDifficultyChip(
              label: 'Medium',
              value: AppConstants.difficultyMedium,
              selectedValue: selectedDifficulty,
              color: const Color(0xFFFF9800),
              isDark: isDark,
              chipBorderSide: chipBorderSide,
            ),
            _buildDifficultyChip(
              label: 'Hard',
              value: AppConstants.difficultyHard,
              selectedValue: selectedDifficulty,
              color: const Color(0xFFF44336),
              isDark: isDark,
              chipBorderSide: chipBorderSide,
            ),

            const SizedBox(width: KlasivoSpacing.sm),

            // ── Type chips ─────────────────────────────────────────────────
            _buildTypeChip(
              label: 'MCQ',
              value: AppConstants.questionTypeMultipleChoice,
              selectedValue: selectedType,
              isDark: isDark,
              chipBorderSide: chipBorderSide,
            ),
            _buildTypeChip(
              label: 'T/F',
              value: AppConstants.questionTypeTrueFalse,
              selectedValue: selectedType,
              isDark: isDark,
              chipBorderSide: chipBorderSide,
            ),
            _buildTypeChip(
              label: 'Short',
              value: AppConstants.questionTypeShortAnswer,
              selectedValue: selectedType,
              isDark: isDark,
              chipBorderSide: chipBorderSide,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip({
    required String label,
    required String value,
    required String? selectedValue,
    required Color color,
    required bool isDark,
    required BorderSide chipBorderSide,
  }) {
    final isSelected = selectedValue == value;
    return Padding(
      padding: const EdgeInsets.only(left: KlasivoSpacing.xs),
      child: FilterChip(
        label: Text(
          label,
          style: KlasivoTypography.labelMedium.copyWith(
            color: isSelected ? Colors.white : color,
          ),
        ),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: isDark
            ? KlasivoColors.darkSurface
            : KlasivoColors.lightSurface,
        side: isSelected
            ? BorderSide.none
            : chipBorderSide,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.pill),
        ),
        onSelected: (_) => ref.read(bankDifficultyFilterProvider.notifier).state =
            isSelected ? null : value,
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required String value,
    required String? selectedValue,
    required bool isDark,
    required BorderSide chipBorderSide,
  }) {
    final isSelected = selectedValue == value;
    return Padding(
      padding: const EdgeInsets.only(left: KlasivoSpacing.xs),
      child: FilterChip(
        label: Text(
          label,
          style: KlasivoTypography.labelMedium.copyWith(
            color: isSelected
                ? Colors.white
                : isDark
                    ? KlasivoColors.darkTextSecondary
                    : KlasivoColors.lightTextSecondary,
          ),
        ),
        selected: isSelected,
        selectedColor: KlasivoColors.primaryDark,
        backgroundColor: isDark
            ? KlasivoColors.darkSurface
            : KlasivoColors.lightSurface,
        side: isSelected ? BorderSide.none : chipBorderSide,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.pill),
        ),
        onSelected: (_) =>
            ref.read(bankTypeFilterProvider.notifier).state =
                isSelected ? null : value,
      ),
    );
  }

  // ─── Add Question Dialog ────────────────────────────────────────────────────

  void _showAddQuestionDialog() {
    final textController = TextEditingController();
    final subjectController = TextEditingController();
    final correctAnswerController = TextEditingController();
    final marksController = TextEditingController(text: '1');
    final tagsController = TextEditingController();
    String type = AppConstants.questionTypeMultipleChoice;
    String difficulty = AppConstants.difficultyMedium;
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final inputBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(KlasivoRadius.md),
            borderSide: BorderSide(
              color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
            ),
          );
          final focusedBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(KlasivoRadius.md),
            borderSide: const BorderSide(
              color: KlasivoColors.primary,
              width: 1.5,
            ),
          );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KlasivoRadius.lg),
            ),
            titlePadding: const EdgeInsets.fromLTRB(
              KlasivoSpacing.xxl,
              KlasivoSpacing.xxl,
              KlasivoSpacing.xxl,
              KlasivoSpacing.sm,
            ),
            contentPadding: const EdgeInsets.fromLTRB(
              KlasivoSpacing.xxl,
              KlasivoSpacing.sm,
              KlasivoSpacing.xxl,
              KlasivoSpacing.lg,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(
              KlasivoSpacing.lg,
              KlasivoSpacing.sm,
              KlasivoSpacing.xxl,
              KlasivoSpacing.xxl,
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.sm),
                  decoration: BoxDecoration(
                    color: KlasivoColors.primarySurface,
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: KlasivoColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.md),
                Text(
                  'Add Question to Bank',
                  style: KlasivoTypography.titleLarge.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(ctx).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Subject ─────────────────────────────────────────────
                    TextField(
                      controller: subjectController,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Subject *',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                      ),
                    ),
                    const SizedBox(height: KlasivoSpacing.md),

                    // ── Type Dropdown ───────────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: type,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Type',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: AppConstants.questionTypeMultipleChoice,
                          child: Text('Multiple Choice'),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.questionTypeTrueFalse,
                          child: Text('True / False'),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.questionTypeShortAnswer,
                          child: Text('Short Answer'),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => type = v!),
                    ),
                    const SizedBox(height: KlasivoSpacing.md),

                    // ── Difficulty Dropdown ─────────────────────────────────
                    DropdownButtonFormField<String>(
                      value: difficulty,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Difficulty',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: AppConstants.difficultyEasy,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: KlasivoSpacing.sm),
                              const Text('Easy'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.difficultyMedium,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF9800),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: KlasivoSpacing.sm),
                              const Text('Medium'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: AppConstants.difficultyHard,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF44336),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: KlasivoSpacing.sm),
                              const Text('Hard'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => difficulty = v!),
                    ),
                    const SizedBox(height: KlasivoSpacing.md),

                    // ── Question Text ──────────────────────────────────────
                    TextField(
                      controller: textController,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Question Text *',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: KlasivoSpacing.md),

                    // ── Options (MCQ only) ──────────────────────────────────
                    if (type == AppConstants.questionTypeMultipleChoice) ...[
                      KlasivoSectionHeader(
                        title: 'Options',
                        actionLabel: null,
                      ),
                      const SizedBox(height: KlasivoSpacing.sm),
                      for (int i = 0; i < 4; i++)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: KlasivoSpacing.sm),
                          child: TextField(
                            controller: optionControllers[i],
                            style:
                                KlasivoTypography.bodyMedium.copyWith(
                              color: isDark
                                  ? KlasivoColors.darkTextPrimary
                                  : KlasivoColors.lightTextPrimary,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Option ${String.fromCharCode(65 + i)}',
                              labelStyle:
                                  KlasivoTypography.bodySmall.copyWith(
                                color: isDark
                                    ? KlasivoColors.darkTextTertiary
                                    : KlasivoColors
                                        .lightTextTertiary,
                              ),
                              border: inputBorder,
                              enabledBorder: inputBorder,
                              focusedBorder: focusedBorder,
                            ),
                          ),
                        ),
                      const SizedBox(height: KlasivoSpacing.md),
                    ],

                    // ── Correct Answer ──────────────────────────────────────
                    TextField(
                      controller: correctAnswerController,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Correct Answer *',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                      ),
                    ),
                    const SizedBox(height: KlasivoSpacing.md),

                    // ── Marks ───────────────────────────────────────────────
                    TextField(
                      controller: marksController,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Marks',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: KlasivoSpacing.md),

                    // ── Tags ────────────────────────────────────────────────
                    TextField(
                      controller: tagsController,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tags (comma-separated)',
                        labelStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                        hintText: 'e.g. algebra, chapter5, midterm',
                        hintStyle: KlasivoTypography.bodySmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextDisabled
                              : KlasivoColors.lightTextDisabled,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: focusedBorder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.lg,
                    vertical: KlasivoSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.md),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: KlasivoTypography.labelLarge.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              ),
              const SizedBox(width: KlasivoSpacing.sm),
              ElevatedButton(
                onPressed: () async {
                  if (textController.text.trim().isEmpty ||
                      subjectController.text.trim().isEmpty) {
                    showSnackBar(context,
                        message:
                            'Subject and question text are required',
                        isError: true);
                    return;
                  }
                  try {
                    final teacherId =
                        ref.read(userIdProvider) ?? '';
                    final tags = tagsController.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    await ref
                        .read(questionBankServiceProvider)
                        .addQuestionToBank(
                          teacherId: teacherId,
                          subject: subjectController.text.trim(),
                          type: type,
                          difficulty: difficulty,
                          text: textController.text.trim(),
                          options: type ==
                                  AppConstants
                                      .questionTypeMultipleChoice
                              ? optionControllers
                                  .map((c) => c.text.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList()
                              : type ==
                                      AppConstants
                                          .questionTypeTrueFalse
                                  ? ['True', 'False']
                                  : [],
                          correctAnswer:
                              correctAnswerController.text.trim(),
                          marks:
                              int.tryParse(marksController.text) ??
                                  1,
                          tags: tags,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      showSnackBar(context,
                          message: 'Question added to bank');
                    }
                  } catch (e) {
                    if (mounted) {
                      showSnackBar(context,
                          message: 'Failed: $e', isError: true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: KlasivoColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.xxl,
                    vertical: KlasivoSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.md),
                  ),
                ),
                child: Text(
                  'Create',
                  style: KlasivoTypography.labelLarge
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUESTION BANK CARD — Styled with Klasivo Design Tokens
// ═══════════════════════════════════════════════════════════════════════════════

class _QuestionBankCard extends ConsumerWidget {
  final QuestionBankData question;

  const _QuestionBankCard({required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        side: BorderSide(
          color: isDark ? KlasivoColors.darkBorder : KlasivoColors.lightBorder,
          width: 1,
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: icon + badges + usage + delete ─────────────────────
            Row(
              children: [
                // Leading icon container with difficulty color
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.sm),
                  decoration: BoxDecoration(
                    color: question.difficultyColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                  ),
                  child: Icon(
                    question.typeIcon,
                    size: 18,
                    color: question.difficultyColor,
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.sm),

                // Difficulty badge (pill)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.sm,
                    vertical: KlasivoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: question.difficultyColor.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  child: Text(
                    question.difficulty.toUpperCase(),
                    style: KlasivoTypography.labelSmall.copyWith(
                      color: question.difficultyColor,
                    ),
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.xs),

                // Subject badge (pill)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.sm,
                    vertical: KlasivoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: KlasivoColors.primary.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  child: Text(
                    question.subject,
                    style: KlasivoTypography.labelSmall.copyWith(
                      color: KlasivoColors.primary,
                    ),
                  ),
                ),

                const Spacer(),

                // Usage count
                Text(
                  '${question.usageCount}× used',
                  style: KlasivoTypography.caption.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: KlasivoSpacing.md),

            // ── Question text ──────────────────────────────────────────────
            Text(
              question.text,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Marks display ──────────────────────────────────────────────
            if (question.marks != 1)
              Padding(
                padding: const EdgeInsets.only(top: KlasivoSpacing.xs),
                child: Text(
                  '${question.marks} marks',
                  style: KlasivoTypography.bodySmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              ),

            // ── Tags row ───────────────────────────────────────────────────
            if (question.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KlasivoSpacing.sm),
                child: Wrap(
                  spacing: KlasivoSpacing.xs,
                  runSpacing: KlasivoSpacing.xs,
                  children: question.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KlasivoSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? KlasivoColors.darkBorder.withOpacity(0.5)
                            : KlasivoColors.lightBackground,
                        borderRadius:
                            BorderRadius.circular(KlasivoRadius.pill),
                      ),
                      child: Text(
                        '#$tag',
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: KlasivoSpacing.md),

            // ── Action Row: Delete + Import ────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Delete button
                InkWell(
                  onTap: () async {
                    final confirmed = await showConfirmationDialog(
                      context: context,
                      title: 'Delete Question',
                      message:
                          'Remove this question from the bank? This cannot be undone.',
                      confirmLabel: 'Delete',
                      isDangerous: true,
                    );
                    if (confirmed == true) {
                      try {
                        await ref
                            .read(questionBankServiceProvider)
                            .deleteQuestionFromBank(question.id);
                        if (context.mounted) {
                          showSnackBar(context,
                              message: 'Question deleted');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showSnackBar(context,
                              message: 'Failed: $e', isError: true);
                        }
                      }
                    }
                  },
                  borderRadius:
                      BorderRadius.circular(KlasivoRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KlasivoSpacing.md,
                      vertical: KlasivoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(KlasivoRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: KlasivoColors.error,
                        ),
                        const SizedBox(width: KlasivoSpacing.xs),
                        Text(
                          'Delete',
                          style: KlasivoTypography.labelMedium
                              .copyWith(color: KlasivoColors.error),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: KlasivoSpacing.sm),

                // Import to Exam button
                InkWell(
                  onTap: () async {
                    try {
                      // For now, show a snackbar indicating the import action
                      // In a real flow, this would navigate to exam selection
                      showSnackBar(context,
                          message:
                              'Select an exam to import this question');
                      // Example call:
                      // await ref.read(questionBankServiceProvider).importQuestionToExam(
                      //   bankQuestionId: question.id,
                      //   examId: selectedExamId,
                      //   order: nextOrder,
                      // );
                    } catch (e) {
                      if (context.mounted) {
                        showSnackBar(context,
                            message: 'Failed: $e', isError: true);
                      }
                    }
                  },
                  borderRadius:
                      BorderRadius.circular(KlasivoRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KlasivoSpacing.md,
                      vertical: KlasivoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: KlasivoColors.primary.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(KlasivoRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.file_download_outlined,
                          size: 16,
                          color: KlasivoColors.primary,
                        ),
                        const SizedBox(width: KlasivoSpacing.xs),
                        Text(
                          'Import to Exam',
                          style: KlasivoTypography.labelMedium
                              .copyWith(color: KlasivoColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
