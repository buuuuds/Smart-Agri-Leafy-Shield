// lib/services/esp32_connection_monitor.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'notification_service.dart';

class ESP32ConnectionMonitor {
  static final ESP32ConnectionMonitor _instance =
      ESP32ConnectionMonitor._internal();
  factory ESP32ConnectionMonitor() => _instance;
  ESP32ConnectionMonitor._internal();

  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://agri-leafy-default-rtdb.firebaseio.com',
  );

  static const String _deviceId = 'ESP32_ALS_001';
  static const int _heartbeatTimeoutSeconds =
      45; // Mark offline after 45 seconds (balanced detection)

  Timer? _monitorTimer;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final NotificationService _notificationService = NotificationService();

  bool _isOnline = false;
  bool _hasNotifiedOffline =
      false; // Track if we already sent offline notification
  DateTime? _lastHeartbeat;

  bool get isOnline => _isOnline;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Start monitoring ESP32 connection status
  void start() async {
    debugPrint('🔍 Starting ESP32 connection monitor...');

    // ✅ IMMEDIATE CHECK on startup - check existing timestamp
    await _performInitialCheck();

    // Monitor heartbeat timestamp for real-time updates
    _database.ref('devices/$_deviceId/status/timestamp').onValue.listen((
      event,
    ) {
      if (event.snapshot.exists) {
        final timestamp = event.snapshot.value?.toString();
        if (timestamp != null) {
          try {
            _lastHeartbeat = DateTime.parse(timestamp);
            _checkConnection();
          } catch (e) {
            debugPrint('❌ Error parsing timestamp: $e');
          }
        }
      }
    });

    // Check connection status every 10 seconds for stable detection
    _monitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnection();
    });

    debugPrint('✅ ESP32 connection monitor started');
  }

  /// ✅ NEW: Perform initial connection check on startup
  Future<void> _performInitialCheck() async {
    try {
      debugPrint('🔍 Performing initial connection check...');

      final snapshot = await _database
          .ref('devices/$_deviceId/status/timestamp')
          .once();

      if (snapshot.snapshot.exists) {
        final timestamp = snapshot.snapshot.value?.toString();
        if (timestamp != null) {
          try {
            _lastHeartbeat = DateTime.parse(timestamp);

            final now = DateTime.now();
            final difference = now.difference(_lastHeartbeat!).inSeconds;

            if (difference < _heartbeatTimeoutSeconds) {
              // Recent heartbeat - ESP32 is online
              _updateConnectionStatus(true);
              debugPrint('✅ Initial check: ESP32 ONLINE (${difference}s ago)');
            } else {
              // Old heartbeat - ESP32 is offline
              _updateConnectionStatus(false);
              _sendDisconnectedNotification();
              debugPrint('❌ Initial check: ESP32 OFFLINE (${difference}s ago)');
            }
          } catch (e) {
            debugPrint('❌ Error parsing timestamp: $e');
            _updateConnectionStatus(false);
            _sendDisconnectedNotification();
          }
        } else {
          // No timestamp
          _updateConnectionStatus(false);
          _sendDisconnectedNotification();
          debugPrint('⚠️ Initial check: No timestamp found - marking OFFLINE');
        }
      } else {
        // No status data at all
        _updateConnectionStatus(false);
        _sendDisconnectedNotification();
        debugPrint('⚠️ Initial check: No status data - marking OFFLINE');
      }
    } catch (e) {
      debugPrint('❌ Initial check failed: $e');
      _updateConnectionStatus(false);
      _sendDisconnectedNotification();
    }
  }

  void _checkConnection() {
    if (_lastHeartbeat == null) {
      if (_isOnline) {
        // Only update if currently showing as online
        _updateConnectionStatus(false);
        _sendDisconnectedNotification();
        debugPrint('❌ ESP32 DISCONNECTED (no heartbeat data)');
      }
      return;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastHeartbeat!).inSeconds;

    final wasOnline = _isOnline;
    final isNowOnline = difference < _heartbeatTimeoutSeconds;

    if (wasOnline != isNowOnline) {
      _updateConnectionStatus(isNowOnline);

      if (isNowOnline) {
        _sendConnectedNotification();
        debugPrint('✅ ESP32 CONNECTED (last heartbeat: ${difference}s ago)');
      } else {
        _sendDisconnectedNotification();
        debugPrint('❌ ESP32 DISCONNECTED (last heartbeat: ${difference}s ago)');
      }
    }
  }

  void _updateConnectionStatus(bool online) {
    _isOnline = online;
    _connectionController.add(online);

    // Update Firebase status/online field
    _database
        .ref('devices/$_deviceId/status/online')
        .set(online)
        .then((_) {
          if (!online) {
            debugPrint('📝 Updated ESP32 status to OFFLINE in Firebase');
          }
        })
        .catchError((error) {
          debugPrint('❌ Failed to update ESP32 status: $error');
        });
  }

  Future<void> _sendConnectedNotification() async {
    if (_hasNotifiedOffline) {
      // Only send "connected" notification if we previously sent "disconnected"
      final notification = NotificationItem(
        id: 'esp32_connected_${DateTime.now().millisecondsSinceEpoch}',
        title: '✅ ESP32 Connected',
        message: 'Your ESP32 device is now online and sending sensor data.',
        timestamp: DateTime.now(),
        priority: NotificationPriority.high,
        isRead: false,
        icon: Icons.wifi,
        color: Colors.green,
      );
      await _notificationService.addNotification(notification);
      _hasNotifiedOffline = false;
      debugPrint('📲 Sent ESP32 connected notification');
    }
  }

  Future<void> _sendDisconnectedNotification() async {
    if (!_hasNotifiedOffline) {
      // Only send once until it reconnects
      final notification = NotificationItem(
        id: 'esp32_disconnected_${DateTime.now().millisecondsSinceEpoch}',
        title: '⚠️ ESP32 Disconnected',
        message:
            'Your ESP32 device has gone offline. Sensor data is not being received.',
        timestamp: DateTime.now(),
        priority: NotificationPriority.high,
        isRead: false,
        icon: Icons.wifi_off,
        color: Colors.red,
      );
      await _notificationService.addNotification(notification);
      _hasNotifiedOffline = true;
      debugPrint('📲 Sent ESP32 disconnected notification');
    }
  }

  /// Manually trigger connection check
  void checkNow() {
    _checkConnection();
  }

  /// Stop monitoring
  void stop() {
    debugPrint('🛑 Stopping ESP32 connection monitor...');
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('✅ ESP32 connection monitor stopped');
  }

  void dispose() {
    stop();
    _connectionController.close();
  }
}
