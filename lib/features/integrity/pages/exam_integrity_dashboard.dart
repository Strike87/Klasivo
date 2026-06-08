import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../providers/exam_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/violation_provider.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/violation_service.dart';

class ExamIntegrityDashboard extends ConsumerStatefulWidget {
  const ExamIntegrityDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<ExamIntegrityDashboard> createState() =>
      _ExamIntegrityDashboardState();
}

class _ExamIntegrityDashboardState
    extends ConsumerState<ExamIntegrityDashboard> {
  String? _selectedExamId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exams = ref.watch(examsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Integrity'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Exam Selector ──
            Text('Select Exam',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedExamId,
              decoration: const InputDecoration(
                hintText: 'Choose an exam to inspect',
                prefixIcon: Icon(Icons.shield_outlined),
                border: OutlineInputBorder(),
              ),
              items: exams
                  .where((e) => e.status == AppConstants.statusPublished)
                  .map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.title),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedExamId = val);
              },
            ),
            const SizedBox(height: 24),

            // ── Integrity Content ──
            if (_selectedExamId != null)
              _ExamIntegrityContent(examId: _selectedExamId!)
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Select an exam to view integrity data',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExamIntegrityContent extends ConsumerWidget {
  final String examId;

  const _ExamIntegrityContent({required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violationsAsync = ref.watch(violationsByExamProvider(examId));
    final theme = Theme.of(context);

    return violationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (snapshot) {
        final violations = snapshot.docs
            .map((doc) => ViolationData.fromFirestore(doc))
            .toList();

        if (violations.isEmpty) {
          return Card(
            color: Colors.green.withValues(alpha: 0.05),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text('No Violations Detected',
                      style: TextStyle(
                          color: Colors.green[700],
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('All students completed this exam without violations',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          );
        }

        // Calculate summary stats
        int highCount = 0, mediumCount = 0, lowCount = 0;
        int unreviewedCount = 0;
        final typeCounts = <String, int>{};
        final studentCounts = <String, int>{};

        for (final v in violations) {
          switch (v.severity) {
            case 'high':
              highCount++;
              break;
            case 'medium':
              mediumCount++;
              break;
            case 'low':
              lowCount++;
              break;
          }
          if (!v.isReviewed) unreviewedCount++;
          typeCounts[v.type] = (typeCounts[v.type] ?? 0) + 1;
          studentCounts[v.studentId] =
              (studentCounts[v.studentId] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Overview Cards ──
            Row(children: [
              _IntegrityCard(
                  title: 'Total',
                  value: '${violations.length}',
                  color: Colors.blue,
                  icon: Icons.warning_amber_outlined),
              const SizedBox(width: 8),
              _IntegrityCard(
                  title: 'High',
                  value: '$highCount',
                  color: Colors.red,
                  icon: Icons.error_outline),
              const SizedBox(width: 8),
              _IntegrityCard(
                  title: 'Medium',
                  value: '$mediumCount',
                  color: Colors.orange,
                  icon: Icons.warning_outlined),
              const SizedBox(width: 8),
              _IntegrityCard(
                  title: 'Low',
                  value: '$lowCount',
                  color: Colors.amber,
                  icon: Icons.info_outline),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _IntegrityCard(
                  title: 'Unreviewed',
                  value: '$unreviewedCount',
                  color: Colors.purple,
                  icon: Icons.pending_outlined),
              const SizedBox(width: 8),
              _IntegrityCard(
                  title: 'Flagged',
                  value: '${violations.where((v) => v.severity == 'high').length}',
                  color: Colors.red,
                  icon: Icons.flag_outlined),
            ]),
            const SizedBox(height: 24),

            // ── Severity Distribution ──
            Text('Severity Distribution',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        if (highCount > 0)
                          PieChartSectionData(
                            value: highCount.toDouble(),
                            color: Colors.red,
                            title: 'High\n$highCount',
                            radius: 50,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        if (mediumCount > 0)
                          PieChartSectionData(
                            value: mediumCount.toDouble(),
                            color: Colors.orange,
                            title: 'Med\n$mediumCount',
                            radius: 50,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        if (lowCount > 0)
                          PieChartSectionData(
                            value: lowCount.toDouble(),
                            color: Colors.amber,
                            title: 'Low\n$lowCount',
                            radius: 50,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Violation Type Breakdown ──
            Text('Violation Types',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: typeCounts.entries.map((entry) {
                    final typeLabel = _getTypeLabel(entry.key);
                    final icon = _getTypeIcon(entry.key);
                    final maxCount =
                        typeCounts.values.fold(0, (a, b) => a > b ? a : b);
                    final pct = maxCount > 0 ? entry.value / maxCount : 0.0;
                    final color = _getTypeColor(entry.key);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 120,
                            child: Text(typeLabel,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Colors.grey[200],
                                color: color,
                                minHeight: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 30,
                            child: Text('${entry.value}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Top Violators ──
            Text('Top Violators',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _getTopViolators(studentCounts, ref).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                item.count >= 3 ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                            child: Text('${item.count}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: item.count >= 3
                                        ? Colors.red
                                        : Colors.orange,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.name,
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.count >= 3
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.count >= 3 ? 'FLAGGED' : 'WARNING',
                              style: TextStyle(
                                  color: item.count >= 3
                                      ? Colors.red
                                      : Colors.orange,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Violation Timeline ──
            Text('Recent Violations',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...violations.take(20).map((v) => _ViolationTile(
                  violation: v,
                  students: ref.watch(allStudentsProvider),
                )),
          ],
        );
      },
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case AppConstants.violationAppMinimized:
        return 'App Minimized';
      case AppConstants.violationAppSwitched:
        return 'App Switched';
      case AppConstants.violationScreenOff:
        return 'Screen Off';
      case AppConstants.violationScreenshotAttempt:
        return 'Screenshot';
      case AppConstants.violationScreenRecording:
        return 'Recording';
      case AppConstants.violationMultipleLogin:
        return 'Multi Login';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case AppConstants.violationAppMinimized:
        return Icons.minimize;
      case AppConstants.violationAppSwitched:
        return Icons.swap_horiz;
      case AppConstants.violationScreenOff:
        return Icons.screen_lock_portrait;
      case AppConstants.violationScreenshotAttempt:
        return Icons.screenshot;
      case AppConstants.violationScreenRecording:
        return Icons.videocam;
      case AppConstants.violationMultipleLogin:
        return Icons.login;
      default:
        return Icons.warning;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case AppConstants.violationScreenshotAttempt:
      case AppConstants.violationScreenRecording:
      case AppConstants.violationMultipleLogin:
        return Colors.red;
      case AppConstants.violationAppSwitched:
      case AppConstants.violationAppMinimized:
        return Colors.orange;
      case AppConstants.violationScreenOff:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  List<_ViolatorInfo> _getTopViolators(
      Map<String, int> studentCounts, WidgetRef ref) {
    final students = ref.read(allStudentsProvider);
    final sorted = studentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) {
      final student = students.where((s) => s.id == e.key).firstOrNull;
      return _ViolatorInfo(
        studentId: e.key,
        name: student?.fullName ?? 'Unknown Student',
        count: e.value,
      );
    }).toList();
  }
}

// ─── Helper Classes ──────────────────────────────────────────────────────────

class _ViolatorInfo {
  final String studentId;
  final String name;
  final int count;

  _ViolatorInfo({
    required this.studentId,
    required this.name,
    required this.count,
  });
}

class _IntegrityCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _IntegrityCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: color)),
              Text(title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViolationTile extends StatelessWidget {
  final ViolationData violation;
  final List<StudentData> students;

  const _ViolationTile({
    required this.violation,
    required this.students,
  });

  @override
  Widget build(BuildContext context) {
    final student =
        students.where((s) => s.id == violation.studentId).firstOrNull;
    final studentName = student?.fullName ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: violation.severityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(violation.typeIcon,
              color: violation.severityColor, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(studentName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: violation.severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(violation.severity.toUpperCase(),
                  style: TextStyle(
                      color: violation.severityColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(violation.typeLabel,
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            if (violation.timestamp != null)
              Text(
                DateFormat('MMM dd, HH:mm').format(violation.timestamp!),
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
          ],
        ),
        trailing: violation.isReviewed
            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
            : const Icon(Icons.pending, color: Colors.orange, size: 20),
      ),
    );
  }
}
