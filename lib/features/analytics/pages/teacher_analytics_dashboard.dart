import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            Row(children: [
              _StatCard(title: 'Classes', value: '$totalClasses', color: Colors.blue, icon: Icons.class_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Students', value: '$totalStudents', color: Colors.green, icon: Icons.people_outlined),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _StatCard(title: 'Exams', value: '${examStats['total'] ?? 0}', color: Colors.orange, icon: Icons.quiz_outlined),
              const SizedBox(width: 12),
              _StatCard(title: 'Avg Score', value: '${avgScore.toStringAsFixed(0)}%', color: Colors.purple, icon: Icons.trending_up),
            ]),
            const SizedBox(height: 24),

            // Score distribution chart
            Text('Score Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ScoreDistributionChart(submissions: submittedSubs),
            const SizedBox(height: 24),

            // Exam status breakdown
            Text('Exam Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ExamStatusChart(
              upcoming: examStats['upcoming'] ?? 0,
              completed: examStats['completed'] ?? 0,
              draft: examStats['draft'] ?? 0,
            ),
          ],
        ),
      ),
    );
  }
}

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
              Icon(icon, color: color, size: 28),
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

class _ScoreDistributionChart extends StatelessWidget {
  final List<SubmissionData> submissions;
  const _ScoreDistributionChart({required this.submissions});

  @override
  Widget build(BuildContext context) {
    // Group scores into ranges
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
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No submission data yet'))));
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
                barRods: [BarChartRodData(toY: e.value.toDouble(), color: _getColor(i), width: 32, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))],
              )).toList(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(ranges.keys.elementAt(v.toInt()), style: const TextStyle(fontSize: 10)))),
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

class _ExamStatusChart extends StatelessWidget {
  final int upcoming;
  final int completed;
  final int draft;

  const _ExamStatusChart({required this.upcoming, required this.completed, required this.draft});

  @override
  Widget build(BuildContext context) {
    final total = upcoming + completed + draft;
    if (total == 0) {
      return const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No exams yet'))));
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendItem({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }
}

// Extension for mapIndexed
extension IterableMapIndexed<E> on Iterable<E> {
  Iterable<T> mapIndexed<T>(T Function(int index, E element) f) sync* {
    int i = 0;
    for (final element in this) {
      yield f(i++, element);
    }
  }
}
