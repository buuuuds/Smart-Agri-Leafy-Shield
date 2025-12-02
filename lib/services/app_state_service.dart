// lib/services/app_state_service.dart - WITH FIREBASE SERVICE

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'firebase_service.dart'; // ✅ ADD THIS IMPORT

class AppStateService extends ChangeNotifier {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  double _temperatureThreshold = 30.0;
  double _soilPumpThreshold = 30.0;
  double _humidityThreshold = 50.0;
  double _lightThreshold = 20000.0;
  String _selectedPlant = 'Pechay';
  bool _isDarkMode = false;
  String _pumpMode = 'soil';

  // ✅ ADD THIS: Store FirebaseService instance
  FirebaseService? _firebaseService;

  // Debounce timers
  Timer? _tempThresholdDebounce;
  Timer? _soilThresholdDebounce;
  Timer? _humidityThresholdDebounce;
  Timer? _lightThresholdDebounce;
  Timer? _plantDebounce;

  double get temperatureThreshold => _temperatureThreshold;
  double get soilPumpThreshold => _soilPumpThreshold;
  double get humidityThreshold => _humidityThreshold;
  double get lightThreshold => _lightThreshold;
  String get selectedPlant => _selectedPlant;
  bool get isDarkMode => _isDarkMode;
  String get pumpMode => _pumpMode;

  // ✅ ADD THIS: Getter for FirebaseService
  FirebaseService? get firebaseService => _firebaseService;

