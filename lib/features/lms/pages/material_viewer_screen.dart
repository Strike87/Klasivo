import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/material_provider.dart';
import '../../../widgets/klasivo_components.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_card.dart';
import '../../../widgets/klasivo_badge.dart';
import '../../../widgets/klasivo_modal.dart';
import '../../../widgets/klasivo_toast.dart';
import '../../../core/services/material_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MATERIAL VIEWER SCREEN — LMS Material Detail & Open
// Displays full material info with file-type hero banner, metadata,
// and primary action (open file / open link).
// Resolves TODO at subject_content_screen.dart line 1522.
// ═══════════════════════════════════════════════════════════════════════════════

class MaterialViewerScreen extends ConsumerStatefulWidget {
  final String materialId;
  final String? subjectId;

  const MaterialViewerScreen({
    Key? key,
    required this.materialId,
    this.subjectId,
  }) : super(key: key);

  @override
  ConsumerState<MaterialViewerScreen> createState() =>
      _MaterialViewerScreenState();
}

class _MaterialViewerScreenState extends ConsumerState<MaterialViewerScreen> {
  MaterialData? _material;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOpening = false;

  @override
  void initState() {
    super.initState();
    _fetchMaterial();
  }

  // ── Fetch Material Data ─────────────────────────────────────────────────

  Future<void> _fetchMaterial() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(materialServiceProvider);
      final data = await service.getMaterial(widget.materialId);

