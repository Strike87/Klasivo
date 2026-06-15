import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/services/sentry_service.dart';
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
///
/// All operations are instrumented with Sentry breadcrumbs, transactions,
/// and error capture for full observability.
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
    final transaction = KlasivoSentry.transactions.liveKitTokenGeneration();

    try {
      KlasivoSentry.breadcrumb.livekit('token_generation_started', data: {
        'roomId': roomId,
      });
      KlasivoCrashlytics.log('[livekit] Connecting to room: $roomId');

      final callable = _functions.httpsCallable('generateLiveKitToken');
      final result = await callable.call<Map<String, dynamic>>({
        'roomId': roomId,
        'displayName': displayName,
      });

      KlasivoSentry.breadcrumb.livekit('token_generation_success', data: {
        'roomId': roomId,
      });

      transaction.status = const SpanStatus.ok();
      return result.data['token'] as String;
    } catch (e, st) {
      transaction.status = const SpanStatus.internalError();
      KlasivoSentry.breadcrumb.livekit('token_generation_failed', data: {
        'roomId': roomId,
        'error': e.toString().substring(0, (e.toString().length).clamp(0, 100)),
      });
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_token_generation');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: token generation failed');
      rethrow;
    } finally {
      await transaction.finish();
    }
  }

  // ─── Room CRUD ───────────────────────────────────────────────

  /// Create a new room document in Firestore.
  Future<String> createRoom(LiveKitRoom room) async {
    KlasivoSentry.breadcrumb.livekit('room_create_start', data: {
      'roomName': room.name,
    });
    try {
      final docRef = await _firestore.collection('livekit_rooms').add(room.toFirestore());
      KlasivoSentry.breadcrumb.livekit('room_create_success', data: {
        'roomId': docRef.id,
      });
      return docRef.id;
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'livekit_rooms');
          scope.setTag('operation', 'create');
          scope.setTag('flow', 'livekit');
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: create room failed');
      rethrow;
    }
  }

  /// Get a room by ID.
  Future<LiveKitRoom?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('livekit_rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return LiveKitRoom.fromFirestore(doc.data()!, doc.id);
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'livekit_rooms');
          scope.setTag('operation', 'get');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: get room failed');
      rethrow;
    }
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
    KlasivoSentry.breadcrumb.livekit('room_update_start', data: {
      'roomId': roomId,
    });
    try {
      await _firestore.collection('livekit_rooms').doc(roomId).update(updates);
      KlasivoSentry.breadcrumb.livekit('room_update_success', data: {
        'roomId': roomId,
      });
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'livekit_rooms');
          scope.setTag('operation', 'update');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: update room failed');
      rethrow;
    }
  }

  /// Delete a room (owner only).
  Future<void> deleteRoom(String roomId) async {
    KlasivoSentry.breadcrumb.livekit('room_delete_start', data: {
      'roomId': roomId,
    });
    try {
      await _firestore.collection('livekit_rooms').doc(roomId).delete();
      KlasivoSentry.breadcrumb.livekit('room_delete_success', data: {
        'roomId': roomId,
      });
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'livekit_rooms');
          scope.setTag('operation', 'delete');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: delete room failed');
      rethrow;
    }
  }

  // ─── Attendance ──────────────────────────────────────────────

  /// Mark a participant as joined (creates or updates attendance record).
  Future<void> markAttendance({
    required String roomId,
    required LiveKitAttendance attendance,
  }) async {
    KlasivoSentry.breadcrumb.livekit('attendance_mark_joined', data: {
      'roomId': roomId,
      'uid': attendance.uid,
      'role': attendance.role,
    });
    try {
      await _firestore
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('attendance')
          .doc(attendance.uid)
          .set(attendance.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_attendance');
          scope.setTag('operation', 'mark_joined');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: mark attendance (joined) failed');
      rethrow;
    }
  }

  /// Mark a participant as left.
  Future<void> markLeft({
    required String roomId,
    required String uid,
  }) async {
    KlasivoSentry.breadcrumb.livekit('attendance_mark_left', data: {
      'roomId': roomId,
      'uid': uid,
    });
    KlasivoCrashlytics.log('[livekit] Disconnected from room');
    try {
      await _firestore
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('attendance')
          .doc(uid)
          .update({
        'leftAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_attendance');
          scope.setTag('operation', 'mark_left');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: mark left failed');
      rethrow;
    }
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
    try {
      await _firestore
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('messages')
          .add(message.toFirestore());
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_chat');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: send chat message failed');
      rethrow;
    }
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
    try {
      await _firestore
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('raised_hands')
          .doc(hand.uid)
          .set(hand.toFirestore(), SetOptions(merge: true));
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_raise_hand');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: toggle raised hand failed');
      rethrow;
    }
  }

  /// Lower a specific raised hand (teacher action).
  Future<void> lowerHand({
    required String roomId,
    required String uid,
  }) async {
    try {
      await _firestore
          .collection('livekit_rooms')
          .doc(roomId)
          .collection('raised_hands')
          .doc(uid)
          .update({
        'isRaised': false,
        'loweredAt': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_lower_hand');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: lower hand failed');
      rethrow;
    }
  }

  /// Lower all raised hands (teacher action).
  Future<void> lowerAllHands(String roomId) async {
    try {
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
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_lower_all_hands');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: lower all hands failed');
      rethrow;
    }
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
    KlasivoSentry.breadcrumb.cloudFunction('removeParticipant_invoked', data: {
      'roomName': roomName,
      'roomId': roomId,
    });
    try {
      final callable = _functions.httpsCallable('removeParticipant');
      final result = await callable.call<Map<String, dynamic>>({
        'roomName': roomName,
        'participantIdentity': participantIdentity,
        'roomId': roomId,
      });
      KlasivoSentry.breadcrumb.cloudFunction('removeParticipant_success', data: {
        'roomId': roomId,
      });
      return result.data['success'] as bool? ?? false;
    } catch (e, st) {
      KlasivoSentry.breadcrumb.cloudFunction('removeParticipant_failed', data: {
        'roomId': roomId,
      });
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('flow', 'livekit_remove_participant');
          scope.setTag('roomId', roomId);
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: remove participant failed');
      rethrow;
    }
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
    try {
      final docRef = await _firestore.collection('scheduled_classes').add(scheduledClass.toFirestore());
      return docRef.id;
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'scheduled_classes');
          scope.setTag('operation', 'create');
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: create scheduled class failed');
      rethrow;
    }
  }

  /// Update a scheduled class.
  Future<void> updateScheduledClass(String classId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = DateTime.now().toIso8601String();
    try {
      await _firestore.collection('scheduled_classes').doc(classId).update(updates);
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'scheduled_classes');
          scope.setTag('operation', 'update');
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: update scheduled class failed');
      rethrow;
    }
  }

  /// Delete a scheduled class.
  Future<void> deleteScheduledClass(String classId) async {
    try {
      await _firestore.collection('scheduled_classes').doc(classId).delete();
    } catch (e, st) {
      await Sentry.captureException(
        e,
        stackTrace: st,
        withScope: (scope) {
          scope.setTag('collection', 'scheduled_classes');
          scope.setTag('operation', 'delete');
        },
      );
      KlasivoCrashlytics.recordError(e, st, reason: 'livekit: delete scheduled class failed');
      rethrow;
    }
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
