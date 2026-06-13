import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../config/app_constants.dart';

// ─── Background message handler (must be top-level function) ────────────────

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseMessaging.instance.getInitialMessage();
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _initialized = false;
  static String? _fcmToken;

  // ─── Get FCM Token ──────────────────────────────────────────────────────

  static String? get fcmToken => _fcmToken;

  // ─── Initialize Timezone, Local Notifications & FCM ─────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

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
        // Will be connected to GoRouter for deep linking
      },
    );

    await _createNotificationChannels();
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
        description: 'General notifications',
        importance: Importance.high,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'klasivo_scheduled',
        'Exam Reminders',
        description: 'Scheduled notifications for exam reminders',
        importance: Importance.high,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'klasivo_messages',
        'Messages',
        description: 'New message notifications',
        importance: Importance.high,
      ));

      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'klasivo_attendance',
        'Attendance',
        description: 'Attendance notifications',
        importance: Importance.defaultImportance,
      ));
    }
  }

  // ─── Initialize Firebase Cloud Messaging ─────────────────────────────────

  static Future<void> _initializeFCM() async {
    await requestPermissions();

    _fcmToken = await _fcm.getToken();

    // Persist FCM token to Firestore for server-side push
    await _persistTokenToFirestore(_fcmToken);

    _fcm.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _persistTokenToFirestore(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageOpenedApp(message);
    });

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

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

  /// Callback type for notification deep-link navigation.
  /// Set from main.dart or the router provider after GoRouter is ready.
  static void Function(Map<String, dynamic> data)? onNotificationTap;

  static void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    _navigateFromPayload(data);
  }

  /// Navigate based on notification payload data.
  static void _navigateFromPayload(Map<String, dynamic> data) {
    if (onNotificationTap != null) {
      onNotificationTap!(data);
      return;
    }
    // Fallback: log for debugging if no navigator is registered
    debugPrint('[NotificationService] No navigation handler registered. Payload: $data');
  }

  // ─── Persist FCM Token to Firestore ──────────────────────────────────────

  static Future<void> _persistTokenToFirestore(String? token) async {
    if (token == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical: token persistence failure shouldn't block the app
      debugPrint('[NotificationService] Failed to persist FCM token: $e');
    }
  }

  // ─── Request Notification Permissions ────────────────────────────────────

  static Future<bool> requestPermissions() async {
    final fcmSettings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

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

  static Future<void> subscribeToOrganization(String orgId) async {
    await _fcm.subscribeToTopic('org_$orgId');
  }

  // ─── Show Local Notification ─────────────────────────────────────────────

  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'klasivo_channel',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'klasivo_messages'
          ? 'Messages'
          : channelId == 'klasivo_attendance'
              ? 'Attendance'
              : 'Klasivo',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE NOTIFICATION RECORDS (In-App Notification Center)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a notification record in Firestore and show a local notification.
  /// This is the central method for all in-app notifications.
  static Future<String> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? organizationId,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? data,
    String localChannelId = 'klasivo_channel',
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.notificationsCollection)
          .add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'organizationId': organizationId,
        'relatedId': relatedId,
        'relatedType': relatedType,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also show a local notification
      await showNotification(
        title: title,
        body: body,
        channelId: localChannelId,
      );

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  /// Create notifications for multiple users (e.g., entire class).
  static Future<void> createBulkNotifications({
    required List<String> userIds,
    required String type,
    required String title,
    required String body,
    String? organizationId,
    String? relatedId,
    String? relatedType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final userId in userIds) {
        final docRef =
            _firestore.collection(AppConstants.notificationsCollection).doc();
        batch.set(docRef, {
          'userId': userId,
          'type': type,
          'title': title,
          'body': body,
          'organizationId': organizationId,
          'relatedId': relatedId,
          'relatedType': relatedType,
          'data': data ?? {},
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Mark a notification as read.
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      rethrow;
    }
  }

  /// Mark all notifications as read for a user.
  static Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Get unread notification count for a user.
  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Stream notifications for a user (for notification center UI).
  static Stream<QuerySnapshot> getUserNotificationsStream(String userId) {
    return _firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(AppConstants.notificationsPageSize)
        .snapshots();
  }

  /// Get a single notification by ID.
  static Future<Map<String, dynamic>?> getNotification(String notificationId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .get();

      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a notification.
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete all notifications for a user.
  static Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-GENERATED NOTIFICATIONS (Triggered by app events)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Called when an exam is created/published.
  /// Notifies all students in the class.
  static Future<void> notifyExamCreated({
    required String organizationId,
    required String classId,
    required String examId,
    required String examTitle,
    required List<String> studentIds,
  }) async {
    await createBulkNotifications(
      userIds: studentIds,
      type: AppConstants.notificationExamPublished,
      title: 'New Exam',
      body: '"$examTitle" has been published',
      organizationId: organizationId,
      relatedId: examId,
      relatedType: 'exam',
      data: {'classId': classId},
    );
  }

  /// Called when an assignment is published.
  /// Notifies all students in the class/group.
  static Future<void> notifyAssignmentPublished({
    required String organizationId,
    required String assignmentId,
    required String assignmentTitle,
    required List<String> studentIds,
  }) async {
    await createBulkNotifications(
      userIds: studentIds,
      type: AppConstants.notificationAssignmentPublished,
      title: 'New Assignment',
      body: '"$assignmentTitle" has been assigned',
      organizationId: organizationId,
      relatedId: assignmentId,
      relatedType: 'assignment',
    );
  }

  /// Called when an assignment is graded.
  /// Notifies the student whose assignment was graded.
  static Future<void> notifyAssignmentGraded({
    required String studentId,
    required String assignmentTitle,
    required double score,
    String? organizationId,
    String? assignmentId,
  }) async {
    await createNotification(
      userId: studentId,
      type: AppConstants.notificationAssignmentGraded,
      title: 'Assignment Graded',
      body: 'Your score for "$assignmentTitle": ${score.toStringAsFixed(1)}%',
      organizationId: organizationId,
      relatedId: assignmentId,
      relatedType: 'assignment',
    );
  }

  /// Called when a message is received.
  static Future<void> notifyNewMessage({
    required String recipientId,
    required String senderName,
    required String messagePreview,
    required String conversationId,
    String? organizationId,
  }) async {
    await createNotification(
      userId: recipientId,
      type: AppConstants.notificationNewMessage,
      title: senderName,
      body: messagePreview.length > 100
          ? '${messagePreview.substring(0, 100)}...'
          : messagePreview,
      organizationId: organizationId,
      relatedId: conversationId,
      relatedType: 'conversation',
      localChannelId: 'klasivo_messages',
    );
  }

  /// Called when attendance is marked (for students).
  static Future<void> notifyAttendanceMarked({
    required String studentId,
    required String date,
    required String status,
    String? organizationId,
  }) async {
    // Only notify if absent or late (not for present/excused)
    if (status == AppConstants.attendanceStatusAbsent ||
        status == AppConstants.attendanceStatusLate) {
      await createNotification(
        userId: studentId,
        type: AppConstants.notificationAttendance,
        title: 'Attendance Marked',
        body: 'You were marked as $status on $date',
        organizationId: organizationId,
        relatedType: 'attendance',
        localChannelId: 'klasivo_attendance',
      );
    }
  }

  /// Called when a teacher is invited to join an organization.
  static Future<void> notifyTeacherInvited({
    required String ownerId,
    required String ownerName,
    required String organizationName,
    String? organizationId,
  }) async {
    await createNotification(
      userId: ownerId,
      type: AppConstants.notificationTeacherInvited,
      title: 'Invite Created',
      body: 'Invite code created for $organizationName',
      organizationId: organizationId,
    );
  }

  /// Called when a student joins via invite code.
  static Future<void> notifyStudentJoined({
    required String teacherId,
    required String studentName,
    required String className,
    String? organizationId,
  }) async {
    await createNotification(
      userId: teacherId,
      type: AppConstants.notificationStudentJoined,
      title: 'New Student',
      body: '$studentName joined $className',
      organizationId: organizationId,
      relatedType: 'student',
    );
  }

  /// Called when exam results are published.
  static Future<void> notifyResultPublished({
    required String studentId,
    required String examTitle,
    required double score,
    String? organizationId,
    String? examId,
  }) async {
    await createNotification(
      userId: studentId,
      type: AppConstants.notificationResultPublished,
      title: 'Result Published',
      body: 'Your result for "$examTitle": ${score.toStringAsFixed(1)}%',
      organizationId: organizationId,
      relatedId: examId,
      relatedType: 'exam',
    );
  }

  /// Called when an exam reminder is due.
  static Future<void> notifyExamReminder({
    required String userId,
    required String examTitle,
    required int minutesLeft,
    String? organizationId,
    String? examId,
  }) async {
    final timeText = minutesLeft >= 60
        ? '${minutesLeft ~/ 60} hour(s)'
        : '$minutesLeft minutes';

    await createNotification(
      userId: userId,
      type: AppConstants.notificationExamReminder,
      title: 'Exam Reminder',
      body: '"$examTitle" starts in $timeText',
      organizationId: organizationId,
      relatedId: examId,
      relatedType: 'exam',
      localChannelId: 'klasivo_scheduled',
    );
  }

  /// Called when an organization update is sent.
  static Future<void> notifyOrgUpdate({
    required List<String> userIds,
    required String title,
    required String body,
    String? organizationId,
  }) async {
    await createBulkNotifications(
      userIds: userIds,
      type: AppConstants.notificationOrgUpdate,
      title: title,
      body: body,
      organizationId: organizationId,
      relatedType: 'organization',
    );
  }

  // ─── Schedule Exam Reminders ─────────────────────────────────────────────

  static Future<void> scheduleExamReminders({
    required String examId,
    required String examTitle,
    required DateTime startDate,
  }) async {
    final now = DateTime.now();

    final twentyFourHoursBefore = startDate.subtract(const Duration(hours: 24));
    if (twentyFourHoursBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 0,
        title: 'Exam Reminder',
        body: '"$examTitle" starts tomorrow',
        scheduledDate: tz.TZDateTime.from(twentyFourHoursBefore, tz.local),
      );
    }

    final oneHourBefore = startDate.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 1,
        title: 'Exam Starting Soon',
        body: '"$examTitle" starts in 1 hour',
        scheduledDate: tz.TZDateTime.from(oneHourBefore, tz.local),
      );
    }

    final fifteenMinBefore = startDate.subtract(const Duration(minutes: 15));
    if (fifteenMinBefore.isAfter(now)) {
      await _scheduleNotification(
        id: (examId.hashCode & 0x7FFFFFFF) + 2,
        title: 'Exam Starting Soon!',
        body: '"$examTitle" starts in 15 minutes',
        scheduledDate: tz.TZDateTime.from(fifteenMinBefore, tz.local),
      );
    }

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