      if (data == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Material not found. It may have been removed.';
          });
        }
        return;
      }

      final material = MaterialData(
        id: data['id'] ?? '',
        organizationId: data['organizationId'] ?? '',
        subjectId: data['subjectId'] ?? '',
        chapterId: data['chapterId'] ?? '',
        lessonId: data['lessonId'] ?? '',
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        type: data['type'] ?? 'pdf',
        fileUrl: data['fileUrl'] ?? '',
        fileName: data['fileName'] ?? '',
        fileSize: data['fileSize'] ?? 0,
        thumbnailUrl: data['thumbnailUrl'] ?? '',
        accessType: data['accessType'] ?? '',
        targetId: data['targetId'] ?? '',
        createdBy: data['createdBy'],
        createdByName: data['createdByName'],
        createdAt: _parseDate(data['createdAt']),
        downloadCount: data['downloadCount'] ?? 0,
      );

      if (mounted) {
        setState(() {
          _material = material;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load material: $e';
        });
      }
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // Timestamp from Firestore
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }

  // ── Open File / Link ────────────────────────────────────────────────────

  Future<void> _openMaterial() async {
    final material = _material;
    if (material == null) return;

    setState(() => _isOpening = true);

    try {
      // Increment download count (fire-and-forget, don't block UX)
      final service = ref.read(materialServiceProvider);
      service.incrementDownloadCount(material.id).catchError((_) {});

      final url = material.isLink ? material.fileUrl : material.fileUrl;
      if (url.isEmpty) {
        if (mounted) {
          KlasivoToast.info(
            context,
            message: material.isLink
                ? 'No link URL available'
                : 'No file URL available',
          );
        }
        return;
      }

      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) {
        if (mounted) {
          KlasivoToast.error(context, message: 'Invalid URL: $url');
        }
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        KlasivoToast.info(
          context,
          message:
              'Could not open ${material.isLink ? "link" : "file"}',
        );
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(context, message: 'Failed to open: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
        // Refresh to show updated download count
        _fetchMaterial();
      }
    }
  }

  // ── Share Material ──────────────────────────────────────────────────────

  void _shareMaterial() {
    final material = _material;
    if (material == null) return;

    final shareText = StringBuffer()
      ..writeln(material.title)
      ..writeln();

    if (material.description.isNotEmpty) {
      shareText
        ..writeln(material.description)
        ..writeln();
    }

    if (material.fileUrl.isNotEmpty) {
      shareText.writeln(material.fileUrl);
    }

    Share.share(
      shareText.toString().trim(),
      subject: material.title,
    );
  }

  // ── Archive Material ────────────────────────────────────────────────────

  Future<void> _archiveMaterial() async {
    final material = _material;
    if (material == null) return;

    final confirmed = await KlasivoModal.confirm(
      context: context,
      title: 'Archive Material',
      message:
          'Are you sure you want to archive "${material.title}"? This material will be hidden from the content browser.',
      confirmLabel: 'Archive',
      cancelLabel: 'Cancel',
      isDangerous: true,
    );

    if (confirmed == true) {
      try {
        final service = ref.read(materialServiceProvider);
        await service.archiveMaterial(material.id);
        if (mounted) {
          KlasivoToast.success(
              context, message: '"${material.title}" archived');
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          KlasivoToast.error(context, message: 'Failed to archive: $e');
        }
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? KlasivoColors.darkBackground
          : KlasivoColors.lightBackground,
      appBar: _buildAppBar(isDark),
      body: _buildBody(isDark),
    );
  }

  // ── App Bar ─────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(
        _material?.title ?? 'Material',
        style: KlasivoTypography.titleLarge.copyWith(
          color: isDark
              ? KlasivoColors.darkTextPrimary
              : KlasivoColors.lightTextPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: isDark
          ? KlasivoColors.darkSurface
          : KlasivoColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (_material != null) ...[
          // Share button
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _shareMaterial,
          ),
          // Overflow menu
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  context.go('/teacher/lms/materials/$materialId/edit');
                  break;
                case 'archive':
                  _archiveMaterial();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: KlasivoSpacing.sm),
                    Text('Edit'),
                  ],
                ),
              ),
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
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const KlasivoLoading(message: 'Loading material...');
    }

    if (_errorMessage != null) {
      return KlasivoEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load material',
        subtitle: _errorMessage!,
        iconColor: KlasivoColors.error,
        actionLabel: 'Retry',
        onAction: _fetchMaterial,
      );
    }

    final material = _material!;
    final typeConfig = _materialTypeConfig(material.type);

    return RefreshIndicator(
      onRefresh: _fetchMaterial,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: KlasivoSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── File Type Hero Banner ────────────────────────────────────
            _FileTypeHeroBanner(
              material: material,
              typeConfig: typeConfig,
            ),

            const SizedBox(height: KlasivoSpacing.xxl),

            // ── Title & Description ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    style: KlasivoTypography.headlineSmall.copyWith(
                      color: isDark
                          ? KlasivoColors.darkTextPrimary
                          : KlasivoColors.lightTextPrimary,
                    ),
                  ),
                  if (material.description.isNotEmpty) ...[
                    const SizedBox(height: KlasivoSpacing.sm),
                    Text(
                      material.description,
                      style: KlasivoTypography.bodyMedium.copyWith(
                        color: isDark
                            ? KlasivoColors.darkTextSecondary
                            : KlasivoColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: KlasivoSpacing.xxl),

            // ── Quick Stats Row ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.lg,
              ),
              child: Row(
                children: [
                  _QuickStatChip(
                    icon: typeConfig.icon,
                    label: typeConfig.label,
                    color: typeConfig.color,
                  ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  if (material.fileSize > 0)
                    _QuickStatChip(
                      icon: Icons.data_usage_outlined,
                      label: material.formattedSize,
                      color: KlasivoColors.accent,
                    ),
                  const SizedBox(width: KlasivoSpacing.sm),
                  _QuickStatChip(
                    icon: Icons.download_outlined,
                    label: '${material.downloadCount} downloads',
                    color: KlasivoColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: KlasivoSpacing.xxl),

            // ── File Metadata Section ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.lg,
              ),
              child: KlasivoSectionHeader(title: 'Details'),
            ),
            const SizedBox(height: KlasivoSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.lg,
              ),
              child: KlasivoCard(
                child: Column(
                  children: [
                    _MetadataRow(
                      icon: Icons.category_outlined,
                      label: 'Type',
                      value: typeConfig.label,
                      isDark: isDark,
                    ),
                    _MetadataDivider(isDark: isDark),
                    _MetadataRow(
                      icon: Icons.data_usage_outlined,
                      label: 'Size',
                      value: material.fileSize > 0
                          ? material.formattedSize
                          : 'Unknown',
                      isDark: isDark,
                    ),
                    _MetadataDivider(isDark: isDark),
                    _MetadataRow(
                      icon: Icons.person_outline,
                      label: 'Uploaded by',
                      value: material.createdByName ?? 'Unknown',
                      isDark: isDark,
                    ),
                    _MetadataDivider(isDark: isDark),
                    _MetadataRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Upload date',
                      value: material.createdAt != null
                          ? DateFormat.yMMMd().format(material.createdAt!)
                          : 'Unknown',
                      isDark: isDark,
                    ),
                    _MetadataDivider(isDark: isDark),
                    _MetadataRow(
                      icon: Icons.download_outlined,
                      label: 'Downloads',
                      value: '${material.downloadCount}',
                      isDark: isDark,
                    ),
                    if (material.fileName.isNotEmpty) ...[
                      _MetadataDivider(isDark: isDark),
                      _MetadataRow(
                        icon: Icons.insert_drive_file_outlined,
                        label: 'File name',
                        value: material.fileName,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: KlasivoSpacing.xxl),

            // ── Primary Action Button ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.lg,
              ),
              child: KlasivoButton(
                label: material.isLink ? 'Open Link' : 'Open File',
                icon: material.isLink
                    ? Icons.open_in_new_outlined
                    : Icons.visibility_outlined,
                variant: KlasivoButtonVariant.primary,
                size: KlasivoButtonSize.lg,
                fullWidth: true,
                loading: _isOpening,
                onPressed: _openMaterial,
              ),
            ),

            const SizedBox(height: KlasivoSpacing.md),

            // ── Secondary Share Button ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KlasivoSpacing.lg,
              ),
              child: KlasivoButton(
                label: 'Share',
                icon: Icons.share_outlined,
                variant: KlasivoButtonVariant.secondary,
                size: KlasivoButtonSize.lg,
                fullWidth: true,
                onPressed: _shareMaterial,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Type Config Helper ──────────────────────────────────────────────────

  static _TypeConfig _materialTypeConfig(String type) {
    switch (type) {
      case 'pdf':
        return _TypeConfig(
          icon: Icons.picture_as_pdf_outlined,
          color: const Color(0xFFE03131),
          label: 'PDF',
          gradientColors: [
            const Color(0xFFE53935),
            const Color(0xFFC62828),
          ],
        );
      case 'word':
        return _TypeConfig(
          icon: Icons.description_outlined,
          color: const Color(0xFF2B579A),
          label: 'Word',
          gradientColors: [
            const Color(0xFF1E88E5),
            const Color(0xFF1565C0),
          ],
        );
      case 'powerpoint':
        return _TypeConfig(
          icon: Icons.slideshow_outlined,
          color: const Color(0xFFD24726),
          label: 'PowerPoint',
          gradientColors: [
            const Color(0xFFFB8C00),
            const Color(0xFFE65100),
          ],
        );
      case 'image':
        return _TypeConfig(
          icon: Icons.image_outlined,
          color: KlasivoColors.secondary,
          label: 'Image',
          gradientColors: [
            const Color(0xFF43A047),
            const Color(0xFF2E7D32),
          ],
        );
      case 'video':
        return _TypeConfig(
          icon: Icons.videocam_outlined,
          color: KlasivoColors.primary,
          label: 'Video',
          gradientColors: [
            const Color(0xFF8E24AA),
            const Color(0xFF6A1B9A),
          ],
        );
      case 'link':
        return _TypeConfig(
          icon: Icons.link_outlined,
          color: const Color(0xFF3B5BDB),
          label: 'Link',
          gradientColors: [
            const Color(0xFF00ACC1),
            const Color(0xFF00838F),
          ],
        );
      default:
        return _TypeConfig(
          icon: Icons.insert_drive_file_outlined,
          color: KlasivoColors.accent,
          label: type,
          gradientColors: [
            KlasivoColors.accent,
            KlasivoColors.accentDark,
          ],
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FILE TYPE HERO BANNER — Gradient banner with large type icon
// ═══════════════════════════════════════════════════════════════════════════════

class _FileTypeHeroBanner extends StatelessWidget {
  final MaterialData material;
  final _TypeConfig typeConfig;

  const _FileTypeHeroBanner({
    required this.material,
    required this.typeConfig,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KlasivoSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: typeConfig.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Large icon in frosted circle
          Container(
            padding: const EdgeInsets.all(KlasivoSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              typeConfig.icon,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: KlasivoSpacing.lg),

          // File type badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: KlasivoSpacing.md,
              vertical: KlasivoSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(KlasivoRadius.pill),
            ),
            child: Text(
              typeConfig.label.toUpperCase(),
              style: KlasivoTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: KlasivoSpacing.md),

          // File name
          if (material.fileName.isNotEmpty)
            Text(
              material.fileName,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUICK STAT CHIP — Inline stat with icon
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

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
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: KlasivoSpacing.xs),
          Text(
            label,
            style: KlasivoTypography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METADATA ROW — Icon + label + value row
// ═══════════════════════════════════════════════════════════════════════════════

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: KlasivoSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark
                ? KlasivoColors.darkTextTertiary
                : KlasivoColors.lightTextTertiary,
          ),
          const SizedBox(width: KlasivoSpacing.md),
          Expanded(
            child: Text(
              label,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextTertiary
                    : KlasivoColors.lightTextTertiary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: KlasivoTypography.bodyMedium.copyWith(
                color: isDark
                    ? KlasivoColors.darkTextPrimary
                    : KlasivoColors.lightTextPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// METADATA DIVIDER — Subtle divider between metadata rows
// ═══════════════════════════════════════════════════════════════════════════════

class _MetadataDivider extends StatelessWidget {
  final bool isDark;

  const _MetadataDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? KlasivoColors.darkDivider
          : KlasivoColors.lightDivider,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPE CONFIG — Material type icon, color, label, and gradient colors
// ═══════════════════════════════════════════════════════════════════════════════

class _TypeConfig {
  final IconData icon;
  final Color color;
  final String label;
  final List<Color> gradientColors;

  const _TypeConfig({
    required this.icon,
    required this.color,
    required this.label,
    required this.gradientColors,
  });
}
