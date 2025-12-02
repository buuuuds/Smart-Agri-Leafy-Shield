// lib/screens/fertilizer_recommendations_page.dart - NPK-BASED RECOMMENDATIONS ONLY
import 'package:flutter/material.dart';
import '../services/app_state_service.dart';
import '../services/firebase_service.dart';
import 'dart:async';

class FertilizerRecommendationsPage extends StatefulWidget {
  const FertilizerRecommendationsPage({super.key});

  @override
  State<FertilizerRecommendationsPage> createState() =>
      _FertilizerRecommendationsPageState();
}

class _FertilizerRecommendationsPageState
    extends State<FertilizerRecommendationsPage> {
  final AppStateService _appState = AppStateService();
  final FirebaseService _firebaseService = FirebaseService();

  int? nitrogen;
  int? phosphorus;
  int? potassium;
  bool isConnected = false;
  bool isLoading = true;

  StreamSubscription<SensorData?>? _sensorSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSensorData();
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeSensorData() async {
    try {
      if (!_firebaseService.isConnected) {
        await _firebaseService.initialize();
      }

      _sensorSubscription = _firebaseService.sensorStream.listen((sensorData) {
        if (mounted && sensorData != null) {
          setState(() {
            nitrogen = sensorData.nitrogen;
            phosphorus = sensorData.phosphorus;
            potassium = sensorData.potassium;
            isConnected = sensorData.isRecent;
            isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error initializing sensor data: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  bool get npkSensorConnected =>
      nitrogen != null && phosphorus != null && potassium != null;

  String _getNutrientStatus(int? value, String nutrient) {
    if (value == null) return 'Unknown';
    switch (nutrient) {
      case 'N':
        if (value < 20) return 'Low';
        if (value < 50) return 'Medium';
        if (value < 100) return 'Optimal';
        return 'High';
      case 'P':
        if (value < 10) return 'Low';
        if (value < 30) return 'Medium';
        if (value < 60) return 'Optimal';
        return 'High';
      case 'K':
        if (value < 50) return 'Low';
        if (value < 150) return 'Medium';
        if (value < 250) return 'Optimal';
        return 'High';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Low':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Optimal':
        return Colors.green;
      case 'High':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<String> _getFertilizerRecommendations() {
    List<String> recommendations = [];

    if (!npkSensorConnected) {
      return ['NPK sensor not connected. Please check wiring.'];
    }

    final nStatus = _getNutrientStatus(nitrogen, 'N');
    final pStatus = _getNutrientStatus(phosphorus, 'P');
    final kStatus = _getNutrientStatus(potassium, 'K');

    if (nStatus == 'Low') {
      recommendations.add(
        '🌱 Apply Nitrogen-Rich Fertilizer:\n'
        '   • Urea (46-0-0)\n'
        '   • Ammonium Sulfate (21-0-0)\n'
        '   • Blood Meal (12-0-0)\n'
        '   Dosage: 50-100g per plant',
      );
    }

    if (pStatus == 'Low') {
      recommendations.add(
        '🌸 Apply Phosphorus Fertilizer:\n'
        '   • Superphosphate (0-20-0)\n'
        '   • Bone Meal (3-15-0)\n'
        '   • Rock Phosphate (0-33-0)\n'
        '   Dosage: 30-80g per plant',
      );
    }

    if (kStatus == 'Low') {
      recommendations.add(
        '💪 Apply Potassium Fertilizer:\n'
        '   • Potassium Chloride (0-0-60)\n'
        '   • Potassium Sulfate (0-0-50)\n'
        '   • Wood Ash (0-1-3)\n'
        '   Dosage: 40-90g per plant',
      );
    }

    if (nStatus == 'Low' && pStatus == 'Low' && kStatus == 'Low') {
      recommendations.clear();
      recommendations.add(
        '⚠️ CRITICAL: All nutrients low!\n'
        '   Apply Complete NPK Fertilizer:\n'
        '   • NPK 14-14-14 (balanced)\n'
        '   • NPK 16-16-16 (general purpose)\n'
        '   Dosage: 100-150g per plant\n'
        '   Frequency: Every 14 days',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        '✅ All nutrients are at optimal levels!\n'
        '   Continue regular maintenance:\n'
        '   • Monitor NPK levels weekly\n'
        '   • Apply balanced fertilizer every 14-21 days\n'
        '   • Water before and after fertilizing',
      );
    }

    return recommendations;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF1F1F1F)
            : const Color(0xFF2E7D32),
        title: const Text(
          'Fertilizer Recommendations',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => isLoading = true);
              _initializeSensorData();
            },
            tooltip: 'Refresh NPK data',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text('Loading NPK sensor data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NPK Status Card
                  Card(
                    color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: npkSensorConnected
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  npkSensorConnected
                                      ? Icons.sensors
                                      : Icons.sensors_off,
                                  color: npkSensorConnected
                                      ? Colors.green
                                      : Colors.red,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NPK Sensor Status',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      npkSensorConnected
                                          ? 'Connected & Reading'
                                          : 'Disconnected',
                                      style: TextStyle(
                                        color: npkSensorConnected
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (npkSensorConnected) ...[
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 16),
                            _buildNutrientStatusRow(
                              'Nitrogen (N)',
                              nitrogen!,
                              'N',
                              Colors.green,
                              isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            _buildNutrientStatusRow(
                              'Phosphorus (P)',
                              phosphorus!,
                              'P',
                              Colors.orange,
                              isDarkMode,
                            ),
                            const SizedBox(height: 12),
                            _buildNutrientStatusRow(
                              'Potassium (K)',
                              potassium!,
                              'K',
                              Colors.blue,
                              isDarkMode,
                            ),
                          ] else ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Check RS485 wiring:\nRX:18, TX:19, DE/RE:23',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red[700],
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

                  const SizedBox(height: 24),

                  // Recommendations Section
                  Text(
                    '💡 Fertilizer Recommendations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ..._getFertilizerRecommendations().map(
                    (recommendation) => Card(
                      color: isDarkMode
                          ? const Color(0xFF2D2D2D)
                          : Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          recommendation,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // General Tips
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.tips_and_updates,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'General Fertilizing Tips',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTipItem(
                            'Water plants before fertilizing',
                            Colors.blue.shade700,
                          ),
                          _buildTipItem(
                            'Apply fertilizer in the morning or evening',
                            Colors.blue.shade700,
                          ),
                          _buildTipItem(
                            'Keep fertilizer away from stems/leaves',
                            Colors.blue.shade700,
                          ),
                          _buildTipItem(
                            'Water again after applying fertilizer',
                            Colors.blue.shade700,
                          ),
                          _buildTipItem(
                            'Monitor plant response after 3-5 days',
                            Colors.blue.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Recommendations are automatically updated based on real-time NPK sensor readings from your soil.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNutrientStatusRow(
    String label,
    int value,
    String nutrient,
    Color color,
    bool isDarkMode,
  ) {
    final status = _getNutrientStatus(value, nutrient);
    final statusColor = _getStatusColor(status);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '$value mg/kg',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
