import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../config/app_constants.dart';

// ─── Background message handler (must be top-level function) ────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background isolate
  await FirebaseMessaging.instance.getInitialMessage();
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static bool _initialized = false;
  static String? _fcmToken;

  // ─── Get FCM Token ──────────────────────────────────────────────────────

  static String? get fcmToken => _fcmToken;

  // ─── Initialize Timezone, Local Notifications & FCM ─────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone data for scheduled notifications
    tz_data.initializeTimeZones();

    // Initialize local notifications
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

    // Create Android notification channels
    await _createNotificationChannels();

    // Initialize FCM
    await _initializeFCM();

    _initialized = true;
  }

  // ─── Create Android Notification Channels ────────────────────────────────

  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'klasivo_channel',
        'Klasivo',
        description: 'Notifications for exams and results',
        importance: Importance.high,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'klasivo_scheduled',
        'Exam Reminders',
        description: 'Scheduled notifications for exam reminders',
        importance: Importance.high,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'exam_notifications',
        'Exam Notifications',
        description: 'Push notifications for exams',
        importance: Importance.high,
      ));
    }
  }

  // ─── Initialize Firebase Cloud Messaging ─────────────────────────────────

  static Future<void> _initializeFCM() async {
    // Request permission
    await requestPermissions();

    // Get FCM token
    _fcmToken = await _fcm.getToken();
    print('FCM Token: $_fcmToken');

    // Listen to token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('FCM Token refreshed: $newToken');
      // TODO: Send token to server for targeted push notifications
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageOpenedApp(message);
    });

    // Check if app was opened from a notification (terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // ─── Handle Foreground Messages ──────────────────────────────────────────

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      showNotification(
        title: notification.title ?? 'Klasivo',
        body: notification.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  // ─── Handle Message Opened App ───────────────────────────────────────────

  static void _handleMessageOpenedApp(RemoteMessage message) {
    // TODO: Navigate to relevant screen based on message.data
    // Example: if message.data['type'] == 'exam', go to exam screen
    final data = message.data;
    print('Notification opened with data: $data');
  }

  // ─── Request Notification Permissions ────────────────────────────────────

  static Future<bool> requestPermissions() async {
    // Request FCM permission (iOS mostly, Android auto-grants)
    final fcmSettings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Also request local notification permission for Android 13+
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      return await androidPlugin.requestNotificationsPermission() ?? false;
    }

    final iosPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }

    return fcmSettings.authorizationStatus == AuthorizationStatus.authorized;
  }

  // ─── Subscribe to Topics ─────────────────────────────────────────────────

  static Future<void> subscribeToClass(String classId) async {
    await _fcm.subscribeToTopic('class_$classId');
  }

  static Future<void> unsubscribeFromClass(String classId) async {
    await _fcm.unsubscribeFromTopic('class_$classId');
  }

  static Future<void> subscribeToExam(String examId) async {
    await _fcm.subscribeToTopic('exam_$examId');
  }

  static Future<void> unsubscribeFromExam(String examId) async {
    await _fcm.unsubscribeFromTopic('exam_$examId');
  }

  // ─── Show Local Notification ─────────────────────────────────────────────

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'klasivo_channel',
      'Klasivo',
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

  // ─── Notification: Homework Assigned ─────────────────────────────────────

  static Future<void> notifyHomeworkAssigned({
    required String homeworkTitle,
    required String className,
  }) async {
    await showNotification(
      title: 'New Homework',
      body: '"$homeworkTitle" assigned for $className',
    );
  }

  // ─── Notification: Announcement ──────────────────────────────────────────

  static Future<void> notifyAnnouncement({
    required String title,
    required String message,
  }) async {
    await showNotification(
      title: title,
      body: message,
    );
  }

  // ─── Schedule Exam Reminders ─────────────────────────────────────────────

  static Future<void> scheduleExamReminders({
    required String examId,
    required String examTitle,
    required DateTime startDate,
  }) async {
    final now = DateTime.now();

    // 24 hours before
    final twentyFourHoursBefore = startDate.subtract(const Duration(hours: 24));
    if (twentyFourHoursBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 0,
        title: 'Exam Reminder',
        body: '"$examTitle" starts tomorrow',
        scheduledDate: tz.TZDateTime.from(twentyFourHoursBefore, tz.local),
      );
    }

    // 1 hour before
    final oneHourBefore = startDate.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 1,
        title: 'Exam Starting Soon',
        body: '"$examTitle" starts in 1 hour',
        scheduledDate: tz.TZDateTime.from(oneHourBefore, tz.local),
      );
    }

    // 15 minutes before
    final fifteenMinBefore = startDate.subtract(const Duration(minutes: 15));
    if (fifteenMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 2,
        title: 'Exam Starting Soon!',
        body: '"$examTitle" starts in 15 minutes',
        scheduledDate: tz.TZDateTime.from(fifteenMinBefore, tz.local),
      );
    }

    // At start time
    if (startDate.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 3,
        title: 'Exam Started!',
        body: '"$examTitle" has started. Open the app to take it now!',
        scheduledDate: tz.TZDateTime.from(startDate, tz.local),
      );
    }
  }

  // ─── Cancel Scheduled Reminders ──────────────────────────────────────────

  static Future<void> cancelExamReminders(String examId) async {
    await _localNotifications.cancel((examId.hashCode & 0x7FFFFFFF) + 0);
    await _localNotifications.cancel((examId.hashCode & 0x7FFFFFFF) + 1);
    await _localNotifications.cancel((examId.hashCode & 0x7FFFFFFF) + 2);
    await _localNotifications.cancel((examId.hashCode & 0x7FFFFFFF) + 3);
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
      'klasivo_scheduled',
      'Exam Reminders',
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
