import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/exam_provider.dart';
import '../../../widgets/klasivo_components.dart';
class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider) ?? 'Owner';
    final orgAsync = ref.watch(currentOrganizationProvider);
    final unreadNotifs = ref.watch(unreadNotificationsProvider);
    final totalStudents = ref.watch(totalStudentsProvider);
    final totalClasses = ref.watch(totalClassesProvider);
    final examStats = ref.watch(examStatsProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentOrganizationProvider);
          ref.invalidate(notificationsProvider);
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
                  onPressed: () => context.go('/inbox'),
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
                    orgAsync.when(
                      data: (org) {
                        final orgName = org?['name'] ?? 'Your Workspace';
                        return KlasivoHeroCard(
                          greeting: _getGreeting(),
                          name: userName,
                          subtitle: orgName,
                        );
                      },
                      loading: () => KlasivoHeroCard(
                        greeting: _getGreeting(),
                        name: userName,
                      ),
                      error: (_, __) => KlasivoHeroCard(
                        greeting: _getGreeting(),
                        name: userName,
                      ),
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Analytics Cards (Real Data) ──
                    const KlasivoSectionHeader(title: 'Overview'),
                    const SizedBox(height: KlasivoSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '$totalStudents',
                            label: 'Students',
                            icon: Icons.people_outline_rounded,
                            color: KlasivoColors.primary,
                            onTap: () => context.go('/people'),
                          ),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '$totalClasses',
                            label: 'Classes',
                            icon: Icons.class_outlined,
                            color: KlasivoColors.secondary,
                            onTap: () => context.go('/academic'),
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
                            label: 'Active Exams',
                            icon: Icons.quiz_outlined,
                            color: KlasivoColors.accent,
                            onTap: () => context.go('/academic'),
                          ),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        Expanded(
                          child: _TeachersCountCard(
                            onTap: () => context.go('/people'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Quick Actions ──
                    const KlasivoSectionHeader(title: 'Quick Actions'),
                    const SizedBox(height: KlasivoSpacing.md),
                    Row(
                      children: [
                        _QuickActionChip(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'New Exam',
                          color: KlasivoColors.primary,
                          onTap: () => context.go('/academic'),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        _QuickActionChip(
                          icon: Icons.person_add_outlined,
                          label: 'Add Student',
                          color: KlasivoColors.secondary,
                          onTap: () => context.go('/people'),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        _QuickActionChip(
                          icon: Icons.notifications_outlined,
                          label: 'Inbox',
                          color: KlasivoColors.accent,
                          onTap: () => context.go('/inbox'),
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Recent Notifications ──
                    const KlasivoSectionHeader(
                      title: 'Recent Notifications',
                      actionLabel: 'View All',
                    ),
                    const SizedBox(height: KlasivoSpacing.md),
                    _RecentNotificationsList(),
                    const SizedBox(height: KlasivoSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ],
        ),
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

class _TeachersCountCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _TeachersCountCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachersAsync = ref.watch(organizationTeachersProvider);
    return teachersAsync.when(
      data: (snapshot) => KlasivoAnalyticsCard(
        value: '${snapshot.docs.length}',
        label: 'Teachers',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF845EF7),
        onTap: onTap,
      ),
      loading: () => KlasivoAnalyticsCard(
        value: '-',
        label: 'Teachers',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF845EF7),
      ),
      error: (_, __) => KlasivoAnalyticsCard(
        value: '0',
        label: 'Teachers',
        icon: Icons.person_outline_rounded,
        color: const Color(0xFF845EF7),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KlasivoSpacing.md,
            vertical: KlasivoSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(KlasivoRadius.md),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: KlasivoSpacing.sm),
              Text(
                label,
                style: KlasivoTypography.labelSmall.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentNotificationsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (notifications.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(KlasivoSpacing.xxl),
          child: KlasivoEmptyState(
            icon: Icons.notifications_none_outlined,
            title: 'No Notifications',
            subtitle: 'Notifications will appear here as your organization grows',
            iconColor: KlasivoColors.primary,
          ),
        ),
      );
    }

    final recent = notifications.take(5).toList();

    return Card(
      child: Column(
        children: recent.map((n) {
          return ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(KlasivoSpacing.sm),
              decoration: BoxDecoration(
                color: _typeColor(n.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
              ),
              child: Icon(_typeIcon(n.type), color: _typeColor(n.type), size: 18),
            ),
            title: Text(
              n.title,
              style: KlasivoTypography.bodyMedium.copyWith(
                fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              n.body,
              style: KlasivoTypography.bodySmall.copyWith(
                color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: !n.isRead
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: KlasivoColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          );
        }).toList(),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case AppConstants.notificationExamPublished:
        return Icons.publish_outlined;
      case AppConstants.notificationExamReminder:
        return Icons.timer_outlined;
      case AppConstants.notificationResultPublished:
        return Icons.assessment_outlined;
      case AppConstants.notificationNewMessage:
        return Icons.message_outlined;
      case AppConstants.notificationStudentJoined:
        return Icons.person_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case AppConstants.notificationExamPublished:
        return KlasivoColors.primary;
      case AppConstants.notificationExamReminder:
        return KlasivoColors.accent;
      case AppConstants.notificationResultPublished:
        return KlasivoColors.secondary;
      case AppConstants.notificationNewMessage:
        return const Color(0xFF845EF7);
      default:
        return KlasivoColors.primary;
    }
  }
}
