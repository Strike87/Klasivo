import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/exam_instance_provider.dart';

/// Exam Instances Screen - Shows per-student exam instances for a specific exam
/// Teachers can see which students have started, randomized question order, and completion status
class ExamInstancesScreen extends ConsumerWidget {
  final String examId;

  const ExamInstancesScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final instancesAsync = ref.watch(examInstancesStreamProvider(examId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Instances'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: instancesAsync.when(
        data: (snapshot) {
          final instances = snapshot.docs
              .map((doc) => ExamInstanceData.fromFirestore(doc))
              .toList();

          if (instances.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No instances yet', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Instances are created when students start the exam',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          // Stats
          final completedCount = instances.where((i) => i.isCompleted).length;
          final randomizedCount = instances.where((i) => i.isRandomized).length;

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Total', instances.length, theme.colorScheme.primary),
                    _buildStat('Started', instances.length - completedCount, Colors.orange),
                    _buildStat('Completed', completedCount, Colors.green),
                    _buildStat('Randomized', randomizedCount, Colors.blue),
                  ],
                ),
              ),
              // Instances list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: instances.length,
                  itemBuilder: (context, index) {
                    final instance = instances[index];
                    return _buildInstanceCard(theme, instance);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 20)),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildInstanceCard(ThemeData theme, ExamInstanceData instance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status icon
                Icon(
                  instance.isCompleted ? Icons.check_circle : Icons.pending,
                  color: instance.isCompleted ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student: ${instance.studentId.substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (instance.isRandomized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Randomized', style: TextStyle(fontSize: 10, color: Colors.blue)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Started: ${_formatDate(instance.startedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (instance.completedAt != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Completed: ${_formatDate(instance.completedAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Questions: ${instance.randomizedQuestions.length} (order: ${instance.randomizedQuestions.take(3).join(', ')}${instance.randomizedQuestions.length > 3 ? '...' : ''})',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            if (instance.submissionId != null)
              Text(
                'Submission: ${instance.submissionId!.substring(0, 8)}...',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
