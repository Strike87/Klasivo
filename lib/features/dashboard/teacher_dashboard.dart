import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common_widgets.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final totalClasses = ref.watch(totalClassesProvider);
    final totalStudents = ref.watch(totalStudentsProvider);
    final examStats = ref.watch(examStatsProvider);
    final unreadNotifs = ref.watch(unreadNotificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasivo'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go('/teacher/notifications'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final confirmed = await showConfirmationDialog(
                  context: context,
                  title: 'Logout',
                  message: 'Are you sure you want to logout?',
                  confirmLabel: 'Logout',
                  isDangerous: true,
                );
                if (confirmed == true && context.mounted) {
                  await clearAuthData();
                  if (context.mounted) {
                    context.go('/auth');
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classesStreamProvider);
          ref.invalidate(allStudentsStreamProvider);
          ref.invalidate(examsStreamProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Section ──
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName ?? 'Teacher',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your exams and students efficiently.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Stats Cards ──
              Row(
                children: [
                  _StatCard(
                    title: 'Total Classes',
                    value: '$totalClasses',
                    icon: Icons.class_outlined,
                    color: Colors.blue,
                    onTap: () => context.go('/teacher/classes'),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    title: 'Total Students',
                    value: '$totalStudents',
                    icon: Icons.people_outlined,
                    color: Colors.green,
                    onTap: () => context.go('/teacher/students'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    title: 'Upcoming Exams',
                    value: '${examStats['upcoming'] ?? 0}',
                    icon: Icons.quiz_outlined,
                    color: Colors.orange,
                    onTap: () => context.go('/teacher/exams'),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    title: 'Completed',
                    value: '${examStats['completed'] ?? 0}',
                    icon: Icons.check_circle_outline,
                    color: Colors.purple,
                    onTap: () => context.go('/teacher/exams'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Quick Actions ──
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _QuickAction(
                    icon: Icons.add_circle_outline,
                    label: 'Create Exam',
                    color: theme.colorScheme.primary,
                    onTap: () => context.go('/teacher/exams/create'),
                  ),
                  _QuickAction(
                    icon: Icons.class_outlined,
                    label: 'Add Class',
                    color: Colors.green,
                    onTap: () => context.go('/teacher/classes/create'),
                  ),
                  _QuickAction(
                    icon: Icons.library_books_outlined,
                    label: 'Question Bank',
                    color: Colors.teal,
                    onTap: () => context.go('/teacher/question-bank'),
                  ),
                  _QuickAction(
                    icon: Icons.upload_file,
                    label: 'Import Students',
                    color: Colors.indigo,
                    onTap: () => context.go('/teacher/classes'),
                  ),
                  _QuickAction(
                    icon: Icons.school_outlined,
                    label: 'Stages',
                    color: Colors.pink,
                    onTap: () => context.go('/teacher/stages'),
                  ),
                  _QuickAction(
                    icon: Icons.analytics_outlined,
                    label: 'Analytics',
                    color: Colors.deepPurple,
                    onTap: () => context.go('/teacher/analytics'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Recent Classes ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Classes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/teacher/classes'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentClassesList(),
              const SizedBox(height: 24),

              // ── Recent Students ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Students',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/teacher/students'),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _RecentStudentsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/teacher/exams/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Exam'),
      ),
    );
  }
}

// ─── Recent Classes Widget ───────────────────────────────────────────────────

class _RecentClassesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);

    if (classes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.class_outlined, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No classes yet', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Create your first class to get started', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    final recentClasses = classes.take(3).toList();

    return Column(
      children: recentClasses.map((classData) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.class_outlined, color: Colors.blue, size: 24),
            ),
            title: Text(classData.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${classData.studentCount} students${classData.grade != null ? ' · ${classData.grade}' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.go('/teacher/classes/${classData.id}/students'),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Recent Students Widget ──────────────────────────────────────────────────

class _RecentStudentsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(allStudentsProvider);

    if (students.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text('No students yet', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text('Add students to your classes', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    final recentStudents = students.take(5).toList();

    return Column(
      children: recentStudents.map((student) {
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green.withOpacity(0.1),
              child: Text(
                student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              '${student.studentCode} · ${student.className}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Action ────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 52) / 3,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
