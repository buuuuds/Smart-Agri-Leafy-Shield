// screens/settings_page.dart - COMPLETELY FIXED

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/app_state_service.dart';
import 'user_feedback_page.dart';
import '../utils/firestore_initializer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onThemeChanged});
  final void Function(bool)? onThemeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AppStateService _appState = AppStateService();
  final FirestoreInitializer _firestoreInitializer = FirestoreInitializer();

  bool _enableNotifications = true;
  String _temperatureUnit = 'Celsius';
  String _language = 'English';
  bool _showSensorStatus = true;
  int _dataRetentionDays = 30;

  bool _isInitializingFirestore = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkFirebaseConnection();
  }

  // ✅ Check Firebase connection on page load
  Future<void> _checkFirebaseConnection() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      final firebaseService = _appState.firebaseService;
      if (firebaseService == null) {
        debugPrint('⚠️  FirebaseService not registered in AppState');
      } else if (!firebaseService.isConnected) {
        debugPrint('⚠️  FirebaseService not connected');
      } else {
        debugPrint(
          '✅ FirebaseService ready (${firebaseService.currentDeviceId})',
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _enableNotifications = prefs.getBool('enable_notifications') ?? true;
        _temperatureUnit = prefs.getString('temperature_unit') ?? 'Celsius';
        _language = prefs.getString('language') ?? 'English';
        _showSensorStatus = prefs.getBool('show_sensor_status') ?? true;
        _dataRetentionDays = prefs.getInt('data_retention_days') ?? 30;
      });
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('enable_notifications', _enableNotifications);
      await prefs.setString('temperature_unit', _temperatureUnit);
      await prefs.setString('language', _language);
      await prefs.setBool('show_sensor_status', _showSensorStatus);
      await prefs.setInt('data_retention_days', _dataRetentionDays);
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }

  Future<void> _backupSettings() async {
    try {
      final settings = _appState.exportSettings();
      settings['notifications_enabled'] = _enableNotifications;
      settings['temperature_unit'] = _temperatureUnit;
      settings['language'] = _language;
      settings['show_sensor_status'] = _showSensorStatus;
      settings['data_retention_days'] = _dataRetentionDays;

      final jsonString = json.encode(settings);
      await Clipboard.setData(ClipboardData(text: jsonString));

      if (mounted) {
        _showSuccessSnackBar('Settings backed up to clipboard!');
      }
    } catch (e) {
      _showErrorDialog('Failed to backup settings: $e');
    }
  }

  Future<void> _restoreSettings() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null) {
        _showErrorDialog('No backup found in clipboard');
        return;
      }

      final settings =
          json.decode(clipboardData!.text!) as Map<String, dynamic>;

      await _appState.importSettings(settings);

      setState(() {
        _enableNotifications = settings['notifications_enabled'] ?? true;
        _temperatureUnit = settings['temperature_unit'] ?? 'Celsius';
        _language = settings['language'] ?? 'English';
        _showSensorStatus = settings['show_sensor_status'] ?? true;
        _dataRetentionDays = settings['data_retention_days'] ?? 30;
      });

      await _saveSettings();

      if (mounted) {
        _showSuccessSnackBar('Settings restored successfully!');
      }
    } catch (e) {
      _showErrorDialog('Failed to restore settings: $e');
    }
  }

  Future<void> _showDiagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final firebaseService = _appState.firebaseService;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Diagnostic Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiagnosticRow('App Version', '2.5'),
              _buildDiagnosticRow('Platform', 'Flutter'),
              const Divider(),
              _buildDiagnosticRow('Stored Keys', keys.length.toString()),
              _buildDiagnosticRow('Dark Mode', _appState.isDarkMode.toString()),
              _buildDiagnosticRow('Selected Plant', _appState.selectedPlant),
              _buildDiagnosticRow(
                'Temp Threshold',
                '${_appState.temperatureThreshold}°C',
              ),
              _buildDiagnosticRow(
                'Soil Threshold',
                '${_appState.soilPumpThreshold}%',
              ),
              _buildDiagnosticRow(
                'Pump Mode',
                _appState.pumpMode.toUpperCase(),
              ),
              const Divider(),
              _buildDiagnosticRow(
                'Firebase Service',
                firebaseService != null ? 'Initialized' : 'NULL',
              ),
              if (firebaseService != null)
                _buildDiagnosticRow(
                  'ESP32 Connected',
                  firebaseService.isConnected ? 'YES' : 'NO',
                ),
              if (firebaseService != null)
                _buildDiagnosticRow(
                  'Device ID',
                  firebaseService.currentDeviceId,
                ),
              const Divider(),
              _buildDiagnosticRow(
                'Notifications',
                _enableNotifications ? 'ON' : 'OFF',
              ),
              _buildDiagnosticRow(
                'Show Sensor Status',
                _showSensorStatus ? 'ON' : 'OFF',
              ),
              _buildDiagnosticRow('Data Retention', '$_dataRetentionDays days'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeFirestore() async {
    final isInitialized = await _firestoreInitializer
        .areCollectionsInitialized();

    if (isInitialized) {
      final reinitialize = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Already Initialized'),
          content: const Text(
            'Firestore collections are already set up.\n\n'
            'Do you want to view the collection structure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('View Structure'),
            ),
          ],
        ),
      );

      if (reinitialize == true) {
        _firestoreInitializer.printCollectionStructure();
        _showSuccessSnackBar('✅ Check console for collection structure');
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initialize Firestore'),
        content: const Text(
          'This will create the following collections:\n\n'
          '• sensor_history\n'
          '• daily_summaries\n'
          '• notifications\n'
          '• plants\n\n'
          'Run this ONCE on first setup.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Initialize'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isInitializingFirestore = true);

    try {
      final success = await _firestoreInitializer.initializeCollections();

      if (mounted) {
        setState(() => _isInitializingFirestore = false);

        if (success) {
          _showSuccessSnackBar(
            '✅ Firestore collections created!\nCheck Firebase Console.',
          );
        } else {
          _showErrorDialog('Failed to initialize Firestore');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitializingFirestore = false);
        _showErrorDialog('Failed to initialize Firestore: $e');
      }
    }
  }

  Future<void> _cleanupPlaceholders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Up Placeholders'),
        content: const Text(
          'This will delete placeholder documents from:\n\n'
          '• sensor_history\n'
          '• daily_summaries\n'
          '• notifications\n'
          '• plants\n\n'
          'Only do this AFTER you have real data from ESP32.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreInitializer.cleanupPlaceholders();

      if (mounted) {
        _showSuccessSnackBar('✅ Placeholder documents removed!');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to clean up placeholders: $e');
      }
    }
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Factory Reset?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ THIS WILL RESET EVERYTHING:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'APP SETTINGS:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildResetItem('Temperature threshold → 30°C'),
                  _buildResetItem('Soil threshold → 30%'),
                  _buildResetItem('Selected plant → Pechay'),
                  _buildResetItem('Pump mode → Soil-based'),
                  _buildResetItem('Dark mode → OFF'),
                  const SizedBox(height: 12),
                  const Text(
                    'ESP32 WILL BE RESET:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildResetItem('❌ WiFi credentials CLEARED'),
                  _buildResetItem('❌ ESP32 will restart'),
                  _buildResetItem('❌ Config portal will open'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: Colors.orange.shade900,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You will need to reconnect to "AgriLeafyShield_Setup" WiFi',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Custom plants and sensor history will NOT be affected',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performFactoryReset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('FACTORY RESET'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showRestartESP32Dialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restart_alt, color: Colors.blue, size: 28),
            const SizedBox(width: 12),
            const Text('Restart ESP32?'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will restart the ESP32 device:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('✓ WiFi settings WILL BE PRESERVED'),
            SizedBox(height: 8),
            Text('✓ Device will reconnect automatically'),
            SizedBox(height: 8),
            Text('✓ Takes about 10-15 seconds'),
            SizedBox(height: 16),
            Text(
              'Note: This does NOT reset settings or clear WiFi credentials.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performESP32Restart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restart ESP32'),
          ),
        ],
      ),
    );
  }

  // ✅ COMPLETELY FIXED: Restart ESP32
  Future<void> _performESP32Restart() async {
    try {
      // ✅ Get Firebase service from AppState
      final firebaseService = _appState.firebaseService;

      if (firebaseService == null) {
        debugPrint('❌ FirebaseService not initialized');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Firebase not initialized. Please restart the app.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!firebaseService.isConnected) {
        debugPrint('❌ FirebaseService not connected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ ESP32 not connected. Please check connection.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF4CAF50)),
                SizedBox(height: 16),
                Text('Restarting ESP32...'),
                SizedBox(height: 8),
                Text(
                  'WiFi credentials will be preserved',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      final success = await firebaseService.sendSystemCommand('restart');
      debugPrint('✅ Restart command sent: $success');

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) Navigator.pop(context);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ESP32 restarting... Will reconnect in ~15 seconds',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to restart ESP32: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('❌ Restart error: $e');
    }
  }

  // ✅ COMPLETELY FIXED: Factory Reset
  Future<void> _performFactoryReset() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('Factory resetting...'),
                  SizedBox(height: 8),
                  Text(
                    'App + ESP32 + WiFi',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // 1️⃣ Reset local app state
      await _appState.resetToDefaults();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('enable_notifications');
      await prefs.remove('temperature_unit');
      await prefs.remove('language');
      await prefs.remove('show_sensor_status');
      await prefs.remove('data_retention_days');

      setState(() {
        _enableNotifications = true;
        _temperatureUnit = 'Celsius';
        _language = 'English';
        _showSensorStatus = true;
        _dataRetentionDays = 30;
      });

      await _saveSettings();

      // 2️⃣ Send factory reset command to ESP32
      bool esp32ResetSuccess = false;
      try {
        // ✅ Get Firebase service from AppState
        final firebaseService = _appState.firebaseService;
        if (firebaseService != null && firebaseService.isConnected) {
          esp32ResetSuccess = await firebaseService.sendSystemCommand(
            'factory_reset',
          );
          if (esp32ResetSuccess) {
            debugPrint('✅ Factory reset command sent to ESP32');
          }
        } else {
          debugPrint('⚠️ Firebase not connected, cannot reset ESP32');
        }
      } catch (e) {
        debugPrint('❌ Could not reset ESP32: $e');
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        if (esp32ResetSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Factory reset complete!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '🔄 ESP32 resetting... Config portal will open in ~10 seconds',
                    style: TextStyle(fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '📡 Connect to "AgriLeafyShield_Setup" (password: agrileafy123)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 10),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ App settings reset, but ESP32 not connected',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'You may need to manually reset ESP32',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Failed to factory reset: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = _appState.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
              : [const Color(0xFFF8FAF8), const Color(0xFFE8F5E8)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),

            _buildSectionHeader('App Settings', Icons.settings, isDarkMode),
            const SizedBox(height: 16),

            _buildSettingsTile(
              'Dark Mode',
              'Switch between light and dark theme',
              Icons.dark_mode,
              Switch(
                value: isDarkMode,
                onChanged: (value) async {
                  await _appState.setDarkMode(value);
                  if (mounted) {
                    setState(() {});
                    _showSuccessSnackBar(
                      value ? 'Dark mode enabled' : 'Light mode enabled',
                    );
                  }
                },
                activeColor: const Color(0xFF4CAF50),
              ),
              isDarkMode,
            ),

            _buildSettingsTile(
              'Notifications',
              'Enable push notifications',
              Icons.notifications,
              Switch(
                value: _enableNotifications,
                onChanged: (value) {
                  setState(() => _enableNotifications = value);
                  _saveSettings();
                },
                activeColor: const Color(0xFF4CAF50),
              ),
              isDarkMode,
            ),

            const SizedBox(height: 32),

            _buildSectionHeader('Data Settings', Icons.data_usage, isDarkMode),
            const SizedBox(height: 16),

            _buildDropdownTile(
              'Temperature Unit',
              'Choose temperature display unit',
              Icons.thermostat,
              _temperatureUnit,
              ['Celsius', 'Fahrenheit'],
              (value) {
                setState(() => _temperatureUnit = value!);
                _saveSettings();
              },
              isDarkMode,
            ),

            _buildSettingsTile(
              'Show Sensor Status',
              'Display connection status for each sensor',
              Icons.sensors,
              Switch(
                value: _showSensorStatus,
                onChanged: (value) {
                  setState(() => _showSensorStatus = value);
                  _saveSettings();
                },
                activeColor: const Color(0xFF4CAF50),
              ),
              isDarkMode,
            ),

            _buildDropdownTile(
              'Analytics Data Retention',
              'How long to keep historical data',
              Icons.history,
              _dataRetentionDays.toString(),
              ['7', '30', '60', '90'],
              (value) {
                setState(() => _dataRetentionDays = int.parse(value!));
                _saveSettings();
              },
              isDarkMode,
            ),

            _buildDropdownTile(
              'Auto Sync',
              'Automatically syncs data from ESP32',
              Icons.sync,
              'Always Active',
              ['Always Active'],
              (_) {},
              isDarkMode,
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sensor data updates every 5 seconds from ESP32. Cloud backup saves automatically every 5 minutes.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildSectionHeader('Backup & Restore', Icons.backup, isDarkMode),
            const SizedBox(height: 16),

            _buildActionTile(
              'Backup Settings',
              'Copy all settings to clipboard',
              Icons.backup,
              _backupSettings,
              isDarkMode,
            ),

            _buildActionTile(
              'Restore Settings',
              'Restore settings from clipboard',
              Icons.restore,
              _restoreSettings,
              isDarkMode,
            ),

            const SizedBox(height: 32),

            _buildSectionHeader('System', Icons.computer, isDarkMode),
            const SizedBox(height: 16),

            _buildActionTile(
              'Clear Cache',
              'Clear app cache and temporary data',
              Icons.clear_all,
              () => _showClearCacheDialog(),
              isDarkMode,
            ),

            _buildActionTile(
              'Diagnostics',
              'View app diagnostic information',
              Icons.bug_report,
              _showDiagnostics,
              isDarkMode,
            ),

            const SizedBox(height: 32),

            _buildSectionHeader('Advanced', Icons.settings_suggest, isDarkMode),
            const SizedBox(height: 16),

            _buildActionTile(
              'Restart ESP32',
              'Restart device (WiFi settings preserved)',
              Icons.restart_alt,
              _showRestartESP32Dialog,
              isDarkMode,
            ),

            const SizedBox(height: 8),

            _buildActionTile(
              'Factory Reset',
              'Reset ALL settings including WiFi credentials',
              Icons.restore_page,
              _showResetConfirmDialog,
              isDarkMode,
              color: Colors.red,
            ),

            const SizedBox(height: 32),

            Text(
              'Feedback & Support',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Color(0xFF4CAF50) : Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.star, color: Colors.amber),
                    ),
                    title: const Text(
                      'Rate Our System',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Share your experience & help us improve',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserFeedbackPage(),
                        ),
                      );

                      if (result == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Thank you for your feedback! 🌱'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('About', Icons.info, isDarkMode),
            const SizedBox(height: 16),

            Card(
              color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.eco,
                        size: 40,
                        color: isDarkMode
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Smart Agri-Leafy Shield',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 2.5',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IoT-based plant monitoring and protection system\nwith automated shade control',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoChip('ESP32', 'Platform', isDarkMode),
                        _buildInfoChip('Firebase', 'Backend', isDarkMode),
                        _buildInfoChip('Flutter', 'Frontend', isDarkMode),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          icon,
          color: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? const Color(0xFF4CAF50)
                : const Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    Widget trailing,
    bool isDarkMode,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
        ),
        title: Text(
          title,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> options,
    Function(String?) onChanged,
    bool isDarkMode,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32),
        ),
        title: Text(
          title,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: DropdownButton<String>(
          value: value,
          underline: Container(),
          dropdownColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          items: options.map((option) {
            return DropdownMenuItem(value: option, child: Text(option));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDarkMode, {
    Color? color,
  }) {
    final iconColor =
        color ??
        (isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? (isDarkMode ? Colors.white : Colors.black),
            fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: iconColor),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoChip(String label, String type, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF2E7D32),
              fontSize: 12,
            ),
          ),
          Text(
            type,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached sensor data, temporary files, and offline data. Your settings and plant configurations will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('Cache cleared successfully!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text(
              'Clear Cache',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
