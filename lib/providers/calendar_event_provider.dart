import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/config/app_constants.dart';
import '../core/services/calendar_event_service.dart';
import 'auth_provider.dart';
import 'organization_provider.dart';

// ─── Service Provider ──────────────────────────────────────────────────────

final calendarEventServiceProvider = Provider<CalendarEventService>((ref) => CalendarEventService());

// ─── Data Model ────────────────────────────────────────────────────────────

class CalendarEventData {
  final String id;
  final String organizationId;
  final String title;
  final String eventType; // 'exam', 'assignment', 'holiday', 'event', 'meeting', 'deadline'
  final DateTime date;
  final DateTime? endDate;
  final String? description;
  final String? classId;
  final String? groupId;
  final String? createdBy;
  final String? createdByName;
  final String? color;
  final bool isAllDay;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CalendarEventData({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.eventType,
    required this.date,
    this.endDate,
    this.description,
    this.classId,
    this.groupId,
    this.createdBy,
    this.createdByName,
    this.color,
    this.isAllDay = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CalendarEventData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarEventData(
      id: doc.id,
      organizationId: data['organizationId'] ?? '',
      title: data['title'] ?? '',
      eventType: data['eventType'] ?? 'event',
      date: (data['date'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      description: data['description'],
      classId: data['classId'],
      groupId: data['groupId'],
      createdBy: data['createdBy'],
      createdByName: data['createdByName'],
      color: data['color'],
      isAllDay: data['isAllDay'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'organizationId': organizationId,
    'title': title,
    'eventType': eventType,
    'date': Timestamp.fromDate(date),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'description': description,
    'classId': classId,
    'groupId': groupId,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'color': color,
    'isAllDay': isAllDay,
  };

  /// Get the display color for this event type
  int get colorValue {
    if (color != null) return int.parse(color!, radix: 16) + 0xFF000000;
    return switch (eventType) {
      'exam' => 0xFF3B5BDB,       // Royal Indigo
      'assignment' => 0xFFF59F00,  // Amber Gold
      'holiday' => 0xFF12B886,     // Emerald
      'event' => 0xFF845EF7,       // Purple
      'meeting' => 0xFF15AABF,     // Cyan
      'deadline' => 0xFFFA5252,    // Red
      _ => 0xFF868E96,             // Grey
    };
  }

  String get typeLabel => switch (eventType) {
    'exam' => 'Exam',
    'assignment' => 'Assignment',
    'holiday' => 'Holiday',
    'event' => 'Event',
    'meeting' => 'Meeting',
    'deadline' => 'Deadline',
    _ => eventType,
  };

  IconData get typeIcon => switch (eventType) {
    'exam' => Icons.quiz,
    'assignment' => Icons.assignment,
    'holiday' => Icons.celebration,
    'event' => Icons.event,
    'meeting' => Icons.people,
    'deadline' => Icons.alarm,
    _ => Icons.calendar_today,
  };
}

// ─── Selected Month Provider ───────────────────────────────────────────────

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ─── Stream Providers ──────────────────────────────────────────────────────

final calendarEventsByMonthProvider = StreamProvider<QuerySnapshot>((ref) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  if (orgId == null) return const Stream.empty();

  final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final end = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
  return ref.read(calendarEventServiceProvider).getEventsByMonthStream(orgId, start, end);
});

final calendarEventsByClassProvider = StreamProvider.family<QuerySnapshot, String>((ref, classId) {
  final orgId = ref.watch(currentOrganizationIdProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  if (orgId == null) return const Stream.empty();

  final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
  final end = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
  return ref.read(calendarEventServiceProvider).getEventsByClassStream(orgId, classId, start, end);
});

// ─── Derived List Provider ─────────────────────────────────────────────────

final calendarEventsProvider = Provider<List<CalendarEventData>>((ref) {
  final asyncEvents = ref.watch(calendarEventsByMonthProvider);
  return asyncEvents.when(
    data: (snapshot) => snapshot.docs.map((doc) => CalendarEventData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('Calendar events provider error: $e'); return []; },
  );
});

/// Events grouped by day of month
final eventsByDayProvider = Provider<Map<int, List<CalendarEventData>>>((ref) {
  final events = ref.watch(calendarEventsProvider);
  final grouped = <int, List<CalendarEventData>>{};
  for (final event in events) {
    final day = event.date.day;
    grouped.putIfAbsent(day, () => []).add(event);
  }
  return grouped;
});
