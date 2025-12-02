// services/firebase_service.dart - FIXED SYSTEM COMMANDS

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class FirebaseService {
  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://agri-leafy-default-rtdb.firebaseio.com',
  );

  static final String _currentDeviceId = 'ESP32_ALS_001';

  static DatabaseReference get _sensorRef =>
      _database.ref('devices/$_currentDeviceId/sensor_data');
  static DatabaseReference get _commandsRef =>
      _database.ref('devices/$_currentDeviceId/commands');
  static DatabaseReference get _settingsRef =>
      _database.ref('devices/$_currentDeviceId/settings');
  static DatabaseReference get _statusRef =>
      _database.ref('devices/$_currentDeviceId/status');

  bool _isConnected = false;
  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _statusSubscription;

  final StreamController<SensorData?> _sensorController =
      StreamController<SensorData?>.broadcast();
  final StreamController<DeviceStatus?> _statusController =
      StreamController<DeviceStatus?>.broadcast();

  bool get isConnected => _isConnected;
  Stream<SensorData?> get sensorStream => _sensorController.stream;
  Stream<DeviceStatus?> get statusStream => _statusController.stream;
  String get currentDeviceId => _currentDeviceId;

  Future<void> initialize() async {
    try {
      await _database.ref('.info/connected').once();
      _isConnected = true;

      _startSensorListening();
      _startStatusListening();

      debugPrint('✅ Firebase service initialized');
    } catch (e) {
      _isConnected = false;
      debugPrint('❌ Firebase init failed: $e');
      rethrow;
    }
  }

  void _startSensorListening() {
    _sensorSubscription = _sensorRef.onValue.listen(
      (DatabaseEvent event) {
        try {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              final sensorData = SensorData.fromFirebaseJson(data);
              _sensorController.add(sensorData);
              _isConnected = true;
            }
          } else {
            _sensorController.add(null);
          }
        } catch (e) {
          debugPrint('❌ Sensor data parse error: $e');
          _sensorController.add(null);
        }
      },
      onError: (error) {
        debugPrint('❌ Sensor stream error: $error');
        _isConnected = false;
        _sensorController.add(null);
      },
    );
  }

  void _startStatusListening() {
    _statusSubscription = _statusRef.onValue.listen(
      (DatabaseEvent event) {
        try {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              final deviceStatus = DeviceStatus.fromFirebaseJson(data);
              _statusController.add(deviceStatus);
            }
          }
        } catch (e) {
          debugPrint('❌ Status parse error: $e');
          _statusController.add(null);
        }
      },
      onError: (error) {
        debugPrint('❌ Status stream error: $error');
      },
    );
  }

  Future<bool> setMode(String mode) async {
    try {
      if (mode != 'auto' && mode != 'manual') {
        debugPrint('❌ Invalid mode: $mode');
        return false;
      }

      await _commandsRef.child('mode').set(mode);
      debugPrint('✅ Mode command sent: $mode');
      return true;
    } catch (e) {
      debugPrint('❌ Set mode failed: $e');
      return false;
    }
  }

  Future<bool> setPumpMode(String mode) async {
    try {
      if (!['soil', 'humidity'].contains(mode)) {
        debugPrint('❌ Invalid pump mode: $mode');
        return false;
      }

      await _commandsRef.child('pump_mode').set(mode);
      debugPrint('✅ Pump mode set: $mode');
      return true;
    } catch (e) {
      debugPrint('❌ Set pump mode failed: $e');
      return false;
    }
  }

  Future<bool> sendShadeCommand(String command) async {
    try {
      String espCommand = command;
      if (command == 'open') {
        espCommand = 'retract';
      }
      if (command == 'close') {
        espCommand = 'deploy';
      }

      final validCommands = ['open', 'close', 'deploy', 'retract', 'stop'];
      if (!validCommands.contains(command)) {
        debugPrint('❌ Invalid shade command: $command');
        return false;
      }

      await _commandsRef.child('shade_command').set(espCommand);
      debugPrint('✅ Shade command sent: $command');
      return true;
    } catch (e) {
      debugPrint('❌ Shade command failed: $e');
      return false;
    }
  }

  Future<bool> sendPumpCommand(String command) async {
    try {
      final validCommands = [
        'irrigation_start',
        'irrigation_stop',
        'misting_start',
        'misting_stop',
      ];

      if (!validCommands.contains(command)) {
        debugPrint('❌ Invalid pump command: $command');
        return false;
      }

      await _commandsRef.child('pump_command').set(command);
      debugPrint('✅ Pump command sent: $command');
      return true;
    } catch (e) {
      debugPrint('❌ Pump command failed: $e');
      return false;
    }
  }

  Future<bool> setTemperatureThreshold(double threshold) async {
    try {
      if (threshold < 15.0 || threshold > 50.0) {
        debugPrint('❌ Invalid temp threshold: $threshold');
        return false;
      }

      await _commandsRef.child('temp_threshold').set(threshold);
      debugPrint('✅ Temp threshold set: $threshold°C');
      return true;
    } catch (e) {
      debugPrint('❌ Set temp threshold failed: $e');
      return false;
    }
  }

  Future<bool> setSoilPumpThreshold(double threshold) async {
    try {
      if (threshold < 0 || threshold > 100) {
        debugPrint('❌ Invalid soil threshold: $threshold');
        return false;
      }

      await _commandsRef.child('soil_threshold').set(threshold);
      debugPrint('✅ Soil threshold set: $threshold%');
      return true;
    } catch (e) {
      debugPrint('❌ Set soil threshold failed: $e');
      return false;
    }
  }

  Future<bool> setHumidityThreshold(double threshold) async {
    try {
      if (threshold < 20.0 || threshold > 90.0) {
        debugPrint('❌ Invalid humidity threshold: $threshold');
        return false;
      }

      await _commandsRef.child('humidity_threshold').set(threshold);
      debugPrint('✅ Humidity threshold set: $threshold%');
      return true;
    } catch (e) {
      debugPrint('❌ Set humidity threshold failed: $e');
      return false;
    }
  }

  Future<bool> setLightThreshold(double threshold) async {
    try {
      if (threshold < 1000.0 || threshold > 100000.0) {
        debugPrint('❌ Invalid light threshold: $threshold');
        return false;
      }

      await _commandsRef.child('light_threshold').set(threshold);
      debugPrint('✅ Light threshold set: $threshold lux');
      return true;
    } catch (e) {
      debugPrint('❌ Set light threshold failed: $e');
      return false;
    }
  }

  Future<bool> setWaterLevelLowThreshold(int threshold) async {
    try {
      if (threshold < 5 || threshold > 50) {
        debugPrint('❌ Invalid water level threshold: $threshold');
        return false;
      }

      await _commandsRef.child('water_level_low_threshold').set(threshold);
      debugPrint('✅ Water level threshold set: $threshold%');
      return true;
    } catch (e) {
      debugPrint('❌ Set water level threshold failed: $e');
      return false;
    }
  }

  Future<bool> setPlantSettings({
    required String plantName,
    required double maxTemperature,
    required int maxLightIntensity,
  }) async {
    try {
      final settingsPath = 'devices/$_currentDeviceId/plant_settings';

      await _database.ref(settingsPath).child('selected_plant').set(plantName);
      await _database
          .ref(settingsPath)
          .child('max_temperature')
          .set(maxTemperature);
      await _database
          .ref(settingsPath)
          .child('max_light_intensity')
          .set(maxLightIntensity);
      await _commandsRef.child('plant_changed').set('true');

      debugPrint('✅ Plant settings sent: $plantName');
      return true;
    } catch (e) {
      debugPrint('❌ Set plant settings failed: $e');
      return false;
    }
  }

  // ✅✅✅ FIXED: Proper system command implementation ✅✅✅
  Future<bool> sendSystemCommand(String command) async {
    try {
      // Validate command
      final validCommands = ['restart', 'factory_reset'];
      if (!validCommands.contains(command)) {
        debugPrint('❌ Invalid system command: $command');
        return false;
      }

      debugPrint('🔄 Sending system command: $command');

      if (command == 'restart') {
        debugPrint('   📝 ESP32 will restart (WiFi preserved)');
      } else if (command == 'factory_reset') {
        debugPrint('   ⚠️  ESP32 will factory reset (WiFi CLEARED!)');
      }

      // Send command to Firebase
      await _commandsRef.child('system_command').set(command);

      debugPrint('✅ System command sent successfully: $command');
      return true;
    } catch (e) {
      debugPrint('❌ System command failed: $e');
      return false;
    }
  }

  // ✅ Helper method for factory reset
  Future<bool> sendFactoryReset() async {
    try {
      debugPrint('🔥 Initiating factory reset...');
      final result = await sendSystemCommand('factory_reset');

      if (result) {
        debugPrint('✅ Factory reset command sent!');
        debugPrint('   ESP32 will clear WiFi and restart in config mode');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Factory reset error: $e');
      return false;
    }
  }

  // ✅ Helper method for restart only
  Future<bool> sendRestart() async {
    try {
      debugPrint('🔄 Initiating restart...');
      final result = await sendSystemCommand('restart');

      if (result) {
        debugPrint('✅ Restart command sent!');
        debugPrint('   ESP32 will restart (WiFi credentials preserved)');
      }

      return result;
    } catch (e) {
      debugPrint('❌ Restart error: $e');
      return false;
    }
  }

  Future<bool> checkConnection() async {
    try {
      final snapshot = await _database.ref('.info/connected').once();
      final connected = snapshot.snapshot.value as bool? ?? false;
      return connected;
    } catch (e) {
      debugPrint('❌ Connection check failed: $e');
      return false;
    }
  }

  void dispose() {
    _sensorSubscription?.cancel();
    _statusSubscription?.cancel();
    _sensorController.close();
    _statusController.close();
  }
}

