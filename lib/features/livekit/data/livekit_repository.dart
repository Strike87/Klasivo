import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_functions/firebase_functions.dart';

import 'domain/livekit_room_model.dart';

/// Repository for LiveKit room management.
///
/// Handles:
///   - Firestore CRUD for `livekit_rooms` collection
///   - Callable function invocation for token generation
class LiveKitRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  LiveKitRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  // ─── Token Generation ────────────────────────────────────────

  /// Generate a LiveKit access token via the `generateLiveKitToken` callable.
  ///
  /// [roomName] — the LiveKit room identifier (must match server-side)
  /// [displayName] — the user's display name in the room
  /// [isTeacher] — whether the user should get roomAdmin privileges
  Future<String> generateToken({
    required String roomName,
    String? displayName,
    bool isTeacher = false,
  }) async {
    final callable = _functions.httpsCallable('generateLiveKitToken');
    final result = await callable.call<Map<String, dynamic>>({
      'roomName': roomName,
      'displayName': displayName,
      'isTeacher': isTeacher,
    });
    return result.data['token'] as String;
  }

  // ─── Room CRUD ───────────────────────────────────────────────

  /// Create a new room document in Firestore.
  Future<String> createRoom(LiveKitRoom room) async {
    final docRef = await _firestore.collection('livekit_rooms').add(room.toFirestore());
    return docRef.id;
  }

  /// Get a room by ID.
  Future<LiveKitRoom?> getRoom(String roomId) async {
    final doc = await _firestore.collection('livekit_rooms').doc(roomId).get();
    if (!doc.exists) return null;
    return LiveKitRoom.fromFirestore(doc.data()!, doc.id);
  }

  /// Watch a room in real-time.
  Stream<LiveKitRoom?> watchRoom(String roomId) {
    return _firestore.collection('livekit_rooms').doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LiveKitRoom.fromFirestore(doc.data()!, doc.id);
    });
  }

  /// List active rooms for an organization.
  Stream<List<LiveKitRoom>> watchActiveRooms(String orgId) {
    return _firestore
        .collection('livekit_rooms')
        .where('organizationId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveKitRoom.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Update room status (e.g., mark as ended).
  Future<void> updateRoomStatus(String roomId, {bool? isActive, DateTime? endedAt}) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (isActive != null) updates['isActive'] = isActive;
    if (endedAt != null) updates['endedAt'] = endedAt.toIso8601String();
    await _firestore.collection('livekit_rooms').doc(roomId).update(updates);
  }

  /// Delete a room (owner only).
  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('livekit_rooms').doc(roomId).delete();
  }
}
