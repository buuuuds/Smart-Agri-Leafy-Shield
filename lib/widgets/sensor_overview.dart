// widgets/sensor_overview.dart - Fixed to show only 4 main sensors

import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../services/plant_service.dart' as plant;
import '../services/firebase_service.dart' as firebase;

class SensorOverview extends StatelessWidget {
  final double? temperature;
  final int? soilMoisture;
  final int? lightIntensity;
  final int? humidity;
  final Plant? currentPlant;
  final bool isConnected;
  final firebase.SensorStatus? sensorStatus;

  const SensorOverview({
    super.key,
    required this.temperature,
    required this.soilMoisture,
    required this.lightIntensity,
    required this.humidity,
    this.currentPlant,
    this.isConnected = false,
    this.sensorStatus,
  });

  Color _getSensorColor(dynamic value, String sensorType, bool isConnected) {
    if (!isConnected) return const Color(0xFFFF5722);

    if (value == null || (value is num && value == 0)) {
      return const Color(0xFFFF9800);
    }

    if (currentPlant == null) return const Color(0xFF4CAF50);

    switch (sensorType) {
      case 'temperature':
        final temp = value as double;
        final status = plant.PlantService.getTemperatureStatus(
          currentPlant!,
          temp,
        );
        switch (status) {
          case plant.TemperatureStatus.cold:
            return const Color(0xFF2196F3);
          case plant.TemperatureStatus.optimal:
            return const Color(0xFF4CAF50);
          case plant.TemperatureStatus.warning:
            return const Color(0xFFFF9800);
          case plant.TemperatureStatus.hot:
            return const Color(0xFFFF5722);
        }
      case 'soilMoisture':
        final moisture = value as int;
        final status = plant.PlantService.getSoilMoistureStatus(
          currentPlant!,
          moisture,
        );
        switch (status) {
          case plant.SensorStatus.low:
            return const Color(0xFFFF5722);
          case plant.SensorStatus.optimal:
            return const Color(0xFF4CAF50);
          case plant.SensorStatus.high:
            return const Color(0xFFFF9800);
        }
      case 'humidity':
        final humid = value as int;
        final status = plant.PlantService.getHumidityStatus(
          currentPlant!,
          humid,
        );
        switch (status) {
          case plant.SensorStatus.low:
            return const Color(0xFFFF5722);
          case plant.SensorStatus.optimal:
            return const Color(0xFF4CAF50);
          case plant.SensorStatus.high:
            return const Color(0xFFFF9800);
        }
      case 'light':
        final light = value as int;
        final status = plant.PlantService.getLightStatus(currentPlant!, light);
        switch (status) {
          case plant.SensorStatus.low:
            return const Color(0xFFFF5722);
          case plant.SensorStatus.optimal:
            return const Color(0xFF4CAF50);
          case plant.SensorStatus.high:
            return const Color(0xFFFF9800);
        }
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String _getSensorStatusText(
    dynamic value,
    String sensorType,
    bool isConnected,
  ) {
    if (!isConnected) return 'Disconnected';

    if (value == null || (value is num && value == 0)) {
      return 'No Reading';
    }

    if (currentPlant == null) return 'OK';

    switch (sensorType) {
      case 'temperature':
        final temp = value as double;
        final status = plant.PlantService.getTemperatureStatus(
          currentPlant!,
          temp,
        );
        switch (status) {
          case plant.TemperatureStatus.cold:
            return 'Too Cold';
          case plant.TemperatureStatus.optimal:
            return 'Optimal';
          case plant.TemperatureStatus.warning:
            return 'Getting Hot';
          case plant.TemperatureStatus.hot:
            return 'Too Hot';
        }
      case 'soilMoisture':
        final moisture = value as int;
        final status = plant.PlantService.getSoilMoistureStatus(
          currentPlant!,
          moisture,
        );
        switch (status) {
          case plant.SensorStatus.low:
            return 'Too Dry';
          case plant.SensorStatus.optimal:
            return 'Optimal';
          case plant.SensorStatus.high:
            return 'Too Wet';
        }
      case 'humidity':
        final humid = value as int;
        final status = plant.PlantService.getHumidityStatus(
          currentPlant!,
          humid,
        );
        switch (status) {
          case plant.SensorStatus.low:
            return 'Too Low';
          case plant.SensorStatus.optimal:
            return 'Optimal';
          case plant.SensorStatus.high:
            return 'Too High';
        }
      case 'light':
        final light = value as int;
        final status = plant.PlantService.getLightStatus(currentPlant!, light);
        switch (status) {
          case plant.SensorStatus.low:
            return 'Too Dark';
          case plant.SensorStatus.optimal:
            return 'Optimal';
          case plant.SensorStatus.high:
            return 'Too Bright';
        }
      default:
        return 'OK';
    }
  }

  String _formatValue(dynamic value, String unit, bool isConnected) {
    if (!isConnected) return 'N/A';
    if (value == null) return '-- $unit';
    return '$value$unit';
  }

  @override
  Widget build(BuildContext context) {
    final tempConnected = sensorStatus?.temperatureConnected ?? true;
    final humidityConnected = sensorStatus?.humidityConnected ?? true;
    final soilConnected = sensorStatus?.soilConnected ?? true;
    final lightConnected = sensorStatus?.lightConnected ?? true;

    final sensors = [
      {
        'icon': Icons.thermostat,
        'label': 'Temperature',
        'value': _formatValue(temperature, '°C', tempConnected),
        'color': _getSensorColor(temperature, 'temperature', tempConnected),
        'status': _getSensorStatusText(
          temperature,
          'temperature',
          tempConnected,
        ),
        'isConnected': tempConnected,
        'hasValidData': temperature != null && temperature! > 0,
      },
      {
        'icon': Icons.water_drop,
        'label': 'Soil Moisture',
        'value': _formatValue(soilMoisture, '%', soilConnected),
        'color': _getSensorColor(soilMoisture, 'soilMoisture', soilConnected),
        'status': _getSensorStatusText(
          soilMoisture,
          'soilMoisture',
          soilConnected,
        ),
        'isConnected': soilConnected,
        'hasValidData': soilMoisture != null && soilMoisture! > 0,
      },
      {
        'icon': Icons.wb_sunny,
        'label': 'Light Intensity',
        'value': _formatValue(lightIntensity, ' lux', lightConnected),
        'color': _getSensorColor(lightIntensity, 'light', lightConnected),
        'status': _getSensorStatusText(lightIntensity, 'light', lightConnected),
        'isConnected': lightConnected,
        'hasValidData': lightIntensity != null && lightIntensity! > 0,
      },
      {
        'icon': Icons.opacity,
        'label': 'Humidity',
        'value': _formatValue(humidity, '%', humidityConnected),
        'color': _getSensorColor(humidity, 'humidity', humidityConnected),
        'status': _getSensorStatusText(humidity, 'humidity', humidityConnected),
        'isConnected': humidityConnected,
        'hasValidData': humidity != null && humidity! > 0,
      },
    ];

    int connectedCount = 0;
    if (tempConnected) connectedCount++;
    if (humidityConnected) connectedCount++;
    if (soilConnected) connectedCount++;
    if (lightConnected) connectedCount++;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '📊 Sensor Readings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getOverallStatusColor(connectedCount).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getOverallStatusIcon(connectedCount),
                    size: 14,
                    color: _getOverallStatusColor(connectedCount),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$connectedCount/4 Connected',
                    style: TextStyle(
                      color: _getOverallStatusColor(connectedCount),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: sensors.length,
          itemBuilder: (context, index) {
            final sensor = sensors[index];
            final isConnected = sensor['isConnected'] as bool;
            final hasValidData = sensor['hasValidData'] as bool;

            return Card(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (sensor['color'] as Color).withOpacity(
                        isConnected && hasValidData ? 0.1 : 0.05,
                      ),
                      Colors.white,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (sensor['color'] as Color).withOpacity(
                      isConnected ? 0.3 : 0.1,
                    ),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            Icon(
                              sensor['icon'] as IconData,
                              color: isConnected && hasValidData
                                  ? sensor['color'] as Color
                                  : Colors.grey[400],
                              size: 28,
                            ),
                            if (!isConnected)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 8,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isConnected && hasValidData
                                ? sensor['color'] as Color
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      sensor['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: isConnected
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sensor['value'] as String,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isConnected && hasValidData
                            ? sensor['color'] as Color
                            : Colors.grey[400],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (sensor['color'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        sensor['status'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sensor['color'] as Color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getOverallStatusColor(int connectedCount) {
    if (connectedCount == 4) return const Color(0xFF4CAF50);
    if (connectedCount >= 2) return const Color(0xFFFF9800);
    return const Color(0xFFFF5722);
  }

  IconData _getOverallStatusIcon(int connectedCount) {
    if (connectedCount == 4) return Icons.check_circle;
    if (connectedCount >= 2) return Icons.warning;
    return Icons.error;
  }
}
