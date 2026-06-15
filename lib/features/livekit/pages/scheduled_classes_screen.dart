import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/scheduled_class_model.dart';
import '../providers/livekit_providers.dart';
import 'live_class_lobby_screen.dart';

/// Screen showing upcoming scheduled classes for students and teachers.
/// Teachers can schedule new classes; students see what's coming up.
class ScheduledClassesScreen extends ConsumerWidget {
  final String orgId;
  final String userId;
  final String displayName;
  final bool isTeacher;

  const ScheduledClassesScreen({
    super.key,
    required this.orgId,
    required this.userId,
    required this.displayName,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(upcomingClassesProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Classes'),
        actions: [
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Schedule Class',
              onPressed: () => _showScheduleDialog(context, ref),
            ),
        ],
      ),
      body: classesAsync.when(
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming classes',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  if (isTeacher) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Schedule a Class'),
                      onPressed: () => _showScheduleDialog(context, ref),
                    ),
                  ],
                ],
              ),
            );
          }

          // Group by date
          final grouped = <String, List<ScheduledClass>>{};
          for (final c in classes) {
            final dateKey = '${c.startsAt.year}-${c.startsAt.month.toString().padLeft(2, '0')}-${c.startsAt.day.toString().padLeft(2, '0')}';
            grouped.putIfAbsent(dateKey, () => []).add(c);
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(upcomingClassesProvider(orgId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final dateKey = grouped.keys.elementAt(index);
                final dayClasses = grouped[dateKey]!;
                final date = DateTime.parse(dateKey);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _formatDate(date),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                    ...dayClasses.map((c) => _ScheduledClassCard(
                          scheduledClass: c,
                          isTeacher: isTeacher,
                          onJoin: () => _navigateToLobby(context),
                          onDelete: () => _deleteClass(context, ref, c),
                        )),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    return '$weekday, ${date.day}/${date.month}';
  }

  void _navigateToLobby(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveClassLobbyScreen(
          orgId: orgId,
          userId: userId,
          displayName: displayName,
          isTeacher: isTeacher,
        ),
      ),
    );
  }

  Future<void> _deleteClass(BuildContext context, WidgetRef ref, ScheduledClass c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Class?'),
        content: Text('Cancel "${c.title}" scheduled for ${c.startsAt.hour}:${c.startsAt.minute.toString().padLeft(2, '0')}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Class'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(liveKitRepositoryProvider);
      await repo.deleteScheduledClass(c.id);
    }
  }

  void _showScheduleDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    DateTime scheduledDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay scheduledTime = const TimeOfDay(hour: 9, minute: 0);
    int duration = 45;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule a Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Class Title *', hintText: 'e.g., Math Grade 6'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject', hintText: 'e.g., Mathematics'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classCtrl,
                  decoration: const InputDecoration(labelText: 'Class/Grade', hintText: 'e.g., Grade 6'),
                ),
                const SizedBox(height: 16),
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Date: ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setDialogState(() => scheduledDate = picked);
                  },
                ),
                // Time picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text('Time: ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}'),
                  onTap: () async {
                    final picked = await showTimePicker(context: ctx, initialTime: scheduledTime);
                    if (picked != null) setDialogState(() => scheduledTime = picked);
                  },
                ),
                // Duration
                DropdownButtonFormField<int>(
                  value: duration,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    DropdownMenuItem(value: 45, child: Text('45 minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                    DropdownMenuItem(value: 120, child: Text('2 hours')),
                  ],
                  onChanged: (v) => setDialogState(() => duration = v ?? 45),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;

                final startsAt = DateTime(
                  scheduledDate.year,
                  scheduledDate.month,
                  scheduledDate.day,
                  scheduledTime.hour,
                  scheduledTime.minute,
                );

                final repo = ref.read(liveKitRepositoryProvider);
                await repo.createScheduledClass(ScheduledClass(
                  id: '',
                  title: title,
                  organizationId: orgId,
                  teacherId: userId,
                  teacherName: displayName,
                  subjectName: subjectCtrl.text.trim().isNotEmpty ? subjectCtrl.text.trim() : null,
                  className: classCtrl.text.trim().isNotEmpty ? classCtrl.text.trim() : null,
                  startsAt: startsAt,
                  durationMinutes: duration,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scheduled Class Card ─────────────────────────────────────────

class _ScheduledClassCard extends StatelessWidget {
  final ScheduledClass scheduledClass;
  final bool isTeacher;
  final VoidCallback onJoin;
  final VoidCallback onDelete;

  const _ScheduledClassCard({
    required this.scheduledClass,
    required this.isTeacher,
    required this.onJoin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final startsIn = scheduledClass.timeUntilStart;
    final isStartingSoon = startsIn.inMinutes <= 10 && startsIn.inMinutes > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isStartingSoon ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scheduledClass.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (isStartingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Starting Soon',
                      style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(scheduledClass.teacherName, style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${scheduledClass.startsAt.hour.toString().padLeft(2, '0')}:${scheduledClass.startsAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (scheduledClass.durationMinutes != null) ...[
                  const SizedBox(width: 4),
                  Text('(${scheduledClass.durationMinutes}m)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
            if (scheduledClass.subjectName != null || scheduledClass.className != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (scheduledClass.subjectName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(scheduledClass.subjectName!, style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                    ),
                  if (scheduledClass.className != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(scheduledClass.className!, style: TextStyle(fontSize: 10, color: Colors.purple.shade700)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isTeacher)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel'),
                  ),
                const SizedBox(width: 8),
                if (isStartingSoon || scheduledClass.isStarted)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(isTeacher ? 'Start Class' : 'Join'),
                    onPressed: onJoin,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
