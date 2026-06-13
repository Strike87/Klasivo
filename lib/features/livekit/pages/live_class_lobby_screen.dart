import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../domain/livekit_room_model.dart';
import '../providers/livekit_providers.dart';
import 'live_class_screen.dart';

/// Lobby screen showing active LiveKit rooms for the organization.
/// Teachers see a "Start Class" button; students see "Join" buttons.
class LiveClassLobbyScreen extends ConsumerWidget {
  final String orgId;
  final String userId;
  final String displayName;
  final bool isTeacher;

  const LiveClassLobbyScreen({
    super.key,
    required this.orgId,
    required this.userId,
    required this.displayName,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(activeLiveKitRoomsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Classes'),
        actions: [
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Start New Class',
              onPressed: () => _showCreateRoomDialog(context, ref),
            ),
        ],
      ),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No active classes right now',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  if (isTeacher) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Start a Class'),
                      onPressed: () => _showCreateRoomDialog(context, ref),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(activeLiveKitRoomsProvider(orgId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return _RoomCard(
                  room: room,
                  isTeacher: isTeacher,
                  displayName: displayName,
                  onJoin: () => _joinRoom(context, ref, room),
                  onEnd: () => _endRoom(context, ref, room),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _joinRoom(BuildContext context, WidgetRef ref, LiveKitRoom room) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final repo = ref.read(liveKitRepositoryProvider);
      final token = await repo.generateToken(
        roomName: room.name,
        displayName: displayName,
        isTeacher: isTeacher,
      );

      if (context.mounted) {
        Navigator.pop(context); // dismiss loading

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveClassScreen(
              token: token,
              url: room.livekitUrl,
              room: room,
              isTeacher: isTeacher,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
    }
  }

  Future<void> _endRoom(BuildContext context, WidgetRef ref, LiveKitRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Class?'),
        content: Text('This will end "${room.name}" for all participants.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Class'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(liveKitRepositoryProvider);
      await repo.updateRoom(room.id, {
        'isActive': false,
        'endedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    String roomType = 'classroom';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Start New Class'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Room Name *',
                    hintText: 'e.g., Grade 6 Math',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g., Mathematics',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Class/Grade',
                    hintText: 'e.g., Grade 6',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: roomType,
                  decoration: const InputDecoration(labelText: 'Room Type'),
                  items: const [
                    DropdownMenuItem(value: 'classroom', child: Text('Classroom')),
                    DropdownMenuItem(value: 'exam_proctoring', child: Text('Exam Proctoring')),
                    DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                  ],
                  onChanged: (v) => setDialogState(() => roomType = v ?? 'classroom'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final repo = ref.read(liveKitRepositoryProvider);
                final roomId = await repo.createRoom(LiveKitRoom(
                  id: '',
                  name: name,
                  organizationId: orgId,
                  createdBy: userId,
                  roomType: roomType,
                  isActive: true,
                  isRecording: false,
                  startedAt: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  metadata: {
                    'subjectName': subjectCtrl.text.trim(),
                    'className': classCtrl.text.trim(),
                    'livekitUrl': 'wss://klasivo.livekit.cloud',
                  },
                ));

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  // Auto-join the created room
                  final room = await repo.getRoom(roomId);
                  if (room != null && context.mounted) {
                    _joinRoom(context, ref, room);
                  }
                }
              },
              child: const Text('Create & Join'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Room Card ─────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final LiveKitRoom room;
  final bool isTeacher;
  final String displayName;
  final VoidCallback onJoin;
  final VoidCallback onEnd;

  const _RoomCard({
    required this.room,
    required this.isTeacher,
    required this.displayName,
    required this.onJoin,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final roomTypeIcon = switch (room.roomType) {
      'classroom' => Icons.school,
      'exam_proctoring' => Icons.shield,
      'meeting' => Icons.groups,
      _ => Icons.videocam,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(roomTypeIcon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    room.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (room.isRecording)
                  const Row(
                    children: [
                      Icon(Icons.fiber_manual_record, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text('REC', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (room.subjectName != null) ...[
                  _InfoChip(label: room.subjectName!),
                  const SizedBox(width: 8),
                ],
                if (room.className != null) ...[
                  _InfoChip(label: room.className!),
                  const SizedBox(width: 8),
                ],
                _InfoChip(
                  label: room.roomType.replaceAll('_', ' ').toUpperCase(),
                  color: Colors.purple.shade100,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isTeacher)
                  TextButton.icon(
                    icon: const Icon(Icons.stop_circle, size: 18),
                    label: const Text('End Class'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: onEnd,
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(isTeacher ? 'Join as Teacher' : 'Join Class'),
                  onPressed: onJoin,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _InfoChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    );
  }
}
