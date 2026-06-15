import 'package:flutter/material.dart';
import '../core/config/theme.dart';
import 'klasivo_card.dart';
import 'klasivo_button.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO COMPONENTS — Reusable UI building blocks for Academic Neo-Minimalism
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Analytics Card — Stripe-style "Large Number + Small Label + Trend" ──────

class KlasivoAnalyticsCard extends StatelessWidget {
  final String value;
  final String label;
  final String? trend; // e.g. "+4%", "-2%"
  final bool trendPositive;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const KlasivoAnalyticsCard({
    Key? key,
    required this.value,
    required this.label,
    this.trend,
    this.trendPositive = true,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(KlasivoSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: KlasivoSpacing.md),

          // Large Number
          Text(
            value,
            style: KlasivoTypography.displayMedium.copyWith(
              color: isDark ? KlasivoColors.darkTextPrimary : KlasivoColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: KlasivoSpacing.xs),

          // Label + Trend
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: KlasivoTypography.bodySmall.copyWith(
                    color: isDark ? KlasivoColors.darkTextTertiary : KlasivoColors.lightTextTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: KlasivoSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.sm,
                    vertical: KlasivoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: trendPositive
                        ? KlasivoColors.secondarySurface
                        : KlasivoColors.errorSurface,
                    borderRadius: BorderRadius.circular(KlasivoRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendPositive ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: trendPositive
                            ? KlasivoColors.secondary
                            : KlasivoColors.error,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: KlasivoTypography.labelSmall.copyWith(
                          color: trendPositive
                              ? KlasivoColors.secondary
                              : KlasivoColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Hero Section — Dashboard welcome card ──────────────────────────────────

class KlasivoHeroCard extends StatelessWidget {
  final String greeting;
  final String name;
  final String? subtitle;
  final String? statLine1;
  final String? statLine2;

  const KlasivoHeroCard({
    Key? key,
    required this.greeting,
    required this.name,
    this.subtitle,
    this.statLine1,
    this.statLine2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KlasivoSpacing.xxl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KlasivoRadius.lg),
        gradient: const LinearGradient(
          colors: [KlasivoColors.primary, KlasivoColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: KlasivoTypography.bodyLarge.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: KlasivoSpacing.xs),
          Text(
            name,
            style: KlasivoTypography.headlineLarge.copyWith(color: Colors.white),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: KlasivoSpacing.sm),
            Text(
              subtitle!,
              style: KlasivoTypography.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
          if (statLine1 != null || statLine2 != null) ...[
            const SizedBox(height: KlasivoSpacing.lg),
            Row(
              children: [
                if (statLine1 != null)
                  Expanded(
                    child: Text(
                      statLine1!,
                      style: KlasivoTypography.titleMedium.copyWith(color: Colors.white),
                    ),
                  ),
                if (statLine1 != null && statLine2 != null)
                  const SizedBox(width: KlasivoSpacing.lg),
                if (statLine2 != null)
                  Expanded(
                    child: Text(
                      statLine2!,
                      style: KlasivoTypography.titleMedium.copyWith(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Breadcrumb — Signature Klasivo hierarchy navigator ─────────────────────

class KlasivoBreadcrumb extends StatelessWidget {
  final List<KlasivoBreadcrumbItem> items;
  final ValueChanged<int>? onItemTap;

  const KlasivoBreadcrumb({
    Key? key,
    required this.items,
    this.onItemTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.sm,
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              InkWell(
                onTap: isLast ? null : () => onItemTap?.call(index),
                borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KlasivoSpacing.xs,
                    vertical: KlasivoSpacing.xs,
                  ),
                  child: Text(
                    item.label,
                    style: isLast
                        ? KlasivoTypography.labelMedium.copyWith(
                            color: KlasivoColors.primary,
                          )
                        : KlasivoTypography.bodySmall.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextTertiary
                                : KlasivoColors.lightTextTertiary,
                          ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class KlasivoBreadcrumbItem {
  final String label;
  final String? id;

  const KlasivoBreadcrumbItem({required this.label, this.id});
}

// ─── Expandable Card — Stages > Classes hierarchy ──────────────────────────

class KlasivoExpandableCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget child;
  final bool initiallyExpanded;
  final VoidCallback? onTap;

  const KlasivoExpandableCard({
    Key? key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
    this.initiallyExpanded = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<KlasivoExpandableCard> createState() => _KlasivoExpandableCardState();
}

class _KlasivoExpandableCardState extends State<KlasivoExpandableCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KlasivoCard(
      variant: KlasivoCardVariant.outlined,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _expanded = !_expanded);
              widget.onTap?.call();
            },
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(KlasivoRadius.md),
              bottom: _expanded
                  ? Radius.zero
                  : Radius.circular(KlasivoRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(width: KlasivoSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: KlasivoTypography.titleLarge.copyWith(
                            color: isDark
                                ? KlasivoColors.darkTextPrimary
                                : KlasivoColors.lightTextPrimary,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: KlasivoSpacing.xs),
                          Text(
                            widget.subtitle!,
                            style: KlasivoTypography.bodySmall.copyWith(
                              color: isDark
                                  ? KlasivoColors.darkTextTertiary
                                  : KlasivoColors.lightTextTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more,
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(
                left: KlasivoSpacing.lg,
                right: KlasivoSpacing.lg,
                bottom: KlasivoSpacing.lg,
              ),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ─── Subject Color Chip — Color-coded subject cards ─────────────────────────

class KlasivoSubjectCard extends StatelessWidget {
  final String name;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const KlasivoSubjectCard({
    Key? key,
    required this.name,
    required this.color,
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      accentColor: color,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            ),
            child: Icon(Icons.menu_book_outlined, color: color, size: 20),
          ),
          const SizedBox(width: KlasivoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KlasivoTypography.titleMedium),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: KlasivoTypography.bodySmall.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }
}

// ─── Attendance Status Button — Large touch targets ─────────────────────────

class KlasivoAttendanceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const KlasivoAttendanceButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    this.isSelected = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KlasivoRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.md,
          vertical: KlasivoSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
          border: Border.all(
            color: isSelected ? color : (Theme.of(context).brightness == Brightness.dark
                ? KlasivoColors.darkBorder
                : KlasivoColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : null),
            const SizedBox(width: KlasivoSpacing.xs),
            Text(
              label,
              style: KlasivoTypography.labelMedium.copyWith(
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Premium Empty State — With illustration feel ───────────────────────────

class KlasivoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const KlasivoEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KlasivoSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(KlasivoSpacing.xxl),
              decoration: BoxDecoration(
                color: (iconColor ?? KlasivoColors.primary).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: iconColor ?? KlasivoColors.primary,
              ),
            ),
            const SizedBox(height: KlasivoSpacing.xxl),
            Text(
              title,
              style: KlasivoTypography.titleLarge.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KlasivoSpacing.sm),
            Text(
              subtitle,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: KlasivoSpacing.xxl),
              KlasivoButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Section Header — Consistent section titles ─────────────────────────────

class KlasivoSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KlasivoSectionHeader({
    Key? key,
    required this.title,
    this.actionLabel,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: KlasivoTypography.titleLarge.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextPrimary
                  : KlasivoColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: KlasivoSpacing.sm),
          KlasivoButton(
            label: actionLabel!,
            onPressed: onAction,
            variant: KlasivoButtonVariant.tertiary,
          ),
        ],
      ],
    );
  }
}

// ─── Stat Pill — Inline stat badge ──────────────────────────────────────────

class KlasivoStatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const KlasivoStatPill({
    Key? key,
    required this.value,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.md,
        vertical: KlasivoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: KlasivoTypography.titleSmall.copyWith(color: color),
          ),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            label,
            style: KlasivoTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Loading Indicator — Consistent loading state ───────────────────────────

class KlasivoLoading extends StatelessWidget {
  final String? message;

  const KlasivoLoading({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          if (message != null) ...[
            const SizedBox(height: KlasivoSpacing.lg),
            Text(
              message!,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
