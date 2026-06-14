import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/theme.dart';
import '../../../core/services/progress_tracking_service.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_card.dart';

// ─── Progress Service Provider ────────────────────────────────────────────────

final progressServiceProvider = Provider<ProgressTrackingService>((ref) => ProgressTrackingService());

final classProgressStreamProvider = StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(progressServiceProvider).getClassProgressStream(classId);
});

final classProgressSummaryProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, classId) {
  return ref.read(progressServiceProvider).getClassSummary(classId);
});

final atRiskStudentsProvider = StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  return ref.read(progressServiceProvider).getAtRiskStudentsStream(classId);
});

// ─── Progress Tracking Screen ─────────────────────────────────────────────────

class ProgressTrackingScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;

  const ProgressTrackingScreen({
    Key? key,
    required this.classId,
    this.className = 'Class',
  }) : super(key: key);

  @override
  ConsumerState<ProgressTrackingScreen> createState() => _ProgressTrackingScreenState();
}

class _ProgressTrackingScreenState extends ConsumerState<ProgressTrackingScreen>
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
    final summaryAsync = ref.watch(classProgressSummaryProvider(widget.classId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} — Progress'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Students'),
            Tab(text: 'At Risk'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverview(summaryAsync),
          _buildStudentList(),
          _buildAtRiskList(),
        ],
      ),
    );
  }

  Widget _buildOverview(AsyncValue<Map<String, dynamic>> summaryAsync) {
    return summaryAsync.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => ErrorWidgetCustom(
        message: 'Failed to load summary: $e',
        onRetry: () => ref.invalidate(classProgressSummaryProvider(widget.classId)),
      ),
      data: (summary) {
        final totalStudents = summary['totalStudents'] as int? ?? 0;
        final avgProgress = summary['averageProgress'] as double? ?? 0;
        final excellent = summary['excellent'] as int? ?? 0;
        final good = summary['good'] as int? ?? 0;
        final average = summary['average'] as int? ?? 0;
        final belowAverage = summary['belowAverage'] as int? ?? 0;
        final atRisk = summary['atRisk'] as int? ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary Cards Row ──
              Row(
                children: [
                  Expanded(
                    child: KlasivoAnalyticsCard(
                      value: '${avgProgress.toStringAsFixed(0)}%',
                      label: 'Average Progress',
                      icon: Icons.trending_up_rounded,
                      color: KlasivoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KlasivoAnalyticsCard(
                      value: '$totalStudents',
                      label: 'Total Students',
                      icon: Icons.people_outline,
                      color: KlasivoColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Grade Distribution ──
              const Text(
                'Grade Distribution',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _DistributionBar(
                label: 'Excellent',
                count: excellent,
                total: totalStudents,
                color: KlasivoColors.secondary,
              ),
              const SizedBox(height: 8),
              _DistributionBar(
                label: 'Good',
                count: good,
                total: totalStudents,
                color: KlasivoColors.primary,
              ),
              const SizedBox(height: 8),
              _DistributionBar(
                label: 'Average',
                count: average,
                total: totalStudents,
                color: KlasivoColors.accent,
              ),
              const SizedBox(height: 8),
              _DistributionBar(
                label: 'Below Average',
                count: belowAverage,
                total: totalStudents,
                color: Colors.orange[700]!,
              ),
              const SizedBox(height: 8),
              _DistributionBar(
                label: 'At Risk',
                count: atRisk,
                total: totalStudents,
                color: KlasivoColors.error,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentList() {
    final asyncProgress = ref.watch(classProgressStreamProvider(widget.classId));

    return asyncProgress.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => ErrorWidgetCustom(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(classProgressStreamProvider(widget.classId)),
      ),
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.trending_up_outlined,
            title: 'No Progress Data',
            subtitle: 'Progress data will appear after students take exams.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.docs[index].data() as Map<String, dynamic>;
            return _StudentProgressCard(data: data);
          },
        );
      },
    );
  }

  Widget _buildAtRiskList() {
    final asyncAtRisk = ref.watch(atRiskStudentsProvider(widget.classId));

    return asyncAtRisk.when(
      loading: () => const Center(child: KlasivoLoading()),
      error: (e, _) => ErrorWidgetCustom(
        message: 'Failed to load: $e',
        onRetry: () => ref.invalidate(atRiskStudentsProvider(widget.classId)),
      ),
      data: (snapshot) {
        if (snapshot.docs.isEmpty) {
          return const KlasivoEmptyState(
            icon: Icons.verified_outlined,
            title: 'No Students At Risk',
            subtitle: 'All students are performing above the risk threshold.',
            iconColor: KlasivoColors.secondary,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.docs[index].data() as Map<String, dynamic>;
            return _StudentProgressCard(data: data, isAtRisk: true);
          },
        );
      },
    );
  }
}

class _StudentProgressCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAtRisk;

  const _StudentProgressCard({required this.data, this.isAtRisk = false});

  @override
  Widget build(BuildContext context) {
    final overallProgress = (data['overallProgress'] as num?)?.toDouble() ?? 0;
    final examAverage = (data['examAverage'] as num?)?.toDouble() ?? 0;
    final attendanceRate = (data['attendanceRate'] as num?)?.toDouble() ?? 0;
    final assignmentRate = (data['assignmentRate'] as num?)?.toDouble() ?? 0;
    final gradeLevel = data['gradeLevel'] as String? ?? 'average';

    Color gradeColor;
    String gradeLabel;
    switch (gradeLevel) {
      case 'excellent':
        gradeColor = KlasivoColors.secondary;
        gradeLabel = 'Excellent';
        break;
      case 'good':
        gradeColor = KlasivoColors.primary;
        gradeLabel = 'Good';
        break;
      case 'average':
        gradeColor = KlasivoColors.accent;
        gradeLabel = 'Average';
        break;
      case 'below_average':
        gradeColor = Colors.orange[700]!;
        gradeLabel = 'Below Avg';
        break;
      case 'at_risk':
        gradeColor = KlasivoColors.error;
        gradeLabel = 'At Risk';
        break;
      default:
        gradeColor = Colors.grey;
        gradeLabel = gradeLevel;
    }

    return KlasivoCard(
      margin: const EdgeInsets.only(bottom: 12),
      variant: isAtRisk ? KlasivoCardVariant.elevated : KlasivoCardVariant.outlined,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student ${data['studentId']?.toString().substring(0, 6) ?? 'Unknown'}...',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gradeLabel,
                          style: TextStyle(color: gradeColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${overallProgress.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                    const Text('Overall', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _MetricChip(label: 'Exams ${examAverage.toStringAsFixed(0)}%', color: KlasivoColors.primary),
                const SizedBox(width: 8),
                _MetricChip(label: 'Attend ${attendanceRate.toStringAsFixed(0)}%', color: KlasivoColors.secondary),
                const SizedBox(width: 8),
                _MetricChip(label: 'Assign ${assignmentRate.toStringAsFixed(0)}%', color: KlasivoColors.accent),
              ],
            ),
          ],
        ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetricChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _DistributionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