// ====== DATA MODELS (same as before) ======

class SensorData {
  final double? temperature;
  final int? soilMoisture;
  final int? lightIntensity;
  final int? humidity;
  final int? nitrogen;
  final int? phosphorus;
  final int? potassium;
  final int? waterPercent;
  final double? waterLevel;
  final double? waterDistance;
  final String timestamp;
  final DateTime receivedAt;
  final SensorStatus sensorStatus;
  final SystemInfo? systemInfo;

  SensorData({
    this.temperature,
    this.soilMoisture,
    this.lightIntensity,
    this.humidity,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.waterPercent,
    this.waterLevel,
    this.waterDistance,
    required this.timestamp,
    DateTime? receivedAt,
    SensorStatus? sensorStatus,
    this.systemInfo,
  }) : receivedAt = receivedAt ?? DateTime.now(),
       sensorStatus = sensorStatus ?? SensorStatus();

  factory SensorData.fromFirebaseJson(Map<dynamic, dynamic> json) {
    return SensorData(
      temperature: _parseNullableDouble(json['temperature']),
      soilMoisture: _parseNullableInt(json['soil']),
      lightIntensity: _parseNullableInt(json['light']),
      humidity: _parseNullableInt(json['humidity']),
      nitrogen: _parseNullableInt(json['nitrogen']),
      phosphorus: _parseNullableInt(json['phosphorus']),
      potassium: _parseNullableInt(json['potassium']),
      waterPercent: _parseNullableInt(json['water_percent']),
      waterLevel: _parseNullableDouble(json['water_level']),
      waterDistance: _parseNullableDouble(json['water_distance']),
      timestamp:
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      sensorStatus: SensorStatus.fromJson(json['sensor_status']),
      systemInfo: json['system_info'] != null
          ? SystemInfo.fromJson(json['system_info'])
          : null,
    );
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null || value == 'N/A') return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String && value != 'N/A') return double.tryParse(value);
    return null;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null || value == 'N/A') return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String && value != 'N/A') return int.tryParse(value);
    return null;
  }

  bool get isRecent => DateTime.now().difference(receivedAt).inMinutes < 3;

  String get formattedTimestamp {
    try {
      final dt = DateTime.parse(timestamp);
      final phTime = dt.toUtc().add(const Duration(hours: 8));

      return '${phTime.hour.toString().padLeft(2, '0')}:${phTime.minute.toString().padLeft(2, '0')}:${phTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('❌ Timestamp parse error: $e for timestamp: $timestamp');
      return 'Unknown';
    }
  }

  String get formattedDate {
    try {
      final dt = DateTime.parse(timestamp);
      final phTime = dt.toUtc().add(const Duration(hours: 8));

      return '${phTime.day.toString().padLeft(2, '0')}/${phTime.month.toString().padLeft(2, '0')}/${phTime.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String get formattedDateTime {
    try {
      final dt = DateTime.parse(timestamp);
      final phTime = dt.toUtc().add(const Duration(hours: 8));

      final formatter = DateFormat('MMM dd, yyyy hh:mm a');
      return formatter.format(phTime);
    } catch (e) {
      return 'Unknown';
    }
  }
}

