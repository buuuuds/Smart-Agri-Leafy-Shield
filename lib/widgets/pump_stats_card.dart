import 'package:flutter/material.dart';

class PumpStatsCard extends StatelessWidget {
  final bool isPumpRunning;
  final String currentPumpMode; // "irrigation", "misting", or "none"

  // Irrigation stats
  final int irrigationRuntime; // in seconds
  final int irrigationCycles;

  // Misting stats
  final int mistingRuntime; // in seconds
  final int mistingCycles;

  final String pumpMode; // "soil" or "humidity"
  final bool isConnected;

  const PumpStatsCard({
    super.key,
    required this.isPumpRunning,
    required this.currentPumpMode,
    required this.irrigationRuntime,
    required this.irrigationCycles,
    required this.mistingRuntime,
    required this.mistingCycles,
    required this.pumpMode,
    required this.isConnected,
  });

  String _formatRuntime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes}m ${secs}s';
    }
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  Color _getPumpStatusColor() {
    if (!isConnected) return Colors.grey;
    if (!isPumpRunning) return Colors.green;

    if (currentPumpMode == "irrigation") return Colors.blue;
    if (currentPumpMode == "misting") return Colors.cyan;
    return Colors.orange;
  }

  IconData _getPumpStatusIcon() {
    if (!isConnected) return Icons.device_unknown;
    if (!isPumpRunning) return Icons.water_drop_outlined;

    if (currentPumpMode == "irrigation") return Icons.water_drop;
    if (currentPumpMode == "misting") return Icons.cloud;
    return Icons.water;
  }

  String _getPumpStatusText() {
    if (!isConnected) return 'OFFLINE';
    if (!isPumpRunning) return 'IDLE';

    if (currentPumpMode == "irrigation") return 'IRRIGATING';
    if (currentPumpMode == "misting") return 'MISTING';
    return 'RUNNING';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getPumpStatusColor().withOpacity(0.05),
              Colors.white.withOpacity(isDarkMode ? 0.02 : 1.0),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getPumpStatusColor().withOpacity(0.3),
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
                    color: _getPumpStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPumpStatusIcon(),
                    color: _getPumpStatusColor(),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pump Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getPumpStatusColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getPumpStatusText(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _getPumpStatusColor(),
                            ),
                          ),
                          if (isPumpRunning) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getPumpStatusColor().withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                currentPumpMode == "irrigation"
                                    ? '30s cycle'
                                    : '15s cycle',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getPumpStatusColor(),
                                ),
                              ),
                            ),
                          ],
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

            // IRRIGATION STATS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.water_drop,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '💧 Irrigation Stats',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Total Runtime',
                          _formatRuntime(irrigationRuntime),
                          Icons.timer,
                          Colors.blue,
                          isDarkMode,
                        ),
                      ),
                      Container(width: 1, height: 50, color: Colors.blue[200]),
                      Expanded(
                        child: _buildStatItem(
                          'Cycles',
                          irrigationCycles.toString(),
                          Icons.repeat,
                          Colors.blue,
                          isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // MISTING STATS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyan.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud, color: Colors.cyan, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '💨 Misting Stats',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Total Runtime',
                          _formatRuntime(mistingRuntime),
                          Icons.timer,
                          Colors.cyan,
                          isDarkMode,
                        ),
                      ),
                      Container(width: 1, height: 50, color: Colors.cyan[200]),
                      Expanded(
                        child: _buildStatItem(
                          'Cycles',
                          mistingCycles.toString(),
                          Icons.repeat,
                          Colors.cyan,
                          isDarkMode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Mode info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pumpMode == "soil"
                          ? '🌱 Auto mode: Soil moisture triggers 30s irrigation'
                          : '💨 Auto mode: Humidity triggers 15s misting',
                      style: TextStyle(fontSize: 11, color: Colors.green[700]),
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
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
