import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../providers/lesson_provider.dart';
import '../../../providers/material_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';
import '../../../core/services/lesson_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LESSON DETAIL SCREEN — Lesson player / detail view
// Shows lesson content, metadata, and related materials.
// Resolves TODO at subject_content_screen.dart line 1359.
// ═══════════════════════════════════════════════════════════════════════════════

class LessonDetailScreen extends ConsumerStatefulWidget {
  final String lessonId;
  final String subjectId;

  const LessonDetailScreen({
    Key? key,
    required this.lessonId,
    required this.subjectId,
  }) : super(key: key);

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  LessonData? _lesson;
  bool _isLoading = true;
  String? _error;
  bool _viewCountIncremented = false;

  @override
  void initState() {
    super.initState();
    _fetchLesson();
  }

  // ── Fetch Lesson Data ─────────────────────────────────────────────────────

  Future<void> _fetchLesson() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lessonService = ref.read(lessonServiceProvider);
      final data = await lessonService.getLesson(widget.lessonId);

      if (data == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'Lesson not found';
          });
        }
        return;
      }

      final lesson = LessonData(
        id: data['id'] ?? '',
        organizationId: data['organizationId'] ?? '',
        subjectId: data['subjectId'] ?? '',
        chapterId: data['chapterId'] ?? '',
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        type: data['type'] ?? 'recorded',
        videoUrl: data['videoUrl'] ?? '',
        thumbnailUrl: data['thumbnailUrl'] ?? '',
        duration: data['duration'] ?? 0,
        viewCount: data['viewCount'] ?? 0,
        accessType: data['accessType'] ?? '',
        targetId: data['targetId'] ?? '',
        createdBy: data['createdBy'],
        createdByName: data['createdByName'],
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] is DateTime
                ? data['createdAt'] as DateTime
                : DateTime.tryParse(data['createdAt'].toString()))
            : null,
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] is DateTime
                ? data['updatedAt'] as DateTime
                : DateTime.tryParse(data['updatedAt'].toString()))
            : null,
      );

      if (mounted) {
        setState(() {
          _lesson = lesson;
          _isLoading = false;
        });

        // Increment view count once on load
        if (!_viewCountIncremented) {
          _viewCountIncremented = true;
          lessonService.incrementViewCount(widget.lessonId).catchError((_) {});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  // ── Launch URL Helper ─────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Could not open the link');
      }
    }
  }

  // ── Archive Lesson ────────────────────────────────────────────────────────

  Future<void> _archiveLesson() async {
    if (_lesson == null) return;

    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Archive Lesson',
      message:
          'Are you sure you want to archive "${_lesson!.title}"? This lesson will be hidden from the content browser.',
      confirmLabel: 'Archive',
      cancelLabel: 'Cancel',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        final service = ref.read(lessonServiceProvider);
        await service.archiveLesson(_lesson!.id);
        if (mounted) {
          KlasivoToast.success(
              context, message: '"${_lesson!.title}" archived');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          KlasivoToast.error(context, message: 'Failed to archive: $e');
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchLesson,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Sliver App Bar ─────────────────────────────────────────────
            SliverAppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              title: Text(
                _lesson?.title ?? 'Lesson Detail',
                style: KlasivoTypography.titleLarge.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              floating: true,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              backgroundColor: isDark
                  ? KlasivoColors.darkSurface
                  : KlasivoColors.lightSurface,
              surfaceTintColor: Colors.transparent,
              actions: [
                if (_lesson != null) ...[
                  // Edit button for teachers
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Lesson',
                    onPressed: () {
                      // TODO: Navigate to lesson edit screen
                      KlasivoToast.info(context,
                          message: 'Lesson editing coming soon');
                    },
                  ),
                  // Overflow menu
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'archive') _archiveLesson();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 20),
                            SizedBox(width: KlasivoSpacing.sm),
                            Text('Archive'),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ],
              ],
            ),

            // ── Content ────────────────────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                child: KlasivoLoading(message: 'Loading lesson...'),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: KlasivoEmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load lesson',
                  subtitle: _error!,
                  iconColor: KlasivoColors.error,
                  actionLabel: 'Retry',
                  onAction: _fetchLesson,
                ),
              )
            else if (_lesson != null)
              ..._buildLessonContent(isDark),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lesson Content Slivers ────────────────────────────────────────────────

  List<Widget> _buildLessonContent(bool isDark) {
    final lesson = _lesson!;

    return [
      // ── Hero Section ─────────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KlasivoSpacing.lg,
            KlasivoSpacing.lg,
            KlasivoSpacing.lg,
            0,
          ),
          child: _HeroSection(lesson: lesson),
        ),
      ),

      // ── Video Player Area ────────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KlasivoSpacing.lg,
            KlasivoSpacing.lg,
            KlasivoSpacing.lg,
            0,
          ),
          child: _VideoPlayerCard(
            lesson: lesson,
            onLaunchUrl: _launchUrl,
          ),
        ),
      ),

      // ── Description & Metadata ───────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KlasivoSpacing.lg,
            KlasivoSpacing.lg,
            KlasivoSpacing.lg,
            0,
          ),
          child: _DescriptionSection(lesson: lesson),
        ),
      ),

      // ── Related Materials Section ────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KlasivoSpacing.lg,
            KlasivoSpacing.xxl,
            KlasivoSpacing.lg,
            0,
          ),
          child: _MaterialsSection(
            lessonId: lesson.id,
            subjectId: widget.subjectId,
            onLaunchUrl: _launchUrl,
          ),
        ),
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO SECTION — Lesson title, type badge, duration, and view count
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroSection extends StatelessWidget {
  final LessonData lesson;

  const _HeroSection({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeConfig = _lessonTypeConfig(lesson.type);

    return KlasivoCard(
      variant: KlasivoCardVariant.outlined,
      padding: const EdgeInsets.all(KlasivoSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge
          KlasivoBadge(
            label: lesson.typeLabel,
            variant: typeConfig.badgeVariant,
            icon: typeConfig.icon,
            size: KlasivoBadgeSize.sm,
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // Title
          Text(
            lesson.title,
            style: KlasivoTypography.headlineMedium.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextPrimary
                  : KlasivoColors.lightTextPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Stats row
          const SizedBox(height: KlasivoSpacing.lg),
          Row(
            children: [
              if (lesson.duration > 0) ...[
                KlasivoStatPill(
                  value: lesson.durationFormatted,
                  label: 'Duration',
                  color: KlasivoColors.primary,
                ),
                const SizedBox(width: KlasivoSpacing.sm),
              ],
              KlasivoStatPill(
                value: '${lesson.viewCount}',
                label: lesson.viewCount == 1 ? 'View' : 'Views',
                color: KlasivoColors.accent,
              ),
              if (lesson.isExternal) ...[
                const SizedBox(width: KlasivoSpacing.sm),
                KlasivoStatPill(
                  value: 'External',
                  label: lesson.typeLabel,
                  color: typeConfig.color,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// VIDEO PLAYER CARD — Type-specific player/launcher card
// ═══════════════════════════════════════════════════════════════════════════════

class _VideoPlayerCard extends StatelessWidget {
  final LessonData lesson;
  final ValueChanged<String> onLaunchUrl;

  const _VideoPlayerCard({
    required this.lesson,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeConfig = _lessonTypeConfig(lesson.type);

    return switch (lesson.type) {
      'youtube' => _YouTubeCard(
          lesson: lesson,
          isDark: isDark,
          typeConfig: typeConfig,
          onLaunchUrl: onLaunchUrl,
        ),
      'zoom' => _ZoomCard(
          lesson: lesson,
          isDark: isDark,
          onLaunchUrl: onLaunchUrl,
        ),
      'google_drive' => _ExternalLinkCard(
          lesson: lesson,
          isDark: isDark,
          typeConfig: typeConfig,
          onLaunchUrl: onLaunchUrl,
        ),
      _ => _RecordedCard(
          lesson: lesson,
          isDark: isDark,
          typeConfig: typeConfig,
        ),
    };
  }
}

// ── YouTube Card ──────────────────────────────────────────────────────────────

class _YouTubeCard extends StatelessWidget {
  final LessonData lesson;
  final bool isDark;
  final _LessonTypeConfig typeConfig;
  final ValueChanged<String> onLaunchUrl;

  const _YouTubeCard({
    required this.lesson,
    required this.isDark,
    required this.typeConfig,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      padding: EdgeInsets.zero,
      onTap: lesson.videoUrl.isNotEmpty
          ? () => onLaunchUrl(lesson.videoUrl)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail / play area
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: typeConfig.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KlasivoRadius.card),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // YouTube icon
                Icon(
                  Icons.play_circle_filled,
                  size: 64,
                  color: typeConfig.color.withValues(alpha: 0.6),
                ),
                // Play overlay
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.lg),
                  decoration: BoxDecoration(
                    color: KlasivoColors.error.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
          // Info bar
          Padding(
            padding: const EdgeInsets.all(KlasivoSpacing.lg),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.sm),
                  decoration: BoxDecoration(
                    color: KlasivoColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                  ),
                  child: const Icon(
                    Icons.smart_display,
                    color: KlasivoColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: KlasivoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YouTube Video',
                        style: KlasivoTypography.titleSmall.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextPrimary
                              : KlasivoColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to open in YouTube',
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: isDark
                      ? KlasivoColors.darkTextTertiary
                      : KlasivoColors.lightTextTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zoom Card ─────────────────────────────────────────────────────────────────

class _ZoomCard extends StatelessWidget {
  final LessonData lesson;
  final bool isDark;
  final ValueChanged<String> onLaunchUrl;

  const _ZoomCard({
    required this.lesson,
    required this.isDark,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    return KlasivoCard(
      variant: KlasivoCardVariant.outlined,
      padding: const EdgeInsets.all(KlasivoSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zoom header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: KlasivoColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                ),
                child: const Icon(
                  Icons.video_call_outlined,
                  color: KlasivoColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: KlasivoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zoom Meeting',
                      style: KlasivoTypography.titleLarge.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lesson.videoUrl.isNotEmpty
                          ? 'Meeting link available'
                          : 'No meeting link configured',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (lesson.videoUrl.isNotEmpty) ...[
            const SizedBox(height: KlasivoSpacing.xxl),
            // Meeting link display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KlasivoSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? KlasivoColors.darkBackground
                    : KlasivoColors.lightBackground,
                borderRadius: BorderRadius.circular(KlasivoRadius.md),
                border: Border.all(
                  color: isDark
                      ? KlasivoColors.darkBorder
                      : KlasivoColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 16,
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  Expanded(
                    child: Text(
                      lesson.videoUrl,
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: KlasivoColors.primary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KlasivoSpacing.lg),
            // Join button
            KlasivoButton(
              label: 'Join Meeting',
              icon: Icons.video_call_outlined,
              variant: KlasivoButtonVariant.primary,
              size: KlasivoButtonSize.lg,
              fullWidth: true,
              onPressed: () => onLaunchUrl(lesson.videoUrl),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Google Drive Card ─────────────────────────────────────────────────────────

class _ExternalLinkCard extends StatelessWidget {
  final LessonData lesson;
  final bool isDark;
  final _LessonTypeConfig typeConfig;
  final ValueChanged<String> onLaunchUrl;

  const _ExternalLinkCard({
    required this.lesson,
    required this.isDark,
    required this.typeConfig,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    return KlasivoCard(
      variant: KlasivoCardVariant.outlined,
      padding: const EdgeInsets.all(KlasivoSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: typeConfig.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KlasivoRadius.sm),
                ),
                child: Icon(
                  typeConfig.icon,
                  color: typeConfig.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: KlasivoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.typeLabel,
                      style: KlasivoTypography.titleLarge.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextPrimary
                            : KlasivoColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'External content hosted on Google Drive',
                      style: KlasivoTypography.bodySmall.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextTertiary
                            : KlasivoColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (lesson.videoUrl.isNotEmpty) ...[
            const SizedBox(height: KlasivoSpacing.lg),
            KlasivoButton(
              label: 'Open in Browser',
              icon: Icons.open_in_new,
              variant: KlasivoButtonVariant.secondary,
              size: KlasivoButtonSize.lg,
              fullWidth: true,
              onPressed: () => onLaunchUrl(lesson.videoUrl),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recorded Lesson Card ─────────────────────────────────────────────────────

class _RecordedCard extends StatelessWidget {
  final LessonData lesson;
  final bool isDark;
  final _LessonTypeConfig typeConfig;

  const _RecordedCard({
    required this.lesson,
    required this.isDark,
    required this.typeConfig,
  });

  @override
  Widget build(BuildContext context) {
    return KlasivoCard(
      variant: KlasivoCardVariant.outlined,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video placeholder area
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  typeConfig.color.withValues(alpha: 0.12),
                  typeConfig.color.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KlasivoRadius.card),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(KlasivoSpacing.lg),
                    decoration: BoxDecoration(
                      color: typeConfig.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.videocam_outlined,
                      size: 40,
                      color: typeConfig.color,
                    ),
                  ),
                  const SizedBox(height: KlasivoSpacing.md),
                  Text(
                    'Recorded Lesson',
                    style: KlasivoTypography.titleMedium.copyWith(
                      color: typeConfig.color,
                    ),
                  ),
                  if (lesson.duration > 0) ...[
                    const SizedBox(height: KlasivoSpacing.xs),
                    Text(
                      lesson.durationFormatted,
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
          ),
          // Description hint
          if (lesson.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(KlasivoSpacing.lg),
              child: Text(
                lesson.description,
                style: KlasivoTypography.bodyMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextSecondary
                      : KlasivoColors.lightTextSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DESCRIPTION SECTION — Lesson description and metadata
// ═══════════════════════════════════════════════════════════════════════════════

class _DescriptionSection extends StatelessWidget {
  final LessonData lesson;

  const _DescriptionSection({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasDescription =
        lesson.description.isNotEmpty;
    final hasMetadata =
        lesson.createdByName != null || lesson.createdAt != null;

    if (!hasDescription && !hasMetadata) return const SizedBox.shrink();

    return KlasivoCard(
      variant: KlasivoCardVariant.outlined,
      padding: const EdgeInsets.all(KlasivoSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
              const SizedBox(width: KlasivoSpacing.sm),
              Text(
                'About this lesson',
                style: KlasivoTypography.titleMedium.copyWith(
                  color: isDark
                      ? KlasivoColors.darkTextPrimary
                      : KlasivoColors.lightTextPrimary,
                ),
              ),
            ],
          ),

          // Description
          if (hasDescription) ...[
            const SizedBox(height: KlasivoSpacing.md),
            Text(
              lesson.description,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextSecondary
                    : KlasivoColors.lightTextSecondary,
                height: 1.6,
              ),
            ),
          ],

          // Metadata
          if (hasMetadata) ...[
            const SizedBox(height: KlasivoSpacing.xxl),
            Divider(
              color: isDark
                  ? KlasivoColors.darkDivider
                  : KlasivoColors.lightDivider,
              height: 1,
            ),
            const SizedBox(height: KlasivoSpacing.md),
            // Created by
            if (lesson.createdByName != null)
              _MetadataRow(
                icon: Icons.person_outline,
                label: 'Created by',
                value: lesson.createdByName!,
                isDark: isDark,
              ),
            // Created date
            if (lesson.createdAt != null) ...[
              const SizedBox(height: KlasivoSpacing.sm),
              _MetadataRow(
                icon: Icons.calendar_today_outlined,
                label: 'Created',
                value: DateFormat.yMMMd().format(lesson.createdAt!),
                isDark: isDark,
              ),
            ],
            // Lesson type
            const SizedBox(height: KlasivoSpacing.sm),
            _MetadataRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: lesson.typeLabel,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? KlasivoColors.darkTextTertiary
              : KlasivoColors.lightTextTertiary,
        ),
        const SizedBox(width: KlasivoSpacing.sm),
        Text(
          label,
          style: KlasivoTypography.caption.copyWith(
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
        ),
        const SizedBox(width: KlasivoSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: KlasivoTypography.caption.copyWith(
              color: isDark
                  ? KlasivoColors.darkTextSecondary
                  : KlasivoColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATERIALS SECTION — Related learning materials for this lesson
// ═══════════════════════════════════════════════════════════════════════════════

class _MaterialsSection extends ConsumerWidget {
  final String lessonId;
  final String subjectId;
  final ValueChanged<String> onLaunchUrl;

  const _MaterialsSection({
    required this.lessonId,
    required this.subjectId,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allMaterials = ref.watch(materialsBySubjectProvider(subjectId));
    final materials =
        allMaterials.where((m) => m.lessonId == lessonId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KlasivoSectionHeader(
          title: 'Materials',
          actionLabel: materials.isNotEmpty ? '${materials.length}' : null,
        ),
        const SizedBox(height: KlasivoSpacing.md),

        if (materials.isEmpty)
          KlasivoCard(
            variant: KlasivoCardVariant.filled,
            padding: const EdgeInsets.all(KlasivoSpacing.xxl),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 32,
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                  const SizedBox(height: KlasivoSpacing.md),
                  Text(
                    'No materials for this lesson',
                    style: KlasivoTypography.bodyMedium.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextTertiary
                          : KlasivoColors.lightTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...materials.map((material) => Padding(
                padding: const EdgeInsets.only(bottom: KlasivoSpacing.sm),
                child: _MaterialCard(
                  material: material,
                  onLaunchUrl: onLaunchUrl,
                ),
              )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MATERIAL CARD — Individual material item with download/open action
// ═══════════════════════════════════════════════════════════════════════════════

class _MaterialCard extends StatelessWidget {
  final MaterialData material;
  final ValueChanged<String> onLaunchUrl;

  const _MaterialCard({
    required this.material,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _materialTypeColor(material.type);

    return KlasivoCard(
      variant: KlasivoCardVariant.interactive,
      padding: const EdgeInsets.all(KlasivoSpacing.lg),
      onTap: material.fileUrl.isNotEmpty
          ? () => onLaunchUrl(material.fileUrl)
          : null,
      child: Row(
        children: [
          // File type icon
          Container(
            padding: const EdgeInsets.all(KlasivoSpacing.sm + 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KlasivoRadius.sm),
            ),
            child: Icon(
              _materialTypeIcon(material.type),
              color: typeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: KlasivoSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.title,
                  style: KlasivoTypography.titleSmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // File type badge
                    KlasivoBadge(
                      label: material.type.toUpperCase(),
                      variant: KlasivoBadgeVariant.neutral,
                      size: KlasivoBadgeSize.sm,
                    ),
                    const SizedBox(width: KlasivoSpacing.sm),
                    // File size
                    if (material.fileSize > 0)
                      Text(
                        material.formattedSize,
                        style: KlasivoTypography.caption.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextTertiary
                              : KlasivoColors.lightTextTertiary,
                        ),
                      ),
                    if (material.fileSize > 0 &&
                        material.downloadCount > 0)
                      const SizedBox(width: KlasivoSpacing.sm),
                    // Download count
                    if (material.downloadCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_outlined,
                            size: 12,
                            color: isDark
                                ? KlasivoColors.darkTextTertiary
                                : KlasivoColors.lightTextTertiary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${material.downloadCount}',
                            style: KlasivoTypography.caption.copyWith(
                              color: isDark
                                  ? KlasivoColors.darkTextTertiary
                                  : KlasivoColors.lightTextTertiary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: KlasivoSpacing.sm),

          // Action icon
          Icon(
            material.isLink ? Icons.open_in_new : Icons.download,
            size: 20,
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS — Lesson type config and material type icons/colors
// ═══════════════════════════════════════════════════════════════════════════════

class _LessonTypeConfig {
  final IconData icon;
  final Color color;
  final KlasivoBadgeVariant badgeVariant;

  const _LessonTypeConfig({
    required this.icon,
    required this.color,
    required this.badgeVariant,
  });
}

_LessonTypeConfig _lessonTypeConfig(String type) {
  return switch (type) {
    'youtube' => const _LessonTypeConfig(
        icon: Icons.smart_display,
        color: KlasivoColors.error,
        badgeVariant: KlasivoBadgeVariant.danger,
      ),
    'zoom' => const _LessonTypeConfig(
        icon: Icons.video_call_outlined,
        color: KlasivoColors.primary,
        badgeVariant: KlasivoBadgeVariant.primary,
      ),
    'google_drive' => const _LessonTypeConfig(
        icon: Icons.cloud_outlined,
        color: KlasivoColors.accent,
        badgeVariant: KlasivoBadgeVariant.accent,
      ),
    _ => const _LessonTypeConfig(
        icon: Icons.videocam_outlined,
        color: KlasivoColors.secondary,
        badgeVariant: KlasivoBadgeVariant.secondary,
      ),
  };
}

IconData _materialTypeIcon(String type) {
  return switch (type) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'word' => Icons.description_outlined,
    'powerpoint' => Icons.slideshow_outlined,
    'image' => Icons.image_outlined,
    'video' => Icons.videocam_outlined,
    'link' => Icons.link_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}

Color _materialTypeColor(String type) {
  return switch (type) {
    'pdf' => KlasivoColors.error,
    'word' => const Color(0xFF2B579A),
    'powerpoint' => const Color(0xFFD24726),
    'image' => KlasivoColors.secondary,
    'video' => KlasivoColors.primary,
    'link' => const Color(0xFF3B5BDB),
    _ => KlasivoColors.accent,
  };
}
