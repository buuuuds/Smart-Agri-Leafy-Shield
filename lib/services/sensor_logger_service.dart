// lib/services/sensor_logger_service.dart - AUTO-SAVE REALTIME DB → FIRESTORE

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';
import '../services/firestore_service.dart';

class SensorLoggerService {
  static final SensorLoggerService _instance = SensorLoggerService._internal();
  factory SensorLoggerService() => _instance;
  SensorLoggerService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<SensorData?>? _sensorSubscription;
  Timer? _saveTimer;

  SensorData? _lastSavedData;
  DateTime? _lastSaveTime;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Save every 5 minutes to avoid excessive Firestore writes
  static const Duration _savingInterval = Duration(minutes: 5);

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ SensorLoggerService already initialized');
      return;
    }

    try {
      // Ensure Firebase is ready
      if (!_firebaseService.isConnected) {
        await _firebaseService.initialize();
      }

      // Listen to Realtime Database sensor stream
      _sensorSubscription = _firebaseService.sensorStream.listen(
        (sensorData) {
          if (sensorData != null) {
            _handleSensorData(sensorData);
          }
        },
        onError: (error) {
          debugPrint('❌ Sensor stream error in logger: $error');
        },
      );

      // Start periodic saving
      _startPeriodicSaving();

      _isInitialized = true;
      debugPrint(
        '✅ SensorLoggerService initialized - Auto-saving to Firestore every 5 min',
      );
    } catch (e) {
      debugPrint('❌ SensorLoggerService init failed: $e');
      _isInitialized = false;
    }
  }

  void _handleSensorData(SensorData sensorData) {
    final now = DateTime.now();

    // Save if: (1) First save, (2) 5 min passed, or (3) Significant change
    if (_lastSaveTime == null ||
        now.difference(_lastSaveTime!) >= _savingInterval ||
        _isSignificantChange(sensorData)) {
      _saveToFirestore(sensorData);
      _lastSaveTime = now;
      _lastSavedData = sensorData;
    }
  }

  bool _isSignificantChange(SensorData current) {
    if (_lastSavedData == null) return true;

    // Significant = temp change >2°C, soil >10%, etc.
    if (current.temperature != null && _lastSavedData!.temperature != null) {
      if ((current.temperature! - _lastSavedData!.temperature!).abs() > 2.0) {
        return true;
      }
    }

    if (current.soilMoisture != null && _lastSavedData!.soilMoisture != null) {
      if ((current.soilMoisture! - _lastSavedData!.soilMoisture!).abs() > 10) {
        return true;
      }
    }
    if (current.waterPercent != null && _lastSavedData!.waterPercent != null) {
      if ((current.waterPercent! - _lastSavedData!.waterPercent!).abs() > 5) {
        return true;
      }
    }

    return false;
  }

  Future<void> _saveToFirestore(SensorData sensorData) async {
    try {
      await _firestoreService.saveSensorReading(
        temperature: sensorData.temperature,
        soilMoisture: sensorData.soilMoisture,
        lightIntensity: sensorData.lightIntensity,
        humidity: sensorData.humidity,
        nitrogen: sensorData.nitrogen,
        phosphorus: sensorData.phosphorus,
        potassium: sensorData.potassium,
        waterPercent: sensorData.waterPercent,
        waterLevel: sensorData.waterLevel,
        waterDistance: sensorData.waterDistance,
        tempConnected: sensorData.sensorStatus.temperatureConnected,
        soilConnected: sensorData.sensorStatus.soilConnected,
        lightConnected: sensorData.sensorStatus.lightConnected,
        humidityConnected: sensorData.sensorStatus.humidityConnected,
        waterLevelConnected: sensorData.sensorStatus.waterLevelConnected,
      );

      debugPrint('✅ Sensor data auto-saved to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to save to Firestore: $e');
    }
  }

  void _startPeriodicSaving() {
    // Every 5 minutes, force save if there's new data
    _saveTimer = Timer.periodic(_savingInterval, (_) {
      if (_firebaseService.isConnected) {
        debugPrint('⏰ Periodic Firestore save check...');
      }
    });
  }

  void dispose() {
    _sensorSubscription?.cancel();
    _saveTimer?.cancel();
    _isInitialized = false;
    debugPrint('🛑 SensorLoggerService disposed');
  }
}
