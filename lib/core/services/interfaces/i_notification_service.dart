/// Abstract interface for local and remote notification operations.
///
/// Implementations may wrap flutter_local_notifications + FCM,
/// or be mock/no-op versions for testing.
abstract class INotificationService {
  /// Initialize the notification system (plugins, channels, listeners).
  Future<void> initialize();

  /// Immediately show a local notification.
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  });

  /// Schedule a notification to appear at [scheduledTime].
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  });

  /// Cancel a previously scheduled notification by [id].
  Future<void> cancelNotification(int id);

  /// Cancel all pending and scheduled notifications.
  Future<void> cancelAllNotifications();
}
