// lib/widgets/threshold_settings_card.dart - NEW FILE

import 'package:flutter/material.dart';
import '../widgets/threshold_slider.dart';

class ThresholdSettingsCard extends StatelessWidget {
  final double temperatureThreshold;
  final double soilMoistureThreshold;
  final double humidityThreshold;
  final double lightIntensityThreshold;

  final Function(double) onTemperatureChanged;
  final Function(double) onSoilMoistureChanged;
  final Function(double) onHumidityChanged;
  final Function(double) onLightIntensityChanged;

  const ThresholdSettingsCard({
    super.key,
    required this.temperatureThreshold,
    required this.soilMoistureThreshold,
    required this.humidityThreshold,
    required this.lightIntensityThreshold,
    required this.onTemperatureChanged,
    required this.onSoilMoistureChanged,
    required this.onHumidityChanged,
    required this.onLightIntensityChanged,
  });

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
                const Icon(Icons.tune, color: Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                Text(
                  'Auto Control Thresholds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'System triggers actions when sensors exceed these values',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // 🌡️ TEMPERATURE
            ThresholdSlider(
              temperatureThreshold: temperatureThreshold,
              onThresholdChanged: onTemperatureChanged,
              label: 'Temperature Threshold',
              icon: Icons.thermostat,
              min: 20.0,
              max: 40.0,
              unit: '°C',
              subtitle: 'Shade deploys when temp exceeds this',
            ),

            const SizedBox(height: 16),

            // 💧 SOIL MOISTURE
            ThresholdSlider(
              temperatureThreshold: soilMoistureThreshold,
              onThresholdChanged: onSoilMoistureChanged,
              label: 'Soil Moisture Threshold',
              icon: Icons.water_drop,
              min: 10.0,
              max: 60.0,
              unit: '%',
              subtitle: 'Water pump starts when soil drops below this',
            ),

            const SizedBox(height: 16),

            // 💨 HUMIDITY
            ThresholdSlider(
              temperatureThreshold: humidityThreshold,
              onThresholdChanged: onHumidityChanged,
              label: 'Humidity Threshold',
              icon: Icons.opacity,
              min: 30.0,
              max: 80.0,
              unit: '%',
              subtitle: 'Mist pump starts when humidity drops below this',
            ),

            const SizedBox(height: 16),

            // ☀️ LIGHT INTENSITY
            ThresholdSlider(
              temperatureThreshold: lightIntensityThreshold,
              onThresholdChanged: onLightIntensityChanged,
              label: 'Light Intensity Threshold',
              icon: Icons.wb_sunny,
              min: 5000.0,
              max: 50000.0,
              unit: ' lux',
              subtitle: 'Shade deploys when light exceeds this',
            ),

            const SizedBox(height: 16),

            // Info box
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
                      'Thresholds sync to ESP32 automatically. Changes apply immediately in Auto mode.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
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
}
