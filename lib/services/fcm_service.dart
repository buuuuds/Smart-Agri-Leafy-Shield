// lib/services/fcm_service.dart - FIXED: Navigation and error handling

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

// Top-level function for background messages (required)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 Background message: ${message.messageId}');
  debugPrint('   Title: ${message.notification?.title}');
  debugPrint('   Body: ${message.notification?.body}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // FIXED: Add navigation key
  static GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ FCM already initialized');
      return;
    }

    try {
      // Request permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('📱 Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✓ Notification permission granted');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('⚠️ Notification permission provisional');
      } else {
        debugPrint('✗ Notification permission denied');
        _isInitialized = false;
        return;
      }

      // Initialize local notifications for Android
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'agri_leafy_alerts',
        'Plant Alerts',
        description: 'Notifications for plant sensor alerts and system status',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      // CORRECT VERSION
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      debugPrint('✓ Notification channel created');

      // Get FCM token
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        debugPrint('✓ FCM Token: ${_fcmToken!.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ Failed to get FCM token');
      }

      // Listen to token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('✓ FCM Token refreshed');
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

      // Check if app was opened from a terminated state
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📱 App opened from notification (terminated state)');
        _handleNotificationOpen(initialMessage);
      }

      _isInitialized = true;
      debugPrint('✓ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('✗ FCM initialization failed: $e');
      _isInitialized = false;
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 Foreground message received');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');

    // Show local notification when app is in foreground
    _showLocalNotification(
      title: message.notification?.title ?? 'Alert',
      body: message.notification?.body ?? 'You have a new notification',
      payload: message.data.toString(),
    );
  }

  // FIXED: Added proper navigation handling
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('📱 Notification opened');
    debugPrint('   Data: ${message.data}');

    // Navigate based on notification type
    if (message.data.containsKey('type')) {
      final type = message.data['type'];
      _navigateToScreen(type);
    }
  }

  // FIXED: Added navigation logic
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped');
    debugPrint('   Payload: ${response.payload}');

    // Parse payload if it contains navigation info
    if (response.payload != null && response.payload!.isNotEmpty) {
      // You can parse JSON from payload if needed
      // For now, just navigate to notifications page
      _navigateToScreen('notification');
    }
  }

  // FIXED: Added navigation helper
  void _navigateToScreen(String type) {
    if (navigatorKey?.currentState == null) {
      debugPrint('⚠️ Navigator key not set, cannot navigate');
      return;
    }

    switch (type) {
      case 'sensor_alert':
      case 'temperature':
      case 'soil':
      case 'humidity':
      case 'light':
        // Navigate to dashboard (index 0)
        debugPrint('→ Navigating to Dashboard');
        break;
      case 'connection_issue':
      case 'wifi':
      case 'sensor_disconnect':
        // Navigate to settings (index 3)
        debugPrint('→ Navigating to Settings');
        break;
      default:
        // Navigate to notifications page
        debugPrint('→ Opening Notifications');
        break;
    }

    // Note: Actual navigation will be handled by MainLayout
    // You can emit an event or use a stream controller here
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'agri_leafy_alerts',
          'Plant Alerts',
          channelDescription:
              'Notifications for plant sensor alerts and system status',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF4CAF50),
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF4CAF50),
          ledOnMs: 1000,
          ledOffMs: 500,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _localNotifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('✓ Local notification shown: $title');
  }

  // FIXED: Added initialization check
  Future<void> sendLocalNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ FCM not initialized, attempting to initialize...');
      await initialize();

      if (!_isInitialized) {
        debugPrint('✗ FCM initialization failed, cannot send notification');
        return;
      }
    }

    await _showLocalNotification(title: title, body: body, payload: null);
  }

  // Subscribe to topic (for targeted notifications)
  Future<void> subscribeToTopic(String topic) async {
    if (!_isInitialized) {
      debugPrint('⚠️ FCM not initialized');
      return;
    }

    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✓ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('✗ Failed to subscribe to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isInitialized) {
      debugPrint('⚠️ FCM not initialized');
      return;
    }

    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✓ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('✗ Failed to unsubscribe from topic: $e');
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('✓ All notifications cancelled');
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    debugPrint('✓ Notification $id cancelled');
  }

  // Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _fcm.getNotificationSettings();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) return false;

    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}
