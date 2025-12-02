// lib/widgets/water_level_card.dart - NEW FILE FOR WATER LEVEL DISPLAY

import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaterLevelCard extends StatelessWidget {
  final int? waterPercent;
  final double? waterLevel; // in cm
  final double? waterDistance; // distance from sensor to water
  final bool isConnected;
  final int tankHeight; // total tank height in cm
  final int lowThreshold; // warning threshold

  const WaterLevelCard({
    super.key,
    required this.waterPercent,
    this.waterLevel,
    this.waterDistance,
    required this.isConnected,
    this.tankHeight = 45,
    this.lowThreshold = 20,
  });

  Color _getWaterLevelColor() {
    if (!isConnected || waterPercent == null) return Colors.grey;
    if (waterPercent! < lowThreshold) return const Color(0xFFFF5722);
    if (waterPercent! < 40) return const Color(0xFFFF9800);
    if (waterPercent! < 60) return const Color(0xFF2196F3);
    return const Color(0xFF4CAF50);
  }

  IconData _getWaterLevelIcon() {
    if (!isConnected || waterPercent == null) return Icons.water_drop_outlined;
    if (waterPercent! < lowThreshold) return Icons.water_drop;
    if (waterPercent! < 40) return Icons.opacity;
    if (waterPercent! < 60) return Icons.water;
    return Icons.water_drop;
  }

  String _getWaterLevelStatus() {
    if (!isConnected) return 'SENSOR OFFLINE';
    if (waterPercent == null) return 'NO DATA';
    if (waterPercent! < lowThreshold) return 'CRITICALLY LOW';
    if (waterPercent! < 40) return 'LOW';
    if (waterPercent! < 60) return 'MEDIUM';
    if (waterPercent! < 80) return 'GOOD';
    return 'FULL';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getWaterLevelColor();
    final isLowWater = waterPercent != null && waterPercent! < lowThreshold;

    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.05),
              Colors.white.withOpacity(isDarkMode ? 0.02 : 1.0),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(isLowWater ? 0.6 : 0.3),
            width: isLowWater ? 3 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getWaterLevelIcon(),
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💧 Water Tank Level',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getWaterLevelStatus(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Connection Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isConnected && waterPercent != null)
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (isConnected && waterPercent != null)
                            ? Icons.sensors
                            : Icons.sensors_off,
                        size: 12,
                        color: (isConnected && waterPercent != null)
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (isConnected && waterPercent != null)
                            ? 'ACTIVE'
                            : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          color: (isConnected && waterPercent != null)
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

            const SizedBox(height: 24),

            // Main Water Level Display
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Animated Water Tank Visualization
                Expanded(
                  flex: 2,
                  child: _buildWaterTankVisualization(isDarkMode, statusColor),
                ),
                const SizedBox(width: 24),

                // Percentage Display
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Big Percentage Number
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            waterPercent != null
                                ? waterPercent.toString()
                                : '--',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '%',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: statusColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Water Level in CM
                      if (waterLevel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${waterLevel!.toStringAsFixed(1)} cm / $tankHeight cm',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Distance from Sensor
                      if (waterDistance != null)
                        Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              size: 14,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Distance: ${waterDistance!.toStringAsFixed(1)} cm',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Tank Capacity',
                    '$tankHeight cm',
                    Icons.height,
                    Colors.blue,
                    isDarkMode,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Expanded(
                  child: _buildStatItem(
                    'Low Alert',
                    '$lowThreshold%',
                    Icons.warning_amber,
                    Colors.orange,
                    isDarkMode,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.grey[300]),
                Expanded(
                  child: _buildStatItem(
                    'Sensor',
                    'HC-SR04',
                    Icons.sensors,
                    Colors.green,
                    isDarkMode,
                  ),
                ),
              ],
            ),

            // Warning Banner (if low water)
            if (isLowWater) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠️ LOW WATER WARNING',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pumps will stop automatically. Refill tank immediately!',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Info Box
            if (!isLowWater) ...[
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
                        'Ultrasonic sensor measures water level every 5 seconds. Pumps auto-stop when level drops below $lowThreshold%.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
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
    );
  }

  Widget _buildWaterTankVisualization(bool isDarkMode, Color statusColor) {
    final fillPercent = (waterPercent ?? 0) / 100.0;

    return Column(
      children: [
        // Tank Container
        Container(
          height: 150,
          width: 80,
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background
                Container(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),

                // Water Fill (Animated)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  height: 150 * fillPercent,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [statusColor.withOpacity(0.7), statusColor],
                    ),
                  ),
                  child: CustomPaint(
                    painter: WavePainter(
                      color: statusColor,
                      animation: fillPercent,
                    ),
                  ),
                ),

                // Percentage Markers
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTankMarker('100%', isDarkMode),
                      _buildTankMarker('75%', isDarkMode),
                      _buildTankMarker('50%', isDarkMode),
                      _buildTankMarker('25%', isDarkMode),
                      _buildTankMarker('0%', isDarkMode),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Label
        Text(
          'Tank View',
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTankMarker(String label, bool isDarkMode) {
    return Container(
      height: 1,
      color: isDarkMode
          ? Colors.grey[600]!.withOpacity(0.3)
          : Colors.grey[400]!.withOpacity(0.3),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// Wave Animation Painter for Water Effect
class WavePainter extends CustomPainter {
  final Color color;
  final double animation;

  WavePainter({required this.color, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Create wave effect
    path.moveTo(0, size.height * 0.1);

    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        size.height * 0.1 +
            math.sin(
                  (i / size.width * 2 * math.pi) + (animation * 2 * math.pi),
                ) *
                5,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.animation != animation;
}
