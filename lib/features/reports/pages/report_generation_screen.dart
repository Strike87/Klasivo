import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/exam_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../providers/exam_stats_provider.dart';
import '../../../core/services/pdf_service.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_toast.dart';

class ReportGenerationScreen extends ConsumerStatefulWidget {
  const ReportGenerationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ReportGenerationScreen> createState() =>
      _ReportGenerationScreenState();
}

class _ReportGenerationScreenState
    extends ConsumerState<ReportGenerationScreen> {
  String? _selectedClassId;
  String? _selectedExamId;
  String? _selectedStudentId;
  ReportType _reportType = ReportType.examAnalytics;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(classesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Reports'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Report Type Selection ──
            Text('Report Type',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildReportTypeSelector(),
            const SizedBox(height: 24),

            // ── Class Selection ──
            Text('Select Class',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedClassId,
              decoration: const InputDecoration(
                hintText: 'Choose a class',
                prefixIcon: Icon(Icons.class_outlined),
                border: OutlineInputBorder(),
              ),
              items: classes
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedClassId = val;
                  _selectedExamId = null;
                  _selectedStudentId = null;
                });
              },
            ),
            const SizedBox(height: 20),

            // ── Exam Selection (for Exam Analytics & Student Report) ──
            if (_reportType != ReportType.classComparison &&
                _selectedClassId != null) ...[
              Text('Select Exam',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildExamDropdown(),
              const SizedBox(height: 20),
            ],

            // ── Student Selection (for Student Report Card) ──
            if (_reportType == ReportType.studentReportCard &&
                _selectedClassId != null) ...[
              Text('Select Student',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildStudentDropdown(),
              const SizedBox(height: 20),
            ],

            // ── Preview Info ──
            if (_canGenerate()) ...[
              KlasivoCard(
                variant: KlasivoCardVariant.filled,
                padding: const EdgeInsets.all(16),
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text('Report Preview',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_getReportDescription(),
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(
                      'PDF will include Arabic font support for bilingual content.',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Generate Button ──
            KlasivoButton(
              label: _isGenerating ? 'Generating...' : 'Generate PDF Report',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: _canGenerate() ? _generateReport : null,
              loading: _isGenerating,
              fullWidth: true,
              size: KlasivoButtonSize.lg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      children: ReportType.values.map((type) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RadioListTile<ReportType>(
            value: type,
            groupValue: _reportType,
            onChanged: (val) {
              setState(() {
                _reportType = val!;
                _selectedExamId = null;
                _selectedStudentId = null;
              });
            },
            title: Text(type.label),
            subtitle: Text(type.description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            secondary: Icon(type.icon, color: type.color),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            dense: true,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExamDropdown() {
    if (_selectedClassId == null) {
      return const Text('Please select a class first');
    }

    final examsAsync = ref.watch(classExamsStreamProvider(_selectedClassId!));
    return examsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (snapshot) {
        final exams = snapshot.docs
            .map((doc) => ExamData.fromFirestore(doc))
            .toList();
        if (exams.isEmpty) {
          return const Text('No exams found for this class');
        }
        return DropdownButtonFormField<String>(
          value: _selectedExamId,
          decoration: const InputDecoration(
            hintText: 'Choose an exam',
            prefixIcon: Icon(Icons.quiz_outlined),
            border: OutlineInputBorder(),
          ),
          items: exams
              .map((e) => DropdownMenuItem(
                    value: e.id,
                    child: Text(e.title),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedExamId = val);
          },
        );
      },
    );
  }

  Widget _buildStudentDropdown() {
    if (_selectedClassId == null) {
      return const Text('Please select a class first');
    }

    final students =
        ref.watch(studentsByClassListProvider(_selectedClassId!));
    if (students.isEmpty) {
      return const Text('No students found in this class');
    }
    return DropdownButtonFormField<String>(
      value: _selectedStudentId,
      decoration: const InputDecoration(
        hintText: 'Choose a student',
        prefixIcon: Icon(Icons.person_outlined),
        border: OutlineInputBorder(),
      ),
      items: students
          .map((s) => DropdownMenuItem(
                value: s.id,
                child: Text('${s.fullName} (${s.studentCode})'),
              ))
          .toList(),
      onChanged: (val) {
        setState(() => _selectedStudentId = val);
      },
    );
  }

  bool _canGenerate() {
    switch (_reportType) {
      case ReportType.examAnalytics:
        return _selectedExamId != null;
      case ReportType.studentReportCard:
        return _selectedStudentId != null && _selectedClassId != null;
      case ReportType.classComparison:
        return _selectedClassId != null;
    }
  }

  String _getReportDescription() {
    switch (_reportType) {
      case ReportType.examAnalytics:
        return 'Detailed exam analytics including grade distribution, pass/fail breakdown, '
            'question-level analysis, and individual student results.';
      case ReportType.studentReportCard:
        return 'Complete student report card showing performance across all exams '
            'with scores, percentages, and pass/fail status.';
      case ReportType.classComparison:
        return 'Class performance overview comparing all exams with averages, '
            'pass rates, and score distributions.';
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      switch (_reportType) {
        case ReportType.examAnalytics:
          await _generateExamAnalyticsReport();
          break;
        case ReportType.studentReportCard:
          await _generateStudentReportCard();
          break;
        case ReportType.classComparison:
          await _generateClassComparisonReport();
          break;
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateExamAnalyticsReport() async {
    if (_selectedExamId == null) return;

    KlasivoToast.info(context, message: 'Generating exam analytics report...');

    // Get exam data
    final snapshot = await ref.read(examsStreamProvider.future);
    final examDoc =
        snapshot.docs.where((d) => d.id == _selectedExamId).firstOrNull;
    if (examDoc == null) throw Exception('Exam not found');

    final exam = ExamData.fromFirestore(examDoc);
    final className = exam.getClassName(ref.read(classesProvider));

    // Get submissions
    final submissions = ref.read(examSubmissionsProvider(_selectedExamId!));
    final submittedSubs = submissions
        .where((s) => s.isSubmitted)
        .toList();

    // Get stats
    await ref.read(examStatsDataProvider(_selectedExamId!).future);

    // Get question analysis
    List<Map<String, dynamic>> questionAnalysis = [];
    try {
      final questions =
          await ref.read(questionAnalysisProvider(_selectedExamId!).future);
      questionAnalysis = questions.map((q) => q.toMap()).toList();
    } catch (_) {}

    // Calculate values
    final totalStudents = ref
        .read(studentsByClassListProvider(exam.classId))
        .length;
    final totalScore =
        submittedSubs.fold<int>(0, (sum, s) => sum + s.score);
    final avgScore = submittedSubs.isNotEmpty
        ? totalScore / submittedSubs.length
        : 0.0;
    final highScore = submittedSubs.isEmpty
        ? 0
        : submittedSubs.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final lowScore = submittedSubs.isEmpty
        ? 0
        : submittedSubs.map((s) => s.score).reduce((a, b) => a < b ? a : b);
    final passCount = submittedSubs
        .where((s) => s.percentage >= exam.passingScore)
        .length;
    final passRate = submittedSubs.isNotEmpty
        ? (passCount / submittedSubs.length) * 100
        : 0.0;

    // Grade distribution
    final gradeDist = <Map<String, dynamic>>[];
    for (var range in [
      ('0-20%', 0, 20),
      ('21-40%', 21, 40),
      ('41-60%', 41, 60),
      ('61-80%', 61, 80),
      ('81-100%', 81, 100)
    ]) {
      final count = submittedSubs
          .where((s) =>
              s.percentage >= range.$2 && s.percentage <= range.$3)
          .length;
      gradeDist.add({
        'range': range.$1,
        'count': count,
        'percentage': submittedSubs.isNotEmpty
            ? (count / submittedSubs.length * 100).round()
            : 0,
      });
    }

    // Student results
    final allStudents = ref.read(allStudentsProvider);
    final studentResults = submittedSubs.map((s) {
      final student =
          allStudents.where((st) => st.id == s.studentId).firstOrNull;
      return {
        'name': student?.fullName ?? 'Unknown',
        'code': student?.studentCode ?? '',
        'score': s.score,
        'totalMarks': exam.totalMarks,
        'percentage': s.percentage,
        'status': s.isFlagged
            ? 'Flagged'
            : (s.percentage >= exam.passingScore ? 'Passed' : 'Failed'),
      };
    }).toList();

    final file = await PdfService.generateExamReport(
      examTitle: exam.title,
      className: className,
      totalStudents: totalStudents,
      submittedStudents: submittedSubs.length,
      averageScore: avgScore,
      highestScore: highScore,
      lowestScore: lowScore,
      passRate: passRate,
      totalMarks: exam.totalMarks,
      passingScore: exam.passingScore,
      gradeDistribution: gradeDist,
      studentResults: studentResults,
      questionAnalysis: questionAnalysis.isNotEmpty ? questionAnalysis : null,
    );

    if (mounted) await PdfService.sharePdf(file);
  }

  Future<void> _generateStudentReportCard() async {
    if (_selectedStudentId == null || _selectedClassId == null) return;

    KlasivoToast.info(context, message: 'Generating student report card...');

    final students =
        ref.read(studentsByClassListProvider(_selectedClassId!));
    final student =
        students.where((s) => s.id == _selectedStudentId).firstOrNull;
    if (student == null) throw Exception('Student not found');

    // Get all submissions for this student
    final submissions = ref.read(studentSubmissionsProvider);
    final studentSubs = submissions
        .where((s) => s.studentId == _selectedStudentId && s.isSubmitted)
        .toList();

    final classes = ref.read(classesProvider);
    final className =
        classes.where((c) => c.id == _selectedClassId).firstOrNull?.name ??
            'Unknown';

    // Calculate overall stats
    final totalPercentage =
        studentSubs.fold<int>(0, (sum, s) => sum + s.percentage);
    final avgScore = studentSubs.isNotEmpty
        ? totalPercentage / studentSubs.length
        : 0.0;
    final passCount = studentSubs
        .where((s) => s.percentage >= 50)
        .length;
    final passRate = studentSubs.isNotEmpty
        ? (passCount / studentSubs.length) * 100
        : 0.0;

    // Build exam results list
    final examResults = <Map<String, dynamic>>[];
    for (final sub in studentSubs) {
      // We'll use what we have from the submission
      examResults.add({
        'examTitle': sub.examId, // Will be resolved in a full impl
        'score': sub.score,
        'totalMarks': sub.totalMarks,
        'percentage': sub.percentage,
        'passed': sub.percentage >= 50,
        'timeSpent': (sub.timeSpent / 60).round(),
      });
    }

    final file = await PdfService.generateStudentReportCard(
      studentName: student.fullName,
      studentCode: student.studentCode,
      className: className,
      examResults: examResults,
      overallStats: {
        'totalExams': studentSubs.length,
        'averageScore': avgScore,
        'passRate': passRate,
      },
    );

    if (mounted) await PdfService.sharePdf(file);
  }

  Future<void> _generateClassComparisonReport() async {
    if (_selectedClassId == null) return;

    KlasivoToast.info(context, message: 'Generating class comparison report...');

    final classes = ref.read(classesProvider);
    final className = classes
            .where((c) => c.id == _selectedClassId)
            .firstOrNull
            ?.name ??
        'Unknown';

    // Get class exam stats
    final statsAsync = await ref
        .read(classExamStatsProvider(_selectedClassId!).future);

    final examResults = <Map<String, dynamic>>[];
    double totalPassRate = 0;
    double totalAvgScore = 0;
    int examsWithData = 0;

    for (final stat in statsAsync) {
      examResults.add({
        'examTitle': stat.examId, // Will be enriched with actual title
        'totalStudents': stat.totalStudents,
        'submittedStudents': stat.submittedStudents,
        'averageScore': stat.averagePercentage,
        'highestScore': stat.highestScore,
        'lowestScore': stat.lowestScore,
        'passRate': stat.passRate,
      });

      if (stat.submittedStudents > 0) {
        totalPassRate += stat.passRate;
        totalAvgScore += stat.averagePercentage;
        examsWithData++;
      }
    }

    final file = await PdfService.generateClassReport(
      className: className,
      examResults: examResults,
      overallStats: {
        'totalExams': statsAsync.length,
        'totalStudents': statsAsync.isNotEmpty
            ? statsAsync.first.totalStudents
            : 0,
        'avgPassRate':
            examsWithData > 0 ? totalPassRate / examsWithData : 0,
        'avgScore':
            examsWithData > 0 ? totalAvgScore / examsWithData : 0,
      },
    );

    if (mounted) await PdfService.sharePdf(file);
  }
}

// ─── Report Type Enum ────────────────────────────────────────────────────────

enum ReportType {
  examAnalytics,
  studentReportCard,
  classComparison,
}

extension ReportTypeExtension on ReportType {
  String get label {
    switch (this) {
      case ReportType.examAnalytics:
        return 'Exam Analytics Report';
      case ReportType.studentReportCard:
        return 'Student Report Card';
      case ReportType.classComparison:
        return 'Class Comparison Report';
    }
  }

  String get description {
    switch (this) {
      case ReportType.examAnalytics:
        return 'Detailed analytics for a single exam with grade distribution and question analysis';
      case ReportType.studentReportCard:
        return 'Performance report card for a specific student across all exams';
      case ReportType.classComparison:
        return 'Overview of class performance across all exams';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportType.examAnalytics:
        return Icons.analytics_outlined;
      case ReportType.studentReportCard:
        return Icons.school_outlined;
      case ReportType.classComparison:
        return Icons.compare_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ReportType.examAnalytics:
        return Colors.blue;
      case ReportType.studentReportCard:
        return Colors.teal;
      case ReportType.classComparison:
        return Colors.purple;
    }
  }
}
