import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_providers.dart';
import '../data/livekit_repository.dart';
import '../domain/livekit_room_model.dart';
import '../domain/livekit_chat_message.dart';
import '../domain/livekit_raised_hand.dart';
import '../domain/livekit_attendance.dart';

// ══════════════════════════════════════════════════════════════════════════
// Repository Provider
// ══════════════════════════════════════════════════════════════════════════

/// [LiveKitRepository] provider — uses FirebaseFunctions + FirebaseFirestore
final liveKitRepositoryProvider = Provider<LiveKitRepository>((ref) {
  return LiveKitRepository();
});

// ══════════════════════════════════════════════════════════════════════════
// Token Generation
// ══════════════════════════════════════════════════════════════════════════

/// Async notifier for generating a LiveKit token.
final liveKitTokenProvider = StateNotifierProvider<LiveKitTokenNotifier, AsyncValue<String>>((ref) {
  return LiveKitTokenNotifier(ref.watch(liveKitRepositoryProvider));
});

class LiveKitTokenNotifier extends StateNotifier<AsyncValue<String>> {
  final LiveKitRepository _repo;

  LiveKitTokenNotifier(this._repo) : super(const AsyncData(''));

  Future<String?> generateToken({
    required String roomName,
    String? displayName,
    bool isTeacher = false,
  }) async {
    state = const AsyncLoading();
    try {
      final token = await _repo.generateToken(
        roomName: roomName,
        displayName: displayName,
        isTeacher: isTeacher,
      );
      state = AsyncData(token);
      return token;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Room Streams
// ══════════════════════════════════════════════════════════════════════════

/// Stream of active LiveKit rooms for the current organization.
final activeLiveKitRoomsProvider = StreamProvider.family<List<LiveKitRoom>, String>((ref, orgId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchActiveRooms(orgId);
});

/// Stream of a single LiveKit room.
final liveKitRoomProvider = StreamProvider.family<LiveKitRoom?, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRoom(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// In-Class Chat
// ══════════════════════════════════════════════════════════════════════════

/// Stream of chat messages for a specific room.
final chatMessagesProvider = StreamProvider.family<List<LiveKitChatMessage>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchChatMessages(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// Raise Hand
// ══════════════════════════════════════════════════════════════════════════

/// Stream of currently raised hands for a specific room.
final raisedHandsProvider = StreamProvider.family<List<LiveKitRaisedHand>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRaisedHands(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// Attendance
// ══════════════════════════════════════════════════════════════════════════

/// Stream of attendance records for a specific room.
final attendanceProvider = StreamProvider.family<List<LiveKitAttendance>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchAttendance(roomId);
});
