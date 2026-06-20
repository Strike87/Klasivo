import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/question_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/exam_security_service.dart';
import '../../../core/services/exam_instance_service.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_text_field.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';

class ExamTakingScreen extends ConsumerStatefulWidget {
  final String examId;

  const ExamTakingScreen({
    Key? key,
    required this.examId,
  }) : super(key: key);

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen>
    with WidgetsBindingObserver {
  // ─── State ──────────────────────────────────────────────────────────────
  int _currentQuestionIndex = 0;
  Map<String, String> _answers = {}; // questionId -> answer
  String? _submissionId;
  String _studentId = '';        // P1-2: required by saveAnswer rules
  String _organizationId = '';   // P1-2: required by isIncomingSameOrg()
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  int _timeSpentSeconds = 0;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeExam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _autoSaveTimer?.cancel();
    WakelockPlus.disable();
    ExamSecurityService.disableAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_hasSubmitted) return;

    if (state == AppLifecycleState.paused) {
      // Student left the app — increment violation count
      _handleLeaveDetection();
    } else if (state == AppLifecycleState.resumed) {
      // Student came back — no action needed
    }
  }

  // ─── Initialize Exam ──────────────────────────────────────────────────────

  Future<void> _initializeExam() async {
    try {
      final studentId = ref.read(userIdProvider) ?? '';
      final classId = ref.read(studentClassIdProvider) ?? '';
      final submissionService = ref.read(submissionServiceProvider);

      // P1-2: cache for saveAnswer / bulkSaveAnswers (rules require these fields)
      _studentId = studentId;
      _organizationId = ref.read(organizationIdProvider) ?? '';

      // Start or get existing submission
      final subId = await submissionService.startSubmission(
        examId: widget.examId,
        studentId: studentId,
        classId: classId,
      );

      // Check if already submitted
      final subData = await submissionService.getSubmission(subId);
      if (subData != null &&
          (subData['status'] == AppConstants.submissionStatusSubmitted ||
              subData['status'] == AppConstants.submissionStatusFlagged)) {
        // Already submitted — check if retake is allowed
        final examData = await ref.read(examServiceProvider).getExam(widget.examId);
        final allowRetake = examData?['allowRetake'] as bool? ?? false;
        if (!allowRetake) {
          if (mounted) {
            setState(() {
              _hasSubmitted = true;
              _isLoading = false;
            });
            KlasivoToast.error(context,
                message: 'You have already submitted this exam');
            context.go('/student/exams');
          }
          return;
        }
      }

      // ── Create or get exam instance (for randomized question order) ──
      final examData = await ref.read(examServiceProvider).getExam(widget.examId);
      final isRandomized = examData?['isRandomized'] as bool? ?? false;
      final teacherId = examData?['teacherId'] as String? ?? '';

      if (isRandomized) {
        // ISSUE 4 FOLLOW-UP FIX — exam_instance must be in the same org as the
        // exam, otherwise Firestore rule isInComingSameOrg() denies the write.
        // Prefer the exam doc's organizationId (already in hand); fall back to
        // the user's current org context.
        final organizationId = (examData?['organizationId'] as String?)
            ?? ref.read(organizationIdProvider);
        if (organizationId == null || organizationId.isEmpty) {
          if (mounted) {
            setState(() => _isLoading = false);
            KlasivoToast.error(context,
                message: 'Organization context missing. Please re-login.');
          }
          return;
        }
        final instanceService = ExamInstanceService();
        await instanceService.createExamInstance(
          examId: widget.examId,
          studentId: studentId,
          classId: classId,
          teacherId: teacherId,
          organizationId: organizationId,
          isRandomized: true,
        );
      }

      // Load existing answers if any
      final existingAnswers = await submissionService.getAnswers(subId);
      final Map<String, String> loadedAnswers = {};
      for (final ans in existingAnswers) {
        loadedAnswers[ans['questionId'] as String] =
            ans['answer'] as String? ?? '';
      }

      // Get exam duration
      final durationMinutes =
          examData?['durationMinutes'] as int? ?? 30;

      // Calculate remaining time from existing timeSpent
      final existingTimeSpent = subData?['timeSpent'] as int? ?? 0;
      final totalSeconds = durationMinutes * 60;
      final remaining = totalSeconds - existingTimeSpent;

      setState(() {
        _submissionId = subId;
        _answers = loadedAnswers;
        _timeSpentSeconds = existingTimeSpent;
        _remainingSeconds = remaining > 0 ? remaining : 0;
        _isLoading = false;
      });

      // Enable wakelock
      await WakelockPlus.enable();

      // Enable exam security
      await ExamSecurityService.enableAll();

      // Start countdown timer
      _startCountdownTimer();

      // Start auto-save timer
      _startAutoSaveTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        KlasivoToast.error(context,
            message: 'Failed to start exam: $e');
        context.go('/student/exams');
      }
    }
  }

  // ─── Countdown Timer ──────────────────────────────────────────────────────

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
        _timeSpentSeconds++;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _autoSubmit();
      }
    });
  }

  // ─── Auto-Save Timer ──────────────────────────────────────────────────────

  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      Duration(seconds: AppConstants.autoSaveInterval),
      (timer) {
        if (!_hasSubmitted) {
          _autoSave();
        }
      },
    );
  }

  // ─── Auto-Save ────────────────────────────────────────────────────────────

  Future<void> _autoSave() async {
    if (_submissionId == null || _answers.isEmpty) return;

    try {
      final submissionService = ref.read(submissionServiceProvider);
      final studentId = ref.read(userIdProvider) ?? '';
      final organizationId = ref.read(organizationIdProvider) ?? '';

      final answersList = _answers.entries
          .map((e) => {
                'questionId': e.key,
                'answer': e.value,
              })
          .toList();

      await submissionService.bulkSaveAnswers(
        submissionId: _submissionId!,
        answers: answersList,
        studentId: studentId,
        organizationId: organizationId,
      );

      // Update time spent
      await submissionService.updateTimeSpent(
          _submissionId!, _timeSpentSeconds);
    } catch (_) {
      // Silent fail for auto-save
    }
  }

  // ─── Save Single Answer ───────────────────────────────────────────────────

  Future<void> _saveAnswer(String questionId, String answer) async {
    if (_submissionId == null) return;

    setState(() {
      _answers[questionId] = answer;
    });

    try {
      final submissionService = ref.read(submissionServiceProvider);
      final studentId = ref.read(userIdProvider) ?? '';
      final organizationId = ref.read(organizationIdProvider) ?? '';
      await submissionService.saveAnswer(
        submissionId: _submissionId!,
        questionId: questionId,
        answer: answer,
        studentId: studentId,
        organizationId: organizationId,
      );
    } catch (_) {
      // Silent fail — will be saved on next auto-save
    }
  }

  // ─── Leave Detection ──────────────────────────────────────────────────────

  Future<void> _handleLeaveDetection() async {
    if (_submissionId == null || _hasSubmitted) return;

    try {
      final submissionService = ref.read(submissionServiceProvider);
      await submissionService.incrementViolationCount(_submissionId!);

      if (mounted) {
        KlasivoToast.warning(context,
            message:
                'Warning: Leaving the exam screen is recorded. More than ${AppConstants.violationThreshold} violations will flag your submission.');
      }
    } catch (_) {}
  }

  // ─── Submit Exam ──────────────────────────────────────────────────────────

  Future<void> _autoSubmit() async {
    if (_hasSubmitted) return;
    await _submitExam();
  }

  Future<void> _manualSubmit() async {
    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Submit Exam',
      message:
          'Are you sure you want to submit? You cannot change your answers after submission.',
      confirmLabel: 'Submit',
    );
    if (confirmed != true) return;
    await _submitExam();
  }

  Future<void> _submitExam() async {
    if (_submissionId == null || _hasSubmitted) return;

    setState(() => _isSubmitting = true);
    _countdownTimer?.cancel();
    _autoSaveTimer?.cancel();

    try {
      // Final save of all answers
      await _autoSave();

      // Submit and auto-grade
      final submissionService = ref.read(submissionServiceProvider);
      await submissionService.submitExam(
        submissionId: _submissionId!,
        examId: widget.examId,
        timeSpent: _timeSpentSeconds,
      );

      setState(() => _hasSubmitted = true);

      await WakelockPlus.disable();
      await ExamSecurityService.disableAll();

      if (mounted) {
        KlasivoToast.success(context, message: 'Exam submitted successfully!');
        // Navigate to results
        context.go('/student/results/$_submissionId');
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context,
            message: 'Failed to submit: $e');
        // Restart timers if submission failed
        _startCountdownTimer();
        _startAutoSaveTimer();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ─── Format Time ──────────────────────────────────────────────────────────

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(questionsStreamProvider(widget.examId));
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Exam...')),
        body: const LoadingIndicator(message: 'Preparing your exam...'),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Prevent back navigation — warn the student
        _handleLeaveDetection();
        KlasivoToast.warning(context,
            message:
                'You cannot go back during an exam. Use the submit button when done.');
      },
      child: questionsAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Loading Questions...')),
          body: const LoadingIndicator(),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: ErrorWidgetCustom(
            message: 'Failed to load questions: $error',
            onRetry: () =>
                ref.invalidate(questionsStreamProvider(widget.examId)),
          ),
        ),
        data: (snapshot) {
          List<QuestionData> questions = snapshot.docs
              .map((doc) => QuestionData.fromFirestore(doc))
              .toList();

          if (questions.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: const Text('Exam')),
              body: const EmptyState(
                icon: Icons.error_outline,
                title: 'No Questions',
                subtitle: 'This exam has no questions',
              ),
            );
          }

          final currentQuestion =
              questions[_currentQuestionIndex.clamp(0, questions.length - 1)];
          final isLastQuestion =
              _currentQuestionIndex == questions.length - 1;
          final answeredCount =
              _answers.values.where((a) => a.isNotEmpty).length;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Exam'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                // ── Timer ──
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingSeconds <= 60
                        ? Colors.red.withValues(alpha: 0.1)
                        : _remainingSeconds <= 300
                            ? Colors.orange.withValues(alpha: 0.1)
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: _remainingSeconds <= 60
                            ? Colors.red
                            : _remainingSeconds <= 300
                                ? Colors.orange
                                : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          color: _remainingSeconds <= 60
                              ? Colors.red
                              : _remainingSeconds <= 300
                                  ? Colors.orange
                                  : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: _isSubmitting
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Submitting your exam...',
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // ── Progress Bar ──
                      LinearProgressIndicator(
                        value: answeredCount / questions.length,
                        backgroundColor: Colors.grey[200],
                      ),

                      // ── Question Counter ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        child: Row(
                          children: [
                            Text(
                              'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$answeredCount answered',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Question Content ──
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Marks badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: currentQuestion.typeColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${currentQuestion.typeLabel} · ${currentQuestion.marks} mark${currentQuestion.marks != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: currentQuestion.typeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Question text
                              Text(
                                currentQuestion.questionText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Answer section
                              _buildAnswerSection(currentQuestion),
                            ],
                          ),
                        ),
                      ),

                      // ── Navigation Bar ──
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
                        child: SafeArea(
                          child: Row(
                            children: [
                              // Previous button
                              if (_currentQuestionIndex > 0)
                                Expanded(
                                  child: KlasivoButton(
                                    label: 'Previous',
                                    icon: Icons.arrow_back,
                                    variant: KlasivoButtonVariant.secondary,
                                    onPressed: () => setState(() =>
                                        _currentQuestionIndex--),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),

                              const SizedBox(width: 12),

                              // Question Navigation Dots
                              SizedBox(
                                height: 40,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(
                                      questions.length,
                                      (i) => GestureDetector(
                                        onTap: () => setState(() =>
                                            _currentQuestionIndex = i),
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: i ==
                                                    _currentQuestionIndex
                                                ? theme.colorScheme.primary
                                                : _answers.containsKey(questions[i].id) &&
                                                        _answers[questions[i].id]!
                                                            .isNotEmpty
                                                    ? Colors.green
                                                        .withValues(alpha: 0.2)
                                                    : Colors.grey[200],
                                            border: i == _currentQuestionIndex
                                                ? null
                                                : Border.all(
                                                    color: _answers.containsKey(
                                                                questions[i]
                                                                    .id) &&
                                                            _answers[questions[i].id]!
                                                                .isNotEmpty
                                                        ? Colors.green
                                                        : Colors.grey[400]!,
                                                  ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${i + 1}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: i ==
                                                        _currentQuestionIndex
                                                    ? Colors.white
                                                    : _answers.containsKey(questions[i].id) &&
                                                            _answers[questions[i].id]!
                                                                .isNotEmpty
                                                        ? Colors.green
                                                        : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Next / Submit button
                              Expanded(
                                child: isLastQuestion
                                    ? KlasivoButton(
                                        label: 'Submit',
                                        icon: Icons.send,
                                        onPressed: _manualSubmit,
                                      )
                                    : KlasivoButton(
                                        label: 'Next',
                                        icon: Icons.arrow_forward,
                                        onPressed: () => setState(() =>
                                            _currentQuestionIndex++),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // ─── Build Answer Section ─────────────────────────────────────────────────

  Widget _buildAnswerSection(QuestionData question) {
    switch (question.questionType) {
      case AppConstants.questionTypeMultipleChoice:
        return _buildMCQAnswer(question);
      case AppConstants.questionTypeTrueFalse:
        return _buildTrueFalseAnswer(question);
      case AppConstants.questionTypeShortAnswer:
        return _buildShortAnswer(question);
      default:
        return const Text('Unknown question type');
    }
  }

  Widget _buildMCQAnswer(QuestionData question) {
    final currentAnswer = _answers[question.id] ?? '';

    return Column(
      children: question.options.map((option) {
        final isSelected = currentAnswer == option;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => _saveAnswer(question.id, option),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.05)
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTrueFalseAnswer(QuestionData question) {
    final currentAnswer = _answers[question.id] ?? '';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _saveAnswer(question.id, 'True'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: currentAnswer == 'True'
                      ? Colors.green
                      : Colors.grey[300]!,
                  width: currentAnswer == 'True' ? 2 : 1,
                ),
                color: currentAnswer == 'True'
                    ? Colors.green.withValues(alpha: 0.05)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: currentAnswer == 'True'
                        ? Colors.green
                        : Colors.grey[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'True',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: currentAnswer == 'True'
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: currentAnswer == 'True'
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _saveAnswer(question.id, 'False'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: currentAnswer == 'False'
                      ? Colors.red
                      : Colors.grey[300]!,
                  width: currentAnswer == 'False' ? 2 : 1,
                ),
                color: currentAnswer == 'False'
                    ? Colors.red.withValues(alpha: 0.05)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: currentAnswer == 'False'
                        ? Colors.red
                        : Colors.grey[600],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'False',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: currentAnswer == 'False'
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: currentAnswer == 'False'
                          ? Colors.red
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortAnswer(QuestionData question) {
    final controller = TextEditingController(
      text: _answers[question.id] ?? '',
    );

    return KlasivoTextField(
      controller: controller,
      label: 'Your Answer',
      hint: 'Type your answer here',
      maxLines: 3,
      onChanged: (value) => _saveAnswer(question.id, value),
    );
  }
}
