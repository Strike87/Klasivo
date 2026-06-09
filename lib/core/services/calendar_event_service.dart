import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';

class CalendarEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a calendar event
  Future<String> createEvent({
    required String organizationId,
    required String title,
    required String eventType, // 'exam', 'assignment', 'holiday', 'event', 'meeting', 'deadline'
    required DateTime date,
    DateTime? endDate,
    String? description,
    String? classId,
    String? groupId,
    String? createdBy,
    String? createdByName,
    String? color, // Hex color string
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.calendarEventsCollection)
          .add({
        'organizationId': organizationId,
        'title': title,
        'eventType': eventType,
        'date': Timestamp.fromDate(date),
        'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
        'description': description,
        'classId': classId,
        'groupId': groupId,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'color': color,
        'isAllDay': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating calendar event: $e');
      rethrow;
    }
  }

  /// Update a calendar event
  Future<void> updateEvent(String eventId, {
    String? title,
    String? eventType,
    DateTime? date,
    DateTime? endDate,
    String? description,
    String? classId,
    String? groupId,
    String? color,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (eventType != null) data['eventType'] = eventType;
      if (date != null) data['date'] = Timestamp.fromDate(date);
      if (endDate != null) data['endDate'] = Timestamp.fromDate(endDate);
      if (description != null) data['description'] = description;
      if (classId != null) data['classId'] = classId;
      if (groupId != null) data['groupId'] = groupId;
      if (color != null) data['color'] = color;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(AppConstants.calendarEventsCollection)
          .doc(eventId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating calendar event: $e');
      rethrow;
    }
  }

  /// Delete a calendar event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore
          .collection(AppConstants.calendarEventsCollection)
          .doc(eventId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting calendar event: $e');
      rethrow;
    }
  }

  /// Stream events by organization for a given month range
  Stream<QuerySnapshot> getEventsByMonthStream(String orgId, DateTime startOfMonth, DateTime endOfMonth) {
    return _firestore
        .collection(AppConstants.calendarEventsCollection)
        .where('organizationId', orgId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date')
        .snapshots();
  }

  /// Stream events by class
  Stream<QuerySnapshot> getEventsByClassStream(String orgId, String classId, DateTime startOfMonth, DateTime endOfMonth) {
    return _firestore
        .collection(AppConstants.calendarEventsCollection)
        .where('organizationId', orgId)
        .where('classId', classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date')
        .snapshots();
  }

  /// Stream all events for a student (org-wide + class-specific)
  Stream<QuerySnapshot> getEventsForStudentStream(String orgId, DateTime startOfMonth, DateTime endOfMonth) {
    return _firestore
        .collection(AppConstants.calendarEventsCollection)
        .where('organizationId', orgId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date')
        .snapshots();
  }
}