class SystemInfo {
  final int wifiRssi;
  final int freeHeap;
  final int uptimeMs;
  final String mode;
  final String pumpMode;
  final String currentPumpMode;
  final bool shadeDeployed;
  final bool pumpRunning;
  final int irrigationRuntimeSec;
  final int irrigationCycles;
  final int mistingRuntimeSec;
  final int mistingCycles;

  SystemInfo({
    required this.wifiRssi,
    required this.freeHeap,
    required this.uptimeMs,
    required this.mode,
    required this.pumpMode,
    required this.currentPumpMode,
    required this.shadeDeployed,
    required this.pumpRunning,
    required this.irrigationRuntimeSec,
    required this.irrigationCycles,
    required this.mistingRuntimeSec,
    required this.mistingCycles,
  });

  factory SystemInfo.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) {
      return SystemInfo(
        wifiRssi: 0,
        freeHeap: 0,
        uptimeMs: 0,
        mode: 'unknown',
        pumpMode: 'soil',
        currentPumpMode: 'none',
        shadeDeployed: false,
        pumpRunning: false,
        irrigationRuntimeSec: 0,
        irrigationCycles: 0,
        mistingRuntimeSec: 0,
        mistingCycles: 0,
      );
    }

    return SystemInfo(
      wifiRssi: json['wifi_rssi'] ?? 0,
      freeHeap: json['free_heap'] ?? 0,
      uptimeMs: json['uptime_ms'] ?? 0,
      mode: json['mode']?.toString() ?? 'unknown',
      pumpMode: json['pump_mode']?.toString() ?? 'soil',
      currentPumpMode: json['current_pump_mode']?.toString() ?? 'none',
      shadeDeployed: json['shade_deployed'] ?? false,
      pumpRunning: json['pump_running'] ?? false,
      irrigationRuntimeSec: json['irrigation_runtime_sec'] ?? 0,
      irrigationCycles: json['irrigation_cycles'] ?? 0,
      mistingRuntimeSec: json['misting_runtime_sec'] ?? 0,
      mistingCycles: json['misting_cycles'] ?? 0,
    );
  }

  int get totalPumpRuntimeSec => irrigationRuntimeSec + mistingRuntimeSec;
  int get pumpCycleCount => irrigationCycles + mistingCycles;
}

