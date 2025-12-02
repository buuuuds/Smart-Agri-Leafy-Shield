// screens/dashboard_page.dart - WITHOUT ADVANCED ANALYTICS

import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/plant_selector.dart';
import '../widgets/mode_selector.dart';
import '../widgets/pump_mode_selector.dart';
import '../widgets/manual_controls.dart';
import '../widgets/sensor_overview.dart';
import '../widgets/npk_display.dart';
import '../widgets/pump_stats_card.dart';
import '../widgets/water_level_card.dart';
import '../services/plant_service.dart' hide SensorStatus;
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/fertilizer_service.dart';
import '../models/plant_model.dart';
import '../services/app_state_service.dart';
import 'fertilizer_recommendations_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AppStateService _appState = AppStateService();
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  final FertilizerService _fertilizerService = FertilizerService();

  String get selectedPlant => _appState.selectedPlant;
  bool isPumpRunning = false;
  String currentPumpMode = 'none';

  bool _isAutoMode = true;
  bool get isAutoMode => _isAutoMode;

  double? temperature;
  int? soilMoisture;
  int? lightIntensity;
  int? humidity;
  int? nitrogen;
  int? phosphorus;
  int? potassium;
  int irrigationRuntime = 0;
  int irrigationCycles = 0;
  int? waterPercent;
  double? waterLevel;
  double? waterDistance;

  int? lastSoilMoisture;
  int? lastLightIntensity;
  int? lastHumidity;
  int? lastNitrogen;
  int? lastPhosphorus;
  int? lastPotassium;
  int mistingRuntime = 0;
  int mistingCycles = 0;
  int? lastWaterPercent;
  double? lastWaterLevel;
  double? lastWaterDistance;
  double? lastTemperature;
  String? lastReadingTime;

  SensorStatus? sensorStatus;
  DeviceStatus? deviceStatus;

  bool isConnected = false;
  bool isLoading = true;
  String connectionStatus = 'Connecting...';
  String lastUpdateTime = '';
  String lastUpdateDate = '';
  bool wifiConnected = false;

  int totalPumpRuntime = 0;
  int pumpCycleCount = 0;

  List<double> temperatureHistory = [];
  StreamSubscription<SensorData?>? _sensorSubscription;
  StreamSubscription<DeviceStatus?>? _statusSubscription;
  Timer? _notificationCheckTimer;

  bool _isInitialized = false;

  bool get isFullyConnected =>
      isConnected &&
      _firebaseService.isConnected &&
      wifiConnected &&
      (deviceStatus?.online ?? false);

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onAppStateChanged);
    _fertilizerService.initialize();
    _initializeServices();
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _sensorSubscription?.cancel();
    _statusSubscription?.cancel();
    _notificationCheckTimer?.cancel();
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeServices() async {
    if (_isInitialized) return;

    setState(() {
      isLoading = true;
      connectionStatus = 'Initializing...';
    });

    try {
      await _notificationService.initialize();

      if (!_firebaseService.isConnected) {
        await _firebaseService.initialize();
      }

      _sensorSubscription = _firebaseService.sensorStream.listen(
        (sensorData) {
          if (mounted) _handleSensorData(sensorData);
        },
        onError: (error) {
          debugPrint('Sensor stream error: $error');
          if (mounted) {
            setState(() {
              isConnected = false;
              connectionStatus = 'Sensor stream error';
            });
          }
        },
      );

      _statusSubscription = _firebaseService.statusStream.listen(
        (deviceStatus) {
          if (mounted) _handleDeviceStatus(deviceStatus);
        },
        onError: (error) {
          debugPrint('Status stream error: $error');
        },
      );

      _startNotificationMonitoring();
      _isInitialized = true;

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          isConnected = false;
          isLoading = false;
          connectionStatus = 'Connection failed';
          wifiConnected = false;
        });
      }
    }
  }

  void _startNotificationMonitoring() {
    _notificationCheckTimer?.cancel();
    _notificationCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _checkForAlerts();
    });
  }

  void _checkForAlerts() {
    // ✅ DON'T check alerts if ESP32 is disconnected
    if (!isConnected || !(deviceStatus?.online ?? false)) {
      debugPrint('⚠️ Skipping alert checks - ESP32 disconnected');
      return;
    }

    final currentPlant = PlantService.getPlantByName(selectedPlant);

    _notificationService.checkSensorAlerts(
      temperature: temperature,
      soilMoisture: soilMoisture,
      lightIntensity: lightIntensity,
      humidity: humidity,
      nitrogen: nitrogen,
      phosphorus: phosphorus,
      potassium: potassium,
      waterPercent: waterPercent,
      waterLevel: waterLevel,
      currentPlant: currentPlant,
      sensorStatus: sensorStatus,
      isConnected: isConnected,
      wifiConnected: wifiConnected,
      espOnline: deviceStatus?.online ?? false,
      isPumpRunning: isPumpRunning,
      currentPumpMode: currentPumpMode,
      pumpCycleCount: irrigationCycles + mistingCycles,
      totalPumpRuntime: irrigationRuntime + mistingRuntime,
      irrigationRuntime: irrigationRuntime,
      irrigationCycles: irrigationCycles,
      mistingRuntime: mistingRuntime,
      mistingCycles: mistingCycles,
      shadeDeployed: deviceStatus?.shadeDeployed ?? false,
      waterLevelLowThreshold: 20,
    );
  }

  void _handleSensorData(SensorData? sensorData) {
    if (sensorData == null) {
      setState(() {
        isConnected = false;
        connectionStatus = 'No data from ESP32';
      });
      return;
    }

    if (sensorData.temperature != null) {
      lastTemperature = sensorData.temperature;
    }
    if (sensorData.soilMoisture != null) {
      lastSoilMoisture = sensorData.soilMoisture;
    }
    if (sensorData.lightIntensity != null) {
      lastLightIntensity = sensorData.lightIntensity;
    }
    if (sensorData.humidity != null) lastHumidity = sensorData.humidity;
    if (sensorData.nitrogen != null) lastNitrogen = sensorData.nitrogen;
    if (sensorData.phosphorus != null) lastPhosphorus = sensorData.phosphorus;
    if (sensorData.potassium != null) lastPotassium = sensorData.potassium;
    lastReadingTime = sensorData.formattedTimestamp;

    if (sensorData.waterPercent != null) {
      lastWaterPercent = sensorData.waterPercent;
    }
    if (sensorData.waterLevel != null) {
      lastWaterLevel = sensorData.waterLevel;
    }
    if (sensorData.waterDistance != null) {
      lastWaterDistance = sensorData.waterDistance;
    }

    lastReadingTime = sensorData.formattedTimestamp;
    setState(() {
      temperature = sensorData.temperature;
      soilMoisture = sensorData.soilMoisture;
      lightIntensity = sensorData.lightIntensity;
      humidity = sensorData.humidity;
      nitrogen = sensorData.nitrogen;
      phosphorus = sensorData.phosphorus;
      potassium = sensorData.potassium;
      waterPercent = sensorData.waterPercent;
      waterLevel = sensorData.waterLevel;
      waterDistance = sensorData.waterDistance;
      sensorStatus = sensorData.sensorStatus;

      if (sensorData.systemInfo != null) {
        isPumpRunning = sensorData.systemInfo!.pumpRunning;
        currentPumpMode = sensorData.systemInfo!.currentPumpMode;
        irrigationRuntime = sensorData.systemInfo!.irrigationRuntimeSec;
        irrigationCycles = sensorData.systemInfo!.irrigationCycles;
        mistingRuntime = sensorData.systemInfo!.mistingRuntimeSec;
        mistingCycles = sensorData.systemInfo!.mistingCycles;
      }

      isConnected = sensorData.isRecent && _firebaseService.isConnected;
      lastUpdateTime = sensorData.formattedTimestamp;
      lastUpdateDate = sensorData.formattedDate;
      connectionStatus = _getConnectionStatus();

      if (temperature != null && temperature! > 0) {
        temperatureHistory.add(temperature!);
        if (temperatureHistory.length > 100) {
          temperatureHistory.removeRange(0, temperatureHistory.length - 100);
        }
      }
    });

    _checkForAlerts();
  }

  void _handleDeviceStatus(DeviceStatus? status) {
    if (status == null) return;

    setState(() {
      deviceStatus = status;
      wifiConnected = status.wifiConnected;
      isPumpRunning = status.pumpRunning;

      _appState.updateFromFirebase(
        pumpMode: status.pumpMode,
      );

      connectionStatus = _getConnectionStatus();
    });
  }

  String _getConnectionStatus() {
    if (deviceStatus != null) {
      if (!deviceStatus!.online) return 'ESP32 offline';
      if (!deviceStatus!.wifiConnected) return 'ESP32 WiFi disconnected';
    }

    if (sensorStatus != null) {
      final count = sensorStatus!.connectedCount;
      if (count == 4) return 'All sensors connected';
      if (count > 0) return '$count/4 sensors connected';
      return 'No sensors detected';
    }

    return isConnected ? 'Connected - Live data' : 'Waiting for data...';
  }

  Future<void> _sendShadeCommand(String command) async {
    if (!isFullyConnected) {
      _showErrorDialog('Cannot send shade command: Device offline');
      return;
    }

    try {
      setState(() => connectionStatus = 'Sending command...');
      final success = await _firebaseService.sendShadeCommand(command);

      if (success) {
        if (mounted) {
          setState(() => connectionStatus = 'Command sent');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shade command sent: $command'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => connectionStatus = _getConnectionStatus());
          }
        });
      } else {
        throw Exception('Command failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => connectionStatus = 'Command failed');
        _showErrorDialog('Failed to send shade command: $e');
      }
    }
  }

  Future<void> _sendPumpCommand(String command) async {
    if (!isFullyConnected) {
      _showErrorDialog('Cannot send pump command: Device offline');
      return;
    }

    try {
      setState(() => connectionStatus = 'Sending command...');
      final success = await _firebaseService.sendPumpCommand(command);

      if (success) {
        if (mounted) {
          setState(() => connectionStatus = 'Command sent');

          String displayText = '';
          if (command == 'irrigation_start') {
            displayText = '💧 Irrigation started (30s)';
          } else if (command == 'irrigation_stop') {
            displayText = '🛑 Irrigation stopped';
          } else if (command == 'misting_start') {
            displayText = '💨 Misting started (15s)';
          } else if (command == 'misting_stop') {
            displayText = '🛑 Misting stopped';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayText),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => connectionStatus = _getConnectionStatus());
          }
        });
      } else {
        throw Exception('Command failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => connectionStatus = 'Command failed');
        _showErrorDialog('Failed to send pump command: $e');
      }
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

  void _updatePlant(String plant) {
    _appState.setSelectedPlant(plant);
    _checkForAlerts();
    _sendPlantSettingsToESP32(plant);
    if (mounted) setState(() {});
  }

  Future<void> _sendPlantSettingsToESP32(String plantName) async {
    final plant = PlantService.getPlantByName(plantName);
    if (plant == null) return;

    if (!isFullyConnected) {
      debugPrint('⚠️ Cannot send plant settings: Device offline');
      return;
    }

    try {
      final success = await _firebaseService.setPlantSettings(
        plantName: plant.name,
        maxTemperature: plant.maxTemperature,
        maxLightIntensity: plant.maxLightIntensity,
      );

      if (success) {
        debugPrint('✅ Plant settings sent to ESP32:');
        debugPrint('   Plant: ${plant.name}');
        debugPrint('   Max Temp: ${plant.maxTemperature}°C');
        debugPrint('   Max Light: ${plant.maxLightIntensity} lux');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Plant settings sent: ${plant.name}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to send plant settings');
      }
    } catch (e) {
      debugPrint('❌ Failed to send plant settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update ESP32: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _updatePumpMode(String mode) async {
    if (!isFullyConnected) {
      _showErrorDialog('Cannot change pump mode: Device offline');
      return;
    }

    try {
      final success = await _firebaseService.setPumpMode(mode);
      if (success) {
        await _appState.setPumpMode(mode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pump mode: ${mode.toUpperCase()}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _showErrorDialog('Failed to change pump mode');
      }
    } catch (e) {
      _showErrorDialog('Failed to change pump mode: $e');
    }
  }

  void _updateMode(bool autoMode) async {
    if (!isFullyConnected) {
      _showErrorDialog('Cannot change mode: Device offline');
      return;
    }

    try {
      final mode = autoMode ? 'auto' : 'manual';
      final success = await _firebaseService.setMode(mode);

      if (success) {
        setState(() => _isAutoMode = autoMode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Mode: ${mode.toUpperCase()}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        _showErrorDialog('Failed to change mode');
      }
    } catch (e) {
      _showErrorDialog('Failed to change mode: $e');
    }
  }

  Plant? get currentPlant => PlantService.getPlantByName(selectedPlant);

  Color _getConnectionStatusColor() {
    if (!_firebaseService.isConnected) return Colors.red;
    if (deviceStatus != null) {
      if (!deviceStatus!.online) return Colors.red;
      if (!deviceStatus!.wifiConnected) return Colors.red;
    }
    if (!isConnected) return Colors.orange;
    if (sensorStatus == null) return Colors.green;

    final count = sensorStatus!.connectedCount;
    if (count == 4) return Colors.green;
    if (count >= 2) return Colors.orange;
    return Colors.red;
  }

  void _navigateToFertilizerRecommendations() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const FertilizerRecommendationsPage(),
          ),
        )
        .then((_) => setState(() {}));
  }

  Widget _buildFertilizerCard(bool isDarkMode) {
    final displayNitrogen = isConnected ? nitrogen : lastNitrogen;
    final displayPhosphorus = isConnected ? phosphorus : lastPhosphorus;
    final displayPotassium = isConnected ? potassium : lastPotassium;

    final npkConnected =
        displayNitrogen != null &&
        displayPhosphorus != null &&
        displayPotassium != null;

    bool needsNitrogen = false;
    bool needsPhosphorus = false;
    bool needsPotassium = false;

    if (npkConnected) {
      needsNitrogen = displayNitrogen < 20;
      needsPhosphorus = displayPhosphorus < 10;
      needsPotassium = displayPotassium < 50;
    }

    final needsFertilizer =
        npkConnected && (needsNitrogen || needsPhosphorus || needsPotassium);

    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: InkWell(
        onTap: _navigateToFertilizerRecommendations,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: needsFertilizer
                  ? Colors.orange.withOpacity(0.5)
                  : Colors.green.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: needsFertilizer
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.science,
                      color: needsFertilizer ? Colors.orange : Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Soil Nutrients (NPK)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              needsFertilizer
                                  ? Icons.warning
                                  : Icons.check_circle,
                              size: 16,
                              color: needsFertilizer
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              needsFertilizer
                                  ? 'Fertilizer Needed'
                                  : npkConnected
                                  ? 'Nutrients Optimal'
                                  : 'Sensor Offline',
                              style: TextStyle(
                                fontSize: 13,
                                color: needsFertilizer
                                    ? Colors.orange
                                    : npkConnected
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDarkMode ? Colors.white : Colors.grey,
                  ),
                ],
              ),
              if (npkConnected) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNPKMiniCard('N', displayNitrogen, needsNitrogen),
                    _buildNPKMiniCard('P', displayPhosphorus, needsPhosphorus),
                    _buildNPKMiniCard('K', displayPotassium, needsPotassium),
                  ],
                ),
                if (needsFertilizer) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap to view detailed fertilizer recommendations',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sensors_off,
                        color: Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NPK sensor offline. Check RS485 wiring (RX:18, TX:19, DE/RE:23)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNPKMiniCard(String label, int value, bool isLow) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isLow ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isLow ? Colors.red : Colors.green).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isLow ? Colors.red : Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isLow ? 'Low' : 'OK',
          style: TextStyle(
            fontSize: 10,
            color: isLow ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final displayTemperature = isConnected ? temperature : lastTemperature;
    final displaySoilMoisture = isConnected ? soilMoisture : lastSoilMoisture;
    final displayLightIntensity = isConnected
        ? lightIntensity
        : lastLightIntensity;
    final displayHumidity = isConnected ? humidity : lastHumidity;
    final displayNitrogen = isConnected ? nitrogen : lastNitrogen;
    final displayPhosphorus = isConnected ? phosphorus : lastPhosphorus;
    final displayPotassium = isConnected ? potassium : lastPotassium;
    final displayWaterPercent = isConnected ? waterPercent : lastWaterPercent;
    final displayWaterLevel = isConnected ? waterLevel : lastWaterLevel;
    final displayWaterDistance = isConnected
        ? waterDistance
        : lastWaterDistance;

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
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 75,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getConnectionStatusColor(),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          connectionStatus,
                          style: TextStyle(
                            color: _getConnectionStatusColor(),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (lastUpdateTime.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, top: 2),
                      child: Text(
                        isConnected
                            ? 'Last update: $lastUpdateTime'
                            : 'Last reading: ${lastReadingTime ?? lastUpdateTime}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              if (!_firebaseService.isConnected && !isLoading)
                IconButton(
                  onPressed: () {
                    _isInitialized = false;
                    _initializeServices();
                  },
                  icon: Icon(
                    Icons.refresh,
                    color: isDarkMode ? Colors.white : const Color(0xFF2E7D32),
                  ),
                  tooltip: 'Retry connection',
                ),
            ],
            automaticallyImplyLeading: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!isConnected && lastReadingTime != null)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Showing Last Reading',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Device offline. Auto-reconnecting... Last data: $lastReadingTime',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isConnected && lastReadingTime != null)
                  const SizedBox(height: 16),

                if (isLoading)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 16),
                          Text(connectionStatus),
                        ],
                      ),
                    ),
                  ),

                if (isLoading) const SizedBox(height: 16),

                PlantSelector(
                  selectedPlant: selectedPlant,
                  onPlantChanged: _updatePlant,
                ),
                const SizedBox(height: 24),

                ModeSelector(
                  isAutoMode: isAutoMode,
                  onModeChanged: _updateMode,
                ),
                const SizedBox(height: 24),

                if (isAutoMode)
                  PumpModeSelector(
                    selectedMode: _appState.pumpMode,
                    onModeChanged: _updatePumpMode,
                  ),
                if (isAutoMode) const SizedBox(height: 24),

                if (!isAutoMode)
                  ManualControls(
                    onShadeCommand: _sendShadeCommand,
                    onPumpCommand: _sendPumpCommand,
                    isConnected: isConnected && (deviceStatus?.online ?? false), // ✅ Pass connection status
                  ),

                const SizedBox(height: 24),

                WaterLevelCard(
                  waterPercent: displayWaterPercent,
                  waterLevel: displayWaterLevel,
                  waterDistance: displayWaterDistance,
                  isConnected: isFullyConnected,
                  tankHeight: 45,
                  lowThreshold: 20,
                ),

                const SizedBox(height: 24),

                PumpStatsCard(
                  isPumpRunning: isPumpRunning,
                  currentPumpMode: currentPumpMode,
                  irrigationRuntime: irrigationRuntime,
                  irrigationCycles: irrigationCycles,
                  mistingRuntime: mistingRuntime,
                  mistingCycles: mistingCycles,
                  pumpMode: _appState.pumpMode,
                  isConnected: isFullyConnected,
                ),

                const SizedBox(height: 24),

                _buildFertilizerCard(isDarkMode),

                const SizedBox(height: 24),

                SensorOverview(
                  temperature: displayTemperature,
                  soilMoisture: displaySoilMoisture,
                  lightIntensity: displayLightIntensity,
                  humidity: displayHumidity,
                  currentPlant: currentPlant,
                  isConnected: isFullyConnected,
                  sensorStatus: sensorStatus,
                ),
                const SizedBox(height: 24),

                NPKDisplay(
                  nitrogen: displayNitrogen,
                  phosphorus: displayPhosphorus,
                  potassium: displayPotassium,
                  isConnected: isFullyConnected,
                ),

                const SizedBox(height: 24),

                const SizedBox(height: 24),

                if (deviceStatus != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'System Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Device ID', 'ESP32_ALS_001'),
                          _buildInfoRow(
                            'Mode',
                            deviceStatus!.currentMode.toUpperCase(),
                          ),
                          _buildInfoRow(
                            'Pump Mode',
                            _appState.pumpMode == 'soil'
                                ? 'Soil-based'
                                : 'Humidity-based',
                          ),
                          if (isPumpRunning)
                            _buildInfoRow(
                              'Currently Running',
                              currentPumpMode == 'irrigation'
                                  ? '💧 Irrigation (30s)'
                                  : '💨 Misting (15s)',
                            ),
                          _buildInfoRow(
                            'Irrigation Stats',
                            '$irrigationCycles cycles, ${irrigationRuntime}s total',
                          ),
                          _buildInfoRow(
                            'Misting Stats',
                            '$mistingCycles cycles, ${mistingRuntime}s total',
                          ),
                          _buildInfoRow(
                            'WiFi Status',
                            deviceStatus!.wifiConnected
                                ? 'Connected'
                                : 'Reconnecting...',
                          ),
                          if (deviceStatus!.wifiConnected)
                            _buildInfoRow(
                              'WiFi Signal',
                              '${deviceStatus!.wifiRssi} dBm',
                            ),
                          _buildInfoRow(
                            'Last Seen',
                            deviceStatus!.formattedTimestamp,
                          ),
                          if (lastUpdateDate.isNotEmpty)
                            _buildInfoRow('Date', lastUpdateDate),
                          if (displayWaterPercent != null)
                            _buildInfoRow(
                              'Water Level',
                              '$displayWaterPercent% (${displayWaterLevel?.toStringAsFixed(1) ?? "N/A"} cm)',
                            ),
                          if (sensorStatus != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Connected Sensors',
                              '${sensorStatus!.connectedCount}/4',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
