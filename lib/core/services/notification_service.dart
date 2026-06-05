import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../config/app_constants.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ─── Initialize Timezone & Local Notifications ──────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data for scheduled notifications
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle notification tap — will be connected to GoRouter for deep linking
      },
    );

    _initialized = true;
  }

  // ─── Request Notification Permissions ────────────────────────────────────

  static Future<bool> requestPermissions() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }

    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }

    return true;
  }

  // ─── Show Local Notification ─────────────────────────────────────────────

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'smart_exam_pro_channel',
      'Smart Exam Pro',
      channelDescription: 'Notifications for exams and results',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ─── Notification: Exam Published ────────────────────────────────────────

  static Future<void> notifyExamPublished({
    required String examTitle,
    required String className,
  }) async {
    await showNotification(
      title: 'New Exam Available',
      body: '"$examTitle" has been published for $className',
    );
  }

  // ─── Notification: Exam Starting Soon ────────────────────────────────────

  static Future<void> notifyExamStartingSoon({
    required String examTitle,
    required int minutesLeft,
  }) async {
    await showNotification(
      title: 'Exam Starting Soon',
      body: '"$examTitle" starts in $minutesLeft minutes',
    );
  }

  // ─── Notification: Exam Started ──────────────────────────────────────────

  static Future<void> notifyExamStarted({
    required String examTitle,
  }) async {
    await showNotification(
      title: 'Exam Started!',
      body: '"$examTitle" has started. Good luck!',
    );
  }

  // ─── Notification: Result Published ──────────────────────────────────────

  static Future<void> notifyResultPublished({
    required String examTitle,
    required int percentage,
  }) async {
    await showNotification(
      title: 'Result Published',
      body: 'Your result for "$examTitle" is ready. Score: $percentage%',
    );
  }

  // ─── Schedule Exam Reminders ─────────────────────────────────────────────

  /// Schedules local notifications for upcoming exams.
  /// Notifies 30 min before and at exam start time.
  static Future<void> scheduleExamReminders({
    required String examId,
    required String examTitle,
    required DateTime startDate,
  }) async {
    final now = DateTime.now();

    // 30 minutes before
    final thirtyMinBefore = startDate.subtract(const Duration(minutes: 30));
    if (thirtyMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 1,
        title: 'Exam Starting Soon',
        body: '"$examTitle" starts in 30 minutes',
        scheduledDate: tz.TZDateTime.from(thirtyMinBefore, tz.local),
      );
    }

    // At start time
    if (startDate.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 2,
        title: 'Exam Started!',
        body: '"$examTitle" has started. Open the app to take it now!',
        scheduledDate: tz.TZDateTime.from(startDate, tz.local),
      );
    }
  }

  // ─── Cancel Scheduled Reminders ──────────────────────────────────────────

  static Future<void> cancelExamReminders(String examId) async {
    await _localNotifications.cancel((examId.hashCode & 0x7FFFFFFF) + 1);
    await _localNotifications.cancel((examId.hashCode & 0x7FFFFFFF) + 2);
  }

  // ─── Cancel All Notifications ────────────────────────────────────────────

  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  // ─── Schedule a Single Notification ──────────────────────────────────────

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'smart_exam_pro_scheduled',
      'Smart Exam Pro - Scheduled',
      channelDescription: 'Scheduled notifications for exam reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
