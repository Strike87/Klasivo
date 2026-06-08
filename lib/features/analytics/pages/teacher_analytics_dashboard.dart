import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/exam_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../providers/exam_stats_provider.dart';
import '../../../core/services/exam_stats_service.dart';

class TeacherAnalyticsDashboard extends ConsumerStatefulWidget {
  const TeacherAnalyticsDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<TeacherAnalyticsDashboard> createState() =>
      _TeacherAnalyticsDashboardState();
}

class _TeacherAnalyticsDashboardState
    extends ConsumerState<TeacherAnalyticsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Generate Report',
            onPressed: () => context.go('/teacher/reports'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 18)),
            Tab(text: 'Performance', icon: Icon(Icons.trending_up, size: 18)),
            Tab(text: 'Questions', icon: Icon(Icons.quiz_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(ref: ref),
          _PerformanceTab(ref: ref),
          _QuestionsTab(ref: ref),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends ConsumerWidget {
  final WidgetRef ref;

  const _OverviewTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalClasses = ref.watch(totalClassesProvider);
    final totalStudents = ref.watch(totalStudentsProvider);
    final examStats = ref.watch(examStatsProvider);
    final submissions = ref.watch(studentSubmissionsProvider);
    final theme = Theme.of(context);

    // Calculate average score from submissions
    final submittedSubs = submissions.where((s) => s.isSubmitted).toList();
    final avgScore = submittedSubs.isNotEmpty
        ? submittedSubs.fold<int>(0, (sum, s) => sum + s.percentage) /
            submittedSubs.length
        : 0.0;

    // Calculate pass/fail counts
    final passCount = submittedSubs.where((s) => s.percentage >= 50).length;
    final failCount = submittedSubs.length - passCount;

    // Get precomputed analytics summary
    final analyticsAsync = ref.watch(teacherAnalyticsSummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary Cards Row 1 ──
          Row(children: [
            _StatCard(
                title: 'Classes',
                value: '$totalClasses',
                color: Colors.blue,
                icon: Icons.class_outlined),
            const SizedBox(width: 12),
            _StatCard(
                title: 'Students',
                value: '$totalStudents',
                color: Colors.green,
                icon: Icons.people_outlined),
          ]),
          const SizedBox(height: 12),
          // ── Summary Cards Row 2 ──
          Row(children: [
            _StatCard(
                title: 'Total Exams',
                value: '${examStats['total'] ?? 0}',
                color: Colors.orange,
                icon: Icons.quiz_outlined),
            const SizedBox(width: 12),
            _StatCard(
                title: 'Avg Score',
                value: '${avgScore.toStringAsFixed(0)}%',
                color: Colors.purple,
                icon: Icons.trending_up),
          ]),
          const SizedBox(height: 12),
          // ── Summary Cards Row 3 ──
          Row(children: [
            _StatCard(
                title: 'Pass Rate',
                value: submittedSubs.isNotEmpty
                    ? '${(passCount / submittedSubs.length * 100).toStringAsFixed(0)}%'
                    : '-',
                color: Colors.teal,
                icon: Icons.check_circle_outline),
            const SizedBox(width: 12),
            _StatCard(
                title: 'Upcoming',
                value: '${examStats['upcoming'] ?? 0}',
                color: Colors.indigo,
                icon: Icons.upcoming_outlined),
          ]),
          const SizedBox(height: 24),

          // ── Enhanced Stats from Precomputed ──
          analyticsAsync.when(
            data: (summary) {
              if (summary.totalSubmissions == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.analytics_outlined,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('No analytics data yet',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Data will appear after students submit exams',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detailed Metrics',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _MetricCard(
                        label: 'Submissions',
                        value: '${summary.totalSubmissions}',
                        icon: Icons.assignment_turned_in_outlined,
                        color: Colors.blue),
                    const SizedBox(width: 12),
                    _MetricCard(
                        label: 'Avg Pass Rate',
                        value:
                            '${summary.averagePassRate.toStringAsFixed(1)}%',
                        icon: Icons.pie_chart_outline,
                        color: Colors.green),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _MetricCard(
                        label: 'Avg Score',
                        value:
                            '${summary.averageScore.toStringAsFixed(1)}%',
                        icon: Icons.bar_chart_outlined,
                        color: Colors.purple),
                    const SizedBox(width: 12),
                    _MetricCard(
                        label: 'Violations',
                        value: '${summary.totalViolations}',
                        icon: Icons.warning_amber_outlined,
                        color: Colors.red),
                  ]),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // ── Score Distribution Chart ──
          Text('Score Distribution',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ScoreDistributionChart(submissions: submittedSubs),
          const SizedBox(height: 24),

          // ── Pass/Fail Pie Chart ──
          Text('Pass / Fail Breakdown',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _PassFailChart(passCount: passCount, failCount: failCount),
          const SizedBox(height: 24),

          // ── Exam Status Breakdown ──
          Text('Exam Status',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ExamStatusChart(
            upcoming: examStats['upcoming'] ?? 0,
            completed: examStats['completed'] ?? 0,
            draft: examStats['draft'] ?? 0,
          ),
          const SizedBox(height: 24),

          // ── Quick Navigation ──
          Text('Quick Access',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickNavCard(
                  title: 'Question Bank',
                  icon: Icons.library_books_outlined,
                  color: Colors.teal,
                  onTap: () => context.go('/teacher/question-bank')),
              _QuickNavCard(
                  title: 'Reports',
                  icon: Icons.picture_as_pdf_outlined,
                  color: Colors.blue,
                  onTap: () => context.go('/teacher/reports')),
              _QuickNavCard(
                  title: 'Stages',
                  icon: Icons.school_outlined,
                  color: Colors.pink,
                  onTap: () => context.go('/teacher/stages')),
              _QuickNavCard(
                  title: 'All Exams',
                  icon: Icons.quiz_outlined,
                  color: Colors.orange,
                  onTap: () => context.go('/teacher/exams')),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PERFORMANCE TAB (Line Charts + Trends)
// ════════════════════════════════════════════════════════════════════════════

class _PerformanceTab extends ConsumerWidget {
  final WidgetRef ref;

  const _PerformanceTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final classes = ref.watch(classesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Class Selector for Performance Trends ──
          Text('Performance Trends',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Select a class to view performance trends across exams',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 12),

          ...classes.map((cls) => _ClassPerformanceCard(
                classId: cls.id,
                className: cls.name,
              )),
        ],
      ),
    );
  }
}

class _ClassPerformanceCard extends ConsumerWidget {
  final String classId;
  final String className;

  const _ClassPerformanceCard({
    required this.classId,
    required this.className,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync =
        ref.watch(classPerformanceTrendProvider(classId));
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.class_outlined,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(className,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Class Performance Trend',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            trendAsync.when(
              data: (trend) {
                if (trend.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.show_chart,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            trend.isEmpty
                                ? 'No exam data yet'
                                : 'Need at least 2 exams for trend analysis',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // ── Average Score Line Chart ──
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 20,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (v, _) {
                                  final idx = v.toInt();
                                  if (idx < 0 || idx >= trend.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _truncateLabel(trend[idx].examTitle, 8),
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (v, _) =>
                                    Text('${v.toInt()}%',
                                        style: const TextStyle(fontSize: 10)),
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            // Average Score line
                            LineChartBarData(
                              spots: trend
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.averageScore.toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.blue,
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (_, __, ___, ____) =>
                                    FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blue,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blue.withValues(alpha: 0.1),
                              ),
                            ),
                            // Pass Rate line
                            LineChartBarData(
                              spots: trend
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(
                                      e.key.toDouble(), e.value.passRate))
                                  .toList(),
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 2,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (_, __, ___, ____) =>
                                    FlDotCirclePainter(
                                  radius: 3,
                                  color: Colors.green,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              dashArray: [5, 5],
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final idx = spot.spotIndex;
                                  final isAvgLine =
                                      spot.barIndex == 0;
                                  return LineTooltipItem(
                                    isAvgLine
                                        ? 'Avg: ${spot.y.toStringAsFixed(1)}%'
                                        : 'Pass: ${spot.y.toStringAsFixed(1)}%',
                                    TextStyle(
                                      color: isAvgLine
                                          ? Colors.blue
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Legend ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ChartLegend(color: Colors.blue, label: 'Avg Score'),
                        const SizedBox(width: 24),
                        _ChartLegend(
                            color: Colors.green,
                            label: 'Pass Rate',
                            dashed: true),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Exam-by-exam stats table ──
                    _buildExamStatsTable(trend),
                  ],
                );
              },
              loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: Text('Error loading trend: $e',
                        style: TextStyle(color: Colors.red[400]))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamStatsTable(List<PerformanceTrendPoint> trend) {
    return Table(
      border: TableBorder.all(color: Colors.grey[300]!, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue[700]),
          children: [
            _tableHeader('Exam'),
            _tableHeader('Avg %'),
            _tableHeader('Pass Rate'),
            _tableHeader('Students'),
          ],
        ),
        ...trend.map((t) => TableRow(
              children: [
                _tableCell(_truncateLabel(t.examTitle, 15)),
                _tableCell('${t.averageScore}%'),
                _tableCell('${t.passRate.toStringAsFixed(0)}%'),
                _tableCell('${t.submittedStudents}'),
              ],
            )),
      ],
    );
  }

  static Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center),
    );
  }

  static Widget _tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
    );
  }

  String _truncateLabel(String label, int maxLen) {
    if (label.length <= maxLen) return label;
    return '${label.substring(0, maxLen)}...';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUESTIONS TAB (Question Difficulty Analysis)
// ════════════════════════════════════════════════════════════════════════════

class _QuestionsTab extends ConsumerWidget {
  final WidgetRef ref;

  const _QuestionsTab({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exams = ref.watch(completedExamsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question Difficulty Analysis',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Select a completed exam to analyze question performance',
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 16),

          if (exams.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.quiz_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No completed exams yet',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 14)),
                    ],
                  ),
                ),
              ),
            )
          else
            ...exams.map((exam) => _ExamQuestionAnalysisCard(
                  examId: exam.id,
                  examTitle: exam.title,
                )),
        ],
      ),
    );
  }
}

class _ExamQuestionAnalysisCard extends ConsumerWidget {
  final String examId;
  final String examTitle;

  const _ExamQuestionAnalysisCard({
    required this.examId,
    required this.examTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync =
        ref.watch(questionAnalysisProvider(examId));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.quiz_outlined,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(examTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Question Analysis',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            questionsAsync.when(
              data: (questions) {
                if (questions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('No question data available yet',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13)),
                    ),
                  );
                }

                // Categorize questions by difficulty based on correct %
                int easyCount = 0;
                int mediumCount = 0;
                int hardCount = 0;

                for (final q in questions) {
                  if (q.correctPercentage >= 70) {
                    easyCount++;
                  } else if (q.correctPercentage >= 40) {
                    mediumCount++;
                  } else {
                    hardCount++;
                  }
                }

                return Column(
                  children: [
                    // ── Difficulty Distribution Bar Chart ──
                    SizedBox(
                      height: 160,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: questions.length.toDouble() + 1,
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [
                              BarChartRodData(
                                toY: easyCount.toDouble(),
                                color: Colors.green,
                                width: 40,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              )
                            ]),
                            BarChartGroupData(x: 1, barRods: [
                              BarChartRodData(
                                toY: mediumCount.toDouble(),
                                color: Colors.orange,
                                width: 40,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              )
                            ]),
                            BarChartGroupData(x: 2, barRods: [
                              BarChartRodData(
                                toY: hardCount.toDouble(),
                                color: Colors.red,
                                width: 40,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              )
                            ]),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, _) {
                                  switch (v.toInt()) {
                                    case 0:
                                      return const Text('Easy (>=70%)');
                                    case 1:
                                      return const Text('Medium (40-69%)');
                                    case 2:
                                      return const Text('Hard (<40%)');
                                    default:
                                      return const Text('');
                                  }
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                getTitlesWidget: (v, _) =>
                                    Text('${v.toInt()}',
                                        style:
                                            const TextStyle(fontSize: 10)),
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Per-Question Correct % List ──
                    const Text('Per-Question Correct Rate',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    ...questions.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final q = entry.value;
                      final color = q.correctPercentage >= 70
                          ? Colors.green
                          : (q.correctPercentage >= 40
                              ? Colors.orange
                              : Colors.red);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text('Q${idx + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: q.correctPercentage / 100,
                                  backgroundColor: Colors.grey[200],
                                  color: color,
                                  minHeight: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 40,
                              child: Text('${q.correctPercentage}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                    child: Text('Error: $e',
                        style: TextStyle(color: Colors.red[400]))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0.5,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color)),
                    Text(label,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNavCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickNavCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _ChartLegend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? Row(
                children: [
                  Container(width: 6, height: 2, color: color),
                  const SizedBox(width: 2),
                  Container(width: 6, height: 2, color: color),
                  const SizedBox(width: 2),
                  Container(width: 6, height: 2, color: color),
                ],
              )
            : Container(width: 20, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

// ─── Score Distribution Chart ────────────────────────────────────────────────

class _ScoreDistributionChart extends StatelessWidget {
  final List<SubmissionData> submissions;
  const _ScoreDistributionChart({required this.submissions});

  @override
  Widget build(BuildContext context) {
    final ranges = <String, int>{
      '0-20%': 0,
      '21-40%': 0,
      '41-60%': 0,
      '61-80%': 0,
      '81-100%': 0,
    };

    for (final s in submissions) {
      if (s.percentage <= 20)
        ranges['0-20%'] = ranges['0-20%']! + 1;
      else if (s.percentage <= 40)
        ranges['21-40%'] = ranges['21-40%']! + 1;
      else if (s.percentage <= 60)
        ranges['41-60%'] = ranges['41-60%']! + 1;
      else if (s.percentage <= 80)
        ranges['61-80%'] = ranges['61-80%']! + 1;
      else
        ranges['81-100%'] = ranges['81-100%']! + 1;
    }

    final maxCount =
        ranges.values.fold(0, (a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
              child: Text('No submission data yet',
                  style: TextStyle(color: Colors.grey[500]))),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxCount + 1,
              barGroups: ranges.entries.mapIndexed((i, e) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: _getColor(i),
                        width: 32,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      )
                    ],
                  )).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(ranges.keys.elementAt(v.toInt()),
                          style: const TextStyle(fontSize: 9)),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: true, reservedSize: 30),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor(int index) {
    switch (index) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.amber;
      case 3:
        return Colors.lightGreen;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// ─── Pass/Fail Pie Chart ─────────────────────────────────────────────────────

class _PassFailChart extends StatelessWidget {
  final int passCount;
  final int failCount;

  const _PassFailChart({required this.passCount, required this.failCount});

  @override
  Widget build(BuildContext context) {
    final total = passCount + failCount;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
              child: Text('No results yet',
                  style: TextStyle(color: Colors.grey[500]))),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: passCount.toDouble(),
                      color: Colors.green,
                      title: passCount > 0 ? '$passCount' : '',
                      radius: 40,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                    PieChartSectionData(
                      value: failCount.toDouble(),
                      color: Colors.red,
                      title: failCount > 0 ? '$failCount' : '',
                      radius: 40,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(
                      color: Colors.green,
                      label: 'Passed',
                      count: passCount,
                      pct: total > 0
                          ? (passCount / total * 100).toStringAsFixed(0)
                          : '0'),
                  const SizedBox(height: 12),
                  _LegendItem(
                      color: Colors.red,
                      label: 'Failed',
                      count: failCount,
                      pct: total > 0
                          ? (failCount / total * 100).toStringAsFixed(0)
                          : '0'),
                  const SizedBox(height: 12),
                  Text('Total: $total submissions',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Exam Status Chart ───────────────────────────────────────────────────────

class _ExamStatusChart extends StatelessWidget {
  final int upcoming;
  final int completed;
  final int draft;

  const _ExamStatusChart({
    required this.upcoming,
    required this.completed,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    final total = upcoming + completed + draft;
    if (total == 0) {
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                  child: Text('No exams yet',
                      style: TextStyle(color: Colors.grey[500])))));
    }

    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                        value: upcoming.toDouble(),
                        color: Colors.orange,
                        title: upcoming > 0 ? '$upcoming' : '',
                        radius: 40,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    PieChartSectionData(
                        value: completed.toDouble(),
                        color: Colors.green,
                        title: completed > 0 ? '$completed' : '',
                        radius: 40,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    PieChartSectionData(
                        value: draft.toDouble(),
                        color: Colors.grey,
                        title: draft > 0 ? '$draft' : '',
                        radius: 40,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(
                      color: Colors.orange,
                      label: 'Upcoming',
                      count: upcoming),
                  const SizedBox(height: 8),
                  _LegendItem(
                      color: Colors.green,
                      label: 'Completed',
                      count: completed),
                  const SizedBox(height: 8),
                  _LegendItem(
                      color: Colors.grey, label: 'Draft', count: draft),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legend Item ──────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final String? pct;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
    this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      if (pct != null)
        Text('$pct% ',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text('$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }
}

// ─── Extension for mapIndexed ────────────────────────────────────────────────

extension IterableMapIndexed<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E element) f) sync* {
    int i = 0;
    for (final element in this) {
      yield f(i++, element);
    }
  }
}
