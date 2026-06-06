import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/exam_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../../core/config/app_constants.dart';

class TeacherAnalyticsDashboard extends ConsumerWidget {
  const TeacherAnalyticsDashboard({Key? key}) : super(key: key);

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
        ? submittedSubs.fold<int>(0, (sum, s) => sum + s.percentage) / submittedSubs.length
        : 0.0;

    // Calculate pass/fail counts
    final passCount = submittedSubs.where((s) => s.percentage >= 50).length;
    final failCount = submittedSubs.length - passCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics Dashboard'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary Cards Row 1 ──
            Row(children: [
              _StatCard(title: 'Classes', value: '$totalClasses', color: Colors.blue, icon: Icons.class_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Students', value: '$totalStudents', color: Colors.green, icon: Icons.people_outlined),
            ]),
            const SizedBox(height: 12),
            // ── Summary Cards Row 2 ──
            Row(children: [
              _StatCard(title: 'Total Exams', value: '${examStats['total'] ?? 0}', color: Colors.orange, icon: Icons.quiz_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Avg Score', value: '${avgScore.toStringAsFixed(0)}%', color: Colors.purple, icon: Icons.trending_up),
            ]),
            const SizedBox(height: 12),
            // ── Summary Cards Row 3 ──
            Row(children: [
              _StatCard(title: 'Pass Rate', value: submittedSubs.isNotEmpty ? '${(passCount / submittedSubs.length * 100).toStringAsFixed(0)}%' : '-', color: Colors.teal, icon: Icons.check_circle_outline),
              const SizedBox(width: 12),
              _StatCard(title: 'Upcoming', value: '${examStats['upcoming'] ?? 0}', color: Colors.indigo, icon: Icons.upcoming_outlined),
            ]),
            const SizedBox(height: 24),

            // ── Score Distribution Chart ──
            Text('Score Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ScoreDistributionChart(submissions: submittedSubs),
            const SizedBox(height: 24),

            // ── Pass/Fail Pie Chart ──
            Text('Pass / Fail Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _PassFailChart(passCount: passCount, failCount: failCount),
            const SizedBox(height: 24),

            // ── Exam Status Breakdown ──
            Text('Exam Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ExamStatusChart(
              upcoming: examStats['upcoming'] ?? 0,
              completed: examStats['completed'] ?? 0,
              draft: examStats['draft'] ?? 0,
            ),
            const SizedBox(height: 24,

            // ── Quick Navigation ──
            Text('Quick Access', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickNavCard(title: 'Question Bank', icon: Icons.library_books_outlined, color: Colors.teal, onTap: () => context.go('/teacher/question-bank')),
                _QuickNavCard(title: 'Stages', icon: Icons.school_outlined, color: Colors.pink, onTap: () => context.go('/teacher/stages')),
                _QuickNavCard(title: 'All Exams', icon: Icons.quiz_outlined, color: Colors.orange, onTap: () => context.go('/teacher/exams')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Nav Card ──────────────────────────────────────────────────────────

class _QuickNavCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickNavCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
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
      if (s.percentage <= 20) ranges['0-20%'] = ranges['0-20%']! + 1;
      else if (s.percentage <= 40) ranges['21-40%'] = ranges['21-40%']! + 1;
      else if (s.percentage <= 60) ranges['41-60%'] = ranges['41-60%']! + 1;
      else if (s.percentage <= 80) ranges['61-80%'] = ranges['61-80%']! + 1;
      else ranges['81-100%'] = ranges['81-100%']! + 1;
    }

    final maxCount = ranges.values.fold(0, (a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('No submission data yet', style: TextStyle(color: Colors.grey[500]))),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                barRods: [BarChartRodData(
                  toY: e.value.toDouble(),
                  color: _getColor(i),
                  width: 32,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                )],
              )).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(ranges.keys.elementAt(v.toInt()), style: const TextStyle(fontSize: 9)),
                  ),
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      case 0: return Colors.red;
      case 1: return Colors.orange;
      case 2: return Colors.amber;
      case 3: return Colors.lightGreen;
      case 4: return Colors.green;
      default: return Colors.grey;
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
        child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No results yet', style: TextStyle(color: Colors.grey[500])))),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    PieChartSectionData(
                      value: failCount.toDouble(),
                      color: Colors.red,
                      title: failCount > 0 ? '$failCount' : '',
                      radius: 40,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                  _LegendItem(color: Colors.green, label: 'Passed', count: passCount, pct: total > 0 ? (passCount / total * 100).toStringAsFixed(0) : '0'),
                  const SizedBox(height: 12),
                  _LegendItem(color: Colors.red, label: 'Failed', count: failCount, pct: total > 0 ? (failCount / total * 100).toStringAsFixed(0) : '0'),
                  const SizedBox(height: 12),
                  Text('Total: $total submissions', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
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

  const _ExamStatusChart({required this.upcoming, required this.completed, required this.draft});

  @override
  Widget build(BuildContext context) {
    final total = upcoming + completed + draft;
    if (total == 0) {
      return Card(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No exams yet', style: TextStyle(color: Colors.grey[500])))));
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    PieChartSectionData(value: upcoming.toDouble(), color: Colors.orange, title: upcoming > 0 ? '$upcoming' : '', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    PieChartSectionData(value: completed.toDouble(), color: Colors.green, title: completed > 0 ? '$completed' : '', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    PieChartSectionData(value: draft.toDouble(), color: Colors.grey, title: draft > 0 ? '$draft' : '', radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LegendItem(color: Colors.orange, label: 'Upcoming', count: upcoming),
                  const SizedBox(height: 8),
                  _LegendItem(color: Colors.green, label: 'Completed', count: completed),
                  const SizedBox(height: 8),
                  _LegendItem(color: Colors.grey, label: 'Draft', count: draft),
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

  const _LegendItem({required this.color, required this.label, required this.count, this.pct});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      if (pct != null) Text('$pct% ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
