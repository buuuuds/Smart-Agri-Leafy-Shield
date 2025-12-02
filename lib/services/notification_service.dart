// lib/services/notification_service.dart - WITH 2K LIMIT ENFORCEMENT

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/plant_model.dart';
import 'firebase_service.dart';
import 'dart:async';
import '../services/fcm_service.dart';
import 'firestore_service.dart';
import 'esp32_connection_monitor.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _notificationsKey = 'notifications_list';
  static const String _alertStatesKey = 'alert_states';
  static const int _maxNotifications = 2000; // ✅ MAX 2000
  static const String DEVICE_ID = 'ESP32_ALS_001';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Timer? _autoCleanupTimer;

  final List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _notificationController =
      StreamController<List<NotificationItem>>.broadcast();

  bool _lastConnectionState = true;
  DateTime? _lastConnectionLostTime;
  bool _lastXYMD02State = true;
  bool _lastSoilState = true;
  bool _lastLightState = true;
  bool _lastNPKState = true;
  int? _lastWaterPercent;
  DateTime? _lastWaterCheckTime;
  bool _lastWaterLevelState = true;

  final Map<String, AlertState> _alertStates = {};

  int _lastWaterCycleCount = 0;
  int _lastMistCycleCount = 0;
  DateTime _lastCycleCheck = DateTime.now();

  int? _lastSoilReading;
  DateTime? _lastSoilReadingTime;
  DateTime? _shadeDeployedSince;

  Stream<List<NotificationItem>> get notificationStream =>
      _notificationController.stream;
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  Future<void> initialize() async {
    await _loadNotifications();
    await _loadAlertStates();
    _startAutoCleanup();
  }

  void _startAutoCleanup() {
    _runCleanup();
    _autoCleanupTimer = Timer.periodic(const Duration(hours: 24), (_) {
      _runCleanup();
    });
    debugPrint('✅ Auto-cleanup scheduled: runs every 24 hours');
  }

  Future<void> _runCleanup() async {
    try {
      debugPrint('🧹 Running automatic archive cleanup...');
      final deletedCount = await _firestoreService.cleanupExpiredArchive();
      final archivedCount = await _firestoreService.getArchivedCount();

      debugPrint(
        '✅ Cleanup complete: $deletedCount expired deleted, '
        '$archivedCount remaining in archive',
      );
    } catch (e) {
      debugPrint('❌ Auto-cleanup failed: $e');
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString(_notificationsKey);

      if (notificationsJson != null) {
        final List<dynamic> notificationsList = json.decode(notificationsJson);
        _notifications.clear();
        _notifications.addAll(
          notificationsList
              .map((item) => NotificationItem.fromJson(item))
              .toList(),
        );
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // ✅ Enforce 2K limit on load
        if (_notifications.length > _maxNotifications) {
          debugPrint(
            '⚠️ Trimming notifications: ${_notifications.length} → $_maxNotifications',
          );
          _notifications.removeRange(_maxNotifications, _notifications.length);
          await _saveNotifications();
        }
      }
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    }
    _notificationController.add(_notifications);
  }

  Future<void> _loadAlertStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? statesJson = prefs.getString(_alertStatesKey);

      if (statesJson != null) {
        final Map<String, dynamic> statesMap = json.decode(statesJson);
        _alertStates.clear();
        statesMap.forEach((key, value) {
          _alertStates[key] = AlertState.fromJson(value);
        });
      }
    } catch (e) {
      debugPrint('Failed to load alert states: $e');
    }
  }

  Future<void> _saveAlertStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> statesMap = {};
      _alertStates.forEach((key, value) {
        statesMap[key] = value.toJson();
      });
      await prefs.setString(_alertStatesKey, json.encode(statesMap));
    } catch (e) {
      debugPrint('Failed to save alert states: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String notificationsJson = json.encode(
        _notifications.map((item) => item.toJson()).toList(),
      );
      await prefs.setString(_notificationsKey, notificationsJson);
    } catch (e) {
      debugPrint('Failed to save notifications: $e');
    }
  }

  Future<void> _saveToFirestore(NotificationItem notification) async {
    try {
      final notificationData = {
        'deviceId': DEVICE_ID,
        'title': notification.title,
        'message': notification.message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': _getNotificationType(notification.title),
        'priority': notification.priority.toString().split('.').last,
        'isRead': false,
        'iconCodePoint': notification.icon.codePoint,
        'colorValue': notification.color.value,
      };

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notificationData);

      debugPrint('✅ Notification saved to Firestore: ${notification.title}');
    } catch (e) {
      debugPrint('❌ Failed to save to Firestore: $e');
    }
  }

  String _getNotificationType(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('temperature') || lowerTitle.contains('temp')) {
      return 'temperature';
    }
    if (lowerTitle.contains('soil')) return 'soil';
    if (lowerTitle.contains('water') || lowerTitle.contains('tank')) {
      return 'water';
    }
    if (lowerTitle.contains('light')) return 'light';
    if (lowerTitle.contains('humidity')) return 'humidity';
    if (lowerTitle.contains('nitrogen') || lowerTitle.contains('npk')) {
      return 'nitrogen';
    }
    if (lowerTitle.contains('phosphorus')) return 'phosphorus';
    if (lowerTitle.contains('potassium')) return 'potassium';
    if (lowerTitle.contains('connection') ||
        lowerTitle.contains('wifi') ||
        lowerTitle.contains('esp32') ||
        lowerTitle.contains('offline')) {
      return 'connection';
    }
    if (lowerTitle.contains('sensor')) return 'sensor';
    if (lowerTitle.contains('pump')) return 'pump';
    if (lowerTitle.contains('shade')) return 'shade';
    if (lowerTitle.contains('fertilizer')) return 'fertilizer';
    return 'alert';
  }

  // 🆕 AUTO-ARCHIVE when approaching 2K limit
  Future<void> _enforceMaxLimit() async {
    final threshold = (_maxNotifications * 0.9).toInt(); // 90% of 2000 = 1800

    if (_notifications.length >= threshold) {
      debugPrint(
        '⚠️ Approaching notification limit: ${_notifications.length}/$_maxNotifications',
      );

      const keepCount = 1500; // Keep most recent 1500

      if (_notifications.length > keepCount) {
        final toArchive = _notifications
            .skip(keepCount)
            .map((n) => n.id)
            .toList();

        debugPrint(
          '📦 Auto-archiving ${toArchive.length} old notifications...',
        );

        int archivedCount = 0;
        for (var id in toArchive) {
          try {
            await _firestoreService.archiveNotification(id);
            archivedCount++;
          } catch (e) {
            debugPrint('⚠️ Failed to archive $id: $e');
          }
        }

        _notifications.removeRange(keepCount, _notifications.length);
        await _saveNotifications();
        _notificationController.add(_notifications);

        debugPrint(
          '✅ Auto-archived $archivedCount notifications. Now: ${_notifications.length}',
        );
      }
    }
  }

  Future<void> addNotification(NotificationItem notification) async {
    final now = DateTime.now();

    final connectionMonitor = ESP32ConnectionMonitor();
    final isESP32Connected = connectionMonitor.isOnline;

    final isConnectionNotification =
        notification.title.toLowerCase().contains('connection') ||
        notification.title.toLowerCase().contains('offline') ||
        notification.title.toLowerCase().contains('disconnected') ||
        notification.title.toLowerCase().contains('online') ||
        notification.title.toLowerCase().contains('connected') ||
        notification.title.toLowerCase().contains('restored');

    if (!isESP32Connected && !isConnectionNotification) {
      debugPrint(
        '⚠️ Notification blocked - ESP32 disconnected: ${notification.title}',
      );
      return;
    }

    int cooldownMinutes;
    if (notification.priority == NotificationPriority.critical) {
      cooldownMinutes = 5;
    } else if (notification.priority == NotificationPriority.high) {
      cooldownMinutes = 5;
    } else if (notification.priority == NotificationPriority.medium) {
      cooldownMinutes = 10;
    } else {
      cooldownMinutes = 30;
    }

    final recentDuplicate = _notifications.any((existing) {
      final isSameType = existing.title == notification.title;
      final isRecent =
          now.difference(existing.timestamp).inMinutes < cooldownMinutes;
      return isSameType && isRecent && !existing.isRead;
    });

    if (recentDuplicate) {
      debugPrint(
        '⏱️ Cooldown active: ${notification.title} (${cooldownMinutes}min)',
      );
      return;
    }

    _notifications.insert(0, notification);

    // 🆕 Enforce max limit (auto-archive if needed)
    await _enforceMaxLimit();

    // ✅ Safety net: Hard trim if still over limit
    if (_notifications.length > _maxNotifications) {
      _notifications.removeRange(_maxNotifications, _notifications.length);
    }

    await _saveNotifications();
    await _saveToFirestore(notification);

    _notificationController.add(_notifications);

    if (notification.priority == NotificationPriority.high ||
        notification.priority == NotificationPriority.critical) {
      try {
        final fcmService = FCMService();
        if (fcmService.isInitialized) {
          final isEnabled = await fcmService.areNotificationsEnabled();
          if (isEnabled) {
            await fcmService.sendLocalNotification(
              title: notification.title,
              body: notification.message,
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Push failed: $e');
      }
    }

    debugPrint('✅ Notification: ${notification.title}');
  }

  bool _shouldSendAlert(String alertKey, dynamic currentValue) {
    final now = DateTime.now();
    final state = _alertStates[alertKey];

    if (state == null) {
      _alertStates[alertKey] = AlertState(
        isActive: true,
        lastValue: currentValue,
        lastAlertTime: now,
      );
      _saveAlertStates();
      return true;
    }

    if (state.isActive) {
      final minutesSinceLastAlert = now
          .difference(state.lastAlertTime)
          .inMinutes;
      if (minutesSinceLastAlert >= 5) {
        _alertStates[alertKey] = AlertState(
          isActive: true,
          lastValue: currentValue,
          lastAlertTime: now,
        );
        _saveAlertStates();
        return true;
      }
      return false;
    }

    if (_hasValueChanged(alertKey, state.lastValue, currentValue)) {
      _alertStates[alertKey] = AlertState(
        isActive: true,
        lastValue: currentValue,
        lastAlertTime: now,
      );
      _saveAlertStates();
      return true;
    }

    return false;
  }

  bool _hasValueChanged(String alertKey, dynamic oldValue, dynamic newValue) {
    if (oldValue == null || newValue == null) return true;

    if (oldValue is bool && newValue is bool) {
      return oldValue != newValue;
    }

    if (oldValue is num && newValue is num) {
      if (alertKey.contains('temp')) {
        return (oldValue - newValue).abs() > 2.0;
      } else if (alertKey.contains('soil') || alertKey.contains('humidity')) {
        return (oldValue - newValue).abs() > 10;
      } else if (alertKey.contains('light')) {
        return (oldValue - newValue).abs() > 500;
      } else if (alertKey.contains('npk') ||
          alertKey.contains('nitrogen') ||
          alertKey.contains('phosphorus') ||
          alertKey.contains('potassium')) {
        return (oldValue - newValue).abs() > 20;
      }
    }

    return oldValue != newValue;
  }

  void _markAlertResolved(String alertKey) {
    if (_alertStates.containsKey(alertKey)) {
      _alertStates[alertKey] = _alertStates[alertKey]!.copyWith(
        isActive: false,
      );
      _saveAlertStates();
    }
  }

  Future<void> checkSensorAlerts({
    required double? temperature,
    required int? soilMoisture,
    required int? lightIntensity,
    required int? humidity,
    required int? nitrogen,
    required int? phosphorus,
    required int? potassium,
    int? waterPercent,
    double? waterLevel,
    required Plant? currentPlant,
    required SensorStatus? sensorStatus,
    required bool isConnected,
    required bool wifiConnected,
    required bool espOnline,
    required bool isPumpRunning,
    required String currentPumpMode,
    required int pumpCycleCount,
    required int totalPumpRuntime,
    required int irrigationRuntime,
    required int irrigationCycles,
    required int mistingRuntime,
    required int mistingCycles,
    required bool shadeDeployed,
    int waterLevelLowThreshold = 20,
  }) async {
    final now = DateTime.now();

    final connectionMonitor = ESP32ConnectionMonitor();
    final isESP32ActuallyOnline = connectionMonitor.isOnline;
    final actualEspOnline = espOnline && isESP32ActuallyOnline;

    if (!isConnected || !wifiConnected || !actualEspOnline) {
      if (_lastConnectionState == true) {
        _lastConnectionLostTime = now;
        _lastConnectionState = false;
      }

      if (_lastConnectionLostTime != null) {
        final timeSinceDisconnect = now.difference(_lastConnectionLostTime!);

        if (timeSinceDisconnect.inSeconds >= 30) {
          String alertKey = 'connection_lost';
          String title = 'Connection Issue';
          String message = '';

          if (!actualEspOnline) {
            title = 'ESP32 Offline';
            message = 'Device not responding. Check power supply.';
          } else if (!wifiConnected) {
            title = 'WiFi Disconnected';
            message = 'ESP32 lost WiFi. Check network.';
          } else {
            title = 'Data Connection Lost';
            message = 'No sensor data. Check connections.';
          }

          if (_shouldSendAlert(alertKey, false)) {
            await addNotification(
              NotificationItem(
                id: 'connection_${now.millisecondsSinceEpoch}',
                title: title,
                message: message,
                timestamp: now,
                priority: NotificationPriority.high,
                isRead: false,
                icon: Icons.wifi_off,
                color: Colors.red,
              ),
            );
          }
        }
      }
    } else {
      if (_lastConnectionState == false) {
        _markAlertResolved('connection_lost');
        await addNotification(
          NotificationItem(
            id: 'connection_restored_${now.millisecondsSinceEpoch}',
            title: '✅ Connection Restored',
            message: 'ESP32 back online and sending data.',
            timestamp: now,
            priority: NotificationPriority.low,
            isRead: false,
            icon: Icons.wifi,
            color: Colors.green,
          ),
        );
      }
      _lastConnectionState = true;
      _lastConnectionLostTime = null;
    }

    if (!isConnected || !wifiConnected || !actualEspOnline) {
      debugPrint('⚠️ Skipping sensor alerts - ESP32 offline');
      return;
    }

    if (sensorStatus != null) {
      await _checkIndividualSensors(sensorStatus, now);
    }

    await _checkNPKAndFertilization(
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      timestamp: now,
    );
    await _checkWaterLevelAlerts(
      waterPercent: waterPercent,
      waterLevel: waterLevel,
      lowThreshold: waterLevelLowThreshold,
      timestamp: now,
    );

    if (currentPlant != null) {
      await _checkPlantAlerts(
        temperature: temperature,
        soilMoisture: soilMoisture,
        humidity: humidity,
        lightIntensity: lightIntensity,
        plant: currentPlant,
        timestamp: now,
      );
    }

    await _checkPumpRuntimeAlerts(
      isPumpRunning: isPumpRunning,
      currentPumpMode: currentPumpMode,
      irrigationCycles: irrigationCycles,
      mistingCycles: mistingCycles,
      totalPumpRuntime: totalPumpRuntime,
      timestamp: now,
    );

    await _checkSoilEmergencyAlerts(soilMoisture: soilMoisture, timestamp: now);
    await _checkShadeAlerts(shadeDeployed: shadeDeployed, timestamp: now);
  }

  Future<void> _checkWaterLevelAlerts({
    required int? waterPercent,
    required double? waterLevel,
    required int lowThreshold,
    required DateTime timestamp,
  }) async {
    if (waterPercent == null || waterLevel == null) {
      if (_lastWaterPercent != null) {
        if (_shouldSendAlert('water_sensor_offline', false)) {
          await addNotification(
            NotificationItem(
              id: 'water_sensor_offline_${timestamp.millisecondsSinceEpoch}',
              title: '💧 Water Level Sensor Offline',
              message:
                  'HC-SR04 ultrasonic sensor not responding.\n\n'
                  'Check connections:\n'
                  '• Trigger Pin: GPIO 2\n'
                  '• Echo Pin: GPIO 15\n'
                  '• Power: 5V\n'
                  '• Ground: GND\n\n'
                  'Pumps may not auto-stop without sensor!',
              timestamp: timestamp,
              priority: NotificationPriority.high,
              isRead: false,
              icon: Icons.sensors_off,
              color: Colors.red,
            ),
          );
        }
      }
      _lastWaterPercent = null;
      return;
    }

    _markAlertResolved('water_sensor_offline');

    if (waterPercent < lowThreshold) {
      if (_lastWaterLevelState == true) {
        _lastWaterLevelState = false;

        if (_shouldSendAlert('water_critically_low', waterPercent)) {
          await addNotification(
            NotificationItem(
              id: 'water_critical_${timestamp.millisecondsSinceEpoch}',
              title: '🚨 CRITICAL: Water Tank Almost Empty',
              message:
                  'Water level: $waterPercent% (${waterLevel.toStringAsFixed(1)} cm)\n\n'
                  '⚠️ IMMEDIATE ACTION REQUIRED ⚠️\n\n'
                  'System status:\n'
                  '• Water pump: AUTO-STOPPED\n'
                  '• Mist pump: AUTO-STOPPED\n'
                  '• Plants: NOT RECEIVING WATER\n\n'
                  '🚰 REFILL TANK IMMEDIATELY!\n\n'
                  'Plants may wilt without water!',
              timestamp: timestamp,
              priority: NotificationPriority.critical,
              isRead: false,
              icon: Icons.local_fire_department,
              color: Colors.red,
            ),
          );
        }
      }
    } else {
      if (_lastWaterLevelState == false) {
        _lastWaterLevelState = true;
        _markAlertResolved('water_critically_low');
        _markAlertResolved('water_very_low');

        await addNotification(
          NotificationItem(
            id: 'water_restored_${timestamp.millisecondsSinceEpoch}',
            title: '✅ Water Tank Refilled',
            message:
                'Water level restored: $waterPercent% (${waterLevel.toStringAsFixed(1)} cm)\n\n'
                'System status:\n'
                '• Pumps can now operate normally\n'
                '• Auto-watering resumed\n'
                '• Plants are safe\n\n'
                'Thank you for refilling! 💧',
            timestamp: timestamp,
            priority: NotificationPriority.low,
            isRead: false,
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        );
      }
    }

    if (waterPercent < 40 && waterPercent >= lowThreshold) {
      if (_shouldSendAlert('water_getting_low', waterPercent)) {
        await addNotification(
          NotificationItem(
            id: 'water_low_${timestamp.millisecondsSinceEpoch}',
            title: '⚠️ Water Level Getting Low',
            message:
                'Water level: $waterPercent% (${waterLevel.toStringAsFixed(1)} cm)\n\n'
                'Current status:\n'
                '• Pumps still operational\n'
                '• System functioning normally\n\n'
                '💡 Recommendation:\n'
                'Plan to refill tank soon to avoid pump shutdown.\n'
                'Pumps auto-stop at $lowThreshold%.',
            timestamp: timestamp,
            priority: NotificationPriority.medium,
            isRead: false,
            icon: Icons.water_drop,
            color: Colors.orange,
          ),
        );
      }
    } else {
      _markAlertResolved('water_getting_low');
    }

    int? minutesSinceLastCheck = _lastWaterCheckTime == null
        ? null
        : timestamp.difference(_lastWaterCheckTime!).inMinutes;

    if (_lastWaterPercent != null && minutesSinceLastCheck != null) {
      final waterDrop = _lastWaterPercent! - waterPercent;

      if (minutesSinceLastCheck >= 30 &&
          minutesSinceLastCheck <= 60 &&
          waterDrop >= 15) {
        if (_shouldSendAlert('water_rapid_consumption', waterDrop)) {
          await addNotification(
            NotificationItem(
              id: 'water_rapid_${timestamp.millisecondsSinceEpoch}',
              title: '📉 Rapid Water Consumption Detected',
              message:
                  'Water dropped $waterDrop% in $minutesSinceLastCheck minutes\n'
                  '($_lastWaterPercent% → $waterPercent%)\n\n'
                  '⚠️ Possible causes:\n'
                  '• System leak\n'
                  '• Pump stuck ON\n'
                  '• Excessive watering cycles\n'
                  '• Faulty sensor reading\n\n'
                  '🔍 Inspect system for leaks!\n'
                  'Check pump operation and connections.',
              timestamp: timestamp,
              priority: NotificationPriority.high,
              isRead: false,
              icon: Icons.trending_down,
              color: Colors.red,
            ),
          );
        }
      }
    }

    if (waterPercent > 100 || waterPercent < 0 || waterLevel < 0) {
      if (_shouldSendAlert('water_sensor_error', waterPercent)) {
        await addNotification(
          NotificationItem(
            id: 'water_sensor_error_${timestamp.millisecondsSinceEpoch}',
            title: '⚠️ Water Sensor Reading Error',
            message:
                'Invalid sensor reading detected:\n'
                'Level: $waterPercent%, ${waterLevel.toStringAsFixed(1)} cm\n\n'
                'Possible issues:\n'
                '• Sensor not properly mounted\n'
                '• Obstruction blocking sensor\n'
                '• Loose wire connection\n'
                '• Sensor needs recalibration\n\n'
                'Check sensor positioning and wiring.',
            timestamp: timestamp,
            priority: NotificationPriority.medium,
            isRead: false,
            icon: Icons.error_outline,
            color: Colors.orange,
          ),
        );
      }
    } else {
      _markAlertResolved('water_sensor_error');
    }

    if (minutesSinceLastCheck == null || minutesSinceLastCheck >= 30) {
      _lastWaterPercent = waterPercent;
      _lastWaterCheckTime = timestamp;
    }
  }

  Future<void> _checkPumpRuntimeAlerts({
    required bool isPumpRunning,
    required String currentPumpMode,
    required int irrigationCycles,
    required int mistingCycles,
    required int totalPumpRuntime,
    required DateTime timestamp,
  }) async {
    if (isPumpRunning && totalPumpRuntime > 35) {
      final pumpKey = 'pump_long_runtime';
      if (_shouldSendAlert(pumpKey, totalPumpRuntime)) {
        String pumpType = currentPumpMode == 'irrigation'
            ? 'Irrigation'
            : 'Misting';
        int expectedDuration = currentPumpMode == 'irrigation' ? 30 : 15;

        await addNotification(
          NotificationItem(
            id: 'pump_long_${timestamp.millisecondsSinceEpoch}',
            title: '⚠️ $pumpType Running Long',
            message:
                '$pumpType has been running for ${totalPumpRuntime}s.\n'
                'Expected: ${expectedDuration}s\n\n'
                'Possible issues:\n'
                '• Pump malfunction\n'
                '• System leak\n'
                '• Sensor error\n\n'
                'Check system immediately!',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.warning_amber,
            color: Colors.orange,
          ),
        );
      }
    } else {
      _markAlertResolved('pump_long_runtime');
    }

    final timeSinceCheck = DateTime.now().difference(_lastCycleCheck);

    if (timeSinceCheck.inHours >= 1) {
      final irrigationCyclesThisHour = irrigationCycles - _lastWaterCycleCount;
      final mistingCyclesThisHour = mistingCycles - _lastMistCycleCount;

      if (irrigationCyclesThisHour >= 5) {
        await addNotification(
          NotificationItem(
            id: 'frequent_irrigation_${timestamp.millisecondsSinceEpoch}',
            title: '🔄 Frequent Irrigation Cycles',
            message:
                'Irrigation ran $irrigationCyclesThisHour times in the last hour.\n\n'
                '⚠️ Possible causes:\n'
                '• Water leak in system\n'
                '• Faulty soil sensor\n'
                '• Soil threshold too low\n'
                '• Poor drainage\n\n'
                'Inspect system for leaks!',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.loop,
            color: Colors.red,
          ),
        );
      }

      if (mistingCyclesThisHour >= 8) {
        await addNotification(
          NotificationItem(
            id: 'frequent_misting_${timestamp.millisecondsSinceEpoch}',
            title: '🔄 Frequent Misting Cycles',
            message:
                'Misting ran $mistingCyclesThisHour times in the last hour.\n\n'
                'Possible causes:\n'
                '• Humidity sensor malfunction\n'
                '• Poor air circulation\n'
                '• Threshold set too high\n'
                '• System leak\n\n'
                'Review system settings!',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.loop,
            color: Colors.cyan,
          ),
        );
      }

      _lastWaterCycleCount = irrigationCycles;
      _lastMistCycleCount = mistingCycles;
      _lastCycleCheck = DateTime.now();
    }
  }

  Future<void> _checkSoilEmergencyAlerts({
    required int? soilMoisture,
    required DateTime timestamp,
  }) async {
    if (soilMoisture == null) return;

    if (soilMoisture < 10) {
      if (_shouldSendAlert('soil_critical_low', soilMoisture)) {
        await addNotification(
          NotificationItem(
            id: 'soil_critical_${timestamp.millisecondsSinceEpoch}',
            title: '🚨 CRITICAL: Soil Extremely Dry',
            message:
                'Soil moisture at $soilMoisture%!\n\n'
                '⚠️ PLANTS IN DANGER ⚠️\n\n'
                'Immediate actions needed:\n'
                '1. Check water pump status\n'
                '2. Water manually if needed\n'
                '3. Verify soil sensor readings\n'
                '4. Check for system leaks\n\n'
                'Plant damage may occur!',
            timestamp: timestamp,
            priority: NotificationPriority.critical,
            isRead: false,
            icon: Icons.local_fire_department,
            color: Colors.red,
          ),
        );
      }
    } else {
      _markAlertResolved('soil_critical_low');
    }

    if (soilMoisture > 90) {
      if (_shouldSendAlert('soil_waterlogged', soilMoisture)) {
        await addNotification(
          NotificationItem(
            id: 'soil_waterlogged_${timestamp.millisecondsSinceEpoch}',
            title: '💦 Soil Waterlogged',
            message:
                'Soil moisture at $soilMoisture%!\n\n'
                'Critical issues:\n'
                '• Poor drainage system\n'
                '• Water pump stuck ON\n'
                '• Sensor calibration error\n'
                '• Excessive rainfall\n\n'
                'Check drainage immediately!\nRoot rot may occur.',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.water_damage,
            color: Colors.blue,
          ),
        );
      }
    } else {
      _markAlertResolved('soil_waterlogged');
    }

    if (_lastSoilReading != null && _lastSoilReadingTime != null) {
      final timeDiff = timestamp.difference(_lastSoilReadingTime!).inMinutes;
      final soilDiff = (soilMoisture - _lastSoilReading!).abs();

      if (timeDiff < 5 && soilDiff >= 20) {
        if (_shouldSendAlert('soil_fluctuation', soilDiff)) {
          await addNotification(
            NotificationItem(
              id: 'soil_fluctuation_${timestamp.millisecondsSinceEpoch}',
              title: '📊 Unstable Soil Readings',
              message:
                  'Soil changed from $_lastSoilReading% to $soilMoisture% in $timeDiff minutes.\n\n'
                  'Likely causes:\n'
                  '• Faulty soil sensor\n'
                  '• Loose connection (Pin 34)\n'
                  '• Sensor needs recalibration\n'
                  '• Interference from nearby wires\n\n'
                  'Check sensor wiring and calibration.',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.signal_cellular_connected_no_internet_0_bar,
              color: Colors.orange,
            ),
          );
        }
      }
    }

    _lastSoilReading = soilMoisture;
    _lastSoilReadingTime = timestamp;
  }

  Future<void> _checkShadeAlerts({
    required bool shadeDeployed,
    required DateTime timestamp,
  }) async {
    if (shadeDeployed) {
      _shadeDeployedSince ??= timestamp;

      final deployedHours = timestamp.difference(_shadeDeployedSince!).inHours;

      if (deployedHours >= 2) {
        if (_shouldSendAlert('shade_deployed_long', deployedHours)) {
          await addNotification(
            NotificationItem(
              id: 'shade_long_${timestamp.millisecondsSinceEpoch}',
              title: '🌂 Shade Deployed ${deployedHours}h',
              message:
                  'Shade has been deployed for $deployedHours hours.\n\n'
                  '⚠️ Plants need sunlight for photosynthesis!\n\n'
                  'Review current conditions:\n'
                  '• Temperature levels\n'
                  '• Light intensity\n'
                  '• Plant health\n\n'
                  'Consider retracting if safe.\nProlonged shade reduces growth.',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.wb_cloudy,
              color: Colors.grey,
            ),
          );
        }
      }
    } else {
      _shadeDeployedSince = null;
      _markAlertResolved('shade_deployed_long');
    }
  }

  Future<void> _checkNPKAndFertilization({
    required int? nitrogen,
    required int? phosphorus,
    required int? potassium,
    required DateTime timestamp,
  }) async {
    final npkConnected =
        nitrogen != null && phosphorus != null && potassium != null;

    if (!npkConnected && _lastNPKState) {
      if (_shouldSendAlert('npk_sensor', false)) {
        await addNotification(
          NotificationItem(
            id: 'npk_disconnected_${timestamp.millisecondsSinceEpoch}',
            title: 'NPK Sensor Disconnected',
            message:
                'Soil nutrient sensor offline. Check RS485 (RX:18, TX:19, DE/RE:23).',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.science_outlined,
            color: Colors.brown,
          ),
        );
      }
      _lastNPKState = false;
    } else if (npkConnected && !_lastNPKState) {
      _markAlertResolved('npk_sensor');
      await addNotification(
        NotificationItem(
          id: 'npk_connected_${timestamp.millisecondsSinceEpoch}',
          title: '✅ NPK Sensor Connected',
          message: 'Soil nutrient sensor is now online and reading data.',
          timestamp: timestamp,
          priority: NotificationPriority.low,
          isRead: false,
          icon: Icons.science,
          color: Colors.green,
        ),
      );
      _lastNPKState = true;
    }

    if (npkConnected) {
      if (nitrogen! < 20) {
        if (_shouldSendAlert('nitrogen_low', nitrogen)) {
          await addNotification(
            NotificationItem(
              id: 'nitrogen_low_${timestamp.millisecondsSinceEpoch}',
              title: '🌱 Low Nitrogen Detected',
              message:
                  'N: $nitrogen mg/kg\n\n'
                  'Apply Nitrogen fertilizer:\n'
                  '• Urea (46-0-0) - 50-100g\n'
                  '• Ammonium Sulfate (21-0-0)\n'
                  '• Blood Meal for organic option',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.grass,
              color: Colors.green,
            ),
          );
        }
      } else {
        _markAlertResolved('nitrogen_low');
      }

      if (phosphorus! < 10) {
        if (_shouldSendAlert('phosphorus_low', phosphorus)) {
          await addNotification(
            NotificationItem(
              id: 'phosphorus_low_${timestamp.millisecondsSinceEpoch}',
              title: '🌸 Low Phosphorus Detected',
              message:
                  'P: $phosphorus mg/kg\n\n'
                  'Apply Phosphorus fertilizer:\n'
                  '• Superphosphate (0-20-0) - 30-80g\n'
                  '• Bone Meal (3-15-0)\n'
                  '• Rock Phosphate for slow release',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.local_florist,
              color: Colors.orange,
            ),
          );
        }
      } else {
        _markAlertResolved('phosphorus_low');
      }

      if (potassium! < 50) {
        if (_shouldSendAlert('potassium_low', potassium)) {
          await addNotification(
            NotificationItem(
              id: 'potassium_low_${timestamp.millisecondsSinceEpoch}',
              title: '💪 Low Potassium Detected',
              message:
                  'K: $potassium mg/kg\n\n'
                  'Apply Potassium fertilizer:\n'
                  '• Potassium Chloride (0-0-60) - 40-90g\n'
                  '• Potassium Sulfate (0-0-50)\n'
                  '• Wood Ash for organic option',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.spa,
              color: Colors.blue,
            ),
          );
        }
      } else {
        _markAlertResolved('potassium_low');
      }

      if (nitrogen < 20 && phosphorus < 10 && potassium < 50) {
        if (_shouldSendAlert(
          'npk_critical',
          nitrogen + phosphorus + potassium,
        )) {
          await addNotification(
            NotificationItem(
              id: 'npk_critical_${timestamp.millisecondsSinceEpoch}',
              title: '⚠️ CRITICAL: All Nutrients Low',
              message:
                  'N:$nitrogen P:$phosphorus K:$potassium mg/kg\n\n'
                  'Apply Complete NPK Fertilizer:\n'
                  '• NPK 14-14-14 (balanced) - 100-150g\n'
                  '• NPK 16-16-16 (general purpose)\n\n'
                  'Apply every 14 days until levels recover.\nSevere nutrient deficiency!',
              timestamp: timestamp,
              priority: NotificationPriority.critical,
              isRead: false,
              icon: Icons.warning,
              color: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _checkIndividualSensors(
    SensorStatus sensorStatus,
    DateTime timestamp,
  ) async {
    final xymd02Connected =
        sensorStatus.temperatureConnected && sensorStatus.humidityConnected;

    if (!xymd02Connected && _lastXYMD02State) {
      if (_shouldSendAlert('xymd02_sensor', false)) {
        await addNotification(
          NotificationItem(
            id: 'xymd02_disconnected_${timestamp.millisecondsSinceEpoch}',
            title: 'XY-MD02 Sensor Disconnected',
            message:
                'Temperature/Humidity sensor offline. Check RS485 (RX:16, TX:17, DE/RE:25).',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.sensors_off,
            color: Colors.red,
          ),
        );
      }
      _lastXYMD02State = false;
    } else if (xymd02Connected && !_lastXYMD02State) {
      _markAlertResolved('xymd02_sensor');
      await addNotification(
        NotificationItem(
          id: 'xymd02_connected_${timestamp.millisecondsSinceEpoch}',
          title: '✅ XY-MD02 Sensor Connected',
          message: 'Temperature/Humidity sensor is now online.',
          timestamp: timestamp,
          priority: NotificationPriority.low,
          isRead: false,
          icon: Icons.sensors,
          color: Colors.green,
        ),
      );
      _lastXYMD02State = true;
    }

    if (!sensorStatus.soilConnected && _lastSoilState) {
      if (_shouldSendAlert('soil_sensor', false)) {
        await addNotification(
          NotificationItem(
            id: 'soil_disconnected_${timestamp.millisecondsSinceEpoch}',
            title: 'Soil Sensor Disconnected',
            message: 'Soil moisture sensor offline. Check analog (Pin 34).',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.sensors_off,
            color: Colors.brown,
          ),
        );
      }
      _lastSoilState = false;
    } else if (sensorStatus.soilConnected && !_lastSoilState) {
      _markAlertResolved('soil_sensor');
      await addNotification(
        NotificationItem(
          id: 'soil_connected_${timestamp.millisecondsSinceEpoch}',
          title: '✅ Soil Sensor Connected',
          message: 'Soil moisture sensor is now online.',
          timestamp: timestamp,
          priority: NotificationPriority.low,
          isRead: false,
          icon: Icons.sensors,
          color: Colors.green,
        ),
      );
      _lastSoilState = true;
    }

    if (!sensorStatus.lightConnected && _lastLightState) {
      if (_shouldSendAlert('light_sensor', false)) {
        await addNotification(
          NotificationItem(
            id: 'light_disconnected_${timestamp.millisecondsSinceEpoch}',
            title: 'Light Sensor Disconnected',
            message: 'BH1750 offline. Check I2C (SDA:21, SCL:22).',
            timestamp: timestamp,
            priority: NotificationPriority.high,
            isRead: false,
            icon: Icons.sensors_off,
            color: Colors.orange,
          ),
        );
      }
      _lastLightState = false;
    } else if (sensorStatus.lightConnected && !_lastLightState) {
      _markAlertResolved('light_sensor');
      await addNotification(
        NotificationItem(
          id: 'light_connected_${timestamp.millisecondsSinceEpoch}',
          title: '✅ Light Sensor Connected',
          message: 'BH1750 sensor is now online.',
          timestamp: timestamp,
          priority: NotificationPriority.low,
          isRead: false,
          icon: Icons.sensors,
          color: Colors.green,
        ),
      );
      _lastLightState = true;
    }
  }

  Future<void> _checkPlantAlerts({
    required double? temperature,
    required int? soilMoisture,
    required int? humidity,
    required int? lightIntensity,
    required Plant plant,
    required DateTime timestamp,
  }) async {
    if (temperature != null) {
      if (temperature < plant.minTemperature) {
        if (_shouldSendAlert('temp_low', temperature)) {
          await addNotification(
            NotificationItem(
              id: 'temp_low_${timestamp.millisecondsSinceEpoch}',
              title: '${plant.emoji} Temperature Too Low',
              message:
                  '${plant.name} needs warmth. Current: ${temperature.toStringAsFixed(1)}°C (Min: ${plant.minTemperature}°C)',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.ac_unit,
              color: Colors.blue,
            ),
          );
        }
      } else if (temperature > plant.maxTemperature) {
        if (_shouldSendAlert('temp_high', temperature)) {
          await addNotification(
            NotificationItem(
              id: 'temp_high_${timestamp.millisecondsSinceEpoch}',
              title: '${plant.emoji} Temperature Too High',
              message:
                  '${plant.name} overheating! Current: ${temperature.toStringAsFixed(1)}°C (Max: ${plant.maxTemperature}°C)',
              timestamp: timestamp,
              priority: NotificationPriority.high,
              isRead: false,
              icon: Icons.thermostat,
              color: Colors.red,
            ),
          );
        }
      } else {
        _markAlertResolved('temp_low');
        _markAlertResolved('temp_high');
      }
    }

    if (soilMoisture != null) {
      if (soilMoisture < plant.minSoilMoisture) {
        if (_shouldSendAlert('soil_low', soilMoisture)) {
          await addNotification(
            NotificationItem(
              id: 'soil_low_${timestamp.millisecondsSinceEpoch}',
              title: '${plant.emoji} Soil Too Dry',
              message:
                  '${plant.name} needs water. Current: $soilMoisture% (Min: ${plant.minSoilMoisture}%)',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.water_drop,
              color: Colors.brown,
            ),
          );
        }
      } else if (soilMoisture > plant.maxSoilMoisture) {
        if (_shouldSendAlert('soil_high', soilMoisture)) {
          await addNotification(
            NotificationItem(
              id: 'soil_high_${timestamp.millisecondsSinceEpoch}',
              title: '${plant.emoji} Soil Too Wet',
              message:
                  '${plant.name} waterlogged. Current: $soilMoisture% (Max: ${plant.maxSoilMoisture}%)',
              timestamp: timestamp,
              priority: NotificationPriority.medium,
              isRead: false,
              icon: Icons.water_damage,
              color: Colors.blue,
            ),
          );
        }
      } else {
        _markAlertResolved('soil_low');
        _markAlertResolved('soil_high');
      }
    }

    if (humidity != null) {
      if (humidity < plant.minHumidity) {
        if (_shouldSendAlert('humidity_low', humidity)) {
          await addNotification(
            NotificationItem(
              id: 'humidity_low_${timestamp.millisecondsSinceEpoch}',
              title: '${plant.emoji} Humidity Too Low',
              message:
                  '${plant.name} needs humidity. Current: $humidity% (Min: ${plant.minHumidity}%)',
              timestamp: timestamp,
              priority: NotificationPriority.low,
              isRead: false,
              icon: Icons.opacity,
              color: Colors.orange,
            ),
          );
        }
      } else {
        _markAlertResolved('humidity_low');
      }
    }

    if (lightIntensity != null) {
      if (lightIntensity < plant.minLightIntensity) {
        if (_shouldSendAlert('light_low', lightIntensity)) {
          await addNotification(
            NotificationItem(
              id: 'light_low_${timestamp.millisecondsSinceEpoch}',
              title: '${plant.emoji} Insufficient Light',
              message:
                  '${plant.name} needs light. Current: $lightIntensity lux (Min: ${plant.minLightIntensity} lux)',
              timestamp: timestamp,
              priority: NotificationPriority.low,
              isRead: false,
              icon: Icons.wb_cloudy,
              color: Colors.grey,
            ),
          );
        }
      } else {
        _markAlertResolved('light_low');
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      _notificationController.add(_notifications);

      try {
        await _firestore.collection('notifications').doc(notificationId).update(
          {'isRead': true},
        );
        debugPrint('✅ Notification marked as read in Firestore');
      } catch (e) {
        debugPrint('⚠️ Failed to update Firestore: $e');
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);

      try {
        await _firestore
            .collection('notifications')
            .doc(_notifications[i].id)
            .update({'isRead': true});
      } catch (e) {
        debugPrint('⚠️ Failed to update ${_notifications[i].id}: $e');
      }
    }
    await _saveNotifications();
    _notificationController.add(_notifications);
  }

  Future<void> clearAllNotifications() async {
    try {
      final archivedCount = await _firestoreService.archiveAllNotifications();
      debugPrint('✅ All notifications archived to Firestore: $archivedCount');
    } catch (e) {
      debugPrint('⚠️ Failed to archive from Firestore: $e');
    }

    _notifications.clear();
    _alertStates.clear();
    await _saveNotifications();
    await _saveAlertStates();
    _notificationController.add(_notifications);
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    _notificationController.add(_notifications);

    try {
      await _firestoreService.archiveNotification(notificationId);
      debugPrint('✅ Notification archived to Firestore');
    } catch (e) {
      debugPrint('⚠️ Failed to archive from Firestore: $e');
    }
  }

  Future<void> clearOldNotifications({int daysToKeep = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    final toArchive = _notifications
        .where((n) => n.timestamp.isBefore(cutoffDate))
        .map((n) => n.id)
        .toList();

    try {
      int archivedCount = 0;
      for (var id in toArchive) {
        final success = await _firestoreService.archiveNotification(id);
        if (success) archivedCount++;
      }
      debugPrint('✅ Old notifications archived to Firestore: $archivedCount');
    } catch (e) {
      debugPrint('⚠️ Failed to archive old notifications: $e');
    }

    _notifications.removeWhere((n) => n.timestamp.isBefore(cutoffDate));
    await _saveNotifications();
    _notificationController.add(_notifications);
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get totalCount => _notifications.length;

  List<NotificationItem> getNotificationsByPriority(
    NotificationPriority priority,
  ) {
    return _notifications.where((n) => n.priority == priority).toList();
  }

  void dispose() {
    _notificationController.close();
    _autoCleanupTimer?.cancel();
  }
}

class AlertState {
  final bool isActive;
  final dynamic lastValue;
  final DateTime lastAlertTime;

  AlertState({
    required this.isActive,
    required this.lastValue,
    required this.lastAlertTime,
  });

  AlertState copyWith({
    bool? isActive,
    dynamic lastValue,
    DateTime? lastAlertTime,
  }) {
    return AlertState(
      isActive: isActive ?? this.isActive,
      lastValue: lastValue ?? this.lastValue,
      lastAlertTime: lastAlertTime ?? this.lastAlertTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'lastValue': lastValue?.toString(),
      'lastAlertTime': lastAlertTime.toIso8601String(),
    };
  }

  factory AlertState.fromJson(Map<String, dynamic> json) {
    return AlertState(
      isActive: json['isActive'] ?? false,
      lastValue: json['lastValue'],
      lastAlertTime: DateTime.parse(json['lastAlertTime']),
    );
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationPriority priority;
  final bool isRead;
  final IconData icon;
  final Color color;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.priority,
    required this.isRead,
    required this.icon,
    required this.color,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationPriority? priority,
    bool? isRead,
    IconData? icon,
    Color? color,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.index,
      'isRead': isRead,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.value,
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
      priority: NotificationPriority.values[json['priority']],
      isRead: json['isRead'],
      icon: IconData(json['iconCodePoint'], fontFamily: 'MaterialIcons'),
      color: Color(json['colorValue']),
    );
  }
}

enum NotificationPriority { low, medium, high, critical }
