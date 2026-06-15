import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config/theme.dart';
import '../core/config/app_constants.dart';
import '../core/services/content_progress_service.dart';
import '../providers/content_progress_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO YOUTUBE PLAYER — Embedded player with progress tracking & resume
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoYouTubePlayer extends ConsumerStatefulWidget {
  final String videoUrl;
  final String lessonId;
  final String subjectId;
  final String classId;
  final String? organizationId;

  const KlasivoYouTubePlayer({
    Key? key,
    required this.videoUrl,
    required this.lessonId,
    required this.subjectId,
    required this.classId,
    this.organizationId,
  }) : super(key: key);

  @override
  ConsumerState<KlasivoYouTubePlayer> createState() => _KlasivoYouTubePlayerState();
}

class _KlasivoYouTubePlayerState extends ConsumerState<KlasivoYouTubePlayer> {
  late YoutubePlayerController _controller;
  bool _isInitialized = false;
  int _lastSavedPosition = 0;
  static const _saveIntervalSeconds = 10; // Save every 10 seconds
  static const _savePositionThreshold = 5; // Only save if moved 5+ seconds

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId == null) {
      debugPrint('[KlasivoYouTube] Invalid YouTube URL: ${widget.videoUrl}');
      return;
    }

    // Get saved resume position via provider
    final progressService = ref.read(contentProgressServiceProvider);
    final studentId = _getCurrentStudentId();
    int startPosition = 0;
    if (studentId != null) {
      startPosition = await progressService.getVideoResumePosition(
        studentId: studentId,
        lessonId: widget.lessonId,
      );
    }

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        startAt: startPosition,
        mute: false,
        isLive: false,
        forceHD: true,
        enableCaption: true,
      ),
    );

    _controller.addListener(_onPlayerStateChange);

    setState(() {
      _isInitialized = true;
    });
  }

  void _onPlayerStateChange() {
    if (_controller.value.isReady && _controller.value.isPlaying) {
      _trackProgress();
    }

    if (_controller.value.playerState == PlayerState.ended) {
      _saveFinalProgress();
    }
  }

  void _trackProgress() {
    final position = _controller.value.position.inSeconds;
    if (position - _lastSavedPosition >= _savePositionThreshold) {
      _saveProgress(position);
      _lastSavedPosition = position;
    }
  }

  Future<void> _saveProgress(int positionSeconds) async {
    final studentId = _getCurrentStudentId();
    if (studentId == null) return;

    final durationSeconds = _controller.value.metaData.duration.inSeconds;
    final progressService = ref.read(contentProgressServiceProvider);

    await progressService.saveVideoProgress(
      studentId: studentId,
      lessonId: widget.lessonId,
      subjectId: widget.subjectId,
      classId: widget.classId,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      organizationId: widget.organizationId,
    );

    // Invalidate the video progress provider so the UI refreshes
    ref.invalidate(videoProgressProvider(widget.lessonId));
  }

  Future<void> _saveFinalProgress() async {
    final durationSeconds = _controller.value.metaData.duration.inSeconds;
    await _saveProgress(durationSeconds);
  }

  String? _getCurrentStudentId() {
    try {
      final box = Hive.box(AppConstants.authBox);
      return box.get('userId') as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    // Save progress on dispose
    if (_controller.value.isReady) {
      final position = _controller.value.position.inSeconds;
      if (position > 0) {
        _saveProgress(position);
      }
    }
    _controller.removeListener(_onPlayerStateChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: KlasivoColors.darkSurface,
          borderRadius: BorderRadius.circular(KlasivoRadius.card),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: KlasivoColors.primary),
        ),
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: KlasivoColors.primary,
        progressColors: ProgressBarColors(
          playedColor: KlasivoColors.primary,
          handleColor: KlasivoColors.primaryLight,
          bufferedColor: KlasivoColors.primarySurface,
          backgroundColor: KlasivoColors.darkBorder,
        ),
        onReady: () {
          debugPrint('[KlasivoYouTube] Player ready');
        },
        onEnded: (data) {
          _saveFinalProgress();
        },
      ),
      builder: (context, player) {
        return Column(
          children: [
            // Player
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(KlasivoRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: player,
            ),

            // Resume badge
            if (_controller.flags.startAt > 0)
              Padding(
                padding: const EdgeInsets.only(top: KlasivoSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 14,
                      color: KlasivoColors.accent,
                    ),
                    const SizedBox(width: KlasivoSpacing.xs),
                    Text(
                      'Resuming from where you left off',
                      style: KlasivoTypography.caption.copyWith(
                        color: KlasivoColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
