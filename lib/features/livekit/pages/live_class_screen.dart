import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/config/app_constants.dart';
import '../domain/livekit_room_model.dart';
import '../providers/livekit_providers.dart';

/// Full-featured live class screen with video grid, in-class chat,
/// raise-hand system, attendance tracking, and recording controls.
class LiveClassScreen extends ConsumerStatefulWidget {
  final String token;
  final String url;
  final LiveKitRoom room;
  final bool isTeacher;

  const LiveClassScreen({
    super.key,
    required this.token,
    required this.url,
    required this.room,
    required this.isTeacher,
  });

  @override
  ConsumerState<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends ConsumerState<LiveClassScreen> {
  late Room _room;
  bool _isConnected = false;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isScreenShareEnabled = false;
  bool _isChatOpen = false;
  bool _isAttendeesOpen = false;

  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _room = Room();
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _room.connect(widget.url, widget.token);

      // Mark attendance on join
      ref.read(liveKitRepositoryProvider).markAttendance(
            roomId: widget.room.id,
            attendance: LiveKitAttendance(
              uid: _room.localParticipant?.identity ?? '',
              displayName: _room.localParticipant?.name ?? '',
              role: widget.isTeacher ? 'teacher' : 'student',
              joinedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);

      // Listen for room events
      _room.addListener(_onRoomChanged);

      setState(() => _isConnected = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _disconnect() async {
    // Mark attendance on leave
    final uid = _room.localParticipant?.identity ?? '';
    await ref.read(liveKitRepositoryProvider).markLeft(
          roomId: widget.room.id,
          uid: uid,
        );

    await _room.disconnect();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _room.removeListener(_onRoomChanged);
    _room.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ─── Actions ─────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    await _room.localParticipant?.setMicrophoneEnabled(!_isMicEnabled);
    setState(() => _isMicEnabled = !_isMicEnabled);
  }

  Future<void> _toggleCamera() async {
    await _room.localParticipant?.setCameraEnabled(!_isCameraEnabled);
    setState(() => _isCameraEnabled = !_isCameraEnabled);
  }

  Future<void> _toggleScreenShare() async {
    if (_isScreenShareEnabled) {
      await _room.localParticipant?.setScreenShareEnabled(false);
    } else {
      await _room.localParticipant?.setScreenShareEnabled(true);
    }
    setState(() => _isScreenShareEnabled = !_isScreenShareEnabled);
  }

  Future<void> _toggleRecording() async {
    final repo = ref.read(liveKitRepositoryProvider);
    final newRecordingState = !widget.room.isRecording;
    await repo.updateRoom(widget.room.id, {'isRecording': newRecordingState});
  }

  Future<void> _toggleRaisedHand() async {
    final uid = _room.localParticipant?.identity ?? '';
    final displayName = _room.localParticipant?.name ?? '';
    final repo = ref.read(liveKitRepositoryProvider);
    await repo.toggleRaisedHand(
      roomId: widget.room.id,
      hand: LiveKitRaisedHand(
        uid: uid,
        displayName: displayName,
        isRaised: true,
        raisedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    final uid = _room.localParticipant?.identity ?? '';
    final displayName = _room.localParticipant?.name ?? '';
    final repo = ref.read(liveKitRepositoryProvider);
    await repo.sendChatMessage(
      roomId: widget.room.id,
      message: LiveKitChatMessage(
        id: '',
        uid: uid,
        displayName: displayName,
        message: text,
        type: 'text',
        sentAt: DateTime.now(),
      ),
    );
    _chatController.clear();
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final participants = _room.remoteParticipants.values.toList();
    final raisedHandsAsync = ref.watch(raisedHandsProvider(widget.room.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          // Recording indicator
          if (widget.room.isRecording)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
            ),
          // Attendees count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text('${participants.length + 1} joined'),
            ),
          ),
        ],
      ),
      body: _isConnected
          ? Row(
              children: [
                // Main video area
                Expanded(
                  flex: _isChatOpen ? 2 : 1,
                  child: Column(
                    children: [
                      // ── Raised hands banner ──
                      raisedHandsAsync.when(
                        data: (hands) {
                          if (hands.isEmpty) return const SizedBox.shrink();
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: Colors.amber.shade100,
                            child: Row(
                              children: [
                                const Icon(Icons.pan_tool, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${hands.map((h) => h.displayName).join(", ")} raised hand(s)',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isTeacher)
                                  TextButton(
                                    onPressed: () => ref
                                        .read(liveKitRepositoryProvider)
                                        .lowerAllHands(widget.room.id),
                                    child: const Text('Lower All'),
                                  ),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // ── Local participant video ──
                      Expanded(
                        flex: 2,
                        child: _buildLocalVideo(),
                      ),

                      // ── Remote participants grid ──
                      Expanded(
                        flex: 3,
                        child: GridView.builder(
                          itemCount: participants.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 16 / 12,
                          ),
                          itemBuilder: (context, index) {
                            return _buildRemoteVideo(participants[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Side panel: Chat or Attendees ──
                if (_isChatOpen) _buildChatPanel(),
                if (_isAttendeesOpen && !_isChatOpen) _buildAttendeesPanel(),
              ],
            )
          : const Center(child: CircularProgressIndicator()),

      // ── Bottom controls ──
      bottomNavigationBar: _isConnected ? _buildControls() : null,
    );
  }

  // ─── Video Widgets ───────────────────────────────────────────

  Widget _buildLocalVideo() {
    final localParticipant = _room.localParticipant;
    if (localParticipant == null) return const SizedBox();

    final videoTracks = localParticipant.videoTrackPublications;
    VideoTrack? videoTrack;
    for (final pub in videoTracks) {
      if (pub.track is VideoTrack && !pub.isScreenShare) {
        videoTrack = pub.track as VideoTrack;
        break;
      }
    }

    return Stack(
      children: [
        if (videoTrack != null && _isCameraEnabled)
          VideoTrackRenderer(videoTrack)
        else
          Container(
            color: Colors.grey.shade800,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 48, color: Colors.white54),
                  Text(
                    localParticipant.name ?? localParticipant.identity ?? 'You',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${localParticipant.name ?? "You"} (You)',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteVideo(RemoteParticipant participant) {
    final videoTracks = participant.videoTrackPublications;
    VideoTrack? videoTrack;
    for (final pub in videoTracks) {
      if (pub.track is VideoTrack) {
        videoTrack = pub.track as VideoTrack;
        break;
      }
    }

    return Stack(
      children: [
        if (videoTrack != null)
          VideoTrackRenderer(videoTrack)
        else
          Container(
            color: Colors.grey.shade900,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 36, color: Colors.white38),
                  Text(
                    participant.name ?? participant.identity ?? '',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              participant.name ?? participant.identity ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Chat Panel ──────────────────────────────────────────────

  Widget _buildChatPanel() {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.room.id));
    return SizedBox(
      width: 300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('In-Class Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _isChatOpen = false),
                ),
              ],
            ),
          ),
          // Messages list
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                // Auto-scroll to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_chatScrollController.hasClients) {
                    _chatScrollController.animateTo(
                      _chatScrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.uid == (_room.localParticipant?.identity ?? '');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${msg.displayName}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isMe ? Colors.blue : Colors.grey.shade700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              msg.message,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading chat')),
            ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Attendees Panel ─────────────────────────────────────────

  Widget _buildAttendeesPanel() {
    final attendanceAsync = ref.watch(attendanceProvider(widget.room.id));
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Attendees', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _isAttendeesOpen = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: attendanceAsync.when(
              data: (attendees) {
                final teachers = attendees.where((a) => a.role == 'teacher').toList();
                final students = attendees.where((a) => a.role == 'student').toList();
                return ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    if (teachers.isNotEmpty) ...[
                      const Text('Teachers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ...teachers.map((a) => ListTile(
                            dense: true,
                            leading: Icon(Icons.person, size: 20, color: Colors.blue.shade700),
                            title: Text(a.displayName, style: const TextStyle(fontSize: 13)),
                            trailing: a.isPresent
                                ? const Icon(Icons.circle, size: 8, color: Colors.green)
                                : const Icon(Icons.circle, size: 8, color: Colors.grey),
                          )),
                      const Divider(),
                    ],
                    Text('Students (${students.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ...students.map((a) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline, size: 20),
                          title: Text(a.displayName, style: const TextStyle(fontSize: 13)),
                          trailing: a.isPresent
                              ? const Icon(Icons.circle, size: 8, color: Colors.green)
                              : const Icon(Icons.circle, size: 8, color: Colors.grey),
                        )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading attendees')),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Controls Bar ────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic
          _ControlButton(
            icon: _isMicEnabled ? Icons.mic : Icons.mic_off,
            label: _isMicEnabled ? 'Mute' : 'Unmute',
            isActive: _isMicEnabled,
            onPressed: _toggleMic,
          ),
          // Camera
          _ControlButton(
            icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: _isCameraEnabled ? 'Stop Video' : 'Start Video',
            isActive: _isCameraEnabled,
            onPressed: _toggleCamera,
          ),
          // Screen share (teacher only)
          if (widget.isTeacher)
            _ControlButton(
              icon: _isScreenShareEnabled ? Icons.screen_share : Icons.stop_screen_share,
              label: _isScreenShareEnabled ? 'Stop Share' : 'Share Screen',
              isActive: _isScreenShareEnabled,
              onPressed: _toggleScreenShare,
            ),
          // Recording (teacher only)
          if (widget.isTeacher)
            _ControlButton(
              icon: widget.room.isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
              label: widget.room.isRecording ? 'Stop Rec' : 'Record',
              isActive: widget.room.isRecording,
              onPressed: _toggleRecording,
              activeColor: Colors.red,
            ),
          // Raise hand (student only)
          if (!widget.isTeacher)
            _ControlButton(
              icon: Icons.pan_tool,
              label: 'Raise Hand',
              onPressed: _toggleRaisedHand,
            ),
          // Chat
          _ControlButton(
            icon: Icons.chat,
            label: 'Chat',
            isActive: _isChatOpen,
            onPressed: () => setState(() {
              _isChatOpen = !_isChatOpen;
              _isAttendeesOpen = false;
            }),
          ),
          // Attendees
          _ControlButton(
            icon: Icons.people,
            label: 'Attendees',
            isActive: _isAttendeesOpen,
            onPressed: () => setState(() {
              _isAttendeesOpen = !_isAttendeesOpen;
              _isChatOpen = false;
            }),
          ),
          // Leave
          _ControlButton(
            icon: Icons.call_end,
            label: 'Leave',
            onPressed: _disconnect,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

// ─── Control Button Widget ───────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? color;
  final Color? activeColor;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.color,
    this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive
        ? (activeColor ?? Theme.of(context).colorScheme.primary)
        : (color ?? Colors.grey.shade600);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: effectiveColor),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: isActive ? effectiveColor.withOpacity(0.12) : null,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: effectiveColor)),
      ],
    );
  }
}
