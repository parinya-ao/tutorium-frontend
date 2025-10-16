import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  factory LocalNotificationService() => _instance;

  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions for iOS
    await _requestPermissions();

    _initialized = true;
  }

  // Request notification permissions (mainly for iOS)
  Future<void> _requestPermissions() async {
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap here
    // You can navigate to specific page based on payload
    print('Notification tapped: ${response.payload}');
  }

  // Schedule class reminder notifications
  // classStartTime: DateTime when the class starts
  // className: Name of the class
  // classSessionId: ID to make notification unique
  Future<void> scheduleClassReminders({
    required DateTime classStartTime,
    required String className,
    required int classSessionId,
  }) async {
    await initialize();

    final now = DateTime.now();

    // Define reminder times before class starts
    final reminderTimes = [
      Duration(hours: 1, minutes: 30), // 1hr 30min
      Duration(hours: 1), // 1hr
      Duration(minutes: 30), // 30min
      Duration(minutes: 10), // 10min
      Duration(minutes: 5), // 5min
      Duration(minutes: 1), // 1min
    ];

    for (int i = 0; i < reminderTimes.length; i++) {
      final reminderTime = classStartTime.subtract(reminderTimes[i]);

      // Only schedule if reminder time is in the future
      if (reminderTime.isAfter(now)) {
        final notificationId = _generateNotificationId(classSessionId, i);

        await _scheduleNotification(
          id: notificationId,
          title: 'Class Reminder: $className',
          body: _getReminderMessage(reminderTimes[i]),
          scheduledTime: reminderTime,
          payload: 'class_session_$classSessionId',
        );
      }
    }
  }

  // Generate unique notification ID
  int _generateNotificationId(int classSessionId, int reminderIndex) {
    // Combine class session ID with reminder index
    // This ensures unique IDs for each reminder
    return classSessionId * 100 + reminderIndex;
  }

  // Get reminder message based on duration
  String _getReminderMessage(Duration duration) {
    if (duration.inHours > 0) {
      if (duration.inMinutes % 60 == 0) {
        return 'Your class starts in ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
      } else {
        return 'Your class starts in ${duration.inHours} hr ${duration.inMinutes % 60} min';
      }
    } else {
      return 'Your class starts in ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  // Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // Show immediate notification (for testing)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails,
        payload: payload);
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all reminders for a class session
  Future<void> cancelClassReminders(int classSessionId) async {
    // Cancel all 6 reminder notifications for this class
    for (int i = 0; i < 6; i++) {
      final notificationId = _generateNotificationId(classSessionId, i);
      await cancelNotification(notificationId);
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
