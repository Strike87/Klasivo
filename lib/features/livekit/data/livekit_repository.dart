import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'domain/livekit_room_model.dart';
import 'domain/livekit_chat_message.dart';
import 'domain/livekit_raised_hand.dart';
import 'domain/livekit_attendance.dart';
import 'domain/recording_model.dart';
import 'domain/scheduled_class_model.dart';
import 'domain/session_analytics_model.dart';

/// Full-featured repository for LiveKit room management.
///
/// Handles:
///   - Firestore CRUD for `livekit_rooms` collection
///   - Callable function invocation for token generation
///   - In-class chat (livekit_room_messages sub-collection)
///   - Raise-hand system (livekit_room_raised_hands sub-collection)
///   - Attendance tracking (livekit_room_attendance sub-collection)
///   - Session recording metadata
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
  /// The server derives roomName and role grants from the room document
  /// and the caller's auth claims — the client sends only roomId.
  Future<String> generateToken({
    required String roomId,
    String? displayName,
  }) async {
    final callable = _functions.httpsCallable('generateLiveKitToken');
    final result = await callable.call<Map<String, dynamic>>({
      'roomId': roomId,
      'displayName': displayName,
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

  /// Update room status (e.g., mark as ended, start recording).
  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = DateTime.now().toIso8601String();
    await _firestore.collection('livekit_rooms').doc(roomId).update(updates);
  }

  /// Delete a room (owner only).
  Future<void> deleteRoom(String roomId) async {
    await _firestore.collection('livekit_rooms').doc(roomId).delete();
  }

  // ─── Attendance ──────────────────────────────────────────────

  /// Mark a participant as joined (creates or updates attendance record).
  Future<void> markAttendance({
    required String roomId,
    required LiveKitAttendance attendance,
  }) async {
    await _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('attendance')
        .doc(attendance.uid)
        .set(attendance.toFirestore(), SetOptions(merge: true));
  }

  /// Mark a participant as left.
  Future<void> markLeft({
    required String roomId,
    required String uid,
  }) async {
    await _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('attendance')
        .doc(uid)
        .update({
      'leftAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Stream attendance for a room.
  Stream<List<LiveKitAttendance>> watchAttendance(String roomId) {
    return _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('attendance')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveKitAttendance.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ─── In-Class Chat ───────────────────────────────────────────

  /// Send a chat message in a room.
  Future<void> sendChatMessage({
    required String roomId,
    required LiveKitChatMessage message,
  }) async {
    await _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toFirestore());
  }

  /// Stream chat messages for a room (last 200).
  Stream<List<LiveKitChatMessage>> watchChatMessages(String roomId) {
    return _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .limitToLast(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveKitChatMessage.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ─── Raise Hand ──────────────────────────────────────────────

  /// Toggle raised hand for a participant.
  Future<void> toggleRaisedHand({
    required String roomId,
    required LiveKitRaisedHand hand,
  }) async {
    await _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('raised_hands')
        .doc(hand.uid)
        .set(hand.toFirestore(), SetOptions(merge: true));
  }

  /// Lower a specific raised hand (teacher action).
  Future<void> lowerHand({
    required String roomId,
    required String uid,
  }) async {
    await _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('raised_hands')
        .doc(uid)
        .update({
      'isRaised': false,
      'loweredAt': DateTime.now().toIso8601String(),
    });
  }

  /// Lower all raised hands (teacher action).
  Future<void> lowerAllHands(String roomId) async {
    final snapshot = await _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('raised_hands')
        .where('isRaised', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRaised': false,
        'loweredAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }

  /// Stream raised hands for a room.
  Stream<List<LiveKitRaisedHand>> watchRaisedHands(String roomId) {
    return _firestore
        .collection('livekit_rooms')
        .doc(roomId)
        .collection('raised_hands')
        .where('isRaised', isEqualTo: true)
        .orderBy('raisedAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => LiveKitRaisedHand.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ─── Participant Removal ────────────────────────────────────

  /// Remove a participant from a room via the `removeParticipant` callable.
  Future<bool> removeParticipant({
    required String roomName,
    required String participantIdentity,
    required String roomId,
  }) async {
    final callable = _functions.httpsCallable('removeParticipant');
    final result = await callable.call<Map<String, dynamic>>({
      'roomName': roomName,
      'participantIdentity': participantIdentity,
      'roomId': roomId,
    });
    return result.data['success'] as bool? ?? false;
  }

  // ─── Recordings ─────────────────────────────────────────────

  /// Get recordings for an organization.
  Stream<List<Recording>> watchRecordings(String orgId) {
    return _firestore
        .collection('recordings')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Recording.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Get recordings for a specific room.
  Stream<List<Recording>> watchRoomRecordings(String roomId) {
    return _firestore
        .collection('recordings')
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Recording.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ─── Scheduled Classes ──────────────────────────────────────

  /// Create a scheduled class.
  Future<String> createScheduledClass(ScheduledClass scheduledClass) async {
    final docRef = await _firestore.collection('scheduled_classes').add(scheduledClass.toFirestore());
    return docRef.id;
  }

  /// Update a scheduled class.
  Future<void> updateScheduledClass(String classId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = DateTime.now().toIso8601String();
    await _firestore.collection('scheduled_classes').doc(classId).update(updates);
  }

  /// Delete a scheduled class.
  Future<void> deleteScheduledClass(String classId) async {
    await _firestore.collection('scheduled_classes').doc(classId).delete();
  }

  /// Watch upcoming classes for an organization.
  Stream<List<ScheduledClass>> watchUpcomingClasses(String orgId) {
    return _firestore
        .collection('scheduled_classes')
        .where('organizationId', isEqualTo: orgId)
        .where('isStarted', isEqualTo: false)
        .orderBy('startsAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ScheduledClass.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Watch a teacher's scheduled classes.
  Stream<List<ScheduledClass>> watchTeacherClasses(String teacherId) {
    return _firestore
        .collection('scheduled_classes')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('startsAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ScheduledClass.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // ─── Session Analytics ──────────────────────────────────────

  /// Get analytics for a specific room.
  Stream<List<SessionAnalytics>> watchRoomAnalytics(String roomId) {
    return _firestore
        .collection('session_analytics')
        .where('roomId', isEqualTo: roomId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionAnalytics.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Get analytics for an organization (teacher dashboard).
  Stream<List<SessionAnalytics>> watchOrgAnalytics(String orgId) {
    return _firestore
        .collection('session_analytics')
        .where('organizationId', isEqualTo: orgId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionAnalytics.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Get analytics for a specific teacher.
  Stream<List<SessionAnalytics>> watchTeacherAnalytics(String teacherId) {
    return _firestore
        .collection('session_analytics')
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SessionAnalytics.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}
