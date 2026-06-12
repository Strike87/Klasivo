import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_providers.dart';
import '../data/livekit_repository.dart';
import '../domain/livekit_room_model.dart';

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
/// Call [generateToken] to request a new token from the callable function.
final liveKitTokenProvider = StateNotifierProvider<LiveKitTokenNotifier, AsyncValue<String>>((ref) {
  return LiveKitTokenNotifier(ref.watch(liveKitRepositoryProvider));
});

class LiveKitTokenNotifier extends StateNotifier<AsyncValue<String>> {
  final LiveKitRepository _repo;

  LiveKitTokenNotifier(this._repo) : super(const AsyncData(''));

  /// Request a LiveKit token from the backend.
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
// Active Rooms Stream
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