class DeviceStatus {
  final String deviceId;
  final String timestamp;
  final int uptimeMs;
  final int freeHeap;
  final bool wifiConnected;
  final int wifiRssi;
  final String currentMode;
  final String pumpMode;
  final String currentPumpMode;
  final bool shadeDeployed;
  final bool pumpRunning;
  final double tempThreshold;
  final double soilPumpThreshold;
  final double humidityThreshold;
  final bool online;

  DeviceStatus({
    required this.deviceId,
    required this.timestamp,
    required this.uptimeMs,
    required this.freeHeap,
    required this.wifiConnected,
    required this.wifiRssi,
    required this.currentMode,
    required this.pumpMode,
    required this.currentPumpMode,
    required this.shadeDeployed,
    required this.pumpRunning,
    required this.tempThreshold,
    required this.soilPumpThreshold,
    required this.humidityThreshold,
    required this.online,
  });

  factory DeviceStatus.fromFirebaseJson(Map<dynamic, dynamic> json) {
    return DeviceStatus(
      deviceId: json['device_id']?.toString() ?? 'unknown',
      timestamp:
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      uptimeMs: json['uptime_ms'] ?? 0,
      freeHeap: json['free_heap'] ?? 0,
      wifiConnected: json['wifi_connected'] ?? false,
      wifiRssi: json['wifi_rssi'] ?? -100,
      currentMode: json['current_mode']?.toString() ?? 'unknown',
      pumpMode: json['pump_mode']?.toString() ?? 'soil',
      currentPumpMode: json['current_pump_mode']?.toString() ?? 'none',
      shadeDeployed: json['shade_deployed'] ?? false,
      pumpRunning: json['pump_running'] ?? false,
      tempThreshold: (json['temperature_threshold'] ?? 30.0).toDouble(),
      soilPumpThreshold: (json['soil_moisture_threshold'] ?? 30.0).toDouble(),
      humidityThreshold: (json['humidity_threshold'] ?? 50.0).toDouble(),
      online: json['online'] == true || json['online'] == 'true',
    );
  }

  String get formattedTimestamp {
    try {
      final dt = DateTime.parse(timestamp);
      final phTime = dt.toUtc().add(const Duration(hours: 8));

      return '${phTime.hour.toString().padLeft(2, '0')}:${phTime.minute.toString().padLeft(2, '0')}:${phTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class SensorStatus {
  final bool temperatureConnected;
  final bool humidityConnected;
  final bool soilConnected;
  final bool lightConnected;
  final bool waterLevelConnected;

  SensorStatus({
    this.temperatureConnected = false,
    this.humidityConnected = false,
    this.soilConnected = false,
    this.lightConnected = false,
    this.waterLevelConnected = false,
  });

  factory SensorStatus.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return SensorStatus();

    return SensorStatus(
      temperatureConnected: json['temperature_connected'] ?? false,
      humidityConnected: json['humidity_connected'] ?? false,
      soilConnected: json['soil_connected'] ?? false,
      lightConnected: json['light_connected'] ?? false,
      waterLevelConnected: json['water_level_connected'] ?? false,
    );
  }

  int get connectedCount {
    int count = 0;
    if (temperatureConnected) count++;
    if (humidityConnected) count++;
    if (soilConnected) count++;
    if (lightConnected) count++;
    return count;
  }

  bool get hasAnySensorConnected => connectedCount > 0;
  bool get allSensorsConnected => connectedCount == 4;
}