  // ✅ ADD THIS: Setter for FirebaseService
  void setFirebaseService(FirebaseService service) {
    _firebaseService = service;
    debugPrint('✅ FirebaseService registered to AppState');
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _temperatureThreshold = prefs.getDouble('temp_threshold') ?? 30.0;
      _soilPumpThreshold = prefs.getDouble('soil_threshold') ?? 30.0;
      _humidityThreshold = prefs.getDouble('humidity_threshold') ?? 50.0;
      _lightThreshold = prefs.getDouble('light_threshold') ?? 20000.0;
      _selectedPlant = prefs.getString('selected_plant') ?? 'Pechay';
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _pumpMode = prefs.getString('pump_mode') ?? 'soil';
      notifyListeners();
      debugPrint('✅ App state initialized');
    } catch (e) {
      debugPrint('Failed to load app state: $e');
    }
  }

  Future<void> setTemperatureThreshold(double value) async {
    _temperatureThreshold = value;
    notifyListeners();

    _tempThresholdDebounce?.cancel();
    _tempThresholdDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('temp_threshold', value);
        debugPrint('✅ Temperature threshold saved: $value°C');
      } catch (e) {
        debugPrint('Failed to save temp threshold: $e');
      }
    });
  }

  Future<void> setSoilPumpThreshold(double value) async {
    _soilPumpThreshold = value;
    notifyListeners();

    _soilThresholdDebounce?.cancel();
    _soilThresholdDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('soil_threshold', value);
        debugPrint('✅ Soil threshold saved: $value%');
      } catch (e) {
        debugPrint('Failed to save soil threshold: $e');
      }
    });
  }

  Future<void> setHumidityThreshold(double value) async {
    _humidityThreshold = value;
    notifyListeners();

    _humidityThresholdDebounce?.cancel();
    _humidityThresholdDebounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('humidity_threshold', value);
          debugPrint('✅ Humidity threshold saved: $value%');
        } catch (e) {
          debugPrint('Failed to save humidity threshold: $e');
        }
      },
    );
  }

  Future<void> setLightThreshold(double value) async {
    _lightThreshold = value;
    notifyListeners();

    _lightThresholdDebounce?.cancel();
    _lightThresholdDebounce = Timer(
      const Duration(milliseconds: 500),
      () async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setDouble('light_threshold', value);
          debugPrint('✅ Light threshold saved: $value lux');
        } catch (e) {
          debugPrint('Failed to save light threshold: $e');
        }
      },
    );
  }

  Future<void> setSelectedPlant(String plant) async {
    _selectedPlant = plant;
    notifyListeners();

    _plantDebounce?.cancel();
    _plantDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_plant', plant);
        debugPrint('✅ Selected plant saved: $plant');
      } catch (e) {
        debugPrint('Failed to save selected plant: $e');
      }
    });
  }

  Future<void> setPumpMode(String mode) async {
    _pumpMode = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pump_mode', mode);
      notifyListeners();
      debugPrint('✅ Pump mode saved: $mode');
    } catch (e) {
      debugPrint('Failed to save pump mode: $e');
    }
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode != value) {
      _isDarkMode = value;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('dark_mode', value);
        notifyListeners();
        debugPrint('✅ Dark mode changed to: $value');
      } catch (e) {
        debugPrint('Failed to save dark mode: $e');
      }
    }
  }

  void updateFromFirebase({String? pumpMode}) async {
    bool changed = false;

    if (pumpMode != null && pumpMode != _pumpMode) {
      _pumpMode = pumpMode;
      changed = true;
    }

    if (changed) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (pumpMode != null) {
          await prefs.setString('pump_mode', _pumpMode);
        }
        notifyListeners();
        debugPrint('✅ Settings synced from Firebase');
      } catch (e) {
        debugPrint('Failed to sync from Firebase: $e');
      }
    }
  }

  Map<String, dynamic> exportSettings() {
    return {
      'temperatureThreshold': _temperatureThreshold,
      'soilPumpThreshold': _soilPumpThreshold,
      'humidityThreshold': _humidityThreshold,
      'lightThreshold': _lightThreshold,
      'selectedPlant': _selectedPlant,
      'isDarkMode': _isDarkMode,
      'pumpMode': _pumpMode,
      'version': '2.5',
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      if (settings.containsKey('temperatureThreshold')) {
        _temperatureThreshold = (settings['temperatureThreshold'] as num)
            .toDouble();
      }
      if (settings.containsKey('soilPumpThreshold')) {
        _soilPumpThreshold = (settings['soilPumpThreshold'] as num).toDouble();
      }
      if (settings.containsKey('humidityThreshold')) {
        _humidityThreshold = (settings['humidityThreshold'] as num).toDouble();
      }
      if (settings.containsKey('lightThreshold')) {
        _lightThreshold = (settings['lightThreshold'] as num).toDouble();
      }
      if (settings.containsKey('selectedPlant')) {
        _selectedPlant = settings['selectedPlant'] as String;
      }
      if (settings.containsKey('isDarkMode')) {
        _isDarkMode = settings['isDarkMode'] as bool;
      }
      if (settings.containsKey('pumpMode')) {
        _pumpMode = settings['pumpMode'] as String;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('temp_threshold', _temperatureThreshold);
      await prefs.setDouble('soil_threshold', _soilPumpThreshold);
      await prefs.setDouble('humidity_threshold', _humidityThreshold);
      await prefs.setDouble('light_threshold', _lightThreshold);
      await prefs.setString('selected_plant', _selectedPlant);
      await prefs.setBool('dark_mode', _isDarkMode);
      await prefs.setString('pump_mode', _pumpMode);

      notifyListeners();
      debugPrint('✅ Settings imported successfully');
    } catch (e) {
      debugPrint('Failed to import settings: $e');
      rethrow;
    }
  }

  Future<void> resetToDefaults() async {
    _temperatureThreshold = 30.0;
    _soilPumpThreshold = 30.0;
    _humidityThreshold = 50.0;
    _lightThreshold = 20000.0;
    _selectedPlant = 'Pechay';
    _pumpMode = 'soil';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('temp_threshold', 30.0);
      await prefs.setDouble('soil_threshold', 30.0);
      await prefs.setDouble('humidity_threshold', 50.0);
      await prefs.setDouble('light_threshold', 20000.0);
      await prefs.setString('selected_plant', 'Pechay');
      await prefs.setString('pump_mode', 'soil');
      notifyListeners();
      debugPrint('✅ Settings reset to defaults');
    } catch (e) {
      debugPrint('Failed to reset settings: $e');
    }
  }

  @override
  void dispose() {
    _tempThresholdDebounce?.cancel();
    _soilThresholdDebounce?.cancel();
    _humidityThresholdDebounce?.cancel();
    _lightThresholdDebounce?.cancel();
    _plantDebounce?.cancel();
    super.dispose();
  }
}
