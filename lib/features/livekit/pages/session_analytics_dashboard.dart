import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session_analytics_model.dart';
import '../providers/livekit_providers.dart';

/// Teacher dashboard showing post-class analytics across all sessions.
/// Displays attendance, duration, messages, raised hands per session.
class SessionAnalyticsDashboard extends ConsumerWidget {
  final String orgId;
  final String? teacherId;

  const SessionAnalyticsDashboard({
    super.key,
    required this.orgId,
    this.teacherId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = teacherId != null
        ? ref.watch(teacherAnalyticsProvider(teacherId!))
        : ref.watch(orgAnalyticsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Analytics'),
      ),
      body: analyticsAsync.when(
        data: (analytics) {
          if (analytics.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No session data yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analytics will appear after your first live class ends.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Aggregate stats
          final totalSessions = analytics.length;
          final totalAttendance = analytics.fold<int>(0, (sum, a) => sum + a.attendanceCount);
          final totalDuration = analytics.fold<int>(0, (sum, a) => sum + a.durationMinutes);
          final totalMessages = analytics.fold<int>(0, (sum, a) => sum + a.messagesCount);
          final totalHandsRaised = analytics.fold<int>(0, (sum, a) => sum + a.raisedHandsCount);
          final avgAttendance = totalSessions > 0 ? (totalAttendance / totalSessions).toStringAsFixed(1) : '0';

          return CustomScrollView(
            slivers: [
              // ── Summary Cards ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatCard(label: 'Sessions', value: '$totalSessions', icon: Icons.videocam, color: Colors.blue),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Total Attendance', value: '$totalAttendance', icon: Icons.people, color: Colors.green),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Avg. Attendance', value: avgAttendance, icon: Icons.person, color: Colors.teal),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StatCard(label: 'Total Duration', value: _formatDuration(totalDuration), icon: Icons.timer, color: Colors.orange),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Messages', value: '$totalMessages', icon: Icons.chat, color: Colors.purple),
                          const SizedBox(width: 8),
                          _StatCard(label: 'Hands Raised', value: '$totalHandsRaised', icon: Icons.pan_tool, color: Colors.amber.shade800),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Per-session list ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recent Sessions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _SessionCard(analytics: analytics[index]),
                  childCount: analytics.length,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}

// ─── Stat Card ────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Session Card ─────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final SessionAnalytics analytics;

  const _SessionCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    analytics.roomName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (analytics.wasRecorded)
                  const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Recorded', style: TextStyle(fontSize: 10, color: Colors.red)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricChip(icon: Icons.people, label: '${analytics.attendanceCount} attended'),
                _MetricChip(icon: Icons.timer, label: analytics.durationLabel),
                _MetricChip(icon: Icons.chat, label: '${analytics.messagesCount} msgs'),
                _MetricChip(icon: Icons.pan_tool, label: '${analytics.raisedHandsCount} hands'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Peak: ${analytics.peakParticipants} participants',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}
