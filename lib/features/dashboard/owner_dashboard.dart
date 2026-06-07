import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/klasivo_components.dart';

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(userNameProvider) ?? 'Owner';
    final orgAsync = ref.watch(currentOrganizationProvider);
    final unreadNotifs = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentOrganizationProvider);
          ref.invalidate(notificationsProvider);
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
                      color: Theme.of(context).brightness == Brightness.dark
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
                  onPressed: () {
                    // Navigate to inbox
                  },
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

                    // ── Analytics Cards ──
                    const KlasivoSectionHeader(title: 'Overview'),
                    const SizedBox(height: KlasivoSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '1,245',
                            label: 'Students',
                            trend: '+12%',
                            trendPositive: true,
                            icon: Icons.people_outline_rounded,
                            color: KlasivoColors.primary,
                            onTap: () {
                              // Navigate to People
                            },
                          ),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '84%',
                            label: 'Attendance',
                            trend: '+4%',
                            trendPositive: true,
                            icon: Icons.how_to_reg_outlined,
                            color: KlasivoColors.secondary,
                            onTap: () {
                              // Navigate to Attendance
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '23',
                            label: 'Active Exams',
                            trend: '+3',
                            trendPositive: true,
                            icon: Icons.quiz_outlined,
                            color: KlasivoColors.accent,
                            onTap: () {
                              // Navigate to Exams
                            },
                          ),
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        Expanded(
                          child: KlasivoAnalyticsCard(
                            value: '15',
                            label: 'Teachers',
                            icon: Icons.person_outline_rounded,
                            color: const Color(0xFF845EF7),
                            onTap: () {
                              // Navigate to Teachers
                            },
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
                          onTap: () {},
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        _QuickActionChip(
                          icon: Icons.person_add_outlined,
                          label: 'Add Teacher',
                          color: KlasivoColors.secondary,
                          onTap: () {},
                        ),
                        const SizedBox(width: KlasivoSpacing.md),
                        _QuickActionChip(
                          icon: Icons.group_add_outlined,
                          label: 'Add Student',
                          color: KlasivoColors.accent,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: KlasivoSpacing.xxl),

                    // ── Recent Activity ──
                    const KlasivoSectionHeader(
                      title: 'Recent Activity',
                      actionLabel: 'View All',
                    ),
                    const SizedBox(height: KlasivoSpacing.md),
                    _RecentActivityList(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

class _RecentActivityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Placeholder — will be replaced with real data from providers
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.xxl),
        child: KlasivoEmptyState(
          icon: Icons.timeline_outlined,
          title: 'No Recent Activity',
          subtitle: 'Activity will appear here as you and your team use Klasivo',
          iconColor: KlasivoColors.primary,
        ),
      ),
    );
  }
}
