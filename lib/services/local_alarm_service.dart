// lib/services/local_alarm_service.dart
import 'dart:typed_data'; // For Int64List
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import '../models/calendar_reminder.dart';

class LocalAlarmService {
  static final LocalAlarmService _instance = LocalAlarmService._internal();
  factory LocalAlarmService() => _instance;
  LocalAlarmService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the alarm service
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('🔔 Initializing Local Alarm Service...');

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Manila')); // PH timezone

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();

    _initialized = true;
    debugPrint('✅ Local Alarm Service initialized');
  }

  /// Request notification permissions (especially for iOS)
  Future<void> _requestPermissions() async {
    // Android 13+ requires runtime permission
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    // iOS permissions
    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // You can navigate to specific screen here based on payload
  }

  /// Schedule an alarm for a reminder
  Future<void> scheduleAlarm(CalendarReminder reminder) async {
    if (!_initialized) await initialize();

    try {
      // Convert DateTime to TZDateTime
      final scheduledDate = tz.TZDateTime.from(
        reminder.notificationDateTime,
        tz.local,
      );

      // Skip if the time has already passed
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        debugPrint('⏰ Skipping past reminder: ${reminder.title}');
        return;
      }

      // Notification details
      final androidDetails = AndroidNotificationDetails(
        'calendar_reminders',
        'Calendar Reminders',
        channelDescription:
            'Reminders for watering, fertilizing, and other tasks',
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound(
          'alarm',
        ), // Custom sound
        enableVibration: true,
        playSound: true,
        vibrationPattern: Int64List.fromList([
          0,
          1000,
          500,
          1000,
        ]), // Vibration pattern
        styleInformation: BigTextStyleInformation(
          reminder.description,
          contentTitle: '📅 ${reminder.type.displayName} Reminder',
          summaryText: 'AgriLeafy',
        ),
        color: reminder.color,
        category: AndroidNotificationCategory.reminder,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alarm.aiff', // Custom sound
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule the notification
      await _notifications.zonedSchedule(
        reminder.id.hashCode, // Unique ID from reminder ID
        '📅 ${reminder.type.displayName} Reminder',
        '${reminder.title}\n${reminder.description}',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.id, // Pass reminder ID for navigation
      );

      debugPrint(
        '✅ Alarm scheduled for: ${reminder.title} at ${scheduledDate}',
      );
    } catch (e) {
      debugPrint('❌ Failed to schedule alarm: $e');
    }
  }

  /// Cancel a scheduled alarm
  Future<void> cancelAlarm(String reminderId) async {
    if (!_initialized) await initialize();

    try {
      await _notifications.cancel(reminderId.hashCode);
      debugPrint('✅ Alarm cancelled for reminder: $reminderId');
    } catch (e) {
      debugPrint('❌ Failed to cancel alarm: $e');
    }
  }

  /// Cancel all scheduled alarms
  Future<void> cancelAllAlarms() async {
    if (!_initialized) await initialize();

    try {
      await _notifications.cancelAll();
      debugPrint('✅ All alarms cancelled');
    } catch (e) {
      debugPrint('❌ Failed to cancel all alarms: $e');
    }
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingAlarms() async {
    if (!_initialized) await initialize();
    return await _notifications.pendingNotificationRequests();
  }

  /// Show immediate notification (for testing)
  Future<void> showImmediateNotification(
    String title,
    String body, {
    Color? color,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'calendar_reminders',
      'Calendar Reminders',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('alarm'),
      enableVibration: true,
      playSound: true,
      color: color,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }
}
