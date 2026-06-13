import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_providers.dart';
import '../data/livekit_repository.dart';
import '../domain/livekit_room_model.dart';
import '../domain/livekit_chat_message.dart';
import '../domain/livekit_raised_hand.dart';
import '../domain/livekit_attendance.dart';
import '../domain/recording_model.dart';
import '../domain/scheduled_class_model.dart';
import '../domain/session_analytics_model.dart';

// ══════════════════════════════════════════════════════════════════════════
// Repository Provider
// ══════════════════════════════════════════════════════════════════════════

final liveKitRepositoryProvider = Provider<LiveKitRepository>((ref) {
  return LiveKitRepository();
});

// ══════════════════════════════════════════════════════════════════════════
// Token Generation
// ══════════════════════════════════════════════════════════════════════════

final liveKitTokenProvider = StateNotifierProvider<LiveKitTokenNotifier, AsyncValue<String>>((ref) {
  return LiveKitTokenNotifier(ref.watch(liveKitRepositoryProvider));
});

class LiveKitTokenNotifier extends StateNotifier<AsyncValue<String>> {
  final LiveKitRepository _repo;

  LiveKitTokenNotifier(this._repo) : super(const AsyncData(''));

  Future<String?> generateToken({
    required String roomId,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    try {
      final token = await _repo.generateToken(
        roomId: roomId,
        displayName: displayName,
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

final activeLiveKitRoomsProvider = StreamProvider.family<List<LiveKitRoom>, String>((ref, orgId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchActiveRooms(orgId);
});

final liveKitRoomProvider = StreamProvider.family<LiveKitRoom?, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRoom(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// In-Class Chat
// ══════════════════════════════════════════════════════════════════════════

final chatMessagesProvider = StreamProvider.family<List<LiveKitChatMessage>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchChatMessages(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// Raise Hand
// ══════════════════════════════════════════════════════════════════════════

final raisedHandsProvider = StreamProvider.family<List<LiveKitRaisedHand>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRaisedHands(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// Attendance
// ══════════════════════════════════════════════════════════════════════════

final attendanceProvider = StreamProvider.family<List<LiveKitAttendance>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchAttendance(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// Recordings
// ══════════════════════════════════════════════════════════════════════════

final orgRecordingsProvider = StreamProvider.family<List<Recording>, String>((ref, orgId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRecordings(orgId);
});

final roomRecordingsProvider = StreamProvider.family<List<Recording>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRoomRecordings(roomId);
});

// ══════════════════════════════════════════════════════════════════════════
// Scheduled Classes
// ══════════════════════════════════════════════════════════════════════════

final upcomingClassesProvider = StreamProvider.family<List<ScheduledClass>, String>((ref, orgId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchUpcomingClasses(orgId);
});

final teacherClassesProvider = StreamProvider.family<List<ScheduledClass>, String>((ref, teacherId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchTeacherClasses(teacherId);
});

// ══════════════════════════════════════════════════════════════════════════
// Session Analytics
// ══════════════════════════════════════════════════════════════════════════

final roomAnalyticsProvider = StreamProvider.family<List<SessionAnalytics>, String>((ref, roomId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchRoomAnalytics(roomId);
});

final orgAnalyticsProvider = StreamProvider.family<List<SessionAnalytics>, String>((ref, orgId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchOrgAnalytics(orgId);
});

final teacherAnalyticsProvider = StreamProvider.family<List<SessionAnalytics>, String>((ref, teacherId) {
  final repo = ref.watch(liveKitRepositoryProvider);
  return repo.watchTeacherAnalytics(teacherId);
});
