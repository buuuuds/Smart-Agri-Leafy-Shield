// widgets/npk_display.dart - UPDATED: With NPK sensor connection tracking

import 'package:flutter/material.dart';
import '../screens/fertilizer_recommendations_page.dart'; // Add this

class NPKDisplay extends StatelessWidget {
  final int? nitrogen;
  final int? phosphorus;
  final int? potassium;
  final bool isConnected;

  const NPKDisplay({
    super.key,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.isConnected = false,
  });

  bool get npkSensorConnected =>
      nitrogen != null && phosphorus != null && potassium != null;

  String _getNutrientLevel(int? value, String nutrient) {
    if (value == null) return 'N/A';
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

  Color _getNutrientColor(int? value, String nutrient) {
    if (!isConnected || value == null) return Colors.grey;
    final level = _getNutrientLevel(value, nutrient);
    switch (level) {
      case 'Low':
        return const Color(0xFFFF5722);
      case 'Medium':
        return const Color(0xFFFF9800);
      case 'Optimal':
        return const Color(0xFF4CAF50);
      case 'High':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }

  IconData _getNutrientIcon(String nutrient) {
    switch (nutrient) {
      case 'N':
        return Icons.grass;
      case 'P':
        return Icons.local_florist;
      case 'K':
        return Icons.spa;
      default:
        return Icons.eco;
    }
  }

  String _getNutrientDescription(String nutrient) {
    switch (nutrient) {
      case 'N':
        return 'Promotes leaf growth and green color';
      case 'P':
        return 'Supports root development and flowering';
      case 'K':
        return 'Enhances disease resistance and water regulation';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.science,
                    color: Color(0xFF8D6E63),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Soil Nutrients (NPK)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        'Essential macronutrients for plant growth',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (npkSensorConnected && isConnected)
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (npkSensorConnected && isConnected)
                            ? Icons.sensors
                            : Icons.sensors_off,
                        size: 12,
                        color: (npkSensorConnected && isConnected)
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (npkSensorConnected && isConnected)
                            ? 'Connected'
                            : 'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          color: (npkSensorConnected && isConnected)
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
            const SizedBox(height: 16),
            _buildNutrientRow(
              nutrient: 'N',
              label: 'Nitrogen',
              value: nitrogen,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            _buildNutrientRow(
              nutrient: 'P',
              label: 'Phosphorus',
              value: phosphorus,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            _buildNutrientRow(
              nutrient: 'K',
              label: 'Potassium',
              value: potassium,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8D6E63).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8D6E63).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRatioBox('N', nitrogen, Colors.green),
                  const Text(
                    ':',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildRatioBox('P', phosphorus, Colors.orange),
                  const Text(
                    ':',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildRatioBox('K', potassium, Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (npkSensorConnected && isConnected)
                    ? Colors.blue.shade50
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: (npkSensorConnected && isConnected)
                      ? Colors.blue.shade200
                      : Colors.grey.shade400,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    (npkSensorConnected && isConnected)
                        ? Icons.info_outline
                        : Icons.warning_amber,
                    color: (npkSensorConnected && isConnected)
                        ? Colors.blue.shade700
                        : Colors.grey.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (npkSensorConnected && isConnected)
                          ? 'Values in mg/kg (ppm). Monitor regularly for optimal nutrient balance.'
                          : 'NPK sensor disconnected. Check RS485 wiring (RX:18, TX:19, DE/RE:23) and power.',
                      style: TextStyle(
                        fontSize: 11,
                        color: (npkSensorConnected && isConnected)
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
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

  Widget _buildNutrientRow({
    required String nutrient,
    required String label,
    required int? value,
    required bool isDarkMode,
  }) {
    final color = _getNutrientColor(value, nutrient);
    final level = _getNutrientLevel(value, nutrient);
    final icon = _getNutrientIcon(nutrient);
    final description = _getNutrientDescription(nutrient);
    final sensorActive = npkSensorConnected && isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(sensorActive ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(sensorActive ? 0.3 : 0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$label ($nutrient)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            level,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: value != null ? (value / 300).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: color.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                value != null ? '$value mg/kg' : 'N/A',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioBox(String label, int? value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value != null ? value.toString() : '--',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
