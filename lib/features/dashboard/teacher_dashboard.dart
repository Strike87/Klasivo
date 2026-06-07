import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/klasivo_components.dart';

class TeacherDashboard extends ConsumerWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider);
    final totalClasses = ref.watch(totalClassesProvider);
    final totalStudents = ref.watch(totalStudentsProvider);
    final examStats = ref.watch(examStatsProvider);
    final unreadNotifs = ref.watch(unreadNotificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classesByOrgProvider);
          ref.invalidate(studentsByOrgProvider);
          ref.invalidate(examsStreamProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              floating: true,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.sm),
                    decoration: BoxDecoration(
                      color: KlasivoColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                    ),
                    child: const Icon(
                      Icons.school_outlined,
                      color: KlasivoColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Text(
                    'Klasivo',
                    style: KlasivoTypography.titleLarge.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
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
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout, color: KlasivoColors.error),
                          const SizedBox(width: KlasivoSpacing.sm),
                          Text(
                            'Logout',
                            style: KlasivoTypography.bodyMedium.copyWith(
                              color: KlasivoColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KlasivoSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: KlasivoSpacing.lg),

                    // ── Hero Card ──
                    KlasivoHeroCard(
                      greeting: _getGreeting(),
                      name: userName ?? 'Teacher',
                      subtitle: 'Manage your exams and students efficiently.',
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Analytics Cards ──
                    const KlasivoSectionHeader(title: 'Overview'),
                    const SizedBox(height: KlasivoSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '$totalClasses',
                            label: 'Total Classes',
                            icon: Icons.class_outlined,
                            color: KlasivoColors.primary,
                            onTap: () => context.go('/teacher/classes'),
                          ),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '$totalStudents',
                            label: 'Total Students',
                            icon: Icons.people_outlined,
                            color: KlasivoColors.secondary,
                            onTap: () => context.go('/teacher/students'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '${examStats['upcoming'] ?? 0}',
                            label: 'Upcoming Exams',
                            icon: Icons.quiz_outlined,
                            color: KlasivoColors.accent,
                            onTap: () => context.go('/teacher/exams'),
                          ),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '${examStats['completed'] ?? 0}',
                            label: 'Completed',
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF845EF7),
                            onTap: () => context.go('/teacher/exams'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Quick Actions ──
                    const KlasivoSectionHeader(title: 'Quick Actions'),
                    const SizedBox(height: KlasivoSpacing.md),
                    Wrap(
                      spacing: KlasivoSpacing.md,
                      runSpacing: KlasivoSpacing.md,
                      children: [
                        _QuickAction(
                          icon: Icons.add_circle_outline,
                          label: 'Create Exam',
                          color: KlasivoColors.primary,
                          onTap: () => context.go('/teacher/exams/create'),
                        ),
                        _QuickAction(
                          icon: Icons.class_outlined,
                          label: 'Add Class',
                          color: KlasivoColors.secondary,
                          onTap: () => context.go('/teacher/classes/create'),
                        ),
                        _QuickAction(
                          icon: Icons.library_books_outlined,
                          label: 'Question Bank',
                          color: KlasivoColors.secondaryLight,
                          onTap: () => context.go('/teacher/question-bank'),
                        ),
                        _QuickAction(
                          icon: Icons.upload_file,
                          label: 'Import Students',
                          color: KlasivoColors.primaryDark,
                          onTap: () => context.go('/teacher/classes'),
                        ),
                        _QuickAction(
                          icon: Icons.school_outlined,
                          label: 'Stages',
                          color: KlasivoColors.subjectArabic,
                          onTap: () => context.go('/teacher/stages'),
                        ),
                        _QuickAction(
                          icon: Icons.analytics_outlined,
                          label: 'Analytics',
                          color: const Color(0xFF845EF7),
                          onTap: () => context.go('/teacher/analytics'),
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Recent Classes ──
                    KlasivoSectionHeader(
                      title: 'My Classes',
                      actionLabel: 'View All',
                      onAction: () => context.go('/teacher/classes'),
                    ),
                    const SizedBox(height: KlasivoSpacing.md),
                    _RecentClassesList(),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Recent Students ──
                    KlasivoSectionHeader(
                      title: 'Recent Students',
                      actionLabel: 'View All',
                      onAction: () => context.go('/teacher/students'),
                    ),
                    const SizedBox(height: KlasivoSpacing.md),
                    _RecentStudentsList(),
                    const SizedBox(height: KlasivoSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/teacher/exams/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Exam'),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ─── Recent Classes Widget ───────────────────────────────────────────────────

class _RecentClassesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (classes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.xxl),
          child: KlasivoEmptyState(
            icon: Icons.class_outlined,
            title: 'No classes yet',
            subtitle: 'Create your first class to get started',
            iconColor: KlasivoColors.primary,
          ),
        ),
      );
    }

    final recentClasses = classes.take(3).toList();

    return Card(
      child: Column(
        children: recentClasses.map((classData) {
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(KlasivoSpacing.sm),
              decoration: BoxDecoration(
                color: KlasivoColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
              ),
              child: const Icon(
                Icons.class_outlined,
                color: KlasivoColors.primary,
                size: 24,
              ),
            ),
            title: Text(
              classData.name,
              style: KlasivoTypography.titleMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              '${classData.studentCount} students${classData.academicYear != null ? ' · ${classData.academicYear}' : ''}',
              style: KlasivoTypography.bodySmall.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark
                  ? KlasivoColors.darkTextTertiary
                  : KlasivoColors.lightTextTertiary,
            ),
            onTap: () => context.go('/teacher/classes/${classData.id}/students'),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Recent Students Widget ──────────────────────────────────────────────────

class _RecentStudentsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(allStudentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (students.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.xxl),
          child: KlasivoEmptyState(
            icon: Icons.people_outline,
            title: 'No students yet',
            subtitle: 'Add students to your classes',
            iconColor: KlasivoColors.secondary,
          ),
        ),
      );
    }

    final recentStudents = students.take(5).toList();

    return Card(
      child: Column(
        children: recentStudents.map((student) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: KlasivoColors.secondary.withOpacity(0.1),
              child: Text(
                student.fullName.isNotEmpty
                    ? student.fullName[0].toUpperCase()
                    : '?',
                style: KlasivoTypography.titleMedium.copyWith(
                  color: KlasivoColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student.fullName,
              style: KlasivoTypography.titleSmall.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
            ),
            subtitle: Text(
              '${student.studentCode}',
              style: KlasivoTypography.bodySmall.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
          );
        }).toList(),
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
      width: (MediaQuery.of(context).size.width - KlasivoSpacing.lg * 2 - KlasivoSpacing.md * 2) / 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: KlasivoSpacing.md + 2,
            horizontal: KlasivoSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(KlasivoRadius.md),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: KlasivoSpacing.sm),
              Text(
                label,
                style: KlasivoTypography.labelSmall.copyWith(color: color),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
