import '../interfaces/i_notification_service.dart';

/// Mock implementation of [INotificationService] that records calls
/// in memory for test assertions.
class MockNotificationService implements INotificationService {
  final List<Map<String, dynamic>> _sentNotifications = [];
  final List<Map<String, dynamic>> _scheduledNotifications = [];

  /// Notifications sent via [sendLocalNotification].
  List<Map<String, dynamic>> get sentNotifications =>
      List.unmodifiable(_sentNotifications);

  /// Notifications scheduled via [scheduleNotification].
  List<Map<String, dynamic>> get scheduledNotifications =>
      List.unmodifiable(_scheduledNotifications);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    _sentNotifications.add({
      'title': title,
      'body': body,
      'payload': payload,
    });
  }

  @override
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    _scheduledNotifications.add({
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime,
    });
  }

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> cancelAllNotifications() async {
    _scheduledNotifications.clear();
  }

  /// Clear all recorded notifications. Useful between test cases.
  void reset() {
    _sentNotifications.clear();
    _scheduledNotifications.clear();
  }
}
